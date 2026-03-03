# SimCast macOS App

Captures iOS Simulator windows, encodes to H.264, streams via LiveKit. Handles remote touch injection.

## Tech Stack

- **Swift** with macOS 15.6+ deployment target
- **100% SwiftUI** for building UI
- **ScreenCaptureKit** - window-specific capture of iOS Simulator
- **VideoToolbox** - hardware H.264 encoding
- **LiveKit Swift SDK** - publishes video track + data channels

## Xcode Project

- Product Name: **simcast**
- Organization Identifier: **com.florinmatinca**
- Bundle Identifier: **com.florinmatinca.simcast**
- Deployment Target: **macOS 15.6**
- **No App Sandbox**
- **Hardened Runtime** enabled (required for notarization)
- Entitlements: `com.apple.security.screen-capture`, `com.apple.security.accessibility`, outgoing + incoming network connections

## Build Verification

After completing any code change, build the app and check for errors:

```bash
xcodebuild -project apps/macos/simcast.xcodeproj \
  -scheme simcast \
  -configuration Debug \
  build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Run this from the repo root. Fix all `error:` lines before considering the task done. Warnings are acceptable.

If XcodeBuildMCP macOS workflows are enabled (requires `.xcodebuildmcp/config.yaml`), prefer those tools over the Bash command.

## Documentation Rules

- SwiftUI patterns handled by SwiftUI Agent Skill
- Concurrency handled by Swift Concurrency Agent Skill
- Always look up ScreenCaptureKit APIs via Apple Docs MCP before using them
- Always verify VideoToolbox property keys
- Always check LiveKit Swift SDK signatures via Context7
