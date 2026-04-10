"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";
import { logDebug, logDebugError } from "@/lib/debug";
import { shouldReconnectForStatus, type ChannelHealth } from "@/lib/realtime";
import {
  COMMAND_ACK_TIMEOUT_MS,
  MAC_PRESENCE_STALE_MS,
  REALTIME_PROTOCOL_VERSION,
  type CommandAck,
  type CommandEnvelope,
  type CommandKind,
  type CommandPayloadMap,
  type CommandResult,
  type MacSessionPresence,
  type RealtimeLogPayload,
  type UserChannelPresence,
  type WebSessionPresence,
} from "@/lib/realtime-protocol";

export type SimulatorCard = {
  id: string;
  name: string;
  osVersion: string;
  deviceTypeIdentifier: string;
  userEmail: string;
  startedAt: string;
  orderIndex: number;
};

export type PresenceSyncState = "syncing" | "live" | "stale" | "offline";

type PendingCommand = {
  kind: CommandKind;
  waitForResult: boolean;
  resultTimeoutMs: number;
  ackTimer: ReturnType<typeof setTimeout>;
  resultTimer?: ReturnType<typeof setTimeout>;
  resolve: (value: { ack: CommandAck; result?: CommandResult }) => void;
  reject: (error: Error) => void;
  ack?: CommandAck;
};

type SendCommandOptions<K extends CommandKind> = {
  kind: K;
  udid?: string | null;
  payload: CommandPayloadMap[K];
  waitForResult?: boolean;
  resultTimeoutMs?: number;
};

function buildMacSignature(sessions: MacSessionPresence[]) {
  return sessions
    .map(session => `${session.session_id}:${session.presence_version}`)
    .sort()
    .join("|");
}

function getPageVisible() {
  if (typeof document === "undefined") return true;
  return !document.hidden;
}

function formatCommandFailureReason(reason?: string | null) {
  if (!reason) {
    return "The mac app reported that the command failed.";
  }

  const normalized = reason.toLowerCase();
  if (
    normalized.includes("could not find the 'status' column") ||
    normalized.includes("column \"status\" does not exist") ||
    normalized.includes("could not find the 'error_message' column") ||
    normalized.includes("column \"error_message\" does not exist")
  ) {
    return "The Supabase media schema is missing the latest screenshot/recording status columns. Apply the latest migration, or use the updated mac app compatibility fallback.";
  }

  return reason;
}

