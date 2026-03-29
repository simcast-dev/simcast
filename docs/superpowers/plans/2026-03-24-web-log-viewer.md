# Web Log Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stream macOS app logs to the web dashboard in real time via Supabase Realtime broadcast, displayed in a resizable footer drawer with color-coded categories and filters.

**Architecture:** macOS `AppLogger` broadcasts each log entry via `SyncService` on the existing `user:{userId}` Realtime channel. The web app listens for broadcast `"log"` events on the same channel, collects entries in state, and renders them in a `LogDrawer` component anchored to the footer.

**Tech Stack:** Swift (macOS), Next.js/TypeScript (web), Supabase Realtime broadcast

**Spec:** `docs/superpowers/specs/2026-03-24-web-log-viewer-design.md`

---

## File Structure

### macOS — Modified
- `apps/macos/simcast/Log/LogEntry.swift` — add `String` raw value to `LogCategory`
- `apps/macos/simcast/Log/AppLogger.swift` — add `syncService` ref, broadcast on log
- `apps/macos/simcast/Sync/SyncService.swift` — add `broadcastLog()`
- `apps/macos/simcast/SimcastApp.swift` — wire `appLogger.syncService = syncService`

### Web — New
- `apps/web/src/app/dashboard/hooks/useLogStream.ts` — log entry state, capped array
- `apps/web/src/app/dashboard/components/LogDrawer.tsx` — footer drawer UI

### Web — Modified
- `apps/web/src/app/globals.css` — log category CSS variables
- `apps/web/src/app/dashboard/hooks/usePresenceSubscription.ts` — add broadcast `"log"` listener, `onLogReceived` callback
- `apps/web/src/app/dashboard/DashboardClient.tsx` — integrate log hook, render LogDrawer in footer

---

## Task 1: macOS — Add log broadcasting

**Files:**
- Modify: `apps/macos/simcast/Log/LogEntry.swift`
- Modify: `apps/macos/simcast/Log/AppLogger.swift`
- Modify: `apps/macos/simcast/Sync/SyncService.swift`
- Modify: `apps/macos/simcast/SimcastApp.swift`

- [ ] **Step 1: Add String raw value to LogCategory**

In `apps/macos/simcast/Log/LogEntry.swift`, change:
```swift
enum LogCategory: Sendable {
```
to:
```swift
enum LogCategory: String, Sendable {
    case stream
    case liveKit = "livekit"
    case presence
    case command
    case error
```

Remove the individual `case` lines that are now provided by the raw value enum declaration. Keep the `symbol`, `label`, and `color` computed properties unchanged.

- [ ] **Step 2: Add broadcastLog to SyncService**

In `apps/macos/simcast/Sync/SyncService.swift`, add this method:

```swift
func broadcastLog(category: String, message: String) {
    guard let channel else { return }
    Task {
        try? await channel.send(
            type: .broadcast,
            event: "log",
            payload: [
                "category": .string(category),
                "message": .string(message),
                "timestamp": .string(Date().ISO8601Format())
            ]
        )
    }
}
```

- [ ] **Step 3: Wire AppLogger to SyncService**

In `apps/macos/simcast/Log/AppLogger.swift`, add a weak reference and broadcast call:

```swift
@Observable
final class AppLogger {
    private(set) var entries: [LogEntry] = []
    weak var syncService: SyncService?

    private let writer = LogWriter()

    var errorCount: Int { entries.filter { $0.category == .error }.count }
    var lastEntry: LogEntry? { entries.last }

    func log(_ category: LogCategory, _ message: String) {
        let entry = LogEntry(category: category, message: message)
        Task {
            let updated = await writer.append(entry)
            entries = updated
        }
        syncService?.broadcastLog(category: category.rawValue, message: message)
    }

    func clear() {
        Task {
            await writer.clear()
            entries = []
        }
    }
}
```

- [ ] **Step 4: Connect logger to sync service in SimcastApp**

In `apps/macos/simcast/SimcastApp.swift`, add after `.onChange(of: auth.status)` block, inside the `case .authenticated` branch, after `await syncService.start(...)`:

