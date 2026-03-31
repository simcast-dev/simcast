# SimCast Web App

Next.js 16 browser client for viewing and controlling SimCast streams.

## Tech Stack

- **Next.js 16** — App Router, TypeScript strict mode
- **Tailwind CSS v4** — `@import "tailwindcss"` in globals.css
- **Supabase** — `@supabase/ssr` for auth (cookie-based sessions), Realtime presence + postgres changes, edge function invocation
- **LiveKit** — `@livekit/components-react` + `livekit-client` for WebRTC stream playback and data channel input injection
- **Package manager** — npm

## Project Structure

```
src/
├── app/
│   ├── globals.css          # @import "tailwindcss" + CSS custom properties (--bg, --text, --log-*, etc.)
│   ├── layout.tsx           # Root layout, Geist font
│   ├── page.tsx             # Root — auth-protected, renders DashboardClient
│   ├── theme-provider.tsx   # Theme context provider
│   ├── theme-script.tsx     # Inline script to prevent FOUC
│   ├── login/
│   │   ├── page.tsx         # Server wrapper
│   │   └── LoginForm.tsx    # Client component
│   └── dashboard/
│       ├── DashboardClient.tsx  # Client root — layout, split-pane, log drawer, background blooms
│       ├── StreamGrid.tsx       # Realtime presence cards + send stream_commands
│       ├── SimulatorViewer.tsx  # LiveKit room viewer wrapper
│       ├── ui.tsx               # Shared UI components (ControlPanelButton, StatItem, DeviceIconBox, etc.)
│       ├── SignOutButton.tsx
│       ├── contexts/
│       │   └── PageVisibilityContext.tsx  # Tracks browser tab visibility
│       ├── components/
│       │   ├── ScreenView.tsx       # Interactive controls (tap, scroll, type, push, link, record, screenshot)
│       │   ├── LogDrawer.tsx        # Footer log drawer with category filters
│       │   ├── AppDropdown.tsx      # App selection dropdown
│       │   ├── PushNotificationModal.tsx
│       │   └── ThemeSelector.tsx
│       ├── hooks/
│       │   ├── usePresenceSubscription.ts  # Realtime presence on user:{userId} channel
│       │   ├── useSimulatorChannel.ts     # Per-simulator channel (simulator:{udid}) for logs + clear_logs
│       │   ├── useLiveKitConnection.ts     # LiveKit token + room connection
│       │   ├── useLogStream.ts             # Log entry state, capped array, error count
│       │   ├── useVideoStats.ts            # Stream quality metrics
│       │   └── usePageVisibility.ts        # Hook for PageVisibilityContext
│       └── gallery/
│           ├── ScreenshotGallery.tsx
│           ├── RecordingGallery.tsx
│           ├── ImagePreviewModal.tsx # Full-size screenshot preview
│           ├── VideoPreviewModal.tsx # Recording playback preview
│           ├── useScreenshots.ts    # Fetch + Realtime INSERT subscription
│           └── useRecordings.ts     # Fetch + Realtime INSERT subscription
├── lib/
│   └── supabase/
│       ├── client.ts        # createBrowserClient
│       └── server.ts        # createServerClient + cookies()
└── proxy.ts                 # Supabase session refresh + route protection + CSP/security headers (used as middleware)
```

## Supabase

- Project URL: `https://ocdfaysptysziokdgbye.supabase.co`
- Credentials in `.env.local` (not committed)
- Server client: `createClient()` from `@/lib/supabase/server`
- Browser client: `createClient()` from `@/lib/supabase/client`

### Edge Functions

| Function | Purpose |
|----------|---------|
| `livekit-token` | Issues LiveKit JWT for authenticated users (publisher or subscriber) |

## Command Flow (Web → macOS)

1. `StreamGrid` calls `sendCommand(action, udid)` → inserts into `stream_commands` table
2. macOS `SyncService` receives the INSERT via Supabase Realtime postgres changes
3. macOS executes the command and updates presence (`streaming_udids[]`)
4. `StreamGrid` reads updated presence and shows streaming badges per simulator

## Realtime

### Presence
`usePresenceSubscription` subscribes to `channel("user:{userId}")` and reads presence state. Each macOS session tracks: `session_id`, `user_email`, `started_at`, `simulators[]`, `streaming_udids[]`. Deduplicates by UDID (keeps most recent session).

### Per-Simulator Channels
`useSimulatorChannel` subscribes to `channel("simulator:{udid}")` for the currently watched simulator. Logs are scoped per-simulator; switching simulators clears the log display and subscribes to the new channel.

### Broadcast (on `simulator:{udid}` channel)
- **`log`** (macOS → web): Real-time log entries from `AppLogger`, scoped to a specific simulator. Displayed in `LogDrawer` footer drawer with category filters. Capped at 500 entries.
- **`clear_logs`** (web → macOS): Clears log panel on both sides for the watched simulator.

### Postgres Changes
- **`screenshots` INSERT**: Gallery auto-updates when macOS uploads a screenshot.
- **`recordings` INSERT**: Gallery auto-updates when macOS uploads a recording.

## Theme

Aurora Dark/Light with theme toggle. CSS custom properties in `globals.css`:
- `--bg: #161330` (violet-black), `--text: #EDE9FF` (light purple-white)
- Violet `#7C3AED` (primary), emerald `#10B981` (active/highlight)
- Glassmorphism with `backdrop-filter: blur()`, radial gradient blooms in background

## Dashboard Layout

Always-visible split-pane: `StreamGrid` on the left (40%), `SimulatorViewer` on the right (60%). Right panel shows a placeholder when no simulator is selected; shows the stream when watching. Footer bar shows stream stats and a "Logs" button that opens a resizable log drawer.

## SimulatorViewer Interactive Controls

`SimulatorViewer` sends LiveKit data channel messages to the macOS app. Three control tabs:

| Data topic | Payload | Control |
|------------|---------|---------|
| `simulator_tap` | `{x, y, vw, vh, longPress?: number}` normalized to video frame | TAP tab — click on video; optional long-press toggle |
| `simulator_gesture` | `{gesture: string}` | SCROLL tab — scroll (up/down/left/right), edge swipes (from-left-edge, from-right-edge, from-top-edge, from-bottom-edge) |
| `simulator_text` | `{text: string}` | TYPE tab — text input field |
| `simulator_button` | `{button: string}` | Hardware buttons — `home`, `lock`, `side` |
| `simulator_screenshot` | `{}` | Screenshot button — macOS captures, uploads to Supabase Storage, broadcasts signed URL back via `simulator_screenshot_result`; auto-downloaded |

TAP tab also supports "Tap by label" — sends `simulator_tap` with an `axeLabel` field for accessibility label targeting.

Real-time stats bar (always visible): RES, FPS, BW (bitrate), PKT (packets lost — red if > 0).

## Route Protection

`proxy.ts` (Next.js middleware) redirects:
- Unauthenticated → any route (except `/login`) redirects to `/login`
- Authenticated → `/login` redirects to `/`

## Security Headers

Set in `proxy.ts`:
- `Content-Security-Policy` — allows Supabase WSS and LiveKit cloud origins
- `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`

## Dev

```bash
cd apps/web
npm install
npm run dev      # http://localhost:3000
npm run build    # verify no TS errors
npm run lint
```

## Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_LIVEKIT_URL=   # optional — LiveKit server URL for future guest viewer
```

## Deployment

- **Vercel** — zero-config, set env vars in project settings
