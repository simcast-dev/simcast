"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { logDebug, logDebugError } from "@/lib/debug";
import { shouldReconnectForStatus, type ChannelHealth } from "@/lib/realtime";


export type SimulatorPresence = {
  udid: string;
  name: string;
  os_version: string;
  device_type_identifier: string;
  order_index?: number;
};

export type SessionPresence = {
  session_id: string;
  user_email: string;
  started_at: string;
  simulators: SimulatorPresence[];
  streaming_udid?: string | null;
};

export type SimulatorCard = {
  id: string;
  name: string;
  osVersion: string;
  deviceTypeIdentifier: string;
  userEmail: string;
  startedAt: string;
  orderIndex: number;
};

export type PresenceSyncState = "syncing" | "live" | "stale";

export function formatDuration(isoTimestamp: string): string {
  const diffMs = Date.now() - new Date(isoTimestamp).getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h ${minutes % 60}m`;
}

export function usePresenceSubscription(
  userId: string,
  onStreamingChange?: (udids: Set<string>) => void,
  channelHealth?: ChannelHealth,
) {
  const [cards, setCards] = useState<SimulatorCard[]>([]);
  const [streamingUdids, setStreamingUdids] = useState<Set<string>>(new Set());
  const [channelStatus, setChannelStatus] = useState<string>("CONNECTING");
  const [lastSyncAt, setLastSyncAt] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase.channel(`user:${userId}`);
    setChannelStatus("CONNECTING");
    channelHealth?.register(channel);
    logDebug("presence", "opening user presence channel", {
      userId,
      reconnectKey: channelHealth?.reconnectKey ?? 0,
    });

    const syncCards = () => {
      const state = channel.presenceState<SessionPresence>();
      const seen = new Map<string, SimulatorCard>();
      const foundStreamingUdids = new Set<string>();

      for (const entries of Object.values(state)) {
        for (const entry of entries) {
          const udids = (entry as any).streaming_udids ??
              (entry.streaming_udid ? [entry.streaming_udid] : []);
          for (const udid of udids) {
            foundStreamingUdids.add(udid);
          }
          for (const sim of entry.simulators) {
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

      const next = Array.from(seen.values());
      next.sort((a, b) => a.orderIndex - b.orderIndex);
      setCards(next);
      setStreamingUdids(foundStreamingUdids);
      setLastSyncAt(new Date().toISOString());
      onStreamingChange?.(foundStreamingUdids);
      logDebug("presence", "presence sync applied", {
        userId,
        sessions: Object.keys(state).length,
        simulators: next.map(card => ({
          udid: card.id,
          name: card.name,
          osVersion: card.osVersion,
        })),
        streamingUdids: Array.from(foundStreamingUdids),
      });
    };

    // All three events needed: sync for initial state + periodic refreshes; join/leave for real-time additions/removals
    channel
      .on("presence", { event: "sync" }, syncCards)
      .on("presence", { event: "join" }, syncCards)
      .on("presence", { event: "leave" }, syncCards)
      .subscribe((status, err) => {
        if (err) {
          setChannelStatus(status);
          logDebugError("presence", "user presence channel reported an error", err, {
            userId,
            status,
            topic: channel.topic,
          });
          channelHealth?.requestReconnect("presence-subscribe-error", {
            userId,
            status,
            topic: channel.topic,
          });
          return;
        }

        setChannelStatus(status);
        logDebug("presence", "user presence channel status changed", {
          userId,
          status,
          topic: channel.topic,
        });
        if (shouldReconnectForStatus(status)) {
          channelHealth?.requestReconnect("presence-status", {
            userId,
            status,
            topic: channel.topic,
          });
        }
      });

    return () => {
      channelHealth?.unregister(channel);
      logDebug("presence", "closing user presence channel", {
        userId,
        topic: channel.topic,
      });
      channel.unsubscribe();
      supabase.removeChannel(channel);
    };
  }, [userId, channelHealth?.reconnectKey]);

  const syncState: PresenceSyncState = channelStatus === "SUBSCRIBED"
    ? "live"
    : (cards.length > 0 || lastSyncAt ? "stale" : "syncing");

  return { cards, streamingUdids, syncState, lastSyncAt, channelStatus };
}