```swift
case .authenticated:
    if let userId = auth.userId, let email = auth.currentUserEmail {
        await syncService.start(userId: userId, email: email)
        appLogger.syncService = syncService
    }
```

And in the `.unauthenticated` branch:
```swift
case .unauthenticated:
    appLogger.syncService = nil
    await syncService.stop()
```

- [ ] **Step 5: Verify macOS build**

Run: `xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add apps/macos/simcast/Log/LogEntry.swift apps/macos/simcast/Log/AppLogger.swift apps/macos/simcast/Sync/SyncService.swift apps/macos/simcast/SimcastApp.swift
git commit -m "feat(macos): broadcast log entries via Supabase Realtime"
```

---

## Task 2: Web — Add log CSS variables and useLogStream hook

**Files:**
- Modify: `apps/web/src/app/globals.css`
- Create: `apps/web/src/app/dashboard/hooks/useLogStream.ts`
- Modify: `apps/web/src/app/dashboard/hooks/usePresenceSubscription.ts`

- [ ] **Step 1: Add log category CSS variables**

In `apps/web/src/app/globals.css`, inside the `:root[data-theme="dark"]` block, add:

```css
  /* Log category colors */
  --log-stream: #1A9950;
  --log-livekit: #2673D9;
  --log-presence: #BF7300;
  --log-command: #8C40D9;
  --log-error: #D92626;
```

And inside the light theme block (`:root[data-theme="light"]` or just `:root`), add the same variables (the colors work on both backgrounds, but adjust if needed for readability):

```css
  --log-stream: #15803d;
  --log-livekit: #1d4ed8;
  --log-presence: #a16207;
  --log-command: #7c3aed;
  --log-error: #dc2626;
```

- [ ] **Step 2: Create useLogStream hook**

Create `apps/web/src/app/dashboard/hooks/useLogStream.ts`:

```typescript
"use client";

import { useState, useCallback } from "react";

export type LogCategory = "stream" | "livekit" | "presence" | "command" | "error";

export type LogEntry = {
  id: string;
  category: LogCategory;
  message: string;
  timestamp: string;
};

const LOG_CAP = 500;

let logCounter = 0;

export function useLogStream() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [errorCount, setErrorCount] = useState(0);

  const addLog = useCallback((payload: { category: string; message: string; timestamp: string }) => {
    const entry: LogEntry = {
      id: `log-${++logCounter}`,
      category: payload.category as LogCategory,
      message: payload.message,
      timestamp: payload.timestamp,
    };
    setLogs(prev => {
      const next = [...prev, entry];
      return next.length > LOG_CAP ? next.slice(next.length - LOG_CAP) : next;
    });
    if (payload.category === "error") {
      setErrorCount(prev => prev + 1);
    }
  }, []);

  const clearLogs = useCallback(() => {
    setLogs([]);
    setErrorCount(0);
  }, []);

  return { logs, errorCount, addLog, clearLogs };
}
```

- [ ] **Step 3: Add broadcast listener to usePresenceSubscription**

In `apps/web/src/app/dashboard/hooks/usePresenceSubscription.ts`, add an `onLogReceived` callback parameter and a broadcast listener on the channel.

Update the function signature:
```typescript
export function usePresenceSubscription(
  userId: string,
  onStreamingChange?: (udids: Set<string>) => void,
  onLogReceived?: (payload: { category: string; message: string; timestamp: string }) => void,
) {
```

Add the broadcast listener to the channel setup, BEFORE `.subscribe()`:
```typescript
    channel
      .on("presence", { event: "sync" }, syncCards)
      .on("presence", { event: "join" }, syncCards)
      .on("presence", { event: "leave" }, syncCards)
      .on("broadcast", { event: "log" }, (payload) => {
        onLogReceived?.(payload.payload as { category: string; message: string; timestamp: string });
      })
      .subscribe();
```

- [ ] **Step 4: Verify web build**

