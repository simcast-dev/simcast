"use client";

import React, { useState, useCallback, useEffect, useRef } from "react";
import { LiveKitRoom } from "@livekit/components-react";
import { useLiveKitConnection } from "./hooks/useLiveKitConnection";
import ScreenView from "./components/ScreenView";
import type { CommandKind, CommandPayloadMap } from "@/lib/realtime-protocol";

type SimulatorViewerProps = {
  udid: string | null;
  userId: string;
  isStreaming: boolean;
  isActive?: boolean;
  onStats?: (stats: import("./hooks/useVideoStats").VideoStats | null) => void;
  onClose?: () => void;
  simulatorName?: string | null;
  sendCommand: <K extends CommandKind>(input: {
    kind: K;
    udid?: string | null;
    payload: CommandPayloadMap[K];
    waitForResult?: boolean;
    resultTimeoutMs?: number;
  }) => Promise<unknown>;
};

export default function SimulatorViewer({ udid, userId, isStreaming, isActive = true, onStats, onClose, simulatorName, sendCommand }: SimulatorViewerProps) {
  const [retryKey, setRetryKey] = useState(0);
  const shouldConnect = Boolean(udid && isStreaming);
  const shouldConnectRef = useRef(shouldConnect);
  shouldConnectRef.current = shouldConnect;

  const { connection, error } = useLiveKitConnection(udid, userId, shouldConnect, retryKey);

  useEffect(() => {
    if (!shouldConnect) {
      setRetryKey(0);
    }
  }, [shouldConnect]);

  const handleDisconnected = useCallback(() => {
    if (!shouldConnectRef.current) return;
    setTimeout(() => {
      if (!shouldConnectRef.current) return;
      setRetryKey(k => k + 1);
    }, 2000);
  }, []);

  if (!udid) {
    return (
      <div className="h-full flex flex-col items-center justify-center gap-3" style={{ color: "var(--text-3)" }}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" className="w-16 h-16 opacity-30">
          <rect x="6" y="2" width="12" height="20" rx="2.5" />
          <circle cx="12" cy="18.5" r="0.75" fill="currentColor" stroke="none" />
          <line x1="6" y1="4.5" x2="18" y2="4.5" strokeWidth="0.5" />
        </svg>
        <p className="text-sm">Select a simulator to watch</p>
      </div>
    );
  }

  return (
    <div className="h-full relative overflow-hidden flex flex-col" style={{ background: "transparent" }}>
      {udid && onClose && (
        <button
          onClick={onClose}
          title="Stop watching"
          className="absolute flex items-center justify-center w-6 h-6 rounded-md transition-all duration-150 hover:scale-110"
          style={{
            top: 8,
            right: 8,
            zIndex: 20,
            background: "var(--control-bg)",
            border: "1px solid var(--control-border)",
            color: "var(--text-3)",
          }}
          onMouseEnter={e => {
            e.currentTarget.style.color = "var(--text)";
            e.currentTarget.style.borderColor = "var(--control-border-hover)";
          }}
          onMouseLeave={e => {
            e.currentTarget.style.color = "var(--text-3)";
            e.currentTarget.style.borderColor = "var(--control-border)";
          }}
        >
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className="w-3 h-3">
            <path d="M4 4l8 8M12 4l-8 8" />
          </svg>
        </button>
      )}
      <div className="flex-1 relative overflow-hidden">
      {!isStreaming ? (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 text-center max-w-sm mx-auto">
          <p style={{ color: "var(--text)" }} className="text-sm font-medium">Stream offline</p>
          <p style={{ color: "var(--text-3)" }} className="text-xs">
            Start the stream from the simulator list to watch {simulatorName ?? "this simulator"}.
          </p>
        </div>
      ) : error ? (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 text-center max-w-sm mx-auto">
          <p style={{ color: "var(--error-text)" }} className="text-sm font-medium">Failed to connect</p>
          <p style={{ color: "var(--text-3)" }} className="text-xs font-mono break-all">{error}</p>
        </div>
      ) : !connection ? (
        <div className="absolute inset-0 flex items-center justify-center text-sm animate-pulse" style={{ color: "var(--text-3)" }}>
          Fetching token…
        </div>
      ) : (
        <LiveKitRoom
          key={connection.token}
          token={connection.token}
          serverUrl={connection.url}
          connect={shouldConnect}
          onDisconnected={handleDisconnected}
          onError={() => {}}
          options={{ adaptiveStream: false }}
          className="absolute inset-0"
        >
          <ScreenView udid={udid} onStats={onStats} isActive={isActive} sendCommand={sendCommand} />
        </LiveKitRoom>
      )}
      </div>
    </div>
  );
}
