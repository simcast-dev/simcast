# Multi-Simulator Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor SimCast from single-simulator streaming to per-simulator session architecture, ready for concurrent multi-stream but keeping single-stream UI behavior for now.

**Architecture:** Replace singleton `SCKManager`/`LiveKitProvider`/`PreviewReceiver` with a per-UDID `StreamSession` dictionary. Move input wiring from `StreamReadyView` into `SCKManager`. Change presence from `streamingUdid: String?` to `streamingUdids: [String]`. Deploy web first (handles both formats), then macOS.

**Tech Stack:** Swift/SwiftUI (macOS), Next.js/TypeScript (web), Supabase Realtime presence, LiveKit WebRTC

**Spec:** `docs/superpowers/specs/2026-03-24-multi-simulator-streaming-design.md`

---

## File Structure

### New Files
- `apps/macos/simcast/Stream/Models/StreamSession.swift` — per-simulator session: bundles SCStream + LiveKitProvider + PreviewReceiver + recording state

### Modified Files (macOS)
- `apps/macos/simcast/Sync/Models/SyncModels.swift` — `streamingUdid` → `streamingUdids`
- `apps/macos/simcast/Sync/SyncService.swift` — `syncPresence(streamingUdids:)`, multi-UDID cleanup
- `apps/macos/simcast/Stream/Managers/SCKManager.swift` — sessions dictionary, per-session start/stop/recording, input wiring
- `apps/macos/simcast/Stream/Views/StreamReadyView.swift` — simplified: remove input wiring, delegate to SCKManager
- `apps/macos/simcast/Stream/Views/SimulatorRow.swift` — read from session dictionary, independent start/stop
- `apps/macos/simcast/SimcastApp.swift` — remove singleton LiveKitProvider/PreviewReceiver, pass dependencies to SCKManager

### Modified Files (Web) — deploy these first
- `apps/web/src/app/dashboard/hooks/usePresenceSubscription.ts` — `streamingUdids: Set<string>`, backward compat
- `apps/web/src/app/dashboard/StreamGrid.tsx` — `pendingUdids: Set<string>`, per-card streaming state
- `apps/web/src/app/dashboard/DashboardClient.tsx` — `streamingUdids: Set<string>`, simplified auto-switch

---

## Task 1: Web — Update usePresenceSubscription for multi-stream

**Files:**
- Modify: `apps/web/src/app/dashboard/hooks/usePresenceSubscription.ts`

- [ ] **Step 1: Update state and types**

Change `streamingUdid` state to `streamingUdids` and update the `syncCards` function to collect a `Set<string>` instead of a single value. Handle both old (`streaming_udid`) and new (`streaming_udids`) presence formats for backward compatibility.

In `usePresenceSubscription.ts`:

```typescript
// Change state declaration (was: const [streamingUdid, setStreamingUdid] = useState<string | null>(null))
const [streamingUdids, setStreamingUdids] = useState<Set<string>>(new Set());
```

In `syncCards()`:
```typescript
// Replace the single foundStreamingUdid with a Set
const foundStreamingUdids = new Set<string>();

// Inside the nested loops, replace:
//   if (entry.streaming_udid) { foundStreamingUdid = entry.streaming_udid; }
// With:
const udids = (entry as any).streaming_udids ??
    (entry.streaming_udid ? [entry.streaming_udid] : []);
for (const udid of udids) {
    foundStreamingUdids.add(udid);
}

// At the end of syncCards, replace:
//   setStreamingUdid(foundStreamingUdid);
//   onStreamingChange?.(foundStreamingUdid);
// With:
setStreamingUdids(foundStreamingUdids);
onStreamingChange?.(foundStreamingUdids);
```

Update the `onStreamingChange` callback type from `(udid: string | null) => void` to `(udids: Set<string>) => void`.

Update the return value: `return { cards, streamingUdids, channelRef };`

- [ ] **Step 2: Verify build**

Run: `cd apps/web && npm run build`
Expected: BUILD passes with no TS errors (will fail — DashboardClient and StreamGrid still use old types)

