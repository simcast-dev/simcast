"use client";

import { useEffect, useRef, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";
import { logDebug, logDebugError } from "@/lib/debug";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { shouldReconnectForStatus, type ChannelHealth } from "@/lib/realtime";

export function useSimulatorChannel(
  udid: string | null,
  onLogReceived?: (payload: { category: string; message: string; timestamp: string }) => void,
  channelHealth?: ChannelHealth,
) {
  const channelRef = useRef<RealtimeChannel | null>(null);
  const onLogRef = useRef(onLogReceived);
  onLogRef.current = onLogReceived;

  useEffect(() => {
    if (!udid) {
      channelRef.current = null;
      return;
    }

    const supabase = createClient();
    const channel = supabase.channel(`simulator:${udid}`);
    channelRef.current = channel;
    channelHealth?.register(channel);
    logDebug("simulator-channel", "opening simulator channel", {
      udid,
      reconnectKey: channelHealth?.reconnectKey ?? 0,
      topic: channel.topic,
    });

    channel
      .on("broadcast", { event: "log" }, (event: { payload?: { category?: string; message?: string; timestamp?: string } }) => {
        const data = event.payload;
        if (data?.category && data?.message && data?.timestamp) {
          onLogRef.current?.(data as { category: string; message: string; timestamp: string });
        }
      })
      .subscribe((status, err) => {
        if (err) {
          logDebugError("simulator-channel", "simulator channel reported an error", err, {
            udid,
            status,
            topic: channel.topic,
          });
          channelHealth?.requestReconnect("simulator-channel-error", {
            udid,
            status,
            topic: channel.topic,
          });
          return;
        }

        logDebug("simulator-channel", "simulator channel status changed", {
          udid,
          status,
          topic: channel.topic,
        });
        if (shouldReconnectForStatus(status)) {
          channelHealth?.requestReconnect("simulator-channel-status", {
            udid,
            status,
            topic: channel.topic,
          });
        }
      });

    return () => {
      channelHealth?.unregister(channel);
      channelRef.current = null;
      logDebug("simulator-channel", "closing simulator channel", {
        udid,
        topic: channel.topic,
      });
      channel.unsubscribe();
      supabase.removeChannel(channel);
    };
  }, [udid, channelHealth?.reconnectKey]);

  const sendClearLogs = useCallback(() => {
    logDebug("simulator-channel", "sending clear_logs broadcast", { udid });
    channelRef.current?.send({ type: "broadcast", event: "clear_logs", payload: {} });
  }, []);

  return { sendClearLogs };
}
