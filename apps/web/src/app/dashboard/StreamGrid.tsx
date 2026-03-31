"use client";

import { useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { DeviceIconBox, SimulatorDeviceInfo, SectionHeaderWithBadge, LoadingSpinner } from "./ui";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { usePresenceSubscription, formatDuration } from "./hooks/usePresenceSubscription";

export default function StreamGrid({
  onSelect,
  onStreamingChange,
  onSessionSummary,
  onNameMap,
  watchingUdid = null,
  userId,
  channelHealth,
}: {
  onSelect: (udid: string | null) => void;
  onStreamingChange?: (udids: Set<string>) => void;
  onSessionSummary?: (s: { count: number; streamingName: string | null }) => void;
  onNameMap?: (names: Map<string, string>) => void;
  watchingUdid?: string | null;
  userId: string;
  channelHealth?: { reconnectKey: number; register: (ch: RealtimeChannel) => void; unregister: (ch: RealtimeChannel) => void };
}) {
  const { cards, streamingUdids } = usePresenceSubscription(userId, onStreamingChange, channelHealth);
  const [pendingUdids, setPendingUdids] = useState<Set<string>>(new Set());
  const onSelectRef = useRef(onSelect);
  const autoWatchRef = useRef<string | null>(null);

  useEffect(() => {
    onSelectRef.current = onSelect;
  }, [onSelect]);

  useEffect(() => {
    setPendingUdids(new Set());

    if (autoWatchRef.current && streamingUdids.has(autoWatchRef.current)) {
      onSelectRef.current(autoWatchRef.current);
      autoWatchRef.current = null;
    }
  }, [streamingUdids]);

  useEffect(() => {
    if (pendingUdids.size === 0) return;
    const timer = setTimeout(() => {
      setPendingUdids(new Set());
      autoWatchRef.current = null;
    }, 12000);
    return () => clearTimeout(timer);
  }, [pendingUdids]);

  useEffect(() => {
    if (cards.length === 0) onSelectRef.current(null);
    const streamingCard = cards.find(c => streamingUdids.has(c.id));
    onSessionSummary?.({ count: cards.length, streamingName: streamingCard?.name ?? null });
    onNameMap?.(new Map(cards.map(c => [c.id, c.name])));
  }, [cards, streamingUdids]);

  const sendCommand = async (action: "start" | "stop", udid: string) => {
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    await supabase.from("stream_commands").insert({ user_id: user.id, action, udid });
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
        <p className="font-semibold mb-2" style={{ color: "var(--text)" }}>No active sessions</p>
        <p className="text-sm text-center max-w-xs leading-relaxed" style={{ color: "var(--text-2)" }}>
          Open the SimCast macOS app and hit Play on a simulator to start broadcasting.
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
        @keyframes ringPulse {
          0%, 100% { opacity: 0.4; transform: scale(1); }
          50% { opacity: 1; transform: scale(1.06); }
        }
        @keyframes btnSpin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        .btn-spinner { animation: btnSpin 0.7s linear infinite; }
      `}</style>
      <SectionHeaderWithBadge
        title="Active simulators"
        count={cards.length}
        trailing={<span style={{ fontSize: "var(--font-size-xs)", color: "var(--text-3)" }}>{sessionUptime}</span>}
        style={{ marginBottom: 12 }}
      />
      <div className="flex flex-col gap-4">
        {cards.map((card) => {
          const isStreaming = streamingUdids.has(card.id);
          const beingStopped = isStreaming && pendingUdids.has(card.id);
          const isWatching = watchingUdid === card.id;
          const isClickable = isStreaming && !beingStopped;

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
              onMouseEnter={e => {
                if (!isWatching) {
                  e.currentTarget.style.border = "1px solid var(--tab-hover-border)";
                  e.currentTarget.style.backgroundColor = "var(--tab-hover-bg)";
                }
              }}
              onMouseLeave={e => {
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
                  {isStreaming && !beingStopped && !isWatching && (
                    <span className="flex items-center gap-1.5 text-[10px] transition-opacity duration-200" style={{ color: "var(--text-3)" }}>
                      <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" className="w-3 h-3">
                        <path d="M1 8s2.5-5 7-5 7 5 7 5-2.5 5-7 5-7-5-7-5z" />
                        <circle cx="8" cy="8" r="2" fill="currentColor" stroke="none" />
                      </svg>
                      Tap to watch
                    </span>
                  )}

                  {isStreaming && !beingStopped && (
                    <button
                      title="Stop streaming"
                      onClick={(e) => {
                        e.stopPropagation();
                        setPendingUdids(prev => new Set(prev).add(card.id));
                        void sendCommand("stop", card.id);
                        if (watchingUdid === card.id) onSelect(null);
                      }}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all duration-200 hover:scale-[1.04]"
                      style={{
                        background: "var(--btn-danger-bg)",
                        border: "1px solid var(--btn-danger-border)",
                        color: "var(--btn-danger-text)",
                      }}
                    >
                      <svg viewBox="0 0 16 16" fill="currentColor" className="w-3 h-3">
                        <rect x="3" y="3" width="10" height="10" rx="1" />
                      </svg>
                      Stop
                    </button>
                  )}

                  {beingStopped && (
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
                        autoWatchRef.current = card.id;
                        setPendingUdids(prev => new Set(prev).add(card.id));
                        void sendCommand("start", card.id);
                      }}
                      disabled={pendingUdids.has(card.id)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all duration-200 hover:scale-[1.04] disabled:opacity-60 disabled:cursor-not-allowed disabled:hover:scale-100"
                      style={{
                        background: "var(--btn-primary-from)",
                        border: "1px solid var(--btn-primary-border)",
                        color: "var(--btn-primary-text)",
                      }}
                    >
                      {pendingUdids.has(card.id) ? (
                        <LoadingSpinner />
                      ) : (
                        <svg viewBox="0 0 16 16" fill="currentColor" className="w-3 h-3">
                          <path d="M3 3.732a1.5 1.5 0 012.305-1.265l6.706 4.267a1.5 1.5 0 010 2.531L5.305 13.533A1.5 1.5 0 013 12.267V3.732z" />
                        </svg>
                      )}
                      {pendingUdids.has(card.id) ? "Starting…" : "Start"}
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
