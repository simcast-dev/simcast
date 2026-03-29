# SimCast macOS App

Captures iOS Simulator windows, encodes to H.264, streams via LiveKit. Handles remote stream commands and interactive input injection from web clients.

## Tech Stack

- **Swift** with macOS 15.6+ deployment target
- **100% SwiftUI** for UI
- **ScreenCaptureKit** — window-specific capture of iOS Simulator
- **VideoToolbox** — hardware H.264 encoding (via LiveKit)
- **LiveKit Swift SDK** — publishes video track; 8 Mbps, 60 fps, H.264, no simulcast, no adaptive stream; receives data channel messages for input injection
- **Supabase Swift SDK** — auth, Realtime presence + postgres changes + broadcast (log streaming)
- **`axe` CLI** (`/opt/homebrew/bin/axe`) — gesture, button, and text injection into Simulator

## Xcode Project

- Product Name: **simcast**
- Organization Identifier: **com.florinmatinca**
- Bundle Identifier: **com.florinmatinca.simcast**
- Deployment Target: **macOS 15.6**
- **No App Sandbox**
- **Hardened Runtime** enabled (required for notarization)
- Entitlements: `com.apple.security.screen-capture`, `com.apple.security.accessibility`, outgoing + incoming network connections
- Supabase credentials in `Config.xcconfig` via `SupabaseURL` and `SupabaseAnonKey` keys (injected into Info.plist)

## Architecture

```
SimcastApp
├── AuthManager          @Observable — Supabase auth state, exposes supabase client
├── SyncService          @Observable — Realtime channels, presence tracking, stream commands, per-simulator log broadcast
│   ├── channel "user:{userId}"
│   │   ├── presence track() — sessionId, userEmail, startedAt, simulators list, streamingUdids[]
│   │   └── postgres changes — stream_commands INSERT (action: start|stop) → onStreamCommand callback
│   └── simulatorChannels "simulator:{udid}" (one per booted simulator, managed by updateSimulators)
│       ├── broadcast "log" — sends log entries scoped to this simulator
│       └── broadcast "clear_logs" — receives clear command from web for this simulator
├── SimulatorService     @Observable — polls simctl every 3s, discovers booted simulators
│   └── WindowService    — maps simulator windowIDs to SCWindows via SCShareableContent
├── SCKManager           @Observable — manages per-simulator StreamSessions
│   ├── sessions: [String: StreamSession]  — keyed by UDID, each session owns:
│   │   ├── SCStream + SCKProxy  — ScreenCaptureKit capture for this window
│   │   ├── LiveKitProvider      — per-session LiveKit room connection + input handlers
│   │   ├── PreviewReceiver      — per-session local preview layer
│   │   └── FileRecordingReceiver — per-session recording (optional)
│   ├── wireInputHandlers()  — wires LiveKit data channel → SimulatorInputService per session
│   └── forceRefresh via SimulatorService for reliable window lookup
├── SimulatorInputService — tap injection via CGEvent + AXUIElement; gesture/button/text via axe CLI
└── AppLogger            @Observable — in-memory log store, broadcasts to web via SyncService per-simulator channels
    └── LogWriter        background actor — append-only, capped at 500
    └── log(_ category:, _ message:, udid: String? = nil) — when udid provided, broadcasts on simulator:{udid} channel
```

### Key Types

- **`StreamSession`** — per-simulator capture pipeline: bundles SCStream + LiveKitProvider + PreviewReceiver + recording state. Created by `SCKManager.start()`, destroyed by `stop(udid:)`.
- **`VideoFrameReceiver`** protocol — `sckManager(didOutput:)` + `sckManagerDidStop()`. Implemented by `PreviewReceiver` and `LiveKitProvider`.
- **`StreamingProvider: VideoFrameReceiver`** protocol — adds `isConnected`, `prepare(size:)`, `connect(roomName:)`, `disconnect()`. Implemented by `LiveKitProvider`.

## Data Flow

1. Web dashboard inserts `stream_commands` row (`action: start|stop`, `udid`, `user_id`)
2. `SyncService` receives it via postgres changes on `user:{userId}` Realtime channel
3. `StreamReadyView.onStreamCommand` dispatches to `SCKManager`
4. `SCKManager.start(window:udid:)` creates a `StreamSession` with per-session `LiveKitProvider` + `PreviewReceiver`, starts ScreenCaptureKit capture, wires input handlers, connects to LiveKit room (room name = UDID). Retries with fresh window on failure.
5. `LiveKitProvider.connect` fetches token from `livekit-token` edge function, connects Room, publishes video track
6. `SyncService.syncPresence(streamingUdids:)` broadcasts `streamingUdids` array so web knows which streams are live
7. Each session's input handlers route data channel messages to `SimulatorInputService` using the captured UDID

## Interactive Input Flow

Each session's `LiveKitProvider` receives data channel messages on its own room via `RoomDelegate.room(_:participant:didReceiveData:forTopic:)`. Input handlers are wired in `SCKManager.wireInputHandlers()` with the UDID captured at session creation:

| Topic | Payload | Handler |
|-------|---------|---------|
| `simulator_tap` | `{x, y, vw?, vh?, longPress?: number, axeLabel?: string}` | `SimulatorInputService.injectTap` — CGEvent mouseDown/mouseUp at screen coords (after AXUIElement focus); long-press via `axe touch --down --up --delay`; label tap via `axe tap --label` |
| `simulator_button` | `{button: "home"\|"lock"\|"side"\|"siri"\|"apple_pay"}` | `SimulatorInputService.pressHardwareButton` — `axe button <type> --udid` |
| `simulator_gesture` | `{gesture: string}` | `SimulatorInputService.performGesture` — `axe gesture <gesture> --udid` (supports scroll and edge swipes) |
| `simulator_text` | `{text: string}` | `SimulatorInputService.typeText` — `axe type <text> --udid` |
| `simulator_screenshot` | `{}` | `SimulatorInputService.captureScreenshot` — captures to temp file, uploads to Supabase Storage, broadcasts signed URL via `simulator_screenshot_result` Realtime broadcast |

## Build Verification

After any code change, build and check for errors:

```bash
xcodebuild -project apps/macos/simcast.xcodeproj \
  -scheme simcast \
  -configuration Debug \
  build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Run from repo root. Fix all `error:` lines before considering the task done. Warnings are acceptable.

If XcodeBuildMCP macOS workflows are enabled (requires `.xcodebuildmcp/config.yaml`), prefer those tools over the Bash command.

## Documentation Rules

- SwiftUI patterns → SwiftUI Agent Skill
- Concurrency → Swift Concurrency Agent Skill
- ScreenCaptureKit APIs → Apple Docs MCP
- VideoToolbox property keys → Apple Docs MCP
- LiveKit Swift SDK signatures → Context7
