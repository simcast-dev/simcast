"use client";

import type { RealtimeChannel } from "@supabase/supabase-js";

export type ChannelHealth = {
  reconnectKey: number;
  register: (channel: RealtimeChannel) => void;
  unregister: (channel: RealtimeChannel) => void;
  requestReconnect: (reason: string, details?: Record<string, unknown>) => void;
};

export function shouldReconnectForStatus(status: string) {
  return status === "TIMED_OUT" || status === "CLOSED" || status === "CHANNEL_ERROR";
}
