"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { logDebug } from "@/lib/debug";

export function useReconnectKey(): {
  reconnectKey: number;
  registerChannel: (channel: RealtimeChannel) => void;
  unregisterChannel: (channel: RealtimeChannel) => void;
  requestReconnect: (reason: string, details?: Record<string, unknown>) => void;
} {
  const [key, setKey] = useState(0);
  const channelsRef = useRef<Set<RealtimeChannel>>(new Set());
  const wasInactiveRef = useRef(false);
  const lastReconnectAtRef = useRef(0);

  const registerChannel = useCallback((channel: RealtimeChannel) => {
    channelsRef.current.add(channel);
    logDebug("reconnect", "registered realtime channel", {
      topic: channel.topic,
      state: channel.state,
      channelCount: channelsRef.current.size,
    });
  }, []);

  const unregisterChannel = useCallback((channel: RealtimeChannel) => {
    channelsRef.current.delete(channel);
    logDebug("reconnect", "unregistered realtime channel", {
      topic: channel.topic,
      state: channel.state,
      channelCount: channelsRef.current.size,
    });
  }, []);

  const requestReconnect = useCallback((reason: string, details?: Record<string, unknown>) => {
    const now = Date.now();
    if (now - lastReconnectAtRef.current < 2000) {
      logDebug("reconnect", "ignored reconnect request because one was requested recently", {
        reason,
        ...details,
      });
      return;
    }

    lastReconnectAtRef.current = now;
    logDebug("reconnect", "forcing realtime reconnect", {
      reason,
      ...details,
    });
    setKey(k => k + 1);
  }, []);

  useEffect(() => {
    const markInactive = () => {
      wasInactiveRef.current = true;
    };

    const checkChannels = () => {
      if (!wasInactiveRef.current) return;
      wasInactiveRef.current = false;

      const hasStale = Array.from(channelsRef.current).some(
        ch => ch.state !== "joined",
      );
      if (hasStale) {
        logDebug("reconnect", "detected stale realtime channel after inactivity", {
          channels: Array.from(channelsRef.current).map(channel => ({
            topic: channel.topic,
            state: channel.state,
          })),
        });
        requestReconnect("inactive-channel-check");
      }
    };

    const onVisibility = () => {
      if (document.hidden) markInactive();
      else checkChannels();
    };

    const onFocus = () => checkChannels();
    const onBlur = () => markInactive();

    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("blur", onBlur);
    window.addEventListener("focus", onFocus);
    return () => {
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("blur", onBlur);
      window.removeEventListener("focus", onFocus);
    };
  }, []);

  return { reconnectKey: key, registerChannel, unregisterChannel, requestReconnect };
}