export function formatDuration(isoTimestamp: string): string {
  const diffMs = Date.now() - new Date(isoTimestamp).getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h ${minutes % 60}m`;
}

export function useUserRealtimeChannel(
  userId: string,
  watchingUdid: string | null,
  channelHealth?: ChannelHealth,
  onLogReceived?: (payload: RealtimeLogPayload) => void,
) {
  const dashboardSessionIdRef = useRef(crypto.randomUUID());
  const openedAtRef = useRef(new Date().toISOString());
  const channelRef = useRef<RealtimeChannel | null>(null);
  const pendingCommandsRef = useRef<Map<string, PendingCommand>>(new Map());
  const watchingUdidRef = useRef(watchingUdid);
  const onLogReceivedRef = useRef(onLogReceived);
  const macSignatureRef = useRef("");
  const macOnlineRef = useRef(false);
  const pageVisibleRef = useRef(getPageVisible());
  const [pageVisible, setPageVisible] = useState(pageVisibleRef.current);
  const [cards, setCards] = useState<SimulatorCard[]>([]);
  const [streamingUdids, setStreamingUdids] = useState<Set<string>>(new Set());
  const [channelStatus, setChannelStatus] = useState<string>("CONNECTING");
  const [lastSyncAt, setLastSyncAt] = useState<string | null>(null);
  const [lastMacSignalAt, setLastMacSignalAt] = useState<string | null>(null);
  const [macOnline, setMacOnline] = useState(false);
  const [clock, setClock] = useState(Date.now());

  watchingUdidRef.current = watchingUdid;
  onLogReceivedRef.current = onLogReceived;

  useEffect(() => {
    const interval = window.setInterval(() => setClock(Date.now()), 5000);
    return () => window.clearInterval(interval);
  }, []);

  useEffect(() => {
    const updateVisibility = () => {
      const next = getPageVisible();
      pageVisibleRef.current = next;
      setPageVisible(next);
    };

    document.addEventListener("visibilitychange", updateVisibility);
    window.addEventListener("focus", updateVisibility);
    window.addEventListener("blur", updateVisibility);
    return () => {
      document.removeEventListener("visibilitychange", updateVisibility);
      window.removeEventListener("focus", updateVisibility);
      window.removeEventListener("blur", updateVisibility);
    };
  }, []);

  const syncMacPresence = useCallback((channel: RealtimeChannel) => {
    const state = channel.presenceState<UserChannelPresence>();
    const seen = new Map<string, SimulatorCard>();
    const foundStreamingUdids = new Set<string>();
    const macSessions: MacSessionPresence[] = [];

    for (const entries of Object.values(state)) {
      for (const entry of entries) {
        if (entry.session_type !== "mac") {
          continue;
        }

        macSessions.push(entry as MacSessionPresence);
        for (const udid of entry.streaming_udids ?? []) {
          foundStreamingUdids.add(udid);
        }
        for (const sim of entry.simulators ?? []) {
          const existing = seen.get(sim.udid);
          if (!existing || entry.started_at > existing.startedAt) {
            seen.set(sim.udid, {
              id: sim.udid,
              name: sim.name,
              osVersion: sim.os_version,
              deviceTypeIdentifier: sim.device_type_identifier,
              userEmail: entry.user_email,
              startedAt: entry.started_at,
              orderIndex: sim.order_index ?? 0,
            });
          }
        }
      }
    }

    const nextCards = Array.from(seen.values()).sort((a, b) => a.orderIndex - b.orderIndex);
    const nextSignature = buildMacSignature(macSessions);
    const now = new Date().toISOString();

    const wasMacOnline = macOnlineRef.current;
    setCards(nextCards);
    setStreamingUdids(foundStreamingUdids);
    setMacOnline(macSessions.length > 0);
    macOnlineRef.current = macSessions.length > 0;
    if (macSessions.length > 0) {
      setLastMacSignalAt(now);
    }

    if (nextSignature !== macSignatureRef.current || (macSessions.length === 0 && wasMacOnline)) {
      macSignatureRef.current = nextSignature;
      setLastSyncAt(now);
    }

    logDebug("presence", "presence sync applied", {
      userId,
      macSessionCount: macSessions.length,
      simulators: nextCards.map(card => ({
        udid: card.id,
        name: card.name,
        osVersion: card.osVersion,
      })),
      streamingUdids: Array.from(foundStreamingUdids),
      signature: nextSignature,
    });
  }, [userId]);

  const trackWebPresence = useCallback(async () => {
    const channel = channelRef.current;
    if (!channel || channel.state !== "joined") return;

    const payload: WebSessionPresence = {
      session_type: "web",
      dashboard_session_id: dashboardSessionIdRef.current,
      opened_at: openedAtRef.current,
      watching_udid: watchingUdidRef.current,
      page_visible: pageVisibleRef.current,
    };

    try {
      await channel.track(payload);
      logDebug("presence", "tracked web dashboard presence", {
        userId,
        dashboardSessionId: dashboardSessionIdRef.current,
        watchingUdid: watchingUdidRef.current,
        pageVisible: pageVisibleRef.current,
      });
    } catch (error) {
      logDebugError("presence", "failed to track web dashboard presence", error, {
        userId,
        dashboardSessionId: dashboardSessionIdRef.current,
      });
    }
  }, [userId]);

  useEffect(() => {
    void trackWebPresence();
  }, [trackWebPresence, watchingUdid, pageVisible]);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase.channel(`user:${userId}`);
    channelRef.current = channel;
    channelHealth?.register(channel);
    setChannelStatus("CONNECTING");
    macSignatureRef.current = "";
    macOnlineRef.current = false;
    logDebug("presence", "opening shared user realtime channel", {
      userId,
      reconnectKey: channelHealth?.reconnectKey ?? 0,
      topic: channel.topic,
    });

    channel
      .on("presence", { event: "sync" }, () => syncMacPresence(channel))
      .on("presence", { event: "join" }, () => syncMacPresence(channel))
      .on("presence", { event: "leave" }, () => syncMacPresence(channel))
      .on("broadcast", { event: "command_ack" }, (event) => {
        const ack = event.payload as CommandAck | undefined;
        if (!ack) return;
        setLastMacSignalAt(new Date().toISOString());
        const pending = pendingCommandsRef.current.get(ack.command_id);
        if (!pending) return;

        clearTimeout(pending.ackTimer);
        pending.ack = ack;

        if (ack.status === "rejected") {
          pendingCommandsRef.current.delete(ack.command_id);
          if (pending.resultTimer) {
            clearTimeout(pending.resultTimer);
          }
          pending.reject(new Error(ack.reason ?? "The mac app rejected this command."));
          return;
        }

        if (!pending.waitForResult) {
          pendingCommandsRef.current.delete(ack.command_id);
          pending.resolve({ ack });
          return;
        }

        pending.resultTimer = setTimeout(() => {
          pendingCommandsRef.current.delete(ack.command_id);
          pending.reject(new Error("The mac app acknowledged the command, but no result arrived in time."));
        }, pending.resultTimeoutMs);
      })
      .on("broadcast", { event: "command_result" }, (event) => {
        const result = event.payload as CommandResult | undefined;
        if (!result) return;
        setLastMacSignalAt(new Date().toISOString());
        const pending = pendingCommandsRef.current.get(result.command_id);
        if (!pending || !pending.ack) return;

        if (pending.resultTimer) {
          clearTimeout(pending.resultTimer);
        }
        pendingCommandsRef.current.delete(result.command_id);

        if (result.status === "failed") {
          pending.reject(new Error(formatCommandFailureReason(result.reason)));
          return;
        }

        pending.resolve({ ack: pending.ack, result });
      })
      .on("broadcast", { event: "log" }, (event) => {
        const payload = event.payload as RealtimeLogPayload | undefined;
        if (!payload?.udid) return;
        setLastMacSignalAt(new Date().toISOString());
        onLogReceivedRef.current?.(payload);
      })
      .subscribe(async (status, err) => {
        if (err) {
          setChannelStatus(status);
          logDebugError("presence", "shared user realtime channel reported an error", err, {
            userId,
            status,
            topic: channel.topic,
          });
          channelHealth?.requestReconnect("user-channel-error", {
            userId,
            status,
            topic: channel.topic,
          });
          return;
        }

        setChannelStatus(status);
        logDebug("presence", "shared user realtime channel status changed", {
          userId,
          status,
          topic: channel.topic,
        });

        if (status === "SUBSCRIBED") {
          await trackWebPresence();
          syncMacPresence(channel);
        }

        if (shouldReconnectForStatus(status)) {
          channelHealth?.requestReconnect("user-channel-status", {
            userId,
            status,
            topic: channel.topic,
          });
        }
      });

    return () => {
      channelHealth?.unregister(channel);
      channelRef.current = null;
      pendingCommandsRef.current.forEach((pending) => {
        clearTimeout(pending.ackTimer);
        if (pending.resultTimer) {
          clearTimeout(pending.resultTimer);
        }
        pending.reject(new Error("Realtime session was closed before the command completed."));
      });
      pendingCommandsRef.current.clear();
      logDebug("presence", "closing shared user realtime channel", {
        userId,
        topic: channel.topic,
      });
      void channel.unsubscribe();
      supabase.removeChannel(channel);
    };
  }, [syncMacPresence, trackWebPresence, userId, channelHealth?.reconnectKey]);

  const syncState: PresenceSyncState = useMemo(() => {
    if (channelStatus !== "SUBSCRIBED") {
      return lastSyncAt || cards.length > 0 ? "stale" : "syncing";
    }

    if (!macOnline) {
      if (!lastSyncAt) {
        return "syncing";
      }

      if (lastMacSignalAt && clock - new Date(lastMacSignalAt).getTime() <= MAC_PRESENCE_STALE_MS) {
        return "stale";
      }

      return "offline";
    }

    if (!lastSyncAt) {
      return "syncing";
    }

    return clock - new Date(lastSyncAt).getTime() > MAC_PRESENCE_STALE_MS ? "stale" : "live";
  }, [cards.length, channelStatus, clock, lastMacSignalAt, lastSyncAt, macOnline]);

  const sendCommand = useCallback(async <K extends CommandKind>({
    kind,
    udid = null,
    payload,
    waitForResult = false,
    resultTimeoutMs = 12000,
  }: SendCommandOptions<K>) => {
    const channel = channelRef.current;
    if (!channel || syncState !== "live" || !macOnline) {
      throw new Error("The mac app is offline or realtime sync is still reconnecting.");
    }

    const commandId = crypto.randomUUID();
    const envelope: CommandEnvelope<K> = {
      protocol_version: REALTIME_PROTOCOL_VERSION,
      command_id: commandId,
      dashboard_session_id: dashboardSessionIdRef.current,
      kind,
      udid,
      payload,
      sent_at: new Date().toISOString(),
    };

    logDebug("command", "sending realtime command", {
      commandId,
      kind,
      udid,
      waitForResult,
      dashboardSessionId: dashboardSessionIdRef.current,
    });

    const promise = new Promise<{ ack: CommandAck; result?: CommandResult }>((resolve, reject) => {
      const ackTimer = setTimeout(() => {
        pendingCommandsRef.current.delete(commandId);
        reject(new Error("The mac app did not acknowledge the command within 5 seconds."));
      }, COMMAND_ACK_TIMEOUT_MS);

      pendingCommandsRef.current.set(commandId, {
        kind,
        waitForResult,
        resultTimeoutMs,
        ackTimer,
        resolve,
        reject,
      });
    });

    const sendStatus = await channel.send({
      type: "broadcast",
      event: "command",
      payload: envelope,
    });

    if (sendStatus !== "ok") {
      const pending = pendingCommandsRef.current.get(commandId);
      if (pending) {
        clearTimeout(pending.ackTimer);
        if (pending.resultTimer) {
          clearTimeout(pending.resultTimer);
        }
      }
      pendingCommandsRef.current.delete(commandId);
      throw new Error("Realtime command delivery failed before the mac app could receive it.");
    }

    return promise;
  }, [macOnline, syncState]);

  return {
    cards,
    streamingUdids,
    syncState,
    lastSyncAt,
    macOnline,
    dashboardSessionId: dashboardSessionIdRef.current,
    sendCommand,
  };
}
