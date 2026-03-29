import React from "react";

// Identifier-based detection: Simulator device type identifiers contain "iPad" for tablets,
// avoiding the need to maintain a device database
function DeviceIcon({ identifier }: { identifier: string }) {
  const lower = identifier.toLowerCase();
  if (lower.includes("ipad")) {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
        <rect x="4" y="2" width="16" height="20" rx="2.5" />
        <circle cx="12" cy="18.5" r="0.75" fill="currentColor" stroke="none" />
        <line x1="4" y1="4.5" x2="20" y2="4.5" strokeWidth="0.75" />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
      <rect x="6" y="2" width="12" height="20" rx="2.5" />
      <circle cx="12" cy="18.5" r="0.75" fill="currentColor" stroke="none" />
      <line x1="6" y1="4.5" x2="18" y2="4.5" strokeWidth="0.75" />
    </svg>
  );
}

export function ControlPanelButton({ onClick, title, disabled, isActive, children }: {
  onClick: React.MouseEventHandler<HTMLButtonElement>;
  title: string;
  disabled?: boolean;
  isActive?: boolean;
  children: React.ReactNode;
}) {
  return (
    <button
      title={title}
      onClick={onClick}
      disabled={disabled}
      style={{
        width: 56,
        height: 52,
        borderRadius: "var(--radius-md)",
        background: isActive ? "var(--streaming-glow-bg)" : "var(--control-bg)",
        backdropFilter: "blur(12px)",
        borderWidth: "1px",
        borderStyle: "solid",
        borderColor: isActive ? "var(--streaming-glow-border)" : "var(--control-border)",
        color: isActive ? "var(--emerald)" : "var(--control-text)",
        cursor: disabled ? "default" : "pointer",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 3,
        padding: 0,
        transition: "background 0.15s, color 0.15s, border-color 0.15s",
      }}
      onMouseEnter={e => {
        if (!isActive && !disabled) {
          const el = e.currentTarget as HTMLButtonElement;
          el.style.background = "var(--control-bg-hover)";
          el.style.color = "var(--text)";
          el.style.borderColor = "var(--control-border-hover)";
        }
      }}
      onMouseLeave={e => {
        if (!isActive && !disabled) {
          const el = e.currentTarget as HTMLButtonElement;
          el.style.background = "var(--control-bg)";
          el.style.color = "var(--control-text)";
          el.style.borderColor = "var(--control-border)";
        }
      }}
    >
      {children}
    </button>
  );
}

export function StatItem({ label, value, valueColor }: {
  label: string;
  value: string | React.ReactNode;
  valueColor?: string;
}) {
  return (
    <span>
      <span style={{ fontSize: "var(--font-size-xs)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" as const, opacity: 0.4, marginRight: 5 }}>
        {label}
      </span>
      {valueColor ? <span style={{ color: valueColor }}>{value}</span> : value}
    </span>
  );
}

export function DeviceIconBox({ identifier }: { identifier: string }) {
  return (
    <div className="relative flex-shrink-0">
      <div
        className="w-12 h-12 rounded-xl flex items-center justify-center"
        style={{
          background: "var(--badge-bg)",
          border: "1px solid var(--badge-border)",
          color: "var(--violet)",
        }}
      >
        <DeviceIcon identifier={identifier} />
      </div>
    </div>
  );
}

export function SimulatorDeviceInfo({ name, osVersion, udid, isStreaming, isWatching }: {
  name: string;
  osVersion: string;
  udid: string;
  isStreaming: boolean;
  isWatching?: boolean;
}) {
  return (
    <div className="flex-1 min-w-0">
      <div className="flex items-center gap-2 mb-0.5">
        <h3 className="font-semibold text-sm truncate" style={{ color: "var(--text)" }}>{name}</h3>
        {isWatching ? (
          <span
            className="flex-shrink-0 flex items-center gap-1 text-[9px] font-bold px-1.5 py-0.5 rounded-full"
            style={{ background: "rgba(124, 58, 237, 0.15)", border: "1px solid rgba(124, 58, 237, 0.3)", color: "var(--violet)" }}
          >
            <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" className="w-2.5 h-2.5">
              <path d="M1 8s2.5-5 7-5 7 5 7 5-2.5 5-7 5-7-5-7-5z" />
              <circle cx="8" cy="8" r="2" fill="currentColor" stroke="none" />
            </svg>
            WATCHING
          </span>
        ) : isStreaming ? (
          <span
            className="flex-shrink-0 flex items-center gap-1 text-[9px] font-bold px-1.5 py-0.5 rounded-full"
            style={{ background: "var(--streaming-glow-bg)", border: "1px solid var(--streaming-glow-border)", color: "var(--emerald)" }}
          >
            <span className="w-1 h-1 rounded-full bg-green-400 animate-pulse inline-block" />
            STREAMING
          </span>
        ) : null}
      </div>
      <p className="text-xs" style={{ color: "var(--text-2)" }}>{osVersion}</p>
      <p className="text-[10px] mt-1 font-code tracking-wide" style={{ color: "var(--text-3)" }}>
        {udid.slice(0, 8).toUpperCase()}
      </p>
    </div>
  );
}

export function SectionHeaderWithBadge({ title, count, trailing, style }: {
  title: string;
  count: number;
  trailing?: React.ReactNode;
  style?: React.CSSProperties;
}) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, ...style }}>
      <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase" as const, color: "var(--text-3)" }}>
        {title}
      </span>
      <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", background: "var(--badge-bg)", border: "1px solid var(--badge-border)", borderRadius: "var(--radius-sm)", padding: "1px 7px", color: "var(--badge-text)" }}>
        {count}
      </span>
      <div style={{ flex: 1, height: 1, background: "var(--border-subtle)" }} />
      {trailing}
    </div>
  );
}

export function PanelDivider() {
  return <div style={{ width: "100%", height: 1, background: "var(--divider)" }} />;
}

export function LoadingSpinner() {
  return (
    <svg viewBox="0 0 16 16" fill="none" className="w-3 h-3 btn-spinner">
      <circle cx="8" cy="8" r="6" stroke="currentColor" strokeOpacity="0.3" strokeWidth="2.5" />
      <path d="M14 8a6 6 0 0 0-6-6" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
    </svg>
  );
}
