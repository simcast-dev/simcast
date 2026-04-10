"use client";

import React, { useEffect, useRef, useState } from "react";
import { VideoTrack, useTracks, useRoomContext } from "@livekit/components-react";
import { Track, RemoteTrackPublication } from "livekit-client";
import { toast } from "sonner";
import { ControlPanelButton, StatItem, PanelDivider } from "../ui";
import { useVideoStats, type VideoStats } from "../hooks/useVideoStats";
import PushNotificationModal from "./PushNotificationModal";
import { usePagePause } from "../contexts/PageVisibilityContext";
import type { CommandKind, CommandPayloadMap, CommandResultMap } from "@/lib/realtime-protocol";

type VideoRect = { left: number; top: number; width: number; height: number };

type ControlTab = "gesture" | "scroll" | "type" | "push" | "link";

const HARDWARE_BUTTONS = [
  {
    id: "home",
    label: "Home",
    icon: (
      <svg viewBox="0 0 20 20" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.6">
        <rect x="4" y="4" width="12" height="12" rx="3.5" />
      </svg>
    ),
  },
  {
    id: "lock",
    label: "Lock",
    icon: (
      <svg viewBox="0 0 20 20" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.6">
        <circle cx="10" cy="11" r="5" />
        <line x1="10" y1="2" x2="10" y2="6" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    id: "side",
    label: "Side",
    icon: (
      <svg viewBox="0 0 20 20" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.6">
        <rect x="8" y="3" width="4" height="14" rx="2" />
      </svg>
    ),
  },
];

const SCROLL_GESTURES = [
  {
    id: "scroll-up",
    title: "Scroll Up",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <path d="M6 10V2M2 6l4-4 4 4" />
      </svg>
    ),
  },
  {
    id: "scroll-down",
    title: "Scroll Down",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <path d="M6 2v8M2 6l4 4 4-4" />
      </svg>
    ),
  },
  {
    id: "scroll-left",
    title: "Scroll Left",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <path d="M10 6H2M6 2 2 6l4 4" />
      </svg>
    ),
  },
  {
    id: "scroll-right",
    title: "Scroll Right",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <path d="M2 6h8M6 2l4 4-4 4" />
      </svg>
    ),
  },
] as const;

const EDGE_GESTURES = [
  {
    id: "swipe-from-left-edge",
    title: "Swipe from Left Edge",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <line x1="1" y1="2" x2="1" y2="10" />
        <path d="M4 6h7M8 3l3 3-3 3" />
      </svg>
    ),
  },
  {
    id: "swipe-from-right-edge",
    title: "Swipe from Right Edge",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <line x1="11" y1="2" x2="11" y2="10" />
        <path d="M8 6H1M4 3 1 6l3 3" />
      </svg>
    ),
  },
  {
    id: "swipe-from-top-edge",
    title: "Swipe from Top Edge",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <line x1="2" y1="1" x2="10" y2="1" />
        <path d="M6 4v7M3 8l3 3 3-3" />
      </svg>
    ),
  },
  {
    id: "swipe-from-bottom-edge",
    title: "Swipe from Bottom Edge",
    icon: (
      <svg viewBox="0 0 12 12" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <line x1="2" y1="11" x2="10" y2="11" />
        <path d="M6 8V1M3 4l3-3 3 3" />
      </svg>
    ),
  },
] as const;

const toolbarBtnBase: React.CSSProperties = {
  width: 28,
  height: 28,
  borderRadius: 6,
  background: "var(--control-bg)",
  borderWidth: "1px",
  borderStyle: "solid",
  borderColor: "var(--control-border)",
  color: "var(--control-text)",
  cursor: "pointer",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  padding: 0,
  flexShrink: 0,
  transition: "background 0.12s, color 0.12s, border-color 0.12s",
};

const mediaButtonBase: React.CSSProperties = {
  width: 56,
  height: 52,
  borderRadius: "var(--radius-md)",
  backdropFilter: "blur(12px)",
  borderWidth: "1px",
  borderStyle: "solid",
  cursor: "pointer",
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  gap: 3,
  padding: 0,
  transition: "background 0.15s, color 0.15s, border-color 0.15s",
};

function ToolbarButton({
  title,
  onClick,
  active,
  children,
}: {
  title: string;
  onClick: () => void;
  active?: boolean;
  children: React.ReactNode;
}) {
  return (
    <button
      title={title}
      onClick={onClick}
      style={{
        ...toolbarBtnBase,
        ...(active
          ? { background: "var(--streaming-glow-bg)", color: "var(--emerald)", borderColor: "var(--streaming-glow-border)" }
          : {}),
      }}
      onMouseEnter={(e) => {
        if (!active) {
          (e.currentTarget as HTMLButtonElement).style.background = "var(--control-bg-hover)";
          (e.currentTarget as HTMLButtonElement).style.color = "var(--text)";
        }
      }}
      onMouseLeave={(e) => {
        if (!active) {
          (e.currentTarget as HTMLButtonElement).style.background = "var(--control-bg)";
          (e.currentTarget as HTMLButtonElement).style.color = "var(--control-text)";
        }
      }}
    >
      {children}
    </button>
  );
}

// 5px: distinguishes intentional swipes from accidental mouse movement during tap
const SWIPE_THRESHOLD = 5;