Run: `cd apps/web && npm run build`
Expected: PASS (hook exists but not yet consumed by DashboardClient — will be wired in Task 3)

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/app/globals.css apps/web/src/app/dashboard/hooks/useLogStream.ts apps/web/src/app/dashboard/hooks/usePresenceSubscription.ts
git commit -m "feat(web): useLogStream hook and broadcast listener for real-time logs"
```

---

## Task 3: Web — Create LogDrawer component and integrate

**Files:**
- Create: `apps/web/src/app/dashboard/components/LogDrawer.tsx`
- Modify: `apps/web/src/app/dashboard/DashboardClient.tsx`

- [ ] **Step 1: Create LogDrawer component**

Create `apps/web/src/app/dashboard/components/LogDrawer.tsx`. This is the main UI component — a footer drawer with:
- Toggle button (log icon + count badge, error count in red)
- Resizable drawer that slides up from below the footer
- Header with category filter chips and clear button
- Scrollable monospaced log list with auto-scroll
- Each row: timestamp (HH:mm:ss.SSS), colored category badge, message

The component receives `logs: LogEntry[]`, `errorCount: number`, `onClear: () => void`.

```typescript
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
```

- [ ] **Step 2: Integrate into DashboardClient**

In `apps/web/src/app/dashboard/DashboardClient.tsx`:

Add imports:
```typescript
import { useLogStream } from "./hooks/useLogStream";
import LogDrawer from "./components/LogDrawer";
```

Add the hook call after other hooks:
```typescript
const { logs, errorCount, addLog, clearLogs } = useLogStream();
```

Pass `addLog` to `StreamGrid` as the `onLogReceived` callback via the presence subscription. Update the `<StreamGrid>` call to pass it:
```typescript
<StreamGrid onSelect={setWatchingUdid} onStreamingChange={setStreamingUdids} onLogReceived={addLog} watchingUdid={watchingUdid} userId={userId} />
```

Add `LogDrawer` inside the footer `<div>` (the one with `position: "relative"`), making the footer `position: relative`:

Add `position: "relative"` to the footer inner div style, then add `<LogDrawer>` as a child:
```tsx
<div
  className="flex items-center justify-center"
  style={{
    position: "relative",
    width: "100%",
    // ... rest of existing styles
  }}
>
  SimCast v0.1.0
  {/* ... existing stats ... */}
  <LogDrawer logs={logs} errorCount={errorCount} onClear={clearLogs} />
</div>
```

- [ ] **Step 3: Pass onLogReceived through StreamGrid to usePresenceSubscription**

In `apps/web/src/app/dashboard/StreamGrid.tsx`:

Add `onLogReceived` to the props:
```typescript
export default function StreamGrid({
  onSelect,
  onStreamingChange,
  onSessionSummary,
  onLogReceived,
  watchingUdid = null,
  userId,
}: {
  onSelect: (udid: string | null) => void;
  onStreamingChange?: (udids: Set<string>) => void;
  onSessionSummary?: (s: { count: number; streamingName: string | null }) => void;
  onLogReceived?: (payload: { category: string; message: string; timestamp: string }) => void;
  watchingUdid?: string | null;
  userId: string;
}) {
```

Pass it to the hook:
```typescript
const { cards, streamingUdids, channelRef } = usePresenceSubscription(userId, onStreamingChange, onLogReceived);
```

- [ ] **Step 4: Verify web build**

Run: `cd apps/web && npm run build`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/app/dashboard/components/LogDrawer.tsx apps/web/src/app/dashboard/DashboardClient.tsx apps/web/src/app/dashboard/StreamGrid.tsx
git commit -m "feat(web): LogDrawer component with real-time log streaming from macOS"
```

---

## Task 4: Verification

- [ ] **Step 1: Build both apps**

```bash
xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
cd apps/web && npm run build
```

- [ ] **Step 2: Functional test**

1. Run macOS app, sign in
2. Open web dashboard
3. Click "Logs" button in footer → drawer opens
4. Start streaming a simulator → verify stream/livekit/presence logs appear in real time
5. Click category filter chips → verify filtering works
6. Click Clear → logs clear
7. Trigger an error → verify red error badge appears on the button
8. Resize drawer via drag handle
9. Press ESC → drawer closes
10. Scroll up in log list → verify auto-scroll pauses; scroll back to bottom → auto-scroll resumes
