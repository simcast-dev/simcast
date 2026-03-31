"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";

export function useReconnectKey(): {
  reconnectKey: number;
  registerChannel: (channel: RealtimeChannel) => void;
  unregisterChannel: (channel: RealtimeChannel) => void;
} {
  const [key, setKey] = useState(0);
  const channelsRef = useRef<Set<RealtimeChannel>>(new Set());
  const wasInactiveRef = useRef(false);

  const registerChannel = useCallback((channel: RealtimeChannel) => {
    channelsRef.current.add(channel);
  }, []);

  const unregisterChannel = useCallback((channel: RealtimeChannel) => {
    channelsRef.current.delete(channel);
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
        setKey(k => k + 1);
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

  return { reconnectKey: key, registerChannel, unregisterChannel };
}