const TABS: { id: ControlTab; label: string }[] = [
  { id: "gesture", label: "TAP" },
  { id: "scroll", label: "SCROLL" },
  { id: "type", label: "TYPE" },
  { id: "push", label: "PUSH" },
  { id: "link", label: "LINK" },
];

function areVideoRectsEqual(a: VideoRect | null, b: VideoRect | null) {
  if (a === b) return true;
  if (!a || !b) return false;
  return (
    Math.abs(a.left - b.left) < 0.5 &&
    Math.abs(a.top - b.top) < 0.5 &&
    Math.abs(a.width - b.width) < 0.5 &&
    Math.abs(a.height - b.height) < 0.5
  );
}

function areSwipePreviewsEqual(
  a: { sx: number; sy: number; ex: number; ey: number } | null,
  b: { sx: number; sy: number; ex: number; ey: number } | null,
) {
  if (a === b) return true;
  if (!a || !b) return false;
  return (
    Math.abs(a.sx - b.sx) < 0.5 &&
    Math.abs(a.sy - b.sy) < 0.5 &&
    Math.abs(a.ex - b.ex) < 0.5 &&
    Math.abs(a.ey - b.ey) < 0.5
  );
}

function areVideoStatsEqual(a: VideoStats | null, b: VideoStats | null) {
  if (a === b) return true;
  if (!a || !b) return false;
  return (
    a.bitrateKbps === b.bitrateKbps &&
    a.fps === b.fps &&
    a.width === b.width &&
    a.height === b.height &&
    a.packetsLost === b.packetsLost &&
    a.jitter === b.jitter
  );
}

type ScreenViewProps = {
  udid?: string | null;
  onStats?: (stats: VideoStats | null) => void;
  isActive?: boolean;
  sendCommand: <K extends CommandKind>(input: {
    kind: K;
    udid?: string | null;
    payload: CommandPayloadMap[K];
    waitForResult?: boolean;
    resultTimeoutMs?: number;
  }) => Promise<unknown>;
};