Note: Build errors in DashboardClient/StreamGrid are expected at this point and will be fixed in Tasks 2-3.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/app/dashboard/hooks/usePresenceSubscription.ts
git commit -m "refactor(web): usePresenceSubscription returns streamingUdids Set instead of single streamingUdid"
```

---

## Task 2: Web — Update DashboardClient and SimulatorViewer for multi-stream

**Files:**
- Modify: `apps/web/src/app/dashboard/DashboardClient.tsx`
- Modify: `apps/web/src/app/dashboard/SimulatorViewer.tsx`

- [ ] **Step 1: Replace streamingUdid with streamingUdids**

```typescript
// Change state (was: const [streamingUdid, setStreamingUdid] = useState<string | null>(null))
const [streamingUdids, setStreamingUdids] = useState<Set<string>>(new Set());
```

- [ ] **Step 2: Update onStreamingChange callback**

The `onStreamingChange` prop passed to `StreamGrid` now receives `Set<string>`:

```typescript
<StreamGrid
  onSelect={setWatchingUdid}
  onStreamingChange={setStreamingUdids}
  watchingUdid={watchingUdid}
  userId={userId}
/>
```

- [ ] **Step 3: Simplify auto-switch logic**

Replace the existing `useEffect` that depends on `streamingUdid` (the one with `wasWatchingRef`, `switchTimeoutRef`, 12-second timeout). The new behavior:
- If the user is watching a stream that stops (its UDID leaves `streamingUdids`), clear `watchingUdid` to show placeholder
- Do NOT auto-switch to another stream when a new one starts
- Remove `isViewerSwitching` state and the switching overlay since we no longer auto-switch

```typescript
useEffect(() => {
    if (watchingUdid && !streamingUdids.has(watchingUdid)) {
        setWatchingUdid(null);
    }
}, [streamingUdids, watchingUdid]);
```

Remove the `wasWatchingRef`, `switchTimeoutRef`, and `isViewerSwitching` state. Remove the `isSwitching` prop from `<SimulatorViewer>`.

- [ ] **Step 4: Clean up SimulatorViewer isSwitching**

In `apps/web/src/app/dashboard/SimulatorViewer.tsx`:
- Remove the `isSwitching` prop from the component signature
- Remove the switching overlay JSX (the `{isSwitching && (...)}` block with the spinner)

- [ ] **Step 5: Update SimulatorViewer isStreaming prop**

```typescript
// Was: isStreaming={streamingUdid === watchingUdid}
// Now:
isStreaming={watchingUdid !== null && streamingUdids.has(watchingUdid)}
```

- [ ] **Step 6: Verify build**

Run: `cd apps/web && npm run build`
Expected: May still fail due to StreamGrid changes needed in Task 3.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/app/dashboard/DashboardClient.tsx apps/web/src/app/dashboard/SimulatorViewer.tsx
git commit -m "refactor(web): DashboardClient uses streamingUdids Set, simplified auto-switch, remove isSwitching"
```

---

## Task 3: Web — Update StreamGrid for multi-stream

**Files:**
- Modify: `apps/web/src/app/dashboard/StreamGrid.tsx`

- [ ] **Step 1: Update props and types**

Change `onStreamingChange` prop type to match the new signature:

```typescript
onStreamingChange?: (udids: Set<string>) => void;
```

- [ ] **Step 2: Update destructured hook return**

```typescript
// Was: const { cards, streamingUdid, channelRef } = usePresenceSubscription(userId, onStreamingChange);
const { cards, streamingUdids, channelRef } = usePresenceSubscription(userId, onStreamingChange);
```

- [ ] **Step 3: Replace pendingUdid with pendingUdids Set**

```typescript
// Was: const [pendingUdid, setPendingUdid] = useState<string | null>(null);
const [pendingUdids, setPendingUdids] = useState<Set<string>>(new Set());
```

Update the pending timeout effect to clear per-UDID:
```typescript
useEffect(() => {
    if (pendingUdids.size === 0) return;
    const timer = setTimeout(() => setPendingUdids(new Set()), 12000);
    return () => clearTimeout(timer);
}, [pendingUdids]);
```

Update the streamingUdid-change effect that clears pending:
```typescript
// Was: useEffect(() => { setPendingUdid(null); }, [streamingUdid]);
useEffect(() => { setPendingUdids(new Set()); }, [streamingUdids]);
```

- [ ] **Step 4: Update streaming checks in card rendering**

Everywhere in the component that checks `streamingUdid === card.id`, change to `streamingUdids.has(card.id)`.

Everywhere that checks `pendingUdid === card.id`, change to `pendingUdids.has(card.id)`.

