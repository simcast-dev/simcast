# SimCast macOS App

The macOS app is the authoritative runtime for simulator discovery, stream publishing, command execution, and media upload.

## Tech Stack

- **Swift + SwiftUI**
- **ScreenCaptureKit** for simulator window capture
- **LiveKit Swift SDK** for publishing video
- **Supabase Swift SDK** for auth, Realtime, and media persistence
- **`axe` CLI** plus `simctl` for interactive simulator control

## High-Level Architecture

```text
SimcastApp
├── AuthManager                 # Keychain-backed Supabase config + auth bootstrap
├── SyncService                 # shared user:{userId} realtime channel
├── SimulatorService            # booted simulator discovery + window mapping
├── SCKManager                  # per-UDID StreamSession lifecycle
├── StreamCommandExecutor       # validates/executes incoming commands
├── SimulatorInputService       # axe / simctl command runner with real failure propagation
└── AppLogger                   # local operator log + web broadcast bridge
```

## App Shell

- `SimcastApp` uses an explicit startup phase:
  - `launching`
  - `unconfigured`
  - `unauthenticated`
  - `authenticated`
- `AppLaunchView` is used during:
  - auth bootstrap
  - authenticated service preparation
  - permission bootstrap before the main screen appears
- This avoids flashing login/setup/permission screens before the app knows the correct destination.

## Realtime Contract

The app joins one Supabase Realtime channel per user: `user:{userId}`.

### Presence
macOS tracks authoritative presence with:
- `session_type: "mac"`
- `session_id`
- `user_email`
- `started_at`
- `simulators[]`
- `streaming_udids[]`
- `presence_version`

### Broadcast handling
`SyncService` listens for:
- `command`

And emits:
- `command_ack`
- `command_result`
- `log`

Listeners are attached before subscription completes so macOS does not miss initial web presence or early commands during reconnect/bootstrap.

## Command Execution

`StreamCommandExecutor` is the single place where incoming realtime commands are decoded and executed.

Supported kinds:
- `start`, `stop`
- `tap`, `swipe`
- `button`, `gesture`, `text`
- `push`, `app_list`, `open_url`
- `screenshot`
- `start_recording`, `stop_recording`
- `clear_logs`

Rules:
- every recognized command gets an ack
- every executed command emits an explicit success or failure result
- stream `start` / `stop` also update mac presence so the web can confirm source-of-truth stream state

## Native Input Layer

`SimulatorInputService`:
- throws structured errors instead of silently logging and returning
- waits for subprocess completion
- checks termination status
- surfaces stderr/stdout details in failure messages when available

This matters because the dashboard depends on explicit `command_result` success/failure, not just “the process launched.”

## Media Lifecycle

`LiveKitProvider` handles:
- LiveKit publisher connection
- screenshot media row creation + upload orchestration
- recording media row creation + upload orchestration

Preferred flow for screenshots and recordings:
1. insert DB row as `pending`
2. return command success quickly
3. upload to Storage in the background
4. update row to `ready` or `failed`

Compatibility note:
- if the remote Supabase project still uses the older media schema without `status` / `error_message`, the mac app falls back to a legacy insert path so uploads still succeed
- the placeholder lifecycle still requires the latest migrations

## Operator UI

- `StreamReadyHeader` shows quick operator pills for:
  - detected simulators
  - live streams
  - active recordings
- `SimulatorRow` includes clearer stream/recording status and better row-level state visibility
- `LogPanel` acts like an operator console:
  - category filter chips
  - simulator filter menu
  - clearer last-entry/error summary
  - simulator names in the filter, not just UDIDs

## Logging

`AppLogger` feeds both the local console and the web dashboard log stream.

`SyncService` now logs the realtime command lifecycle clearly:
- command received
- ack sent / ack rejected
- result sent / result failed

These entries are tagged by simulator UDID when available so they can be filtered per simulator in the mac log panel and in the web dashboard.

## Verification

```bash
xcodebuild -project apps/macos/simcast.xcodeproj \
  -scheme simcast \
  -configuration Debug \
  build
```

If XcodeBuildMCP is available, prefer it for simulator-oriented verification.
