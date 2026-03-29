# Multi-Simulator Streaming Architecture

**Date:** 2026-03-24
**Status:** Preparatory refactor — restructure internals for multi-stream, keep single-stream UI behavior for now

## Context

SimCast currently enforces single-simulator streaming: one `SCStream`, one `LiveKitProvider` room, one `streamingUdid` in presence. To stream a different simulator, the current one must be stopped first. The goal is to refactor the architecture so that multiple simultaneous streams are structurally supported, without changing the user-facing behavior yet.

## Design Decisions

- **Independent control**: each simulator gets its own start/stop lifecycle
- **One viewer at a time**: web dashboard right panel shows one stream; user clicks "Watch" to switch
- **No resource cap**: allow unlimited concurrent streams (hardware is the natural limit)
- **Each stream = its own LiveKit room** (room name = UDID)
- **Deploy web first**: web app handles both old (`streaming_udid`) and new (`streaming_udids`) presence formats, then deploy macOS

## Architecture

### New Type: `StreamSession`

A reference type bundling everything needed for one simulator's capture pipeline:

```swift
// apps/macos/simcast/Stream/Models/StreamSession.swift
@Observable
@MainActor
final class StreamSession: Identifiable {
    let id: String  // == udid
    let udid: String
    let window: SCWindow
    private(set) var stream: SCStream?
    private(set) var proxy: SCKProxy?
    let liveKitProvider: LiveKitProvider
    let previewReceiver: PreviewReceiver
    private(set) var isCapturing: Bool = false
    private(set) var isConnected: Bool = false
    var captureSize: CGSize = .zero

    // Per-session recording
    private(set) var isRecording: Bool = false
    private var fileRecordingReceiver: FileRecordingReceiver?
}
```

`Identifiable` conformance enables SwiftUI `ForEach` over sessions for future multi-preview UI.

### SCKManager Changes

**Current**: holds single `stream: SCStream?`, `streamingUdid: String?`, `providers: [StreamingProvider]`, `receivers: [VideoFrameReceiver]`

**New**: manages a dictionary of active sessions. Remove top-level `providers`/`receivers` arrays and `addProvider`/`addReceiver`/`removeReceiver` API. `SCKManager` needs `supabase` client and `logger` injected so it can create `LiveKitProvider` instances per session.

```swift
// Key changes in SCKManager
private let supabase: SupabaseClient
private let logger: AppLogger

private(set) var sessions: [String: StreamSession] = [:]  // keyed by UDID

var isCapturing: Bool { !sessions.isEmpty }
var streamingUdids: [String] { Array(sessions.keys) }

func start(window: SCWindow, udid: String) async throws {
    // Create NEW LiveKitProvider + PreviewReceiver for this session
    // Create StreamSession
    // Configure SCStream for this window
    // Wire up input handlers on the provider (see Input Routing below)
    // Connect LiveKitProvider to room named `udid`
    // Store in sessions[udid]
}

func stop(udid: String) async {
    // Tear down sessions[udid]: stop capture, disconnect provider, stop recording if active
    // Remove from dictionary
}

func stopAll() async {
    for udid in sessions.keys { await stop(udid: udid) }
}

// Per-session recording
func startRecording(udid: String) { ... }
func stopRecording(udid: String) async -> (url: URL, duration: Double)? { ... }
```

The old `stop()` (no args) becomes `stopAll()`. Recording moves from top-level state to per-session: `startRecording(udid:)` finds the session and creates a `FileRecordingReceiver` attached to that session's proxy. `stopRecording(udid:)` removes it from the session.

### LiveKitProvider Changes

**Current**: singleton, one `room: Room?`
**New**: per-session instance. Each `StreamSession` creates its own `LiveKitProvider`. No structural changes to `LiveKitProvider` itself — it already manages one room. Multiple instances coexist.

### PreviewReceiver Changes

**Current**: singleton, one `AVSampleBufferDisplayLayer`
**New**: per-session instance. `SimulatorRow` reads the preview from `sessions[simulator.udid]?.previewReceiver`.

### Input Routing

**Current**: `StreamReadyView` sets closures on a single `liveKitProvider` from the environment. Each closure guards on `sckManager?.streamingUdid` to get the target UDID.

**New**: `SCKManager.start()` wires input handlers on each session's `LiveKitProvider` during creation. The UDID is captured in the closure at creation time — no need to look it up:

