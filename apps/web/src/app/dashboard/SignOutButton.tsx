"use client";

import { useRouter } from "next/navigation";
import { useState, useRef, useEffect } from "react";
import { createClient } from "@/lib/supabase/client";

export default function UserMenu({ userEmail }: { userEmail: string | undefined }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function handleClick(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [open]);

  useEffect(() => {
    if (!open) return;
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("keydown", handleKey);
    return () => document.removeEventListener("keydown", handleKey);
  }, [open]);

  async function handleSignOut() {
    const supabase = createClient();
    setOpen(false);
    await supabase.auth.signOut();
    router.replace("/login");
    router.refresh();
  }

  return (
    <div ref={menuRef} style={{ position: "relative" }}>
      <nav
        className="flex items-center"
        style={{
          background: "var(--surface)",
          backdropFilter: "blur(20px)",
          WebkitBackdropFilter: "blur(20px)",
          borderRadius: "var(--radius-lg)",
          border: "1px solid var(--border)",
          padding: 4,
          boxShadow: "0 2px 16px rgba(0,0,0,0.15), inset 0 1px 0 var(--surface-2)",
        }}
      >
        <button
          onClick={() => setOpen(v => !v)}
          className="flex items-center gap-2"
          style={{
            padding: "8px 16px",
            borderRadius: "var(--radius-md)",
            fontSize: "var(--font-size-base)",
            fontWeight: "var(--font-weight-semibold)",
            letterSpacing: "var(--tracking-normal)",
            backgroundImage: open
              ? "linear-gradient(135deg, var(--tab-active-from), var(--tab-active-to))"
              : "none",
            border: open
              ? "1px solid var(--tab-active-border)"
              : "1px solid transparent",
            color: open ? "var(--tab-active-text)" : "var(--text-3)",
            cursor: "pointer",
            whiteSpace: "nowrap",
            boxShadow: open ? "var(--tab-active-shadow)" : "none",
            transition: "color 0.15s",
          }}
          onMouseEnter={e => {
            if (!open) {
              const el = e.currentTarget;
              el.style.backgroundColor = "var(--tab-hover-bg)";
              el.style.color = "var(--text-2)";
              el.style.borderColor = "var(--tab-hover-border)";
            }
          }}
          onMouseLeave={e => {
            if (!open) {
              const el = e.currentTarget;
              el.style.backgroundColor = "transparent";
              el.style.color = "var(--text-3)";
              el.style.borderColor = "transparent";
            }
          }}
        >
          <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="8" cy="5.5" r="3" />
            <path d="M2.5 14.5c0-3 2.5-5 5.5-5s5.5 2 5.5 5" />
          </svg>
          <span className="hidden sm:inline">Account</span>
        </button>
      </nav>

      {open && (
        <div
          style={{
            position: "absolute",
            top: "calc(100% + 8px)",
            right: 0,
            minWidth: 220,
            background: "var(--card-bg)",
            backdropFilter: "blur(20px)",
            WebkitBackdropFilter: "blur(20px)",
            border: "1px solid var(--card-border)",
            borderRadius: "var(--radius-md)",
            boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
            overflow: "hidden",
            zIndex: 100,
          }}
        >
          {userEmail && (
            <div
              style={{
                padding: "12px 16px",
                borderBottom: "1px solid var(--divider)",
              }}
            >
              <div
                style={{
                  fontSize: "var(--font-size-xs)",
                  fontWeight: "var(--font-weight-bold)",
                  letterSpacing: "var(--tracking-wide)",
                  textTransform: "uppercase",
                  color: "var(--text-3)",
                  marginBottom: 4,
                }}
              >
                Signed in as
              </div>
              <div
                style={{
                  fontSize: "var(--font-size-sm)",
                  fontWeight: "var(--font-weight-medium)",
                  color: "var(--text)",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {userEmail}
              </div>
            </div>
          )}
          <button
            onClick={handleSignOut}
            className="flex items-center gap-3"
            style={{
              width: "100%",
              padding: "12px 16px",
              fontSize: "var(--font-size-base)",
              fontWeight: "var(--font-weight-medium)",
              color: "var(--text-2)",
              background: "transparent",
              border: "none",
              cursor: "pointer",
              transition: "background 0.15s, color 0.15s",
              textAlign: "left",
            }}
            onMouseEnter={e => {
              e.currentTarget.style.background = "var(--control-bg-hover)";
              e.currentTarget.style.color = "var(--text)";
            }}
            onMouseLeave={e => {
              e.currentTarget.style.background = "transparent";
              e.currentTarget.style.color = "var(--text-2)";
            }}
          >
            <svg viewBox="0 0 16 16" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M6 14H3a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1h3" />
              <path d="M10 11l3-3-3-3" />
              <path d="M13 8H6" />
            </svg>
            Sign out
          </button>
        </div>
      )}
    </div>
  );
}
