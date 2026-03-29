"use client";

import React, { useEffect, useRef, useState } from "react";

export default function AppDropdown({
  apps,
  value,
  onChange,
  loading,
}: {
  apps: Array<{ bundleId: string; name: string }>;
  value: string;
  onChange: (bundleId: string) => void;
  loading?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const selected = apps.find((a) => a.bundleId === value);

  useEffect(() => {
    if (!open) return;
    // mousedown instead of click: fires before focus changes, preventing race conditions with input focus
    function onMouseDown(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onMouseDown);
    return () => document.removeEventListener("mousedown", onMouseDown);
  }, [open]);

  return (
    <div ref={ref} style={{ position: "relative", width: "100%" }}>
      <button
        onClick={() => setOpen((v) => !v)}
        style={{
          width: "100%",
          padding: "10px 36px 10px 12px",
          borderRadius: "var(--radius-sm)",
          background: "var(--input-bg)",
          border: "1px solid var(--input-border)",
          color: "var(--text)",
          cursor: "pointer",
          textAlign: "left",
          display: "flex",
          flexDirection: "column",
          gap: 3,
          position: "relative",
          transition: "border-color 0.15s",
        }}
        onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--input-border-focus)"; }}
        onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--input-border)"; }}
      >
        {selected ? (
          <>
            <span style={{ fontSize: "var(--font-size-lg)", fontWeight: "var(--font-weight-semibold)", color: "var(--text)", lineHeight: 1.3 }}>{selected.name}</span>
            <span style={{ fontSize: "var(--font-size-xs)", fontFamily: "monospace", color: "var(--muted-label)", letterSpacing: "var(--tracking-tight)" }}>{selected.bundleId}</span>
          </>
        ) : (
          <span style={{ fontSize: "var(--font-size-base)", color: "var(--placeholder-text)" }}>Select app…</span>
        )}
        <svg
          style={{ position: "absolute", right: 12, top: "50%", transform: `translateY(-50%) rotate(${open ? 180 : 0}deg)`, transition: "transform 0.15s" }}
          viewBox="0 0 12 8" width="12" height="8" fill="none" stroke="var(--muted-label)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"
        >
          <path d="M1 1.5l5 5 5-5" />
        </svg>
      </button>

      {open && (
        <div
          style={{
            position: "absolute",
            top: "calc(100% + 4px)",
            left: 0,
            right: 0,
            maxHeight: 220,
            overflowY: "auto",
            background: "var(--surface)",
            border: "1px solid var(--input-border)",
            borderRadius: "var(--radius-sm)",
            zIndex: 10,
            boxShadow: "0 8px 32px rgba(0,0,0,0.5)",
          }}
        >
          {loading ? (
            <div style={{ padding: "14px 16px", fontSize: "var(--font-size-sm)", color: "var(--placeholder-text)" }}>Fetching apps…</div>
          ) : apps.length === 0 ? (
            <div style={{ padding: "14px 16px", fontSize: "var(--font-size-sm)", color: "var(--placeholder-text)" }}>No apps found</div>
          ) : (
            apps.map((app) => {
              const isSel = app.bundleId === value;
              return (
                <button
                  key={app.bundleId}
                  onClick={() => { onChange(app.bundleId); setOpen(false); }}
                  style={{
                    width: "100%",
                    padding: "10px 14px",
                    paddingLeft: isSel ? 11 : 14,
                    textAlign: "left",
                    background: isSel ? "linear-gradient(135deg, var(--tab-active-from), var(--tab-active-to))" : "transparent",
                    border: "none",
                    borderLeft: isSel ? "3px solid var(--violet)" : "3px solid transparent",
                    cursor: "pointer",
                    display: "flex",
                    flexDirection: "column",
                    gap: 3,
                  }}
                  onMouseEnter={(e) => { if (!isSel) (e.currentTarget as HTMLButtonElement).style.background = "var(--control-bg-hover)"; }}
                  onMouseLeave={(e) => { if (!isSel) (e.currentTarget as HTMLButtonElement).style.background = "transparent"; }}
                >
                  <span style={{ fontSize: "var(--font-size-base)", fontWeight: "var(--font-weight-medium)", color: isSel ? "var(--violet-2)" : "var(--text)" }}>{app.name}</span>
                  <span style={{ fontSize: "var(--font-size-xs)", fontFamily: "monospace", color: "var(--muted-label-2)", letterSpacing: "var(--tracking-tight)" }}>{app.bundleId}</span>
                </button>
              );
            })
          )}
        </div>
      )}
    </div>
  );
}