export default function ScreenView({ udid, onStats, isActive = true, sendCommand }: ScreenViewProps) {
  const tracks = useTracks([Track.Source.ScreenShare], { onlySubscribed: true });
  const track = tracks[0];
  const room = useRoomContext();
  const hadTrackRef = useRef(false);
  if (track) hadTrackRef.current = true;
  const containerRef = useRef<HTMLDivElement>(null);
  const [videoRect, setVideoRect] = useState<VideoRect | null>(null);
  const [activeTab, setActiveTab] = useState<ControlTab>("gesture");
  const [longPressMode, setLongPressMode] = useState(false);
  const [labelText, setLabelText] = useState("");
  const labelInputRef = useRef<HTMLInputElement>(null);
  const [keyboardText, setKeyboardText] = useState("");
  const [pushApps, setPushApps] = useState<Array<{ bundleId: string; name: string }>>([]);
  const [pushAppsLoading, setPushAppsLoading] = useState(false);
  const keyboardInputRef = useRef<HTMLInputElement>(null);
  const dragStartRef = useRef<{
    clientX: number;
    clientY: number;
    overlayX: number;
    overlayY: number;
    nx: number;
    ny: number;
  } | null>(null);
  const [swipePreview, setSwipePreview] = useState<{
    sx: number;
    sy: number;
    ex: number;
    ey: number;
  } | null>(null);
  const { isPaused: isPagePaused } = usePagePause();
  const stats = useVideoStats(track);
  const lastReportedStatsRef = useRef<VideoStats | null>(null);
  useEffect(() => {
    if (areVideoStatsEqual(lastReportedStatsRef.current, stats)) return;
    lastReportedStatsRef.current = stats;
    onStats?.(stats);
  }, [stats, onStats]);

  useEffect(() => {
    const shouldPause = isPagePaused || !isActive;

    room.remoteParticipants.forEach(p => {
      p.trackPublications.forEach(pub => {
        if (pub.source === Track.Source.ScreenShare && pub instanceof RemoteTrackPublication) {
          pub.setSubscribed(!shouldPause);
        }
      });
    });

    if (!containerRef.current) return;
    const video = containerRef.current.querySelector("video");
    if (!video) return;
    if (shouldPause) {
      video.pause();
    } else {
      video.play().catch(() => {});
    }
  }, [isPagePaused, isActive, room]);

  const [panelOpen, setPanelOpen] = useState(false);
  const [screenshotLoading, setScreenshotLoading] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingStart, setRecordingStart] = useState<number | null>(null);
  const [recordingElapsed, setRecordingElapsed] = useState("0:00");
  const [pushModalOpen, setPushModalOpen] = useState(false);
  const [linkUrl, setLinkUrl] = useState("");
  const [recentUrls, setRecentUrls] = useState<string[]>([]);
  const showCommandError = (title: string, error: unknown) => {
    toast(title, {
      description: error instanceof Error ? error.message : "The mac app did not accept the command.",
    });
  };

  async function runCommand<K extends CommandKind>(
    title: string,
    input: {
      kind: K;
      payload: CommandPayloadMap[K];
      waitForResult?: boolean;
      resultTimeoutMs?: number;
    },
  ) {
    if (!udid) {
      throw new Error("No simulator is selected.");
    }

    try {
      return await sendCommand({
        ...input,
        udid,
        waitForResult: input.waitForResult ?? true,
      });
    } catch (error) {
      showCommandError(title, error);
      throw error;
    }
  }

  useEffect(() => {
    setPushApps([]);
    setPushAppsLoading(false);
    setIsRecording(false);
    setRecordingStart(null);
    setRecordingElapsed("0:00");
    setScreenshotLoading(false);
    setLabelText("");
    setKeyboardText("");
    setPanelOpen(false);
  }, [udid]);

  useEffect(() => {
    let cancelled = false;
    if (activeTab === "push" && udid) {
      setPushApps([]);
      setPushAppsLoading(true);
      void runCommand("Failed to load apps", {
        kind: "app_list",
        payload: {},
        waitForResult: true,
      })
        .then((response) => {
          if (cancelled) return;
          const typedResponse = response as { result?: { payload?: CommandResultMap["app_list"] } } | undefined;
          setPushApps(typedResponse?.result?.payload?.apps ?? []);
          setPushAppsLoading(false);
        })
        .catch(() => {
          if (cancelled) return;
          setPushAppsLoading(false);
        });
    }
    return () => {
      cancelled = true;
    };
  }, [activeTab, udid]); // eslint-disable-line react-hooks/exhaustive-deps
  const [panelAnchorY, setPanelAnchorY] = useState<number | string>("50%");
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!panelOpen) return;
    function onPointerDown(e: PointerEvent) {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) {
        setPanelOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [panelOpen]);

  useEffect(() => {
    if (!recordingStart) return;
    const id = setInterval(() => {
      const s = Math.floor((Date.now() - recordingStart) / 1000);
      const m = Math.floor(s / 60);
      setRecordingElapsed(`${m}:${(s % 60).toString().padStart(2, "0")}`);
    }, 1000);
    return () => clearInterval(id);
  }, [recordingStart]);

  function toggleRecording() {
    if (isRecording) {
      void runCommand("Failed to stop recording", {
        kind: "stop_recording",
        payload: {},
      }).then(() => {
        setIsRecording(false);
        setRecordingStart(null);
        setRecordingElapsed("0:00");
      }).catch(() => {});
    } else {
      void runCommand("Failed to start recording", {
        kind: "start_recording",
        payload: {},
      }).then(() => {
        setIsRecording(true);
        setRecordingStart(Date.now());
      }).catch(() => {});
    }
  }

  function updateVideoRect() {
    const container = containerRef.current;
    if (!container) return;
    const video = container.querySelector("video");
    if (!video || !video.videoWidth || !video.videoHeight) return;
    const { width, height } = container.getBoundingClientRect();
    const scale = Math.min(width / video.videoWidth, height / video.videoHeight);
    const w = video.videoWidth * scale;
    const h = video.videoHeight * scale;
    const nextRect = { left: (width - w) / 2, top: (height - h) / 2, width: w, height: h };
    setVideoRect((prev) => (areVideoRectsEqual(prev, nextRect) ? prev : nextRect));
  }

  useEffect(() => {
    setVideoRect((prev) => (prev === null ? prev : null));
  }, [track]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    const ro = new ResizeObserver(updateVideoRect);
    ro.observe(container);
    container.addEventListener("loadedmetadata", updateVideoRect, true);
    // HTMLVideoElement fires "resize" when videoWidth/videoHeight change;
    // it doesn't bubble, but capture phase still intercepts it.
    container.addEventListener("resize", updateVideoRect, true);
    return () => {
      ro.disconnect();
      container.removeEventListener("loadedmetadata", updateVideoRect, true);
      container.removeEventListener("resize", updateVideoRect, true);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [track]);

  useEffect(() => {
    if (activeTab === "type") {
      const t = setTimeout(() => keyboardInputRef.current?.focus(), 50);
      return () => clearTimeout(t);
    }
  }, [activeTab]);

  function switchTab(tab: ControlTab) {
    dragStartRef.current = null;
    setSwipePreview((prev) => (prev === null ? prev : null));
    setActiveTab(tab);
  }

  function sendButton(button: string) {
    void runCommand("Failed to send hardware button command", {
      kind: "button",
      payload: { button },
    }).catch(() => {});
  }

  function sendGesture(gesture: string) {
    void runCommand("Failed to send gesture command", {
      kind: "gesture",
      payload: { gesture },
    }).catch(() => {});
  }

  function submitText() {
    const text = keyboardText.trim();
    if (!text) return;
    void runCommand("Failed to type text", {
      kind: "text",
      payload: { text },
    }).then(() => {
      setKeyboardText("");
      keyboardInputRef.current?.focus();
    }).catch(() => {});
  }

  function handlePushSend(payload: Record<string, unknown>) {
    void runCommand("Failed to send push notification", {
      kind: "push",
      payload: payload as CommandPayloadMap["push"],
    }).catch(() => {});
  }

  function closePushModal() {
    setPushModalOpen(false);
    switchTab("gesture");
    setPanelOpen(false);
  }

  useEffect(() => {
    const stored = localStorage.getItem("simcast_recent_urls");
    if (stored) setRecentUrls(JSON.parse(stored));
  }, []);

  function sendOpenURL() {
    const url = linkUrl.trim();
    if (!url) return;
    void runCommand("Failed to open URL", {
      kind: "open_url",
      payload: { url },
    }).then(() => {
      const updated = [url, ...recentUrls.filter(u => u !== url)].slice(0, 10);
      setRecentUrls(updated);
      localStorage.setItem("simcast_recent_urls", JSON.stringify(updated));
      setLinkUrl("");
    }).catch(() => {});
  }

  // Normalized 0-1 coords + video dimensions: decouples web viewport from macOS capture resolution;
  // macOS reconstructs absolute coordinates using actual display frame
  function sendTap(nx: number, ny: number) {
    const video = containerRef.current?.querySelector("video");
    void runCommand("Failed to send tap command", {
      kind: "tap",
      payload: {
        x: nx, y: ny,
        vw: video?.videoWidth ?? 1920,
        vh: video?.videoHeight ?? 1080,
        ...(longPressMode ? { longPress: true, duration: 1.0 } : {}),
      },
    }).catch(() => {});
  }

  function sendSwipe(startNX: number, startNY: number, endNX: number, endNY: number) {
    const video = containerRef.current?.querySelector("video");
    const vw = video?.videoWidth ?? 1920;
    const vh = video?.videoHeight ?? 1080;
    void runCommand("Failed to send swipe command", {
      kind: "swipe",
      payload: {
        startX: startNX * vw, startY: startNY * vh,
        endX: endNX * vw, endY: endNY * vh,
        vw, vh,
      },
    }).catch(() => {});
  }

  function sendLabelTap() {
    const label = labelText.trim();
    if (!label) return;
    void runCommand("Failed to send label tap", {
      kind: "tap",
      payload: { label },
    }).then(() => {
      setLabelText("");
      setPanelOpen(false);
    }).catch(() => {});
  }

  function handleOverlayMouseDown(e: React.MouseEvent<HTMLDivElement>) {
    if (activeTab === "type" || activeTab === "push" || activeTab === "link") return;
    e.preventDefault();
    const rect = e.currentTarget.getBoundingClientRect();
    dragStartRef.current = {
      clientX: e.clientX,
      clientY: e.clientY,
      overlayX: e.clientX - rect.left,
      overlayY: e.clientY - rect.top,
      nx: (e.clientX - rect.left) / rect.width,
      ny: (e.clientY - rect.top) / rect.height,
    };
  }

  function handleOverlayMouseMove(e: React.MouseEvent<HTMLDivElement>) {
    if (!dragStartRef.current) return;
    const dx = e.clientX - dragStartRef.current.clientX;
    const dy = e.clientY - dragStartRef.current.clientY;
    if (Math.sqrt(dx * dx + dy * dy) > SWIPE_THRESHOLD) {
      const rect = e.currentTarget.getBoundingClientRect();
      const nextPreview = {
        sx: dragStartRef.current.overlayX,
        sy: dragStartRef.current.overlayY,
        ex: e.clientX - rect.left,
        ey: e.clientY - rect.top,
      };
      setSwipePreview((prev) => (areSwipePreviewsEqual(prev, nextPreview) ? prev : nextPreview));
    }
  }

  function handleOverlayMouseUp(e: React.MouseEvent<HTMLDivElement>) {
    const start = dragStartRef.current;
    if (!start) return;
    dragStartRef.current = null;
    setSwipePreview((prev) => (prev === null ? prev : null));

    const dx = e.clientX - start.clientX;
    const dy = e.clientY - start.clientY;
    if (Math.sqrt(dx * dx + dy * dy) > SWIPE_THRESHOLD) {
      const rect = e.currentTarget.getBoundingClientRect();
      sendSwipe(
        start.nx, start.ny,
        (e.clientX - rect.left) / rect.width,
        (e.clientY - rect.top) / rect.height
      );
    } else {
      sendTap(start.nx, start.ny);
      if (longPressMode) setLongPressMode(false);
    }
  }

  function handleOverlayMouseLeave() {
    dragStartRef.current = null;
    setSwipePreview((prev) => (prev === null ? prev : null));
  }

  const isPausedWithoutTrack = !track && hadTrackRef.current && (isPagePaused || !isActive);

  if (!track && !isPausedWithoutTrack) {
    return (
      <div className="w-full h-full flex items-center justify-center text-sm" style={{ color: "var(--text-3)" }}>
        Waiting for stream…
      </div>
    );
  }

  const overlayCursor = (activeTab === "type" || activeTab === "push" || activeTab === "link")
    ? "default"
    : longPressMode ? "cell" : "crosshair";

  return (
    <div className="w-full h-full flex flex-col">
      <div ref={containerRef} className="flex-1 min-h-0 relative">
      {track && <VideoTrack trackRef={track} className="w-full h-full object-contain" />}

      {/* Paused placeholder — shown when stream tab is not active or browser tab is hidden */}
      {(!isActive || isPagePaused || isPausedWithoutTrack) && (
        <div
          style={{
            position: "absolute",
            ...(videoRect
              ? { left: videoRect.left, top: videoRect.top, width: videoRect.width, height: videoRect.height }
              : { inset: 0 }),
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: 16,
            background: "#0a0a0a",
            borderRadius: 4,
            zIndex: 10,
          }}
        >
          {isPagePaused ? (
            <>
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#555" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
                <line x1="8" y1="21" x2="16" y2="21" />
                <line x1="12" y1="17" x2="12" y2="21" />
              </svg>
              <span style={{ color: "#888", fontSize: 15, fontWeight: 500 }}>
                Stream Paused
              </span>
              <span style={{ color: "#555", fontSize: 12 }}>
                Return to this tab to resume automatically
              </span>
            </>
          ) : (
            <p style={{ color: "var(--text-2)", fontSize: "var(--font-size-sm)", letterSpacing: "var(--tracking-normal)" }}>
              Stream paused. Resuming…
            </p>
          )}
        </div>
      )}

      {/* Interaction overlay — tap on click, swipe on drag */}
      {videoRect && (
        <div
          style={{
            position: "absolute",
            left: videoRect.left,
            top: videoRect.top,
            width: videoRect.width,
            height: videoRect.height,
            cursor: overlayCursor,
            userSelect: "none",
          }}
          onMouseDown={handleOverlayMouseDown}
          onMouseMove={handleOverlayMouseMove}
          onMouseUp={handleOverlayMouseUp}
          onMouseLeave={handleOverlayMouseLeave}
        >
          {swipePreview && (
            <svg
              style={{
                position: "absolute",
                inset: 0,
                width: "100%",
                height: "100%",
                pointerEvents: "none",
                overflow: "visible",
              }}
            >
              <defs>
                <filter id="swipe-glow" x="-50%" y="-50%" width="200%" height="200%">
                  <feGaussianBlur stdDeviation="3" result="blur" />
                  <feMerge>
                    <feMergeNode in="blur" />
                    <feMergeNode in="SourceGraphic" />
                  </feMerge>
                </filter>
              </defs>
              <line
                x1={swipePreview.sx} y1={swipePreview.sy}
                x2={swipePreview.ex} y2={swipePreview.ey}
                stroke="rgba(255,255,255,0.7)"
                strokeWidth="2"
                strokeDasharray="8 4"
                strokeLinecap="round"
                filter="url(#swipe-glow)"
              />
              <circle
                cx={swipePreview.sx} cy={swipePreview.sy}
                r="5"
                fill="rgba(255,255,255,0.9)"
                filter="url(#swipe-glow)"
              />
              <circle
                cx={swipePreview.ex} cy={swipePreview.ey}
                r="5"
                fill="rgba(16,185,129,0.95)"
                filter="url(#swipe-glow)"
              />
            </svg>
          )}
        </div>
      )}

      {/* Right side controls — hardware buttons + control tabs */}
      {videoRect && (
        <div
          ref={panelRef}
          style={{
            position: "absolute",
            top: videoRect.top + videoRect.height / 2,
            left: videoRect.left + videoRect.width,
            transform: "translate(6px, -50%)",
            display: "flex",
            flexDirection: "row",
            alignItems: "center",
            gap: 6,
            zIndex: 20,
          }}
        >
          {/* Expanded control panel — opens to the left of the buttons column */}
          {panelOpen && (
            <div
              style={{
                position: "absolute",
                right: "calc(100% + 6px)",
                top: panelAnchorY,
                transform: "translateY(-50%)",
                width: 168,
                background: "var(--overlay-bg)",
                backdropFilter: "blur(16px)",
                borderRadius: "var(--radius-md)",
                border: "1px solid var(--border-subtle)",
                overflow: "hidden",
              }}
            >
              <div style={{ padding: "10px 8px", display: "flex", flexDirection: "column", gap: 8, alignItems: "center", maxHeight: 270, overflowY: "auto" }}>

                {/* ── TAP TAB ── */}
                {activeTab === "gesture" && (
                  <>
                    <button
                      onClick={() => setLongPressMode((v) => !v)}
                      title={longPressMode ? "Long press active — click to disable" : "Enable long press (1s hold)"}
                      style={{
                        display: "flex",
                        flexDirection: "column",
                        alignItems: "center",
                        gap: 3,
                        padding: "6px 8px",
                        borderRadius: "var(--radius-sm)",
                        width: "100%",
                        background: longPressMode ? "var(--streaming-glow-bg)" : "var(--control-bg)",
                        borderWidth: "1px",
                        borderStyle: "solid",
                        borderColor: longPressMode ? "var(--streaming-glow-border)" : "var(--control-border)",
                        color: longPressMode ? "var(--emerald)" : "var(--text-3)",
                        cursor: "pointer",
                        transition: "all 0.15s",
                      }}
                      onMouseEnter={e => {
                        if (!longPressMode) {
                          (e.currentTarget as HTMLButtonElement).style.background = "var(--control-bg-hover)";
                          (e.currentTarget as HTMLButtonElement).style.color = "var(--text-2)";
                        }
                      }}
                      onMouseLeave={e => {
                        if (!longPressMode) {
                          (e.currentTarget as HTMLButtonElement).style.background = "var(--control-bg)";
                          (e.currentTarget as HTMLButtonElement).style.color = "var(--text-3)";
                        }
                      }}
                    >
                      <svg viewBox="0 0 16 20" width="14" height="17" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
                        <path d="M8 1C5.2 1 3 3.2 3 6v6l-.8 1.5A1 1 0 0 0 3.1 15h9.8a1 1 0 0 0 .9-1.5L13 12V6c0-2.8-2.2-5-5-5Z" />
                        <line x1="8" y1="15" x2="8" y2="19" />
                      </svg>
                      <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)" }}>
                        {longPressMode ? "HOLD ON" : "HOLD"}
                      </span>
                    </button>

                    <PanelDivider />

                    <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: 4 }}>
                      <span style={{ fontSize: "var(--font-size-xs)", color: "var(--text-3)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>
                        Tap by label
                      </span>
                      <div style={{ display: "flex", gap: 4, width: "100%" }}>
                        <input
                          ref={labelInputRef}
                          value={labelText}
                          onChange={(e) => setLabelText(e.target.value)}
                          onKeyDown={(e) => { if (e.key === "Enter") sendLabelTap(); }}
                          placeholder="e.g. Safari"
                          style={{
                            flex: 1,
                            minWidth: 0,
                            padding: "4px 6px",
                            borderRadius: 6,
                            background: "var(--input-bg)",
                            borderWidth: "1px",
                            borderStyle: "solid",
                            borderColor: "var(--control-border)",
                            color: "var(--text)",
                            fontSize: "var(--font-size-xs)",
                            outline: "none",
                          }}
                        />
                        <button
                          onClick={sendLabelTap}
                          disabled={!labelText.trim()}
                          title="Tap by accessibility label"
                          style={{
                            width: 26,
                            height: 26,
                            borderRadius: 6,
                            background: labelText.trim() ? "var(--streaming-glow-bg)" : "var(--control-bg)",
                            borderWidth: "1px",
                            borderStyle: "solid",
                            borderColor: labelText.trim() ? "var(--streaming-glow-border)" : "var(--control-border)",
                            color: labelText.trim() ? "var(--emerald)" : "var(--text-3)",
                            cursor: labelText.trim() ? "pointer" : "default",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            flexShrink: 0,
                            transition: "all 0.15s",
                            padding: 0,
                          }}
                        >
                          <svg viewBox="0 0 10 10" width="9" height="9" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                            <path d="M2 5h6M5.5 2l3 3-3 3" />
                          </svg>
                        </button>
                      </div>
                    </div>
                  </>
                )}

                {/* ── SCROLL TAB ── */}
                {activeTab === "scroll" && (
                  <>
                    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
                      <span style={{ fontSize: "var(--font-size-xs)", color: "var(--text-3)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>
                        Scroll
                      </span>
                      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 28px)", gridTemplateRows: "repeat(3, 28px)", gap: 3 }}>
                        <div /><ToolbarButton title="Scroll Up" onClick={() => sendGesture("scroll-up")}>{SCROLL_GESTURES[0].icon}</ToolbarButton><div />
                        <ToolbarButton title="Scroll Left" onClick={() => sendGesture("scroll-left")}>{SCROLL_GESTURES[2].icon}</ToolbarButton>
                        <div />
                        <ToolbarButton title="Scroll Right" onClick={() => sendGesture("scroll-right")}>{SCROLL_GESTURES[3].icon}</ToolbarButton>
                        <div /><ToolbarButton title="Scroll Down" onClick={() => sendGesture("scroll-down")}>{SCROLL_GESTURES[1].icon}</ToolbarButton><div />
                      </div>
                    </div>

                    <PanelDivider />

                    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
                      <span style={{ fontSize: "var(--font-size-xs)", color: "var(--text-3)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>
                        Edge
                      </span>
                      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 28px)", gridTemplateRows: "repeat(3, 28px)", gap: 3 }}>
                        <div /><ToolbarButton title="Swipe from Top Edge" onClick={() => sendGesture("swipe-from-top-edge")}>{EDGE_GESTURES[2].icon}</ToolbarButton><div />
                        <ToolbarButton title="Swipe from Left Edge" onClick={() => sendGesture("swipe-from-left-edge")}>{EDGE_GESTURES[0].icon}</ToolbarButton>
                        <div />
                        <ToolbarButton title="Swipe from Right Edge" onClick={() => sendGesture("swipe-from-right-edge")}>{EDGE_GESTURES[1].icon}</ToolbarButton>
                        <div /><ToolbarButton title="Swipe from Bottom Edge" onClick={() => sendGesture("swipe-from-bottom-edge")}>{EDGE_GESTURES[3].icon}</ToolbarButton><div />
                      </div>
                    </div>
                  </>
                )}

                {/* ── TYPE TAB ── */}
                {activeTab === "type" && (
                  <div style={{ display: "flex", flexDirection: "column", gap: 5, width: "100%" }}>
                    <input
                      ref={keyboardInputRef}
                      value={keyboardText}
                      onChange={(e) => setKeyboardText(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") submitText();
                        if (e.key === "Escape") { setKeyboardText(""); switchTab("gesture"); setPanelOpen(false); }
                      }}
                      placeholder="Type here…"
                      style={{
                        width: "100%",
                        padding: "5px 7px",
                        borderRadius: 7,
                        background: "var(--input-bg)",
                        borderWidth: "1px",
                        borderStyle: "solid",
                        borderColor: "var(--input-border-focus)",
                        color: "var(--text)",
                        fontSize: "var(--font-size-xs)",
                        outline: "none",
                        boxSizing: "border-box",
                      }}
                    />
                    <button
                      onClick={submitText}
                      disabled={!keyboardText.trim()}
                      style={{
                        padding: "5px 0",
                        borderRadius: 6,
                        background: keyboardText.trim() ? "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))" : "var(--control-bg)",
                        borderWidth: "1px",
                        borderStyle: "solid",
                        borderColor: keyboardText.trim() ? "var(--btn-primary-border)" : "var(--control-border)",
                        color: keyboardText.trim() ? "var(--btn-primary-text)" : "var(--text-3)",
                        fontSize: "var(--font-size-xs)",
                        fontWeight: "var(--font-weight-bold)",
                        cursor: keyboardText.trim() ? "pointer" : "default",
                        letterSpacing: "var(--tracking-normal)",
                        width: "100%",
                        transition: "all 0.15s",
                      }}
                    >
                      SEND
                    </button>
                  </div>
                )}

                {/* ── LINK TAB ── */}
                {activeTab === "link" && (
                  <div style={{ display: "flex", flexDirection: "column", gap: 5, width: "100%" }}>
                    <input
                      value={linkUrl}
                      onChange={(e) => setLinkUrl(e.target.value)}
                      onKeyDown={(e) => { if (e.key === "Enter") sendOpenURL(); }}
                      placeholder="myapp://path..."
                      style={{
                        width: "100%", padding: "5px 7px", borderRadius: 7,
                        background: "var(--input-bg)", borderWidth: "1px", borderStyle: "solid",
                        borderColor: "var(--input-border-focus)", color: "var(--text)", fontSize: "var(--font-size-xs)",
                        outline: "none", boxSizing: "border-box",
                      }}
                    />
                    <button
                      onClick={sendOpenURL}
                      disabled={!linkUrl.trim()}
                      style={{
                        padding: "5px 0", borderRadius: 6,
                        background: linkUrl.trim() ? "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))" : "var(--control-bg)",
                        borderWidth: "1px", borderStyle: "solid",
                        borderColor: linkUrl.trim() ? "var(--btn-primary-border)" : "var(--control-border)",
                        color: linkUrl.trim() ? "var(--btn-primary-text)" : "var(--text-3)",
                        fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", cursor: linkUrl.trim() ? "pointer" : "default",
                        letterSpacing: "var(--tracking-normal)", width: "100%", transition: "all 0.15s",
                      }}
                    >
                      OPEN
                    </button>
                    {recentUrls.length > 0 && (
                      <>
                        <div style={{ width: "100%", height: 1, background: "var(--divider)", margin: "2px 0" }} />
                        <span style={{ fontSize: "var(--font-size-xs)", color: "var(--text-3)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>
                          Recent
                        </span>
                        {recentUrls.slice(0, 5).map((url, i) => (
                          <button
                            key={i}
                            onClick={() => { setLinkUrl(url); }}
                            style={{
                              width: "100%", padding: "3px 6px", borderRadius: 5,
                              background: "var(--control-bg)", border: "1px solid var(--control-border)",
                              color: "var(--muted-label)", fontSize: "var(--font-size-xs)", textAlign: "left" as const,
                              cursor: "pointer", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" as const,
                            }}
                          >
                            {url}
                          </button>
                        ))}
                      </>
                    )}
                  </div>
                )}

              </div>
            </div>
          )}

          {/* Buttons column */}
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            {HARDWARE_BUTTONS.map(({ id, label, icon }) => (
              <ControlPanelButton key={id} title={label} onClick={() => sendButton(id)}>
                {icon}
                <span style={{ fontSize: "var(--font-size-xs)", letterSpacing: "var(--tracking-tight)", fontWeight: "var(--font-weight-medium)", lineHeight: 1 }}>{label}</span>
              </ControlPanelButton>
            ))}

            <div style={{ marginTop: 30, display: "flex", flexDirection: "column", gap: 6 }}>
            {TABS.map((tab) => {
              const isActive = tab.id === "push" ? pushModalOpen : (panelOpen && activeTab === tab.id);
              return (
                <ControlPanelButton
                  key={tab.id}
                  title={tab.label}
                  isActive={isActive}
                  onClick={(e) => {
                    if (tab.id === "push") {
                      switchTab("push");
                      setPushModalOpen(true);
                    } else if (panelOpen && activeTab === tab.id) {
                      setPanelOpen(false);
                    } else {
                      if (panelRef.current) {
                        const btn = (e.currentTarget as HTMLButtonElement).getBoundingClientRect();
                        const container = panelRef.current.getBoundingClientRect();
                        setPanelAnchorY(btn.top + btn.height / 2 - container.top);
                      }
                      switchTab(tab.id);
                      setPanelOpen(true);
                    }
                  }}
                >
                  {tab.id === "gesture" && (
                    <svg viewBox="0 0 14 16" width="16" height="18" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M5 7V3.5a1 1 0 0 1 2 0V7m0 0V4.5a1 1 0 0 1 2 0V7m0 0V5.5a1 1 0 0 1 2 0V9a5 5 0 0 1-5 5H4A3 3 0 0 1 1 11V7.5a1 1 0 0 1 2 0V7" />
                    </svg>
                  )}
                  {tab.id === "scroll" && (
                    <svg viewBox="0 0 12 14" width="14" height="16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M6 1v12M3 4l3-3 3 3M3 10l3 3 3-3" />
                    </svg>
                  )}
                  {tab.id === "type" && (
                    <svg viewBox="0 0 12 12" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
                      <path d="M2 3h8M6 3v7M4 10h4" />
                    </svg>
                  )}
                  {tab.id === "push" && (
                    <svg viewBox="0 0 14 16" width="14" height="16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M7 1a4 4 0 0 1 4 4v4l1 2H2l1-2V5a4 4 0 0 1 4-4Z" />
                      <line x1="7" y1="14" x2="7" y2="16" />
                    </svg>
                  )}
                  {tab.id === "link" && (
                    <svg viewBox="0 0 14 14" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M6 8a3 3 0 0 0 4.24 0l2-2a3 3 0 0 0-4.24-4.24L7 2.76" />
                      <path d="M8 6a3 3 0 0 0-4.24 0l-2 2a3 3 0 0 0 4.24 4.24L7 11.24" />
                    </svg>
                  )}
                  <span style={{ fontSize: "var(--font-size-xs)", letterSpacing: "var(--tracking-tight)", fontWeight: "var(--font-weight-medium)", lineHeight: 1 }}>
                    {tab.label}
                  </span>
                </ControlPanelButton>
              );
            })}
            </div>

            <ScreenMediaBar
              isRecording={isRecording}
              recordingElapsed={recordingElapsed}
              screenshotLoading={screenshotLoading}
              onToggleRecording={toggleRecording}
              onScreenshot={() => {
                setScreenshotLoading(true);
                void runCommand("Failed to capture screenshot", {
                  kind: "screenshot",
                  payload: {},
                }).finally(() => {
                  setScreenshotLoading(false);
                });
              }}
            />
          </div>
        </div>
      )}

      </div>


      <PushNotificationModal
        open={pushModalOpen}
        onClose={closePushModal}
        udid={udid ?? null}
        onSend={handlePushSend}
        apps={pushApps}
        appsLoading={pushAppsLoading}
      />
    </div>
  );
}

function ScreenMediaBar({
  isRecording,
  recordingElapsed,
  screenshotLoading,
  onToggleRecording,
  onScreenshot,
}: {
  isRecording: boolean;
  recordingElapsed: string;
  screenshotLoading: boolean;
  onToggleRecording: () => void;
  onScreenshot: () => void;
}) {
  return (
    <div style={{ marginTop: 30, display: "flex", flexDirection: "column", gap: 6 }}>
      <button
        title={isRecording ? "Stop recording" : "Start recording"}
        onClick={onToggleRecording}
        style={{
          ...mediaButtonBase,
          background: isRecording ? "var(--btn-danger-bg)" : "var(--control-bg)",
          borderColor: isRecording ? "var(--btn-danger-border)" : "var(--control-border)",
          color: isRecording ? "var(--btn-danger-text)" : "var(--control-text)",
        }}
        onMouseEnter={e => {
          if (!isRecording) {
            const el = e.currentTarget as HTMLButtonElement;
            el.style.background = "var(--control-bg-hover)";
            el.style.color = "var(--text)";
            el.style.borderColor = "var(--control-border-hover)";
          }
        }}
        onMouseLeave={e => {
          if (!isRecording) {
            const el = e.currentTarget as HTMLButtonElement;
            el.style.background = "var(--control-bg)";
            el.style.color = "var(--control-text)";
            el.style.borderColor = "var(--control-border)";
          }
        }}
      >
        {isRecording ? (
          <div style={{ width: 16, height: 16, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ width: 10, height: 10, borderRadius: 2, background: "var(--btn-danger-text)", animation: "pulse 1.5s ease-in-out infinite" }} />
          </div>
        ) : (
          <div style={{ width: 16, height: 16, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ width: 10, height: 10, borderRadius: "50%", background: "var(--btn-danger-text)" }} />
          </div>
        )}
        <span style={{ fontSize: "var(--font-size-xs)", letterSpacing: "var(--tracking-tight)", fontWeight: "var(--font-weight-medium)", lineHeight: 1 }}>
          {isRecording ? recordingElapsed : "REC"}
        </span>
      </button>

      <ControlPanelButton
        title="Take screenshot"
        disabled={screenshotLoading}
        onClick={onScreenshot}
      >
        {screenshotLoading ? (
          <svg viewBox="0 0 16 16" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" style={{ animation: "spin 0.8s linear infinite", transformOrigin: "center" }}>
            <circle cx="8" cy="8" r="6" strokeOpacity="0.25" />
            <path d="M8 2a6 6 0 0 1 6 6" />
          </svg>
        ) : (
          <svg viewBox="0 0 16 16" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
            <rect x="1" y="3" width="14" height="11" rx="2" />
            <circle cx="8" cy="8.5" r="2.5" />
            <path d="M5 3l1-2h4l1 2" />
          </svg>
        )}
        <span style={{ fontSize: "var(--font-size-xs)", letterSpacing: "var(--tracking-tight)", fontWeight: "var(--font-weight-medium)", lineHeight: 1 }}>
          {screenshotLoading ? "…" : "SHOT"}
        </span>
      </ControlPanelButton>
    </div>
  );
}