```swift
func start(window: SCWindow, udid: String) async throws {
    let provider = LiveKitProvider(supabase: supabase, logger: logger)
    // ...

    // Wire input handlers with captured udid
    provider.onTapReceived = { [weak self] x, y, duration in
        self?.inputService.injectTap(x: x, y: y, holdDuration: duration, udid: udid)
    }
    provider.onButtonReceived = { [weak self] button in
        self?.inputService.pressHardwareButton(button, udid: udid)
    }
    provider.onGestureReceived = { [weak self] gesture in
        self?.inputService.performGesture(gesture, udid: udid)
    }
    provider.onTextReceived = { [weak self] text in
        self?.inputService.typeText(text, udid: udid)
    }
    provider.onScreenshotRequested = { [weak self] in
        await self?.captureScreenshot(udid: udid)
    }
    provider.onStartRecordingRequested = { [weak self] in
        self?.startRecording(udid: udid)
    }
    provider.onStopRecordingRequested = { [weak self] in
        await self?.stopRecording(udid: udid)
    }
    // ... etc for all handlers
}
```

This moves input wiring from `StreamReadyView` into `SCKManager`, which is cleaner — the view no longer needs to know about input routing. `StreamReadyView` becomes simpler: it just handles stream commands and delegates to `SCKManager`.

`SCKManager` needs a reference to `SimulatorInputService` (injected at init or set as a property).

### `onStreamStopped` Callback

**Current**: single `onStreamStopped: (() -> Void)?` on `SCKManager`
**New**: per-session callback. When a session's LiveKit provider disconnects or SCStream stops unexpectedly, the session cleans itself up and notifies `SCKManager`, which removes it from the dictionary and calls a general `onSessionStopped: ((String) -> Void)?` callback with the UDID. The call site syncs presence:

```swift
sckManager.onSessionStopped = { udid in
    Task { await syncService.syncPresence(streamingUdids: sckManager.streamingUdids) }
}
```

### SyncService / Presence Changes

**Current model**:
```swift
struct SessionPresence: Codable {
    let streamingUdid: String?
}
```

**New model**:
```swift
struct SessionPresence: Codable {
    let streamingUdids: [String]  // was streamingUdid: String?
}
```

`syncPresence()` changes:
```swift
// Current
func syncPresence(streamingUdid: String?) async
// New
func syncPresence(streamingUdids: [String]) async
```

**Cleanup in `stop()`**: `SyncService.stop()` currently deletes from the `streams` table using `currentStreamingUdid`. Change to loop over `currentStreamingUdids` and delete each, or batch delete.

### StreamReadyView Changes

**Current**: sets up all input handler closures on the singleton `liveKitProvider`, handles stream commands
**New**: significantly simplified. Input wiring moves to `SCKManager.start()`. StreamReadyView only:
1. Sets `onStreamCommand` to delegate start/stop to `SCKManager`
2. Sets `onSessionStopped` to sync presence
3. Runs the refresh polling loop

```swift
case .start:
    guard let simulator = ..., let window = ... else { return }
    try? await service.windowService.refresh()
    try await sckManager.start(window: window, udid: cmd.udid)
    await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
case .stop:
    await sckManager.stop(udid: cmd.udid)
    await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
```

**`onChange` handler**: currently stops ALL streaming if the streaming simulator disappears. Change to stop only the sessions whose simulators disappeared:

```swift
.onChange(of: service.simulators.map(\.id)) { _, newIds in
    let newIdSet = Set(newIds)
    for udid in sckManager.streamingUdids where !newIdSet.contains(udid) {
        Task { await sckManager.stop(udid: udid) }
    }
}
```

### SimulatorRow Changes

- Remove `if sckManager.isCapturing { await sckManager.stop() }` before starting
- Remove `.disabled(isCapturingThis || simulator.udid == nil)` — only disable if `simulator.udid == nil`
- `isCapturingThis` checks `sckManager.sessions[simulator.udid] != nil`
- `isConnecting`/`isStreaming` read from the session: `sckManager.sessions[simulator.udid]?.isConnected`
- Preview reads from `sckManager.sessions[simulator.udid]?.previewReceiver`
- Stop button calls `sckManager.stop(udid: simulator.udid!)`

### SimcastApp Changes

