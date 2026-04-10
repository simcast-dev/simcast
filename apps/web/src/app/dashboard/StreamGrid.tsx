"use client";

import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import { logDebug } from "@/lib/debug";
import { STREAM_STATE_TIMEOUT_MS } from "@/lib/realtime-protocol";
import { DeviceIconBox, SimulatorDeviceInfo, SectionHeaderWithBadge, LoadingSpinner } from "./ui";
import { formatDuration, type PresenceSyncState, type SimulatorCard } from "./hooks/useUserRealtimeChannel";

function areSetsEqual(a: Set<string>, b: Set<string>) {
  if (a.size !== b.size) return false;
  for (const value of a) {
    if (!b.has(value)) return false;
  }
  return true;
}

type StreamGridProps = {
  cards: SimulatorCard[];
  streamingUdids: Set<string>;
  syncState: PresenceSyncState;
  lastSyncAt: string | null;
  watchingUdid?: string | null;
  onSelect: (udid: string | null) => void;
  onStreamCommand: (action: "start" | "stop", udid: string) => Promise<void>;
};

export default function StreamGrid({
  cards,
  streamingUdids,
  syncState,
  lastSyncAt,
  watchingUdid = null,
  onSelect,
  onStreamCommand,
}: StreamGridProps) {
  const [pendingUdids, setPendingUdids] = useState<Set<string>>(new Set());
  const onSelectRef = useRef(onSelect);
  const autoWatchRef = useRef<string | null>(null);
  const commandsDisabled = syncState !== "live";
  const statusMessage = syncState === "syncing"
    ? "Connecting to realtime sync…"
    : syncState === "stale"
      ? `Realtime sync is reconnecting${lastSyncAt ? ` · last update ${formatDuration(lastSyncAt)} ago` : ""}`
      : syncState === "offline"
        ? "The macOS app is offline"
        : null;

  const clearPending = (udid: string) => {
    setPendingUdids((prev) => {
      if (!prev.has(udid)) return prev;
      const next = new Set(prev);
      next.delete(udid);
      return next;
    });
  };

  useEffect(() => {
    onSelectRef.current = onSelect;
  }, [onSelect]);

  useEffect(() => {
    if (pendingUdids.size === 0) return;
    let shouldSelect: string | null = null;
    const nextPending = new Set<string>();

    pendingUdids.forEach((udid) => {
      const isStreaming = streamingUdids.has(udid);
      if (autoWatchRef.current === udid) {
        if (isStreaming) {
          shouldSelect = udid;
          autoWatchRef.current = null;
        } else {
          nextPending.add(udid);
        }
        return;
      }

      if (isStreaming) {
        nextPending.add(udid);
      }
    });

    if (!areSetsEqual(pendingUdids, nextPending)) {
      setPendingUdids(nextPending);
    }
    if (shouldSelect) {
      onSelectRef.current(shouldSelect);
    }
  }, [pendingUdids, streamingUdids]);

  useEffect(() => {
    if (pendingUdids.size === 0 || syncState !== "live") return;
    const timer = window.setTimeout(() => {
      logDebug("command", "pending command timeout expired", {
        pendingUdids: Array.from(pendingUdids),
        syncState,
      });
      toast("Mac app did not confirm the state change yet", {
        description: "The command was acknowledged, but the source-of-truth stream state did not change within 12 seconds.",
      });
      setPendingUdids(new Set());
      autoWatchRef.current = null;
    }, STREAM_STATE_TIMEOUT_MS);
    return () => window.clearTimeout(timer);
  }, [pendingUdids, syncState]);

  useEffect(() => {
    if (cards.length === 0) {
      onSelectRef.current(null);
    }
  }, [cards]);

  const handleStart = (udid: string) => {
    if (pendingUdids.has(udid) || commandsDisabled) return;

    autoWatchRef.current = udid;
    setPendingUdids((prev) => new Set(prev).add(udid));

    void onStreamCommand("start", udid).catch((error) => {
      clearPending(udid);
      if (autoWatchRef.current === udid) {
        autoWatchRef.current = null;
      }
      toast("Failed to start the stream", {
        description: error instanceof Error ? error.message : "The mac app did not accept the command.",
      });
    });
  };

  const handleStop = (udid: string) => {
    if (pendingUdids.has(udid) || commandsDisabled) return;

    setPendingUdids((prev) => new Set(prev).add(udid));

    void onStreamCommand("stop", udid).catch((error) => {
      clearPending(udid);
      toast("Failed to stop the stream", {
        description: error instanceof Error ? error.message : "The mac app did not accept the command.",
      });
    });
  };

  if (cards.length === 0) {
    return (
      <div
        className="flex flex-col items-center justify-center rounded-3xl"
        style={{
          height: "calc(100% - 8px)",
          border: "1px solid var(--border-subtle)",
          background: "linear-gradient(135deg, var(--skeleton-bg) 0%, transparent 100%)",
        }}
      >
        <div
          className="w-14 h-14 rounded-2xl flex items-center justify-center mb-5"
          style={{ background: "var(--badge-bg)", border: "1px solid var(--badge-border)" }}
        >
          <svg viewBox="0 0 16 16" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" style={{ color: "var(--violet)" }}>
            <rect x="3" y="1" width="10" height="14" rx="2.5" />
            <circle cx="8" cy="12" r="0.7" fill="currentColor" stroke="none" />
          </svg>
        </div>
        <p className="font-semibold mb-2" style={{ color: "var(--text)" }}>
          {syncState === "live" ? "No active sessions" : syncState === "offline" ? "macOS app offline" : "Realtime sync unavailable"}
        </p>
        <p className="text-sm text-center max-w-xs leading-relaxed" style={{ color: "var(--text-2)" }}>
          {syncState === "live"
            ? "Open the SimCast macOS app and boot a simulator to make it available here."
            : syncState === "offline"
              ? "Open SimCast on macOS and keep it signed in to control your local simulators."
              : "The dashboard is reconnecting to realtime services. Simulator state may be temporarily out of date."}
        </p>
      </div>
    );
  }

  const sessionUptime = cards.length > 0
    ? `${formatDuration(cards.reduce((min, c) => c.startedAt < min ? c.startedAt : min, cards[0].startedAt))} session`
    : "";

  return (
    <>
      <style>{`
        @keyframes btnSpin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        .btn-spinner { animation: btnSpin 0.7s linear infinite; }
      `}</style>
      <SectionHeaderWithBadge
        title="Active simulators"
        count={cards.length}
        trailing={
          <div className="flex items-center gap-2">
            {statusMessage && (
              <span
                style={{
                  fontSize: "var(--font-size-xs)",
                  color: syncState === "live" ? "var(--text-3)" : syncState === "offline" ? "var(--error-text)" : "#f59e0b",
                }}
              >
                {statusMessage}
              </span>
            )}
            <span style={{ fontSize: "var(--font-size-xs)", color: "var(--text-3)" }}>{sessionUptime}</span>
          </div>
        }
        style={{ marginBottom: 12 }}
      />
      <div className="flex flex-col gap-4">
        {cards.map((card) => {
          const isStreaming = streamingUdids.has(card.id);
          const isPending = pendingUdids.has(card.id);
          const isWatching = watchingUdid === card.id;
          const isClickable = isStreaming && !isPending;

          return (
            <div
              key={card.id}
              className="rounded-2xl overflow-hidden group"
              style={{
                background: "var(--surface)",
                border: isWatching
                  ? "1px solid var(--violet)"
                  : "1px solid transparent",
                boxShadow: isWatching
                  ? "0 0 16px rgba(124, 58, 237, 0.25), 0 0 4px rgba(124, 58, 237, 0.15)"
                  : "none",
                cursor: isClickable ? "pointer" : "default",
                transition: "border-color 0.2s, box-shadow 0.2s",
              }}
              onClick={() => {
                if (isClickable) onSelect(isWatching ? null : card.id);
              }}
              onMouseEnter={(e) => {
                if (!isWatching) {
                  e.currentTarget.style.border = "1px solid var(--tab-hover-border)";
                  e.currentTarget.style.backgroundColor = "var(--tab-hover-bg)";
                }
              }}
              onMouseLeave={(e) => {
                if (!isWatching) {
                  e.currentTarget.style.border = "1px solid transparent";
                  e.currentTarget.style.backgroundColor = "var(--surface)";
                } else {
                  e.currentTarget.style.backgroundColor = "var(--surface)";
                }
              }}
            >
              <div
                className="px-5 pt-5 pb-4"
                style={{ borderBottom: "1px solid var(--border-subtle)" }}
              >
                <div className="flex items-start gap-4">
                  <DeviceIconBox identifier={card.deviceTypeIdentifier} />
                  <SimulatorDeviceInfo name={card.name} osVersion={card.osVersion} udid={card.id} isStreaming={isStreaming} isWatching={isWatching} />
                </div>
              </div>

              <div className="px-5 py-3 flex items-center justify-between">
                <div className="flex flex-col gap-0.5">
                  <span className="text-[10px]" style={{ color: "var(--text-3)" }}>
                    Started {formatDuration(card.startedAt)} ago
                  </span>
                </div>

                <div className="flex items-center gap-2">
                  {isStreaming && !isPending && !isWatching && (
                    <span className="flex items-center gap-1.5 text-[10px] transition-opacity duration-200" style={{ color: "var(--text-3)" }}>
                      <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" className="w-3 h-3">
                        <path d="M1 8s2.5-5 7-5 7 5 7 5-2.5 5-7 5-7-5-7-5z" />
                        <circle cx="8" cy="8" r="2" fill="currentColor" stroke="none" />
                      </svg>
                      Tap to watch
                    </span>
                  )}

                  {isStreaming && !isPending && (
                    <button
                      title="Stop streaming"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleStop(card.id);
                      }}
                      disabled={commandsDisabled}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all duration-200 hover:scale-[1.04]"
                      style={{
                        background: "var(--btn-danger-bg)",
                        border: "1px solid var(--btn-danger-border)",
                        color: "var(--btn-danger-text)",
                        opacity: commandsDisabled ? 0.6 : 1,
                        cursor: commandsDisabled ? "not-allowed" : "pointer",
                      }}
                    >
                      <svg viewBox="0 0 16 16" fill="currentColor" className="w-3 h-3">
                        <rect x="3" y="3" width="10" height="10" rx="1" />
                      </svg>
                      Stop
                    </button>
                  )}

                  {isPending && isStreaming && (
                    <button
                      disabled
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold opacity-60 cursor-not-allowed"
                      style={{
                        background: "var(--btn-danger-bg)",
                        border: "1px solid var(--btn-danger-border)",
                        color: "var(--btn-danger-text)",
                      }}
                    >
                      <LoadingSpinner />
                      Stopping…
                    </button>
                  )}

                  {!isStreaming && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleStart(card.id);
                      }}
                      disabled={isPending || commandsDisabled}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all duration-200 hover:scale-[1.04] disabled:opacity-60 disabled:cursor-not-allowed disabled:hover:scale-100"
                      style={{
                        background: "var(--btn-primary-from)",
                        border: "1px solid var(--btn-primary-border)",
                        color: "var(--btn-primary-text)",
                      }}
                    >
                      {isPending ? (
                        <LoadingSpinner />
                      ) : (
                        <svg viewBox="0 0 16 16" fill="currentColor" className="w-3 h-3">
                          <path d="M3 3.732a1.5 1.5 0 012.305-1.265l6.706 4.267a1.5 1.5 0 010 2.531L5.305 13.533A1.5 1.5 0 013 12.267V3.732z" />
                        </svg>
                      )}
                      {isPending ? "Starting…" : "Start"}
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
}
