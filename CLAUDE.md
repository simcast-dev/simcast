# SimCast

Open-source platform that streams iOS Simulator windows over WebRTC. The macOS app captures and publishes streams via LiveKit; the web dashboard controls streaming and views live output.

- **Domain**: simcast.dev
- **GitHub**: github.com/simcast-dev/simcast
- **License**: MIT

## Repository

```
simcast/
├── CLAUDE.md
├── apps/
│   ├── macos/              # Swift/SwiftUI — captures Simulator, streams via LiveKit, syncs via Supabase Realtime
│   │   └── CLAUDE.md
│   └── web/                # Next.js 16 — dashboard, stream control, LiveKit viewer, interactive controls, guest share links
│       └── CLAUDE.md
```

## System Overview

```
Web Dashboard ──► stream_commands (Supabase DB insert)
                        │
                        ▼
              macOS SyncService (Realtime postgres changes)
                        │
                        ▼
              SCKManager ──► StreamSession (per simulator)
                  │              │
                  │         LiveKitProvider ──► LiveKit Room (WebRTC)
                  │                                   │
                  ▼                                   ▼
              Supabase Presence              Web SimulatorViewer
              (streaming_udids[])            (livekit-token edge fn)
```

- **Auth**: Supabase email/password, shared between macOS and web
- **Signaling**: Supabase Realtime — user channel `user:{userId}` for presence (simulator list + streaming state) and postgres changes (stream commands); per-simulator channel `simulator:{udid}` for log broadcast and clear_logs
- **Streaming**: LiveKit cloud — H.264, 8 Mbps, 60 fps, no simulcast. Per-simulator `StreamSession` (multi-stream ready, each simulator gets its own LiveKit room)
- **Screenshots**: macOS captures → Supabase Storage → signed URL → broadcast to web → auto-download
- **Logs**: macOS `AppLogger` → per-simulator Realtime broadcast (`simulator:{udid}`) → web `LogDrawer` (real-time, category-filtered, scoped to watched simulator)

## Git Workflow

- Do NOT push to remote unless I explicitly ask
- Do NOT amend or rebase existing commits unless asked

## Code Style

- No comments that restate what the code does — comments only for WHY
- Prefer descriptive names over comments
- Error messages should be actionable

## MCP Servers

| Server | Use For | Install |
|--------|---------|---------|
| **Apple Docs MCP** | Apple framework APIs: ScreenCaptureKit, VideoToolbox, AXUIElement, CGEvent, SwiftUI. WWDC sessions. | `claude mcp add apple-docs -- npx -y @kimsungwhee/apple-docs-mcp@latest` |
| **Context7** | Non-Apple libraries: LiveKit Swift SDK, Next.js, Supabase JS/Swift. Current version-specific docs. | `claude mcp add context7 -- npx -y @upstash/context7-mcp@latest` |
| **XcodeBuildMCP** | Build, run, test in Simulator. | `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp` |

Rules:
- Apple APIs → **Apple Docs MCP** first
- LiveKit, third-party libs → **Context7**
- Build and run → **XcodeBuildMCP**

## Agent Skills

| Skill | Purpose |
|-------|---------|
| **SwiftUI Expert** (AvdLee) | Modern SwiftUI patterns, `@Observable`, view composition, state management |
| **Swift Concurrency Expert** (AvdLee) | Safe async/await, actors, `@MainActor`, Sendable, Swift 6 |