For start button `disabled` — was `pendingUdid !== null`, now: `pendingUdids.has(card.id)` (each simulator is independent).

For start command: `setPendingUdids(prev => new Set(prev).add(card.id))` instead of `setPendingUdid(card.id)`.

For stop command: keep `onSelect(null)` only if `watchingUdid === card.id` (don't hide viewer for other simulators stopping). Use `setPendingUdids(prev => new Set(prev).add(card.id))`.

- [ ] **Step 5: Update onSessionSummary**

```typescript
// Was: const streamingCard = cards.find(c => c.id === streamingUdid);
const streamingCard = cards.find(c => streamingUdids.has(c.id));
```

- [ ] **Step 6: Verify build**

Run: `cd apps/web && npm run build`
Expected: PASS — all web changes now consistent.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/app/dashboard/StreamGrid.tsx
git commit -m "refactor(web): StreamGrid uses streamingUdids Set and pendingUdids Set"
```

---

## Task 4: macOS — Create StreamSession model

**Files:**
- Create: `apps/macos/simcast/Stream/Models/StreamSession.swift`

- [ ] **Step 1: Create StreamSession.swift**

```swift
import ScreenCaptureKit
import Observation

@Observable
@MainActor
final class StreamSession: Identifiable {
    let id: String
    let udid: String

    private(set) var stream: SCStream?
    private(set) var proxy: SCKProxy?
    let liveKitProvider: LiveKitProvider
    let previewReceiver: PreviewReceiver
    private(set) var isCapturing: Bool = false
    var captureSize: CGSize = .zero

    var isConnected: Bool { liveKitProvider.isConnected }

    // Per-session recording
    private(set) var isRecording: Bool = false
    private var fileRecordingReceiver: FileRecordingReceiver?

    init(udid: String, liveKitProvider: LiveKitProvider, previewReceiver: PreviewReceiver) {
        self.id = udid
        self.udid = udid
        self.liveKitProvider = liveKitProvider
        self.previewReceiver = previewReceiver
    }

    func setStream(_ stream: SCStream, proxy: SCKProxy) {
        self.stream = stream
        self.proxy = proxy
        self.isCapturing = true
    }

    func stopCapture() async {
        isCapturing = false
        if let stream {
            self.stream = nil
            try? await stream.stopCapture()
        }
        await liveKitProvider.disconnect()
        proxy = nil
    }

    func startRecording(captureSize: CGSize) throws {
        guard isCapturing, !isRecording else { return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("simcast_rec_\(UUID().uuidString).mp4")
        let receiver = FileRecordingReceiver(outputURL: url, dimensions: captureSize)
        try receiver.start()
        proxy?.addReceiver(receiver)
        fileRecordingReceiver = receiver
        isRecording = true
    }

    func stopRecording() async -> (url: URL, duration: Double)? {
        guard let receiver = fileRecordingReceiver else { return nil }
        isRecording = false
        fileRecordingReceiver = nil
        proxy?.removeReceiver(receiver)
        let duration = await receiver.stop()
        return (receiver.outputURL, duration)
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

The file should be at `apps/macos/simcast/Stream/Models/StreamSession.swift`. Xcode auto-discovers Swift files in the project directory.

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: BUILD SUCCEEDED (new file has no dependents yet)

- [ ] **Step 4: Commit**

```bash
git add apps/macos/simcast/Stream/Models/StreamSession.swift
git commit -m "feat(macos): add StreamSession model for per-simulator capture pipeline"
```

---

## Task 5: macOS — Update SyncModels and SyncService for multi-UDID presence

**Files:**
- Modify: `apps/macos/simcast/Sync/Models/SyncModels.swift`
- Modify: `apps/macos/simcast/Sync/SyncService.swift`

- [ ] **Step 1: Update SessionPresence in SyncModels.swift**

Change `streamingUdid: String?` to `streamingUdids: [String]` and update its CodingKey:

```swift
struct SessionPresence: Codable {
    let sessionId: String
    let userEmail: String
    let startedAt: String
    let simulators: [SimulatorInfo]
    let streamingUdids: [String]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userEmail = "user_email"
        case startedAt = "started_at"
        case simulators
        case streamingUdids = "streaming_udids"
    }
}
```

- [ ] **Step 2: Update SyncService**

Change `currentStreamingUdid: String?` to `currentStreamingUdids: [String] = []` (line 25).

Update `syncPresence` method (line 106-110):
```swift
func syncPresence(streamingUdids: [String]) async {
    currentStreamingUdids = streamingUdids
    logger.log(.presence, "presence synced · streamingUdids=\(streamingUdids)")
    await track()
}
```

Update `track()` (line 138):
```swift
// Was: streamingUdid: currentStreamingUdid
streamingUdids: currentStreamingUdids
```

Update `stop()` (lines 83-84) for multi-UDID cleanup:
```swift
for udid in currentStreamingUdids {
    try? await supabase.from("streams").delete().eq("room_name", value: udid).execute()
}
```

And reset to empty array instead of nil (line 94):
```swift
// Was: currentStreamingUdid = nil
currentStreamingUdids = []
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: BUILD FAILED — callers still use old `syncPresence(streamingUdid:)`. This is expected; fixed in Tasks 6-7.

- [ ] **Step 4: Commit**

```bash
git add apps/macos/simcast/Sync/Models/SyncModels.swift apps/macos/simcast/Sync/SyncService.swift
git commit -m "refactor(macos): SyncService uses streamingUdids array instead of single streamingUdid"
```

---

## Task 6: macOS — Refactor SCKManager to session-based architecture

**Files:**
- Modify: `apps/macos/simcast/Stream/Managers/SCKManager.swift`

This is the largest task. `SCKManager` goes from managing a single stream to managing a dictionary of `StreamSession` objects.

- [ ] **Step 1: Update stored properties**

Remove: `stream`, `proxy`, `providers`, `receivers`, `fileRecordingReceiver`, `isRecording`, `streamingUdid`, `isAnyProviderConnected`, `captureSize`, `onStreamStopped`.

Add: `sessions` dictionary, dependency references, `onSessionStopped` callback.

```swift
@Observable
@MainActor
final class SCKManager {
    private(set) var sessions: [String: StreamSession] = [:]
    var onSessionStopped: ((String) -> Void)?

    var isCapturing: Bool { !sessions.isEmpty }
    var streamingUdids: [String] { Array(sessions.keys) }

    private let supabase: SupabaseClient
    private let logger: AppLogger
    var inputService: SimulatorInputService?

    init(supabase: SupabaseClient, logger: AppLogger) {
        self.supabase = supabase
        self.logger = logger
    }
}
```

Remove `addReceiver`, `removeReceiver`, `addProvider` methods entirely.

- [ ] **Step 2: Rewrite start(window:udid:)**

The new `start` creates a per-session `LiveKitProvider`, `PreviewReceiver`, configures the SCStream, wires input handlers, connects LiveKit, and stores the session.

```swift
func start(window: SCWindow, udid: String) async throws {
    // Stop existing session for this UDID if any
    if sessions[udid] != nil { await stop(udid: udid) }

    let scaleFactor = NSScreen.screens.first(where: {
        $0.frame.intersects(window.frame)
    })?.backingScaleFactor ?? 1.0

    let captureRect: CGRect
    if let pid = window.owningApplication?.processID,
       let simFrame = WindowService.findSimDisplayFrame(in: AXUIElementCreateApplication(pid_t(pid))) {
        captureRect = CGRect(
            x: simFrame.origin.x - window.frame.origin.x,
            y: simFrame.origin.y - window.frame.origin.y,
            width: simFrame.width,
            height: simFrame.height
        )
        logger.log(.stream, "SimDisplayRenderableView frame: \(simFrame)")
    } else {
        captureRect = CGRect(origin: .zero, size: window.frame.size)
        logger.log(.stream, "SimDisplayRenderableView not found, capturing full window")
    }

    logger.log(.stream, "captureRect: \(captureRect)")

    let config = SCStreamConfiguration()
    config.sourceRect = captureRect
    config.width = Int(captureRect.width * scaleFactor)
    config.height = Int(captureRect.height * scaleFactor)
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(60))
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = false
    config.capturesAudio = false
    config.queueDepth = 5

    let size = CGSize(width: captureRect.width * scaleFactor, height: captureRect.height * scaleFactor)

    // Create per-session instances
    let provider = LiveKitProvider(supabase: supabase, logger: logger)
    let preview = PreviewReceiver()
    let session = StreamSession(udid: udid, liveKitProvider: provider, previewReceiver: preview)
    session.captureSize = size

    provider.prepare(size: size)
    wireInputHandlers(provider: provider, udid: udid)

    let proxy = SCKProxy(receivers: [preview, provider], onStop: { [weak self] in
        Task { @MainActor in
            guard let self, self.sessions[udid] != nil else { return }
            await self.stop(udid: udid)
            self.onSessionStopped?(udid)
        }
    })

    let stream = SCStream(
        filter: SCContentFilter(desktopIndependentWindow: window),
        configuration: config,
        delegate: proxy
    )
    try stream.addStreamOutput(proxy, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
    try await stream.startCapture()

    session.setStream(stream, proxy: proxy)
    logger.log(.stream, "capture started · \(udid.shortId())")

    do {
        provider.onDisconnected = { [weak self] in
            Task { @MainActor in
                guard let self, self.sessions[udid] != nil else { return }
                await self.stop(udid: udid)
                self.onSessionStopped?(udid)
            }
        }
        try await provider.connect(roomName: udid)
        sessions[udid] = session
    } catch {
        await session.stopCapture()
        logger.log(.error, "stream failed · \(error.localizedDescription)")
        throw error
    }
}
```

- [ ] **Step 3: Write stop(udid:) and stopAll()**

```swift
func stop(udid: String) async {
    guard let session = sessions.removeValue(forKey: udid) else { return }
    if session.isRecording { _ = await session.stopRecording() }
    await session.stopCapture()
    session.previewReceiver.sckManagerDidStop()
    logger.log(.stream, "stream stopped · \(udid.shortId())")
}

func stopAll() async {
    for udid in Array(sessions.keys) { await stop(udid: udid) }
}
```

- [ ] **Step 4: Add per-session recording methods**

```swift
func startRecording(udid: String) {
    guard let session = sessions[udid] else { return }
    do {
        try session.startRecording(captureSize: session.captureSize)
        logger.log(.stream, "recording started · \(udid.shortId())")
    } catch {
        logger.log(.error, "recording start failed · \(error.localizedDescription)")
    }
}

func stopRecording(udid: String) async -> (url: URL, duration: Double)? {
    guard let session = sessions[udid] else { return nil }
    let result = await session.stopRecording()
    if let result {
        logger.log(.stream, "recording stopped · \(String(format: "%.1f", result.duration))s")
    }
    return result
}
```

- [ ] **Step 5: Add wireInputHandlers helper**

This method captures the UDID in closures, replacing the StreamReadyView wiring. Reference `SimulatorInputService` and `SimulatorService` for window lookups.

```swift
private func wireInputHandlers(provider: LiveKitProvider, udid: String) {
    guard let inputService else { return }

    provider.onTapReceived = { [weak self] x, y, holdDuration in
        guard let self else { return }
        inputService.injectTap(normalizedX: x, normalizedY: y, holdDuration: holdDuration,
                               pid: self.findPid(udid: udid), udid: udid)
    }
    provider.onLabelTapReceived = { label in
        inputService.injectLabelTap(label: label, udid: udid)
    }
    provider.onSwipeReceived = { [weak self] startNX, startNY, endNX, endNY in
        guard let self else { return }
        inputService.injectSwipe(startNX: startNX, startNY: startNY, endNX: endNX, endNY: endNY,
                                 pid: self.findPid(udid: udid), udid: udid)
    }
    provider.onButtonReceived = { button in
        inputService.pressHardwareButton(button, udid: udid)
    }
    provider.onGestureReceived = { [weak self] gesture in
        guard let self else { return }
        inputService.performGesture(gesture, pid: self.findPid(udid: udid), udid: udid)
    }
    provider.onTextReceived = { text in
        inputService.typeText(text, udid: udid)
    }
    provider.onPushReceived = { bundleId, title, subtitle, body, badge, sound, category, silent in
        inputService.sendPushNotification(bundleId: bundleId, title: title, subtitle: subtitle, body: body,
                                          badge: badge, sound: sound, category: category, silent: silent, udid: udid)
    }
    provider.onOpenURLReceived = { url in
        inputService.openURL(url, udid: udid)
    }
    provider.onScreenshotRequested = { [weak self] in
        guard let self,
              let session = self.sessions[udid],
              let sim = self.simulatorService?.simulators.first(where: { $0.udid == udid }),
              let data = await inputService.captureScreenshot(udid: udid) else { return }
        await session.liveKitProvider.uploadAndPublishScreenshot(data, simulatorName: sim.title, simulatorUdid: udid)
    }
    provider.onAppListRequested = { [weak self] in
        guard let self, let session = self.sessions[udid] else { return }
        let apps = inputService.listApps(udid: udid)
        await session.liveKitProvider.publishAppList(apps)
    }
    provider.onStartRecordingRequested = { [weak self] in
        self?.startRecording(udid: udid)
    }
    provider.onStopRecordingRequested = { [weak self] in
        guard let self,
              let session = self.sessions[udid],
              let sim = self.simulatorService?.simulators.first(where: { $0.udid == udid }),
              let result = await self.stopRecording(udid: udid) else { return }
        await session.liveKitProvider.uploadAndPublishRecording(result.url, simulatorName: sim.title, simulatorUdid: udid, duration: result.duration)
    }
}
```

Note: `SCKManager` needs a `simulatorService: SimulatorService?` property for window/simulator lookups in input handlers. Add a helper:

```swift
var simulatorService: SimulatorService?

private func findPid(udid: String) -> pid_t {
    guard let sim = simulatorService?.simulators.first(where: { $0.udid == udid }),
          let window = simulatorService?.windowService.window(for: sim.windowID),
          let pid = window.owningApplication?.processID else { return 0 }
    return pid_t(pid)
}
```

The tap/swipe/gesture handlers need a PID. If `findPid` returns 0, the input service methods should handle that gracefully (they already guard on valid frames).

- [ ] **Step 6: Verify build**

Run: `xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: BUILD FAILED — SimcastApp and StreamReadyView still use old API. Fixed in Tasks 7-8.

- [ ] **Step 7: Commit**

```bash
git add apps/macos/simcast/Stream/Managers/SCKManager.swift
git commit -m "refactor(macos): SCKManager manages per-UDID StreamSession dictionary with input wiring"
```

---

## Task 7: macOS — Update SimcastApp to pass dependencies

**Files:**
- Modify: `apps/macos/simcast/SimcastApp.swift`

- [ ] **Step 1: Remove singleton LiveKitProvider and PreviewReceiver**

Remove `@State private var previewReceiver` and `@State private var liveKitProvider` declarations.

Update `SCKManager` init to pass `supabase` and `logger`:
```swift
let sckManager = SCKManager(supabase: auth.supabase, logger: logger)
```

Remove lines:
```swift
// DELETE these:
let previewReceiver = PreviewReceiver()
let liveKitProvider = LiveKitProvider(supabase: auth.supabase, logger: logger)
sckManager.addReceiver(previewReceiver)
sckManager.addProvider(liveKitProvider)
_previewReceiver = State(initialValue: previewReceiver)
_liveKitProvider = State(initialValue: liveKitProvider)
```

- [ ] **Step 2: Remove environment injections**

Remove from the `.environment()` chain:
```swift
// DELETE these:
.environment(previewReceiver)
.environment(liveKitProvider)
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: BUILD FAILED — StreamReadyView and SimulatorRow still reference old environment. Fixed in Task 8.

- [ ] **Step 4: Commit**

```bash
git add apps/macos/simcast/SimcastApp.swift
git commit -m "refactor(macos): remove singleton LiveKitProvider/PreviewReceiver from app, pass deps to SCKManager"
```

---

## Task 8: macOS — Simplify StreamReadyView and update SimulatorRow

**Files:**
- Modify: `apps/macos/simcast/Stream/Views/StreamReadyView.swift`
- Modify: `apps/macos/simcast/Stream/Views/SimulatorRow.swift`

- [ ] **Step 1: Simplify StreamReadyView**

Remove `@Environment(LiveKitProvider.self)` — no longer in environment.

Remove all input handler wiring (lines 58-119 in `.task`). Input wiring is now in `SCKManager.wireInputHandlers()`.

Set up `inputService` and `simulatorService` on `sckManager` in `.task`:
```swift
.task {
    let inputService = SimulatorInputService(logger: logger)
    sckManager.inputService = inputService
    sckManager.simulatorService = service

    sckManager.onSessionStopped = { _ in
        Task { await syncService.syncPresence(streamingUdids: sckManager.streamingUdids) }
    }

    syncService.onStreamCommand = { cmd in
        Task { @MainActor in
            switch cmd.action {
            case .start:
                if sckManager.sessions[cmd.udid] != nil {
                    await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                    return
                }
                try? await service.windowService.refresh()
                guard let simulator = service.simulators.first(where: { $0.udid == cmd.udid }),
                      let window = service.windowService.window(for: simulator.windowID) else { return }
                do {
                    try await sckManager.start(window: window, udid: cmd.udid)
                    await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                } catch {
                    await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                }
            case .stop:
                await sckManager.stop(udid: cmd.udid)
                await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
            }
        }
    }

    while !Task.isCancelled {
        await service.refresh()
        await syncService.updateSimulators(service.simulators)
        try? await Task.sleep(for: .seconds(3))
    }
}
```

Update `isCapturing` check for row highlighting:
```swift
// Was: let isCapturing = sckManager.streamingUdid == simulator.udid && sckManager.isCapturing
let isCapturing = sckManager.sessions[simulator.udid] != nil
```

Update `.onChange` handler to stop only disappeared sessions:
```swift
.onChange(of: service.simulators.map(\.id)) { _, newIds in
    let newIdSet = Set(newIds)
    for udid in sckManager.streamingUdids where !newIdSet.contains(udid) {
        Task {
            await sckManager.stop(udid: udid)
            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
        }
    }
}
```

- [ ] **Step 2: Update SimulatorRow**

Remove `@Environment(PreviewReceiver.self)` — no longer in environment.

Update computed properties:
```swift
var session: StreamSession? { sckManager.sessions[simulator.udid ?? ""] }
var isCapturingThis: Bool { session != nil }
var isConnecting: Bool { isCapturingThis && !(session?.isConnected ?? false) }
var isStreaming: Bool { isCapturingThis && (session?.isConnected ?? false) }
```

Update start button handler — remove `if sckManager.isCapturing { await sckManager.stop() }`:
```swift
Button(action: {
    streamError = nil
    Task {
        guard let udid = simulator.udid else { return }
        try? await simulatorService.windowService.refresh()
        guard let window = simulatorService.windowService.window(for: simulator.windowID) else {
            streamError = "Simulator window is no longer available"
            return
        }
        do {
            try await sckManager.start(window: window, udid: udid)
            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
        } catch {
            streamError = error.localizedDescription
        }
    }
})
```

Update stop button handler:
```swift
Button(action: {
    Task {
        guard let udid = simulator.udid else { return }
        await sckManager.stop(udid: udid)
        await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
    }
})
```

Update start button disabled state — only disable if already capturing this simulator or no udid:
```swift
.disabled(isCapturingThis || simulator.udid == nil)
```

Update preview to use per-session receiver:
```swift
if let session {
    SCKPreviewView(layer: session.previewReceiver.displayLayer)
        .aspectRatio(...)
        .frame(maxHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.opacity)
}
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Full verification**

1. Run the macOS app
2. Start streaming one simulator → verify stream works
3. Stop stream → verify cleanup
4. Start a different simulator → verify it works without error
5. Check web dashboard shows streaming badge correctly
6. Test input controls (tap, scroll, type, buttons)
7. Test screenshot and recording

- [ ] **Step 5: Commit**

```bash
git add apps/macos/simcast/Stream/Views/StreamReadyView.swift apps/macos/simcast/Stream/Views/SimulatorRow.swift
git commit -m "refactor(macos): simplify StreamReadyView, update SimulatorRow for per-session architecture"
```

---

## Task 9: Final integration verification

- [ ] **Step 1: Clean build both apps**

```bash
cd /Users/florinm/Developer/Sources/simcast
xcodebuild -project apps/macos/simcast.xcodeproj -scheme simcast -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
cd apps/web && npm run build
```

Both must pass.

- [ ] **Step 2: End-to-end functional test**

1. Start web dev server: `cd apps/web && npm run dev`
2. Launch macOS app, sign in
3. Boot 2 simulators in Xcode
4. From web: start streaming simulator A → verify video appears
5. From web: stop simulator A → verify cleanup, right panel shows placeholder
6. From web: start simulator B → verify it starts without error
7. Test Watch/Hide buttons
8. Test screenshot, recording, tap, scroll, type on active stream
9. Force-quit macOS app → verify web cleans up streaming badges after ~60s

- [ ] **Step 3: Commit any fixes**

If any issues found during testing, fix and commit.
