"use client";

export const REALTIME_PROTOCOL_VERSION = 1;
export const COMMAND_ACK_TIMEOUT_MS = 5000;
export const STREAM_STATE_TIMEOUT_MS = 12000;
export const MAC_PRESENCE_STALE_MS = 20000;

export type SimulatorPresence = {
  udid: string;
  name: string;
  os_version: string;
  device_type_identifier: string;
  order_index?: number;
};

export type MacSessionPresence = {
  session_type: "mac";
  session_id: string;
  user_email: string;
  started_at: string;
  simulators: SimulatorPresence[];
  streaming_udids: string[];
  presence_version: number;
};

export type WebSessionPresence = {
  session_type: "web";
  dashboard_session_id: string;
  opened_at: string;
  watching_udid: string | null;
  page_visible: boolean;
};

export type UserChannelPresence = MacSessionPresence | WebSessionPresence;

export type CommandKind =
  | "start"
  | "stop"
  | "tap"
  | "swipe"
  | "button"
  | "gesture"
  | "text"
  | "push"
  | "app_list"
  | "screenshot"
  | "start_recording"
  | "stop_recording"
  | "open_url"
  | "clear_logs";

export type TapPayload = {
  x?: number;
  y?: number;
  vw?: number;
  vh?: number;
  longPress?: boolean;
  duration?: number;
  label?: string;
};

export type SwipePayload = {
  startX: number;
  startY: number;
  endX: number;
  endY: number;
  vw: number;
  vh: number;
};

export type ButtonPayload = { button: string };
export type GesturePayload = { gesture: string };
export type TextPayload = { text: string };
export type OpenUrlPayload = { url: string };
export type PushPayload = {
  bundleId: string;
  title?: string;
  subtitle?: string;
  body?: string;
  badge?: number;
  sound?: string;
  category?: string;
  contentAvailable?: boolean;
};

export type CommandPayloadMap = {
  start: Record<string, never>;
  stop: Record<string, never>;
  tap: TapPayload;
  swipe: SwipePayload;
  button: ButtonPayload;
  gesture: GesturePayload;
  text: TextPayload;
  push: PushPayload;
  app_list: Record<string, never>;
  screenshot: Record<string, never>;
  start_recording: Record<string, never>;
  stop_recording: Record<string, never>;
  open_url: OpenUrlPayload;
  clear_logs: Record<string, never>;
};

export type CommandEnvelope<K extends CommandKind = CommandKind> = {
  protocol_version: number;
  command_id: string;
  dashboard_session_id: string;
  kind: K;
  udid: string | null;
  payload: CommandPayloadMap[K];
  sent_at: string;
};

export type CommandAck = {
  protocol_version: number;
  command_id: string;
  dashboard_session_id: string;
  status: "received" | "rejected";
  reason?: string | null;
  received_at: string;
};

export type CommandResult = {
  protocol_version: number;
  command_id: string;
  dashboard_session_id: string;
  kind: CommandKind;
  udid: string | null;
  status: "ok" | "failed";
  reason?: string | null;
  payload?: unknown;
  completed_at: string;
};

export type CommandResultMap = {
  app_list: { apps: Array<{ bundleId: string; name: string }> };
};

export type RealtimeLogPayload = {
  protocol_version: number;
  udid: string;
  category: string;
  message: string;
  timestamp: string;
};

export function isMacSessionPresence(value: UserChannelPresence): value is MacSessionPresence {
  return value.session_type === "mac";
}

export function isWebSessionPresence(value: UserChannelPresence): value is WebSessionPresence {
  return value.session_type === "web";
}