- Remove singleton `LiveKitProvider` and `PreviewReceiver` from app-level `@State`
- Remove `sckManager.addProvider(liveKit)` and `sckManager.addReceiver(preview)` calls
- `SCKManager` init takes `supabase`, `logger`, and `inputService` so it can create per-session instances
- Remove `LiveKitProvider` and `PreviewReceiver` from the environment

## Web App Changes

### usePresenceSubscription

**Current**: `streamingUdid: string | null` (singular)
**New**: `streamingUdids: Set<string>`

```typescript
const foundStreamingUdids = new Set<string>();
for (const entries of Object.values(state)) {
    for (const entry of entries) {
        // Handle both old and new presence format
        const udids = entry.streaming_udids ??
            (entry.streaming_udid ? [entry.streaming_udid] : []);
        for (const udid of udids) {
            foundStreamingUdids.add(udid);
        }
    }
}
```

### StreamGrid

- `isStreaming` changes from `streamingUdid === card.id` to `streamingUdids.has(card.id)`
- Stream button: no longer disabled when another simulator is streaming
- Stop button: stops only this simulator's stream
- Watch/Hide: unchanged (already per-card)
- `pendingUdid: string | null` → `pendingUdids: Set<string>` to handle concurrent operations

### DashboardClient

- `streamingUdid: string | null` → `streamingUdids: Set<string>`
- `watchingUdid` stays single (one viewer at a time)
- **Auto-switch logic changes**: only auto-switch if the user is not already watching a stream. If they're watching stream A and stream B starts, do NOT switch. If the stream they're watching stops, show the placeholder (don't auto-switch to another active stream).

### SimulatorViewer / useLiveKitConnection

No changes needed — already connects to one room by UDID. The `watchingUdid` determines which room to connect to.

## Backward Compatibility

**Deployment order**: Deploy web app first (handles both `streaming_udid` and `streaming_udids`), then macOS app. This avoids a window where the new macOS sends `streaming_udids` but the old web only reads `streaming_udid`.

**Web reads both formats**:
```typescript
const udids = entry.streaming_udids ??
    (entry.streaming_udid ? [entry.streaming_udid] : []);
```

## Files Modified

### macOS
| File | Change |
|------|--------|
| `Stream/Models/StreamSession.swift` | **NEW** — per-simulator session type with recording state |
| `Stream/Managers/SCKManager.swift` | Dictionary of sessions, `start`/`stop(udid:)`, per-session recording, input wiring, takes supabase/logger/inputService |
| `Stream/Managers/LiveKitProvider.swift` | No structural changes (instantiated per session) |
| `Stream/Receivers/PreviewReceiver.swift` | No structural changes (instantiated per session) |
| `Sync/Models/SyncModels.swift` | `streamingUdid` → `streamingUdids: [String]` |
| `Sync/SyncService.swift` | `syncPresence(streamingUdids:)`, multi-UDID cleanup in `stop()` |
| `Stream/Views/StreamReadyView.swift` | Remove input wiring (moved to SCKManager), simplify command handler, fix onChange |
| `Stream/Views/SimulatorRow.swift` | Independent start/stop, read from session dictionary |
| `SimcastApp.swift` | Remove singleton LiveKitProvider/PreviewReceiver, pass dependencies to SCKManager |

### Web
| File | Change |
|------|--------|
| `hooks/usePresenceSubscription.ts` | `streamingUdids: Set<string>`, handle both presence formats |
| `StreamGrid.tsx` | Check set membership, `pendingUdids: Set<string>`, independent buttons |
| `DashboardClient.tsx` | `streamingUdids: Set<string>`, simplified auto-switch (don't switch away from active watch) |

### Supabase
| Change | Detail |
|--------|--------|
| Presence payload | `streamingUdids: string[]` (no DB migration needed — presence is ephemeral) |

## Verification

1. **macOS build**: `xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast build`
2. **Web build**: `cd apps/web && npm run build`
3. **Functional test**: start streaming one simulator → verify stream works as before
4. **No regression**: stop stream → verify cleanup, start different simulator → verify switch works
5. **Presence check**: verify web dashboard correctly shows streaming badge on the active simulator
6. **Recording**: verify recording works on an active stream session
7. **Input controls**: verify tap/scroll/type/buttons work on the watched stream
8. **Crash recovery**: force-quit macOS app → verify web cleans up streaming badges after presence timeout
