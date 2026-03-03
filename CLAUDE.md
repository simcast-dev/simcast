# SimCast

Open-source platform that streams iOS Simulator windows over WebRTC with remote touch interaction.

- **Domain**: simcast.dev
- **GitHub**: github.com/simcast-dev/simcast
- **License**: MIT

## Repository

```
simcast/
├── CLAUDE.md
├── apps/
│   ├── macos/              # macOS streaming app
│   │   └── CLAUDE.md
│   ├── web/                # Next.js browser client
│   │   └── CLAUDE.md
│   └── ios/                # iOS/iPadOS viewer app
│       └── CLAUDE.md
```

## Git Workflow

- When committing, set the git author to Claude: git commit --author="Claude <noreply@anthropic.com>"
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
| **Context7** | Non-Apple libraries: LiveKit Swift SDK, Next.js (later). Current version-specific docs. | `claude mcp add context7 -- npx -y @upstash/context7-mcp@latest` |
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
