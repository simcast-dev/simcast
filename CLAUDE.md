# SimCast

Open-source platform for streaming and controlling local iOS Simulators in realtime. The macOS app is the source of truth for simulator inventory, stream state, command execution, and media capture. The web dashboard is the remote operator UI.

- **Domain**: simcast.dev
- **GitHub**: github.com/simcast-dev/simcast
- **License**: MIT

## Repository

```text
simcast/
├── CLAUDE.md
├── README.md
├── apps/
│   ├── macos/              # SwiftUI publisher + operator console
│   │   └── CLAUDE.md
│   ├── web/                # Next.js dashboard + LiveKit viewer
│   │   └── CLAUDE.md
│   └── supabase/           # media schema/storage policies + LiveKit token function
├── docs/
└── .github/workflows/
```

## System Overview

```text
Web Dashboard ── Broadcast command/ack/result/logs ──► user:{userId} ◄── Presence (mac + web)
      │                                                      │
      │                                                      ▼
      │                                            macOS SyncService
      │                                                      │
      ▼                                                      ▼
LiveKit viewer ◄────────────── video only ────────────── SCKManager / StreamSession
      │                                                      │
      └──────────── viewer token (user + udid) ──────────────┘

macOS screenshot / recording capture ──► PostgreSQL rows + Storage upload
                                              │
                                              └── pending → ready / failed gallery lifecycle
```

## Realtime-First Architecture

- **Auth**: Supabase email/password on both macOS and web.
- **Realtime topology**: one per-user Supabase Realtime channel, `user:{userId}`.
- **Commands**: Broadcast only. There is no durable database-backed command queue.
- **Streaming**: LiveKit transports video only.
- **Persistence**: PostgreSQL + Storage are used only for screenshots and recordings.

### Presence on `user:{userId}`

macOS presence is authoritative and includes:
- `session_type: "mac"`
- `session_id`
- `user_email`
- `started_at`
- `simulators[]`
- `streaming_udids[]`
- `presence_version`

Web presence is lightweight and includes:
- `session_type: "web"`
- `dashboard_session_id`
- `opened_at`
- `watching_udid`
- `page_visible`

### Broadcast events on `user:{userId}`

- `command`: web → macOS realtime command envelope
- `command_ack`: macOS → web immediate `received` / `rejected`
- `command_result`: macOS → web explicit success / failure result
- `log`: macOS → web realtime log payload tagged by simulator UDID

### Source-of-truth rules

- The web renders simulator availability and stream state from **mac presence only**.
- The web never assumes a stream changed just because a command was sent.
- Stream `start` / `stop` are only complete after mac presence confirms `streaming_udids[]`.
- The mac app may recover an unseen dashboard session from a valid incoming command after reconnect, but presence remains the canonical long-lived session signal.

## Media Lifecycle

- `screenshots` and `recordings` are the only durable operational tables.
- The intended schema includes:
  - `status: pending | ready | failed`
  - `error_message`
- macOS inserts a row as `pending`, uploads to Storage, then updates it to `ready` or `failed`.
- The web gallery subscribes to `INSERT` and `UPDATE` and renders placeholders while items are pending.
- The mac app currently includes a legacy-schema fallback so screenshot/recording upload still works if the remote project has older tables, but placeholder status requires the latest migrations.

## Current Architecture Notes

- The macOS app owns:
  - simulator discovery
  - Simulator window matching
  - ScreenCaptureKit capture
  - LiveKit publishing
  - realtime command execution
  - screenshot/recording upload orchestration
  - local/operator logging
- The web app owns:
  - dashboard layout
  - realtime command sending
  - ack/result handling
  - LiveKit playback
  - gallery rendering
  - log viewing/filtering
- The `livekit-token` edge function derives room names from authenticated `user + udid`. Clients should not choose arbitrary room names.

## UX Notes

- macOS startup uses an explicit launch/bootstrap flow to avoid flashing the wrong screen before auth and permissions are known.
- The mac operator UI is intentionally console-like:
  - simulator list with stream/recording state
  - filterable log panel
  - command lifecycle logs including `received`, `ack`, and `result`
- The web dashboard exposes realtime health clearly:
  - header badge
  - simulator grid stale/offline states
  - command-level timeout and failure messaging

## Supabase Files

- `apps/supabase/migrations/20260322_create_media_library_tables.sql`
- `apps/supabase/migrations/20260325_configure_media_storage_and_realtime.sql`
- `apps/supabase/functions/livekit-token/index.ts`

The checked-in migration set reflects the current architecture:
- media tables only
- storage policies
- realtime publication for screenshots/recordings
- no `stream_commands` / `streams` dependency in app behavior

## Git Workflow

- Do NOT push to remote unless explicitly asked.
- Do NOT amend or rebase existing commits unless asked.

## Code Style

- Prefer descriptive names over explanatory comments.
- Comments should explain **why**, not restate **what**.
- Error messages should be actionable and user-facing when practical.
- Realtime logs should help reconstruct command flow, not just record failures.

## MCP Servers

| Server | Use For | Install |
|--------|---------|---------|
| **Apple Docs MCP** | Apple APIs: SwiftUI, ScreenCaptureKit, AX, AppKit | `claude mcp add apple-docs -- npx -y @kimsungwhee/apple-docs-mcp@latest` |
| **Context7** | Supabase, LiveKit, Next.js, third-party SDKs | `claude mcp add context7 -- npx -y @upstash/context7-mcp@latest` |
| **XcodeBuildMCP** | Build and run the macOS app | `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp` |

Rules:
- Apple frameworks → **Apple Docs MCP** first
- Third-party SDKs → **Context7**
- macOS build/run/test → **XcodeBuildMCP**

## Agent Skills

| Skill | Purpose |
|-------|---------|
| **SwiftUI Expert** | SwiftUI state, routing, view extraction, performance |
| **Swift Concurrency Expert** | async/await, actor isolation, MainActor correctness |
