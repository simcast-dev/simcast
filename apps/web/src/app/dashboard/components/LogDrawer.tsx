"use client";

import React, { useState, useRef, useEffect, useCallback } from "react";
import type { LogEntry, LogCategory } from "../hooks/useLogStream";

const CATEGORY_CONFIG: Record<LogCategory, { label: string; symbol: string; color: string }> = {
  stream:   { label: "stream",   symbol: "\u25CF", color: "var(--log-stream)" },
  livekit:  { label: "livekit",  symbol: "\u2191", color: "var(--log-livekit)" },
  presence: { label: "presence", symbol: "\u2B21", color: "var(--log-presence)" },
  command:  { label: "cmd",      symbol: "\u26A1", color: "var(--log-command)" },
  error:    { label: "error",    symbol: "\u2715", color: "var(--log-error)" },
};

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString("en-US", { hour12: false, hour: "2-digit", minute: "2-digit", second: "2-digit" })
    + "." + d.getMilliseconds().toString().padStart(3, "0");
}

export default function LogDrawer({ logs, errorCount, onClear }: { logs: LogEntry[]; errorCount: number; onClear: () => void }) {
  const [open, setOpen] = useState(false);
  const [height, setHeight] = useState(240);
  const [filters, setFilters] = useState<Set<LogCategory>>(new Set(["stream", "livekit", "presence", "command", "error"]));
  const listRef = useRef<HTMLDivElement>(null);
  const shouldAutoScroll = useRef(true);
  const dragRef = useRef<{ startY: number; startH: number } | null>(null);

  const filteredLogs = logs.filter(l => filters.has(l.category));

  const toggleFilter = useCallback((cat: LogCategory) => {
    setFilters(prev => {
      const next = new Set(prev);
      if (next.has(cat)) next.delete(cat);
      else next.add(cat);
      return next;
    });
  }, []);

  useEffect(() => {
    if (shouldAutoScroll.current && listRef.current) {
      listRef.current.scrollTop = listRef.current.scrollHeight;
    }
  }, [filteredLogs.length]);

  const handleScroll = useCallback(() => {
    if (!listRef.current) return;
    const { scrollTop, scrollHeight, clientHeight } = listRef.current;
    shouldAutoScroll.current = scrollHeight - scrollTop - clientHeight < 40;
  }, []);

  const handleDragStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    dragRef.current = { startY: e.clientY, startH: height };
    const handleMove = (ev: MouseEvent) => {
      if (!dragRef.current) return;
      const newH = dragRef.current.startH + (dragRef.current.startY - ev.clientY);
      setHeight(Math.max(100, Math.min(window.innerHeight * 0.5, newH)));
    };
    const handleUp = () => {
      dragRef.current = null;
      window.removeEventListener("mousemove", handleMove);
      window.removeEventListener("mouseup", handleUp);
    };
    window.addEventListener("mousemove", handleMove);
    window.addEventListener("mouseup", handleUp);
  }, [height]);

  useEffect(() => {
    if (!open) return;
    const handleKey = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [open]);

  return (
    <>
      {/* Toggle button — rendered inline in footer by parent */}
      <button
        onClick={() => setOpen(prev => !prev)}
        className="flex items-center gap-1.5"
        style={{
          position: "absolute",
          right: 12,
          top: "50%",
          transform: "translateY(-50%)",
          background: open ? "var(--surface-2)" : "transparent",
          border: "1px solid var(--border-subtle)",
          borderRadius: "var(--radius-sm)",
          padding: "4px 10px",
          cursor: "pointer",
          color: "var(--text-3)",
          fontSize: "var(--font-size-xs)",
          fontWeight: "var(--font-weight-semibold)",
        }}
      >
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" className="w-3.5 h-3.5">
          <rect x="2" y="2" width="12" height="12" rx="2" />
          <line x1="2" y1="8" x2="14" y2="8" />
          <line x1="5" y1="10.5" x2="11" y2="10.5" strokeOpacity="0.5" />
          <line x1="5" y1="12.5" x2="9" y2="12.5" strokeOpacity="0.3" />
        </svg>
        Logs
        {logs.length > 0 && (
          <span style={{
            background: "var(--badge-bg)",
            border: "1px solid var(--badge-border)",
            borderRadius: "var(--radius-sm)",
            padding: "0 5px",
            fontSize: 10,
            color: "var(--badge-text)",
          }}>
            {logs.length}
          </span>
        )}
        {errorCount > 0 && (
          <span style={{
            background: "rgba(220,38,38,0.15)",
            border: "1px solid rgba(220,38,38,0.3)",
            borderRadius: "var(--radius-sm)",
            padding: "0 5px",
            fontSize: 10,
            color: "var(--log-error)",
          }}>
            {errorCount}
          </span>
        )}
      </button>

      {/* Drawer */}
      {open && (
        <div
          style={{
            position: "fixed",
            bottom: 0,
            left: 0,
            right: 0,
            height,
            zIndex: 100,
            display: "flex",
            flexDirection: "column",
            background: "var(--bg)",
            borderTop: "1px solid var(--border)",
          }}
        >
          {/* Drag handle */}
          <div
            onMouseDown={handleDragStart}
            style={{
              height: 6,
              cursor: "ns-resize",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
            }}
          >
            <div style={{ width: 40, height: 3, borderRadius: 2, background: "var(--border)" }} />
          </div>

          {/* Header */}
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              padding: "4px 12px 6px",
              borderBottom: "1px solid var(--border-subtle)",
              flexShrink: 0,
            }}
          >
            <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", color: "var(--text-3)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>
              Logs
            </span>

            <div style={{ display: "flex", gap: 4 }}>
              {(Object.entries(CATEGORY_CONFIG) as [LogCategory, typeof CATEGORY_CONFIG[LogCategory]][]).map(([cat, cfg]) => {
                const active = filters.has(cat);
                return (
                  <button
                    key={cat}
                    onClick={() => toggleFilter(cat)}
                    style={{
                      padding: "2px 8px",
                      borderRadius: "var(--radius-sm)",
                      fontSize: 10,
                      fontWeight: "var(--font-weight-semibold)",
                      border: `1px solid ${active ? cfg.color : "var(--border-subtle)"}`,
                      background: active ? `${cfg.color}18` : "transparent",
                      color: active ? cfg.color : "var(--text-3)",
                      cursor: "pointer",
                      opacity: active ? 1 : 0.5,
                    }}
                  >
                    {cfg.label}
                  </button>
                );
              })}
            </div>

            <div style={{ flex: 1 }} />

            <button
              onClick={onClear}
              style={{
                fontSize: 10,
                color: "var(--text-3)",
                background: "transparent",
                border: "1px solid var(--border-subtle)",
                borderRadius: "var(--radius-sm)",
                padding: "2px 8px",
                cursor: "pointer",
              }}
            >
              Clear
            </button>
            <button
              onClick={() => setOpen(false)}
              style={{
                fontSize: 14,
                color: "var(--text-3)",
                background: "transparent",
                border: "none",
                cursor: "pointer",
                padding: "0 4px",
              }}
            >
              ✕
            </button>
          </div>

          {/* Log list */}
          <div
            ref={listRef}
            onScroll={handleScroll}
            style={{
              flex: 1,
              overflowY: "auto",
              padding: "4px 0",
              fontFamily: "var(--font-geist-mono, monospace)",
              fontSize: 11,
              lineHeight: "18px",
            }}
          >
            {filteredLogs.length === 0 ? (
              <div style={{ padding: "20px 12px", color: "var(--text-3)", textAlign: "center", fontSize: "var(--font-size-xs)" }}>
                {logs.length === 0 ? "No logs yet" : "No logs match the selected filters"}
              </div>
            ) : (
              filteredLogs.map(log => {
                const cfg = CATEGORY_CONFIG[log.category];
                return (
                  <div
                    key={log.id}
                    style={{
                      display: "flex",
                      alignItems: "baseline",
                      gap: 8,
                      padding: "1px 12px",
                      whiteSpace: "nowrap",
                    }}
                  >
                    <span style={{ color: "var(--text-3)", flexShrink: 0, width: 85 }}>
                      {formatTime(log.timestamp)}
                    </span>
                    <span style={{
                      color: cfg.color,
                      flexShrink: 0,
                      width: 70,
                      fontWeight: "var(--font-weight-medium)",
                    }}>
                      {cfg.symbol} {cfg.label}
                    </span>
                    <span style={{ color: "var(--text)", overflow: "hidden", textOverflow: "ellipsis" }}>
                      {log.message}
                    </span>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}
    </>
  );
}
