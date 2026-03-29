# Web Log Viewer

**Date:** 2026-03-24
**Status:** Ready for implementation

## Context

The macOS app has a full-featured in-app log panel (`AppLogger` + `LogPanel`) with 5 color-coded categories. These logs are only visible in the macOS app. The web dashboard needs to display them in real time for remote debugging.

## Design

### Data Transport — Supabase Realtime Broadcast

Logs are broadcast on the existing `user:{userId}` channel using Realtime broadcast (no database table — logs are ephemeral, fire-and-forget).

**macOS sends:**
```json
{
  "type": "broadcast",
  "event": "log",
  "payload": {
    "category": "stream",
    "message": "capture started · CC91216B",
    "timestamp": "2026-03-24T15:30:00.000Z"
  }
}
```

**Categories and colors:**

| Category | macOS Symbol | Web Color | CSS Variable |
|----------|-------------|-----------|--------------|
| `stream` | `●` | `#1A9950` (green) | `--log-stream` |
| `livekit` | `↑` | `#2673D9` (blue) | `--log-livekit` |
| `presence` | `⬡` | `#BF7300` (orange) | `--log-presence` |
| `command` | `⚡` | `#8C40D9` (purple) | `--log-command` |
| `error` | `✕` | `#D92626` (red) | `--log-error` |

### macOS Changes

**SyncService** — add `broadcastLog(category:message:)`:

```swift
func broadcastLog(category: String, message: String) {
    guard let channel else { return }
    Task {
        try? await channel.send(
            type: .broadcast,
            event: "log",
            payload: ["category": .string(category), "message": .string(message), "timestamp": .string(Date().ISO8601Format())]
        )
    }
}
```

**AppLogger** — add a weak reference to `SyncService`, call `broadcastLog` after local append:

```swift
weak var syncService: SyncService?

func log(_ category: LogCategory, _ message: String) {
    // ... existing local append ...
    syncService?.broadcastLog(category: category.rawValue, message: message)
}
```

**LogCategory** — add `rawValue` string conformance:

```swift
enum LogCategory: String, Sendable {
    case stream, liveKit, presence, command, error
}
```

### Web Changes

**New hook: `useLogStream(channelRef)`** — subscribes to broadcast `"log"` events on the existing channel, maintains a capped array of log entries (500 max). Returns `{ logs, clearLogs }`.

```typescript
type LogEntry = {
  id: string;
  category: "stream" | "livekit" | "presence" | "command" | "error";
  message: string;
  timestamp: string;
};
```

**Integration:** `usePresenceSubscription` already creates the channel. The log hook receives the `channelRef` and attaches a broadcast listener to the same channel.

**New component: `LogDrawer`** — footer drawer UI:

- **Trigger button** in footer bar: log icon + badge showing total count (error count highlighted in red if > 0)
- **Drawer** slides up from the bottom, resizable via drag handle (100px–50vh)
- **Header row**: "Logs" title, filter chips (one per category, colored, toggleable, all ON by default), clear button, close button
- **Log list**: monospaced font, each row shows:
  - Timestamp (`HH:mm:ss.SSS`) in muted color
  - Category badge (colored pill with category name)
  - Message text
- **Auto-scroll** to bottom on new entries (unless user has scrolled up)
- **ESC** or close button dismisses drawer

**Styling:** Aurora Dark theme — drawer background `var(--surface)`, border `var(--border-subtle)`, monospaced text. Category colors as CSS variables in `globals.css`.

### File Structure

**macOS:**
| File | Change |
|------|--------|
| `Log/LogEntry.swift` | `LogCategory` gets `String` raw value |
| `Log/AppLogger.swift` | Add `weak var syncService`, broadcast on log |
| `Sync/SyncService.swift` | Add `broadcastLog(category:message:)` |
| `SimcastApp.swift` | Wire `appLogger.syncService = syncService` |

**Web:**
| File | Change |
|------|--------|
| `globals.css` | Add `--log-stream`, `--log-livekit`, etc. CSS variables |
| `hooks/useLogStream.ts` | **NEW** — broadcast listener, capped log array |
| `components/LogDrawer.tsx` | **NEW** — footer drawer with filters |
| `DashboardClient.tsx` | Add `useLogStream`, render `LogDrawer` in footer |
| `hooks/usePresenceSubscription.ts` | Export `channelRef` (already returned) |

## Verification

1. macOS build passes
2. Web build passes
3. Start macOS app → start streaming → web log drawer shows stream/livekit/presence logs in real time
4. Filter chips toggle categories on/off
5. Clear button empties the log list
6. Error logs show red badge on the footer button
7. Drawer is resizable and dismissible
