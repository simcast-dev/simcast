"use client";

import { useTheme } from "@/app/theme-provider";

type ThemeOption = "auto" | "light" | "dark";

const options: { value: ThemeOption; label: string; icon: React.ReactNode }[] = [
  {
    value: "auto",
    label: "Auto",
    icon: (
      <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
        <rect x="2" y="3" width="12" height="9" rx="1.5" />
        <path d="M5 14h6" />
        <path d="M8 12v2" />
      </svg>
    ),
  },
  {
    value: "light",
    label: "Light",
    icon: (
      <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="8" cy="8" r="3" />
        <path d="M8 2v1.5M8 12.5V14M2 8h1.5M12.5 8H14M3.75 3.75l1.06 1.06M11.19 11.19l1.06 1.06M12.25 3.75l-1.06 1.06M4.81 11.19l-1.06 1.06" />
      </svg>
    ),
  },
  {
    value: "dark",
    label: "Dark",
    icon: (
      <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
        <path d="M13.5 8.5a5.5 5.5 0 1 1-6-6 4.5 4.5 0 0 0 6 6z" />
      </svg>
    ),
  },
];

export default function ThemeSelector() {
  const { theme, setTheme } = useTheme();

  return (
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
      {options.map(opt => {
        const isActive = theme === opt.value;
        return (
          <button
            key={opt.value}
            onClick={() => setTheme(opt.value)}
            title={opt.label}
            className="flex items-center gap-2"
            style={{
              padding: "8px 16px",
              borderRadius: "var(--radius-md)",
              fontSize: "var(--font-size-base)",
              fontWeight: "var(--font-weight-semibold)",
              letterSpacing: "var(--tracking-normal)",
              backgroundImage: isActive
                ? "linear-gradient(135deg, var(--tab-active-from), var(--tab-active-to))"
                : "none",
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
            {opt.icon}
            <span className="hidden sm:inline">{opt.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
