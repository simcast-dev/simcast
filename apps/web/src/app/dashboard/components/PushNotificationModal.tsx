"use client";

import React, { useState } from "react";
import AppDropdown from "./AppDropdown";

const modalInputStyle: React.CSSProperties = {
  width: "100%",
  padding: "10px 12px",
  borderRadius: "var(--radius-sm)",
  background: "var(--input-bg)",
  border: "1px solid var(--input-border)",
  color: "var(--text)",
  fontSize: "var(--font-size-base)",
  outline: "none",
  boxSizing: "border-box",
  transition: "border-color 0.15s",
};

export default function PushNotificationModal({
  open,
  onClose,
  udid,
  onSend,
  apps,
  appsLoading,
}: {
  open: boolean;
  onClose: () => void;
  udid: string | null;
  onSend: (payload: Record<string, unknown>) => void;
  apps: Array<{ bundleId: string; name: string }>;
  appsLoading: boolean;
}) {
  const [bundleId, setBundleId] = useState("");
  const [title, setTitle] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [body, setBody] = useState("");
  const [badge, setBadge] = useState("");
  const [sound, setSound] = useState("");
  const [category, setCategory] = useState("");
  const [silent, setSilent] = useState(false);
  const [showAdvanced, setShowAdvanced] = useState(false);

  if (!open) return null;

  function handleSend() {
    const bid = bundleId.trim();
    const b = body.trim();
    if (!bid || (!silent && !b)) return;
    const payload: Record<string, unknown> = { bundleId: bid };
    if (b) payload.body = b;
    const t = title.trim();
    if (t) payload.title = t;
    const st = subtitle.trim();
    if (st) payload.subtitle = st;
    const badgeNum = parseInt(badge, 10);
    if (!isNaN(badgeNum) && badge.trim() !== "") payload.badge = badgeNum;
    const s = sound.trim();
    if (s) payload.sound = s;
    const cat = category.trim();
    if (cat) payload.category = cat;
    // Maps to APNs content-available: wakes the app without showing a user-visible notification
    if (silent) payload.contentAvailable = true;
    onSend(payload);
    handleClose();
  }

  function handleClose() {
    setBundleId("");
    setTitle("");
    setSubtitle("");
    setBody("");
    setBadge("");
    setSound("");
    setCategory("");
    setSilent(false);
    setShowAdvanced(false);
    onClose();
  }

  return (
    <div style={{ position: "fixed", inset: 0, zIndex: 1000, display: "flex", alignItems: "center", justifyContent: "center" }}>
      {/* Backdrop */}
      <div
        onClick={handleClose}
        style={{ position: "absolute", inset: 0, background: "var(--overlay-bg)", backdropFilter: "blur(8px)", WebkitBackdropFilter: "blur(8px)" }}
      />

      {/* Card */}
      <div style={{
        position: "relative",
        width: 420,
        background: "var(--card-bg)",
        border: "1px solid var(--card-border)",
        borderRadius: "var(--radius-lg)",
        padding: 24,
        display: "flex",
        flexDirection: "column",
        gap: 16,
        boxShadow: "0 24px 64px rgba(0,0,0,0.6), 0 0 0 1px rgba(124,58,237,0.1) inset",
      }}>
        {/* Header */}
        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
          <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", color: "var(--muted-label)", textTransform: "uppercase" }}>
            Push Notification
            {udid && <span style={{ color: "var(--muted-label-2)", fontWeight: "var(--font-weight-medium)" }}> · {udid}</span>}
          </span>
        </div>

        {/* App selector */}
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <label style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--muted-label)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>App</label>
          <AppDropdown apps={apps} value={bundleId} onChange={setBundleId} loading={appsLoading} />
        </div>

        {/* Title + Badge row */}
        <div style={{ display: "flex", gap: 10 }}>
          <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 6 }}>
            <label style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--muted-label)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>Title <span style={{ fontWeight: "var(--font-weight-normal)", color: "var(--muted-label-2)" }}>(optional)</span></label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Notification title…"
              style={modalInputStyle}
              onFocus={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border-focus)"; }}
              onBlur={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border)"; }}
            />
          </div>
          <div style={{ width: 88, flexShrink: 0, display: "flex", flexDirection: "column", gap: 6 }}>
            <label style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--muted-label)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>Badge</label>
            <input
              type="number"
              min="0"
              value={badge}
              onChange={(e) => setBadge(e.target.value)}
              placeholder="0"
              style={{ ...modalInputStyle, MozAppearance: "textfield", appearance: "textfield" } as React.CSSProperties}
              onFocus={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border-focus)"; }}
              onBlur={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border)"; }}
            />
          </div>
        </div>

        {/* Body textarea — hidden when silent */}
        {!silent && (
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <label style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--muted-label)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>Body <span style={{ color: "var(--muted-label-2)" }}>*</span></label>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Notification body…"
              rows={3}
              style={{
                ...modalInputStyle,
                resize: "vertical",
                fontFamily: "inherit",
              }}
              onFocus={(e) => { (e.currentTarget as HTMLTextAreaElement).style.borderColor = "var(--input-border-focus)"; }}
              onBlur={(e) => { (e.currentTarget as HTMLTextAreaElement).style.borderColor = "var(--input-border)"; }}
            />
          </div>
        )}

        {/* Silent toggle */}
        <label style={{ display: "flex", alignItems: "center", gap: 10, cursor: "pointer", userSelect: "none" }}>
          <div
            onClick={() => setSilent((v) => !v)}
            style={{
              width: 36,
              height: 20,
              borderRadius: "var(--radius-sm)",
              background: silent ? "var(--toggle-on-bg)" : "var(--toggle-off-bg)",
              border: `1px solid ${silent ? "var(--toggle-on-border)" : "var(--toggle-off-border)"}`,
              position: "relative",
              flexShrink: 0,
              transition: "background 0.15s, border-color 0.15s",
              cursor: "pointer",
            }}
          >
            <div style={{
              position: "absolute",
              top: 2,
              left: silent ? 17 : 2,
              width: 14,
              height: 14,
              borderRadius: 7,
              background: "#fff",
              transition: "left 0.15s",
            }} />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
            <span style={{ fontSize: "var(--font-size-base)", color: silent ? "var(--violet-2)" : "var(--text-2)", fontWeight: "var(--font-weight-medium)", transition: "color 0.15s" }}>Silent</span>
            <span style={{ fontSize: "var(--font-size-xs)", color: "var(--muted-label-2)" }}>content-available: 1 — wakes app, no visible alert</span>
          </div>
        </label>

        {/* Advanced toggle */}
        <div>
          <button
            onClick={() => setShowAdvanced((v) => !v)}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 6,
              background: "none",
              border: "none",
              padding: 0,
              cursor: "pointer",
              color: "var(--muted-label-2)",
              fontSize: "var(--font-size-xs)",
              fontWeight: "var(--font-weight-semibold)",
              letterSpacing: "var(--tracking-wide)",
              textTransform: "uppercase",
            }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "var(--muted-label)"; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "var(--muted-label-2)"; }}
          >
            <svg style={{ transform: `rotate(${showAdvanced ? 90 : 0}deg)`, transition: "transform 0.15s", flexShrink: 0 }} viewBox="0 0 8 12" width="6" height="10" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M2 2l4 4-4 4" />
            </svg>
            More options
          </button>

          {showAdvanced && (
            <div style={{ display: "flex", flexDirection: "column", gap: 12, marginTop: 12 }}>
              {/* Subtitle */}
              <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                <label style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--muted-label)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>Subtitle <span style={{ fontWeight: "var(--font-weight-normal)", color: "var(--muted-label-2)" }}>(optional)</span></label>
                <input
                  value={subtitle}
                  onChange={(e) => setSubtitle(e.target.value)}
                  placeholder="Secondary line below title…"
                  style={modalInputStyle}
                  onFocus={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border-focus)"; }}
                  onBlur={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border)"; }}
                />
              </div>

              {/* Sound + Category row */}
              <div style={{ display: "flex", gap: 10 }}>
                <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 6 }}>
                  <label style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--muted-label)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>Sound</label>
                  <input
                    value={sound}
                    onChange={(e) => setSound(e.target.value)}
                    placeholder="default"
                    style={modalInputStyle}
                    onFocus={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border-focus)"; }}
                    onBlur={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border)"; }}
                  />
                </div>
                <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 6 }}>
                  <label style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--muted-label)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" }}>Category</label>
                  <input
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                    placeholder="ACTION_CATEGORY"
                    style={modalInputStyle}
                    onFocus={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border-focus)"; }}
                    onBlur={(e) => { (e.currentTarget as HTMLInputElement).style.borderColor = "var(--input-border)"; }}
                  />
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Actions */}
        <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
          <button
            onClick={handleClose}
            style={{
              padding: "8px 18px",
              borderRadius: "var(--radius-sm)",
              background: "var(--btn-secondary-bg)",
              border: "1px solid var(--btn-secondary-border)",
              color: "var(--btn-secondary-text)",
              fontSize: "var(--font-size-base)",
              cursor: "pointer",
              transition: "all 0.15s",
            }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "var(--control-bg-hover)"; (e.currentTarget as HTMLButtonElement).style.color = "var(--text)"; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "var(--btn-secondary-bg)"; (e.currentTarget as HTMLButtonElement).style.color = "var(--btn-secondary-text)"; }}
          >
            Cancel
          </button>
          <button
            onClick={handleSend}
            disabled={!bundleId.trim() || (!silent && !body.trim())}
            style={{
              padding: "8px 20px",
              borderRadius: "var(--radius-sm)",
              background: (bundleId.trim() && (silent || body.trim())) ? "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))" : "var(--control-bg)",
              border: `1px solid ${(bundleId.trim() && (silent || body.trim())) ? "var(--btn-primary-border)" : "var(--control-border)"}`,
              color: (bundleId.trim() && (silent || body.trim())) ? "var(--btn-primary-text)" : "var(--text-3)",
              fontSize: "var(--font-size-base)",
              fontWeight: "var(--font-weight-semibold)",
              cursor: (bundleId.trim() && (silent || body.trim())) ? "pointer" : "default",
              transition: "all 0.15s",
              letterSpacing: "var(--tracking-tight)",
            }}
          >
            Send
          </button>
        </div>
      </div>
    </div>
  );
}
