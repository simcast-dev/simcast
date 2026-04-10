"use client";

import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { toast, Toaster } from "sonner";
import StreamGrid from "./StreamGrid";
import SimulatorViewer from "./SimulatorViewer";
import UserMenu from "./SignOutButton";
import ScreenshotGallery from "./gallery/ScreenshotGallery";
import RecordingGallery from "./gallery/RecordingGallery";
import ThemeSelector from "./components/ThemeSelector";
import { StatItem } from "./ui";
import type { VideoStats } from "./hooks/useVideoStats";
import { useLogStream } from "./hooks/useLogStream";
import { useSimulatorChannel } from "./hooks/useSimulatorChannel";
import LogDrawer from "./components/LogDrawer";
import { PageVisibilityProvider } from "./contexts/PageVisibilityContext";
import { useReconnectKey } from "./hooks/useReconnectKey";
import type { PresenceSyncState } from "./hooks/usePresenceSubscription";

export default function DashboardClient({ userEmail, userId }: { userEmail: string | undefined; userId: string }) {
  const [watchingUdid, setWatchingUdid] = useState<string | null>(null);
  const [streamingUdids, setStreamingUdids] = useState<Set<string>>(new Set());
  const [simulatorNames, setSimulatorNames] = useState<Map<string, string>>(new Map());
  const [activeView, setActiveView] = useState<"stream" | "screenshots" | "recordings">("stream");
  const [streamStats, setStreamStats] = useState<VideoStats | null>(null);
  const [presenceSyncState, setPresenceSyncState] = useState<PresenceSyncState>("syncing");
  const [presenceLastSyncAt, setPresenceLastSyncAt] = useState<string | null>(null);
  const handleStats = useCallback((s: VideoStats | null) => setStreamStats(s), []);
  const activeViewRef = useRef(activeView);
  activeViewRef.current = activeView;

  const onNewScreenshot = useCallback((item: { simulator_name: string | null }) => {
    const name = item.simulator_name ?? "Simulator";
    toast("Screenshot saved", {
      description: name,
      action: activeViewRef.current !== "screenshots" ? {
        label: "View",
        onClick: () => setActiveView("screenshots"),
      } : undefined,
    });
  }, []);

  const onNewRecording = useCallback((item: { simulator_name: string | null; duration_seconds: number }) => {
    const name = item.simulator_name ?? "Simulator";
    const m = Math.floor(item.duration_seconds / 60);
    const s = Math.floor(item.duration_seconds % 60);
    toast("Recording saved", {
      description: `${name} \u00B7 ${m}:${s.toString().padStart(2, "0")}`,
      action: activeViewRef.current !== "recordings" ? {
        label: "View",
        onClick: () => setActiveView("recordings"),
      } : undefined,
    });
  }, []);

  const { reconnectKey, registerChannel, unregisterChannel, requestReconnect } = useReconnectKey();
  const channelHealth = useMemo(() => ({
    reconnectKey,
    register: registerChannel,
    unregister: unregisterChannel,
    requestReconnect,
  }), [reconnectKey, registerChannel, unregisterChannel, requestReconnect]);

  useEffect(() => {
    if (reconnectKey > 0) {
      toast("Reconnecting to real-time channels…", { duration: 2000 });
    }
  }, [reconnectKey]);

  const { logs, errorCount, addLog, clearLogs } = useLogStream();
  const { sendClearLogs } = useSimulatorChannel(watchingUdid, addLog, channelHealth);
  const handleClearLogs = useCallback(() => {
    clearLogs();
    sendClearLogs();
  }, [clearLogs, sendClearLogs]);


  useEffect(() => {
    clearLogs();
  }, [watchingUdid, clearLogs]);

  useEffect(() => {
    if (watchingUdid && !streamingUdids.has(watchingUdid)) {
      setWatchingUdid(null);
    }
  }, [streamingUdids, watchingUdid]);

  const realtimeBadge = (() => {
    if (presenceSyncState === "live") {
      return {
        label: "Realtime Live",
        description: presenceLastSyncAt ? `Updated ${new Date(presenceLastSyncAt).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}` : "Connected",
        color: "var(--emerald)",
        background: "rgba(16, 185, 129, 0.12)",
        border: "rgba(16, 185, 129, 0.28)",
      };
    }

    if (presenceSyncState === "stale") {
      return {
        label: "Realtime Reconnecting",
        description: presenceLastSyncAt ? `Last sync ${new Date(presenceLastSyncAt).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}` : "Waiting for sync",
        color: "#f59e0b",
        background: "rgba(245, 158, 11, 0.12)",
        border: "rgba(245, 158, 11, 0.28)",
      };
    }

    return {
      label: "Realtime Connecting",
      description: "Joining channels",
      color: "var(--text-3)",
      background: "var(--badge-bg)",
      border: "var(--badge-border)",
    };
  })();

  return (
    <div
      className="flex flex-col"
      style={{ height: "100vh", background: "var(--bg)", color: "var(--text)" }}
    >
      <Toaster
        position="bottom-right"
        toastOptions={{
          style: {
            background: "var(--surface)",
            border: "1px solid var(--border)",
            color: "var(--text)",
            backdropFilter: "blur(20px)",
            WebkitBackdropFilter: "blur(20px)",
          },
        }}
      />
      <PageVisibilityProvider>
      {/* Background blooms */}
      <div className="fixed inset-0 pointer-events-none" style={{ zIndex: 0 }}>
        <div
          className="absolute"
          style={{
            top: "-10%",
            left: "10%",
            width: "45vw",
            height: "35vw",
            maxWidth: 600,
            maxHeight: 420,
            background: "radial-gradient(ellipse at center, var(--bloom-violet) 0%, transparent 70%)",
            borderRadius: "50%",
          }}
        />
        <div
          className="absolute"
          style={{
            top: "5%",
            right: "5%",
            width: "35vw",
            height: "28vw",
            maxWidth: 480,
            maxHeight: 360,
            background: "radial-gradient(ellipse at center, var(--bloom-emerald) 0%, transparent 70%)",
            borderRadius: "50%",
          }}
        />
        <div
          className="absolute"
          style={{
            bottom: "0%",
            left: "40%",
            width: "25vw",
            height: "20vw",
            maxWidth: 320,
            maxHeight: 240,
            background: "radial-gradient(ellipse at center, var(--bloom-indigo) 0%, transparent 70%)",
            borderRadius: "50%",
          }}
        />
      </div>

      {/* Header */}
      <header
        className="relative flex-shrink-0"
        style={{
          zIndex: 50,
          background: "transparent",
          borderBottom: "none",
        }}
      >
        <div className="max-w-full px-6 py-4 flex items-center justify-between">
          <nav
            className="flex items-center"
            style={{
              background: "var(--surface)",
              backdropFilter: "blur(20px)",
              WebkitBackdropFilter: "blur(20px)",
              borderRadius: "var(--radius-lg)",
              border: "1px solid var(--border)",
              padding: 4,
              gap: 4,
              boxShadow: "0 2px 16px rgba(0,0,0,0.15), inset 0 1px 0 var(--surface-2)",
            }}
          >
            {(["stream", "screenshots", "recordings"] as const).map(tab => {
              const isActive = activeView === tab;
              const icons: Record<string, React.ReactNode> = {
                stream: (
                  <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="1" width="10" height="14" rx="2.5" />
                    <circle cx="8" cy="12" r="0.7" fill="currentColor" stroke="none" />
                  </svg>
                ),
                screenshots: (
                  <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="1" y="3.5" width="14" height="10" rx="2" />
                    <circle cx="8" cy="8.5" r="2.2" />
                    <path d="M5.5 3.5L6.5 1.5h3l1 2" />
                  </svg>
                ),
                recordings: (
                  <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="8" cy="8" r="6" />
                    <circle cx="8" cy="8" r="2.2" fill="currentColor" stroke="none" />
                  </svg>
                ),
              };
              return (
                <button
                  key={tab}
                  onClick={() => setActiveView(tab)}
                  className="flex items-center gap-2"
                  style={{
                    padding: "8px 16px",
                    borderRadius: "var(--radius-md)",
                    fontSize: "var(--font-size-base)",
                    fontWeight: "var(--font-weight-semibold)",
                    letterSpacing: "var(--tracking-normal)",
                    backgroundImage: isActive ? "linear-gradient(135deg, var(--tab-active-from), var(--tab-active-to))" : "none",
                    border: isActive
                      ? "1px solid var(--tab-active-border)"
                      : "1px solid transparent",
                    color: isActive ? "var(--tab-active-text)" : "var(--text-3)",
                    cursor: "pointer",
                    whiteSpace: "nowrap",
                    boxShadow: isActive ? "var(--tab-active-shadow)" : "none",
                    transition: "color 0.15s",
                  }}
                  onMouseEnter={e => {
                    if (!isActive) {
                      const el = e.currentTarget;
                      el.style.backgroundImage = "none";
                      el.style.backgroundColor = "var(--tab-hover-bg)";
                      el.style.color = "var(--text-2)";
                      el.style.borderColor = "var(--tab-hover-border)";
                    }
                  }}
                  onMouseLeave={e => {
                    if (!isActive) {
                      const el = e.currentTarget;
                      el.style.backgroundImage = "none";
                      el.style.backgroundColor = "transparent";
                      el.style.color = "var(--text-3)";
                      el.style.borderColor = "transparent";
                    }
                  }}
                >
                  {icons[tab]}
                  {tab === "stream" ? "Stream" : tab === "screenshots" ? "Screenshots" : "Recordings"}
                </button>
              );
            })}
          </nav>

          <div className="flex items-center gap-4">
            <div
              title={realtimeBadge.description}
              className="flex items-center gap-2"
              style={{
                padding: "8px 12px",
                borderRadius: "999px",
                background: realtimeBadge.background,
                border: `1px solid ${realtimeBadge.border}`,
                color: realtimeBadge.color,
                boxShadow: "inset 0 1px 0 rgba(255,255,255,0.05)",
              }}
            >
              <span
                style={{
                  width: 8,
                  height: 8,
                  borderRadius: "50%",
                  background: realtimeBadge.color,
                  boxShadow: `0 0 10px ${realtimeBadge.color}`,
                  flexShrink: 0,
                }}
              />
              <div className="flex flex-col" style={{ lineHeight: 1.05 }}>
                <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)" }}>
                  {realtimeBadge.label}
                </span>
                <span style={{ fontSize: "10px", color: "var(--text-3)" }}>
                  {realtimeBadge.description}
                </span>
              </div>
            </div>
            <ThemeSelector />
            <UserMenu userEmail={userEmail} />
          </div>
        </div>
      </header>

      {/* Main content — all views stay mounted, hidden via display to avoid remount flicker */}
      <div className="relative flex-1 min-h-0" style={{ zIndex: 10 }}>
        <div
          className="flex flex-1 min-h-0 h-full transition-all duration-300"
          style={{ display: activeView === "stream" ? "flex" : "none" }}
        >
          <div
            className="overflow-y-auto transition-all duration-300"
            style={{
              width: "40%",
            }}
          >
            <div className="px-6 pt-6 pb-2 h-full">
              <StreamGrid
                onSelect={setWatchingUdid}
                onStreamingChange={setStreamingUdids}
                onSyncStatus={({ syncState, lastSyncAt }) => {
                  setPresenceSyncState(syncState);
                  setPresenceLastSyncAt(lastSyncAt);
                }}
                onNameMap={setSimulatorNames}
                watchingUdid={watchingUdid}
                userId={userId}
                channelHealth={channelHealth}
              />
            </div>
          </div>
          <div className="flex flex-col" style={{ width: "60%" }}>
            <SimulatorViewer udid={watchingUdid} userId={userId} isStreaming={watchingUdid !== null && streamingUdids.has(watchingUdid)} isActive={activeView === "stream"} onStats={handleStats} onClose={() => setWatchingUdid(null)} simulatorName={watchingUdid ? simulatorNames.get(watchingUdid) ?? null : null} />
          </div>
        </div>
        <div
          className="overflow-y-auto h-full"
          style={{ display: activeView === "screenshots" ? "block" : "none" }}
        >
          <ScreenshotGallery userId={userId} onNewItem={onNewScreenshot} channelHealth={channelHealth} />
        </div>
        <div
          className="overflow-y-auto h-full"
          style={{ display: activeView === "recordings" ? "block" : "none" }}
        >
          <RecordingGallery userId={userId} onNewItem={onNewRecording} channelHealth={channelHealth} />
        </div>
      </div>

      {/* Footer */}
      <footer
        className="relative flex-shrink-0"
        style={{ zIndex: 50, padding: "0 24px 8px" }}
      >
        <div
          className="flex items-center justify-center"
          style={{
            position: "relative",
            width: "100%",
            padding: "8px 0",
            borderRadius: "var(--radius-lg)",
            border: "1px solid var(--border-subtle)",
            background: "linear-gradient(135deg, var(--skeleton-bg) 0%, transparent 100%)",
            color: "var(--text-3)",
            fontSize: "var(--font-size-xs)",
            letterSpacing: "var(--tracking-normal)",
          }}
        >
          SimCast v0.1.0
          {streamStats && (
            <>
              <span style={{ margin: "0 8px", opacity: 0.4 }}>|</span>
              <StatItem label="RES" value={`${streamStats.width}×${streamStats.height}`} />
              <span style={{ margin: "0 6px", opacity: 0.4 }}>·</span>
              <StatItem label="FPS" value={streamStats.fps.toFixed(1)} valueColor={streamStats.fps >= 55 ? "var(--emerald)" : streamStats.fps >= 30 ? "#fbbf24" : "#ef4444"} />
              <span style={{ margin: "0 6px", opacity: 0.4 }}>·</span>
              <StatItem label="BW" value={streamStats.bitrateKbps >= 1000 ? `${(streamStats.bitrateKbps / 1000).toFixed(2)} Mbps` : `${streamStats.bitrateKbps.toFixed(0)} kbps`} />
              <span style={{ margin: "0 6px", opacity: 0.4 }}>·</span>
              <StatItem label="PKT" value={`${streamStats.packetsLost} lost`} valueColor={streamStats.packetsLost > 0 ? "#ef4444" : undefined} />
              <span style={{ margin: "0 6px", opacity: 0.4 }}>·</span>
              <StatItem label="JTR" value={`${(streamStats.jitter * 1000).toFixed(1)} ms`} />
            </>
          )}
          <LogDrawer logs={logs} errorCount={errorCount} onClear={handleClearLogs} />
        </div>
      </footer>
      </PageVisibilityProvider>
    </div>
  );
}
