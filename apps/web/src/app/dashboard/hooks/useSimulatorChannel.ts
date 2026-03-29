"use client";

import { useEffect, useRef, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";
import type { RealtimeChannel } from "@supabase/supabase-js";

export function useSimulatorChannel(
  udid: string | null,
  onLogReceived?: (payload: { category: string; message: string; timestamp: string }) => void,
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

    channel
      .on("broadcast", { event: "log" }, (event: { payload?: { category?: string; message?: string; timestamp?: string } }) => {
        const data = event.payload;
        if (data?.category && data?.message && data?.timestamp) {
          onLogRef.current?.(data as { category: string; message: string; timestamp: string });
        }
      })
      .subscribe();

    return () => {
      channelRef.current = null;
      channel.unsubscribe();
      supabase.removeChannel(channel);
    };
  }, [udid]);

  const sendClearLogs = useCallback(() => {
    channelRef.current?.send({ type: "broadcast", event: "clear_logs", payload: {} });
  }, []);

  return { sendClearLogs };
}
