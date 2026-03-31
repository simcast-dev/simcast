<p align="center">
  <img src="apps/macos/release/SimCast-iOS-Default-1024x1024@1x.png" alt="SimCast" width="128" height="128" />
</p>

<h3 align="center">Stream iOS Simulator to the browser over WebRTC.</h3>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-macOS_15.6+-lightgrey.svg" alt="Platform: macOS 15.6+">
  <img src="https://img.shields.io/badge/Swift-6-orange.svg" alt="Swift 6">
  <img src="https://img.shields.io/badge/Next.js-16-black.svg" alt="Next.js 16">
  <a href="https://simcast.dev"><img src="https://img.shields.io/badge/web-simcast.dev-7C3AED.svg" alt="simcast.dev"></a>
</p>

<!-- <p align="center">
  <img src="docs/assets/demo.gif" alt="SimCast demo — macOS capturing a simulator, web dashboard viewing the stream and tapping remotely" width="800" />
</p> -->

---

SimCast captures individual iOS Simulator windows using ScreenCaptureKit, hardware-encodes to H.264 at 60 fps, and streams them to any browser via [LiveKit](https://livekit.io) (WebRTC).

A web dashboard lets you start and stop streams, interact with the simulator remotely - tap, scroll, type, press hardware buttons - view real-time logs, and capture screenshots and recordings.

Stream commands and presence are coordinated in real time through [Supabase Realtime](https://supabase.com/realtime) (WebSockets), and screenshots and recordings are stored in [Supabase Storage](https://supabase.com/storage).

No Xcode required on the viewer side.

## Features

**Stream any simulator, instantly**
- Captures individual Simulator windows --- not the whole screen, just what matters
- Hardware H.264 encoding via VideoToolbox at 8 Mbps, 60 fps
- Sub-second latency over WebRTC. Works behind NATs, no port forwarding needed
- Run multiple simulators at once --- each gets its own stream

**Touch it like it's real**
- Tap anywhere on the stream --- coordinates map straight to the simulator
- Tap by accessibility label --- type "Safari" and hit it without aiming
- Long-press, scroll in any direction, swipe from edges for navigation gestures
- Freeform swipe --- drag across the stream to draw custom gestures
- Type text directly into whatever field has focus
- Press Home, Lock, or Side Button from the control panel
- Fire push notifications with custom title, body, badge, sound, and silent mode
- Open deep links and custom URL schemes on the simulator

**Capture everything**
- One-click screenshots - instantly available in the gallery
- Start/stop video recordings with a live elapsed timer
- Screenshot and recording gallery - browse, preview, download, bulk delete
- Gallery updates in real time as new captures arrive

**See what's happening**
- Split-pane dashboard - simulator grid on the left, full-size viewer on the right
- Live stream stats - resolution, FPS, bitrate, packet loss, jitter
- Per-simulator log stream with category filters (stream, livekit, presence, command, error)
- Resizable log drawer that stays out of your way until you need it

## Prerequisites

You need a Mac to run the capture app. The web dashboard is deployed to Vercel.

| Requirement | Install |
|------------|---------|
| macOS 15.6+ | --- |
| At least one booted iOS Simulator | `open -a Simulator` |
| [axe](https://github.com/cameroncooke/AXe) CLI (for interactive controls) | `brew install cameroncooke/tap/axe` |
| [Supabase](https://supabase.com) account | Free tier works --- [create one](https://supabase.com/dashboard) |
| [LiveKit Cloud](https://cloud.livekit.io) account | Free tier works --- [sign up](https://cloud.livekit.io) |

## Setup

### 1. Create a Supabase project

Go to [supabase.com/dashboard](https://supabase.com/dashboard) and create a new project. Note down:
- **Project URL** --- `https://<project-ref>.supabase.co` (found on the project overview page)
- **Anon Key** --- go to **Project Settings → API Keys**, select the **Legacy API Keys** tab, and copy the `anon` key

### 2. Create a LiveKit Cloud project

Go to [cloud.livekit.io](https://cloud.livekit.io) and create a new project. Note down:
- **LiveKit URL** --- `wss://your-app.livekit.cloud` (shown at the top of your project dashboard, or in **Settings → Keys**)
- **API Key** and **API Secret** --- go to **Settings → Keys**, select an API key, and click to reveal its secret

### 3. Disable email confirmation and create a user

By default, Supabase requires email verification on sign-up. Since SimCast doesn't need it:

1. Go to Supabase Dashboard → **Authentication** → **Sign In / Providers**
2. Find the **Sign In / Providers** provider section
3. In the **User Signups** area, uncheck **Confirm email**
4. Click **Save Changes**

Then create a user that will be used to sign in on both the macOS app and the web dashboard:

1. Go to **Authentication** → **Users**
2. Click **Add User** → **Create New User**
3. Enter an email and password and click **Create User**

### 4. Set up the database

Open your Supabase project dashboard and go to **SQL Editor**. Run the following two scripts in order:

**Script 1** --- paste the contents of [`apps/supabase/migrations/20260322_create_screenshots_and_recordings.sql`](apps/supabase/migrations/20260322_create_screenshots_and_recordings.sql) and click **Run**.

This creates the `screenshots` and `recordings` tables with row-level security policies and indexes.

**Script 2** --- paste the contents of [`apps/supabase/migrations/20260325_create_stream_commands_and_storage.sql`](apps/supabase/migrations/20260325_create_stream_commands_and_storage.sql) and click **Run**.

This creates the `stream_commands` and `streams` tables, `screenshots` and `recordings` storage buckets with per-user RLS policies, and enables Realtime for `stream_commands`, `screenshots`, and `recordings`.

> Run these in order --- the second script builds on the first.

After running both scripts, verify:
- **Storage** → confirm `screenshots` and `recordings` buckets exist

### 5. Deploy edge functions

SimCast uses a Supabase Edge Function to issue LiveKit tokens. Deploy it from the Supabase Dashboard:

1. Go to **Edge Functions** in your project dashboard
2. Click **Create a new function**
3. Name it **`livekit-token`**
4. Replace the default code with the contents of [`apps/supabase/functions/livekit-token/index.ts`](apps/supabase/functions/livekit-token/index.ts)
5. Click **Deploy**
6. After deploying, go to the function's **Settings** and disable **Verify JWT with legacy secret** --- the function handles authentication in code via `supabase.auth.getUser()`, and the legacy JWT gateway check will reject requests on projects using the new signing keys

> The function name must match exactly: `livekit-token`.

### 6. Set edge function secrets

Go to **Project Settings → Edge Functions** in the Supabase Dashboard and add these secrets:

| Secret | Value |
|--------|-------|
| `LIVEKIT_URL` | `wss://your-app.livekit.cloud` |
| `LIVEKIT_API_KEY` | Your LiveKit API key |
| `LIVEKIT_API_SECRET` | Your LiveKit API secret |

> `SUPABASE_URL` and `SUPABASE_ANON_KEY` are automatically available to edge functions --- you don't need to add those.

### 7. Deploy the web dashboard

**Fork the repository** --- Vercel requires a Pro tier to import from repositories you don't own. Fork [simcast-dev/simcast](https://github.com/simcast-dev/simcast) to your own GitHub account. You can sync your fork later to pull in updates from the upstream repository.

**Import into Vercel:**

1. Go to [vercel.com/new](https://vercel.com/new), select **Import Git Repository**, and choose your forked repository
2. In the **Configure Project** screen, set **Root Directory** to `apps/web` (the web dashboard is not in the repository root)
3. Add the following **Environment Variables**:
   - `NEXT_PUBLIC_SUPABASE_URL` --- your project URL (e.g. `https://abcdefghijkl.supabase.co`)
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` --- your anon key
4. Click **Deploy**

**After deploying**, add your Vercel domain to Supabase's allowed redirect URLs:
- Go to Supabase Dashboard → **Authentication** → **URL Configuration**
- Add `https://your-app.vercel.app` to **Redirect URLs**

### 8. Verify everything works

1. Open your Vercel deployment URL
2. Sign in with the user account you created in step 3
3. Sign in on the macOS app with the same account
4. Boot a simulator (`open -a Simulator`) --- it should appear in the dashboard's stream grid
5. Click **Start Stream** on a simulator card --- on first run, macOS will prompt you to grant **Screen Recording** permission. Allow it and restart the app if needed.
6. The live stream should appear in the viewer pane
7. Try tapping on the stream, typing text, or pressing hardware buttons

> The macOS app must be running for streams to work. Vercel only hosts the web dashboard --- viewers can access it from anywhere, but streaming requires the macOS app to be running on your Mac.

## Repository Structure

```
simcast/
├── apps/
│   ├── macos/              # Swift 6 / SwiftUI — captures Simulator, streams via LiveKit
│   ├── web/                # Next.js 16 — dashboard, stream viewer, interactive controls
│   └── supabase/           # Database migrations, edge functions, config
├── .github/workflows/      # CI/CD — notarized DMG release pipeline
├── CLAUDE.md               # AI assistant project context
└── README.md
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| macOS App | Swift 6, SwiftUI, ScreenCaptureKit, VideoToolbox |
| Web Dashboard | Next.js 16, TypeScript, React 19, Tailwind CSS v4 |
| Streaming | LiveKit (WebRTC), H.264, 8 Mbps / 60 fps |
| Backend | Supabase (Auth, Realtime, Storage, Edge Functions) |
| Input Injection | [axe](https://github.com/cameroncooke/AXe) CLI |

## Troubleshooting

<details>
<summary><b>General: streaming not starting or unexpected errors</b></summary>

1. Quit the macOS app
2. Wait for the simulators to disappear from the web dashboard
3. Reopen the macOS app

This resets presence and stream state cleanly.
</details>

<details>
<summary><b>Black frames or no video</b></summary>

The macOS app needs **Screen Recording** permission. Go to System Settings → Privacy & Security → Screen Recording and make sure SimCast is enabled. Restart the app after granting.
</details>

<details>
<summary><b>Tap, scroll, or text input not working</b></summary>

1. Grant **Accessibility** permission: System Settings → Privacy & Security → Accessibility → enable SimCast
2. Verify `axe` CLI is installed: `/opt/homebrew/bin/axe --version`
3. Restart the app after granting permissions
</details>

<details>
<summary><b>No simulators appear in the dashboard</b></summary>

Make sure at least one simulator is booted:
```bash
xcrun simctl list devices booted
```
If empty, boot one: `open -a Simulator` or `xcrun simctl boot "iPhone 16"`.
</details>

<details>
<summary><b>Stream doesn't start</b></summary>

1. Check that LiveKit secrets are set: Supabase Dashboard → Project Settings → Edge Functions → Secrets
2. Check edge function logs: Supabase Dashboard → Edge Functions → livekit-token → Logs
3. Verify both apps are signed in with the same account
</details>

<details>
<summary><b>CSP or CORS errors in the browser console</b></summary>

Ensure `NEXT_PUBLIC_SUPABASE_URL` in your Vercel environment variables matches your Supabase project URL exactly. The CSP headers are derived from this environment variable.
</details>

<details>
<summary><b>Edge function not working</b></summary>

1. Verify the function name matches exactly: `livekit-token`
2. Make sure the code was pasted completely (no truncation)
3. Check the function's **Logs** tab in Supabase Dashboard → Edge Functions for errors
4. Confirm all three LiveKit secrets are set (see step 6 in Setup)
</details>

## License

MIT --- see LICENSE for details.
