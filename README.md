<p align="center">
  <img src="apps/macos/release/SimCast-iOS-Default-1024x1024@1x.png" alt="SimCast" width="128" height="128" />
</p>

<h3 align="center">Stream and control local iOS Simulators from the browser in realtime.</h3>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-macOS_15.6+-lightgrey.svg" alt="Platform: macOS 15.6+">
  <img src="https://img.shields.io/badge/Swift-6-orange.svg" alt="Swift 6">
  <img src="https://img.shields.io/badge/Next.js-16-black.svg" alt="Next.js 16">
  <a href="https://simcast.dev"><img src="https://img.shields.io/badge/web-simcast.dev-7C3AED.svg" alt="simcast.dev"></a>
</p>

---

SimCast captures individual iOS Simulator windows using ScreenCaptureKit, hardware-encodes them to H.264 at 60 fps, and streams them to any browser through [LiveKit](https://livekit.io).

The browser dashboard lets you:
- start and stop streams
- tap, swipe, scroll, type, press hardware buttons, send pushes, and open links
- inspect realtime logs
- capture screenshots and recordings

The product is intentionally **realtime-first**:
- the **macOS app** is the single source of truth for simulator inventory and stream state
- the **web dashboard** is the remote operator UI
- simulator commands travel over **Supabase Realtime Broadcast**
- video travels over **LiveKit**
- screenshots and recordings are the only operational data persisted in **Supabase Postgres + Storage**

<h3 align="center"><a href="https://vimeo.com/manage/videos/1184608499">▶ Watch the demo video</a> · <a href="https://simcast.dev">simcast.dev</a></h3>

## Features

**Realtime simulator streaming**
- Captures individual Simulator windows, not the whole display
- Hardware H.264 encoding via VideoToolbox at 8 Mbps / 60 fps
- WebRTC playback in the browser through LiveKit
- Multiple simulators can be streamed independently

**Realtime simulator control**
- Tap anywhere on the stream with coordinate mapping back to the real simulator
- Tap by accessibility label
- Long press, freeform swipe, edge gestures, and scroll gestures
- Type directly into the focused field
- Press Home, Lock, or Side button
- Send push notifications
- Open deep links and custom URL schemes

**Capture + gallery**
- One-click screenshots
- Start and stop video recordings
- Realtime gallery updates for screenshots and recordings
- Pending / ready / failed media lifecycle when the latest media migrations are installed

**Operator visibility**
- Realtime status badge in the dashboard
- Stream stats in the viewer
- Per-simulator log filtering in the web dashboard
- Operator-style log console in the macOS app, including command `received`, `ack`, and `result` lifecycle logs

## Architecture

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
                                              └── pending → ready / failed
```

### Realtime contract

- Both apps join the same Supabase Realtime channel: `user:{userId}`.
- **mac presence** advertises:
  - simulator inventory
  - streaming UDIDs
  - presence freshness via `presence_version`
- **web presence** advertises dashboard session identity and visibility.
- Every command is sent as Broadcast `command`.
- macOS replies with:
  - `command_ack`
  - `command_result`
  - `log`

### Source-of-truth rules

- The web never treats “command sent” as success.
- `start` / `stop` are complete only after mac presence confirms the new `streaming_udids[]`.
- If the mac app is offline or realtime is stale, the dashboard should surface that instead of queueing commands in the database.

## Prerequisites

You need a Mac to run the capture app. The web dashboard can be self-hosted or deployed to Vercel.

| Requirement | Install |
|------------|---------|
| macOS 15.6+ | — |
| At least one booted iOS Simulator | `open -a Simulator` |
| [axe](https://github.com/cameroncooke/AXe) CLI | `brew install cameroncooke/tap/axe` |
| [Supabase](https://supabase.com) account | Free tier works |
| [LiveKit Cloud](https://cloud.livekit.io) account | Free tier works |

## Setup

### 1. Create a Supabase project

Create a project in [Supabase Dashboard](https://supabase.com/dashboard), then note:
- **Project URL**: `https://<project-ref>.supabase.co`
- **Anon Key**: Project Settings → API Keys → Legacy API Keys → `anon`

### 2. Create a LiveKit Cloud project

Create a project in [LiveKit Cloud](https://cloud.livekit.io), then note:
- **LiveKit URL**
- **API Key**
- **API Secret**

### 3. Create a shared SimCast user

Use the same Supabase user account for:
- the macOS app
- the web dashboard

If you want the simplest setup, disable required email confirmation first:
1. Supabase Dashboard → Authentication → Sign In / Providers
2. Disable **Confirm email**
3. Create a user in Authentication → Users

### 4. Apply the database schema

Run these SQL files in your Supabase SQL Editor, in order:

1. [`apps/supabase/migrations/20260322_create_media_library_tables.sql`](apps/supabase/migrations/20260322_create_media_library_tables.sql)
2. [`apps/supabase/migrations/20260325_configure_media_storage_and_realtime.sql`](apps/supabase/migrations/20260325_configure_media_storage_and_realtime.sql)

This creates:
- `screenshots`
- `recordings`
- media `status` / `error_message` columns
- storage buckets and policies
- realtime publication for screenshots and recordings

Important:
- the app no longer relies on `stream_commands` or `streams`
- if you skip the latest media schema, uploads can still work through compatibility fallback, but pending placeholders will not

### 5. Deploy the `livekit-token` edge function

Deploy [`apps/supabase/functions/livekit-token/index.ts`](apps/supabase/functions/livekit-token/index.ts) as `livekit-token`.

After deploying:
- disable **Verify JWT with legacy secret** in the function settings
- add these Edge Function secrets:

| Secret | Value |
|--------|-------|
| `LIVEKIT_URL` | your LiveKit websocket URL |
| `LIVEKIT_API_KEY` | your LiveKit API key |
| `LIVEKIT_API_SECRET` | your LiveKit API secret |

The function derives room identity from the authenticated user and simulator UDID.

### 6. Deploy the web dashboard

Recommended path: deploy `apps/web` to Vercel.

Required environment variables:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

After deployment, add your app URL to:
- Supabase Dashboard → Authentication → URL Configuration → Redirect URLs

### 7. Verify the flow

1. Open the web dashboard and sign in
2. Open the macOS app and sign in with the same account
3. Boot a simulator
4. Confirm it appears in the simulator grid
5. Start the stream from the dashboard
6. Allow Screen Recording / Accessibility permissions on macOS if prompted
7. Interact with the stream, then try screenshot and recording capture

## Repository Structure

```text
simcast/
├── apps/
│   ├── macos/              # SwiftUI publisher + operator console
│   ├── web/                # Next.js 16 dashboard + LiveKit viewer
│   └── supabase/           # SQL migrations + edge function
├── .github/workflows/      # release pipeline
├── CLAUDE.md               # project architecture guide
└── README.md
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| macOS App | Swift 6, SwiftUI, ScreenCaptureKit, VideoToolbox |
| Web Dashboard | Next.js 16, TypeScript, React, Tailwind CSS v4 |
| Streaming | LiveKit (video only) |
| Backend | Supabase Auth, Realtime, Storage, Edge Functions |
| Input Injection | [axe](https://github.com/cameroncooke/AXe) CLI + `simctl` |

## Troubleshooting

<details>
<summary><b>No simulators appear in the dashboard</b></summary>

Make sure:
- the macOS app is open and signed in
- at least one simulator is booted
- both apps use the same Supabase account

Useful check:
```bash
xcrun simctl list devices booted
```
</details>

<details>
<summary><b>Stream does not start</b></summary>

Check:
- macOS Screen Recording permission
- `livekit-token` edge function deployment
- LiveKit secrets in Supabase Edge Function settings
- same user account on web and macOS
</details>

<details>
<summary><b>Realtime says offline or reconnecting</b></summary>

The dashboard depends on live mac presence. If the mac app restarts or loses realtime briefly:
1. wait for the realtime badge to recover
2. confirm the simulator list refreshes from mac presence
3. retry the command

The system does not intentionally queue commands for later execution.
</details>

<details>
<summary><b>Screenshot or recording works, but no pending placeholder appears</b></summary>

Apply the latest media migrations:
- `20260322_create_media_library_tables.sql`
- `20260325_configure_media_storage_and_realtime.sql`

Without those columns, the mac app uses a compatibility fallback and media uploads still work, but the full `pending → ready / failed` lifecycle is not available.
</details>

<details>
<summary><b>Tap, scroll, or typing does not work</b></summary>

Check:
- macOS Accessibility permission for SimCast
- `axe` CLI is installed and available
- the simulator window is present and interactable
</details>

## License

MIT — see `LICENSE`.
