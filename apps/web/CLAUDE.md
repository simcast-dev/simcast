# SimCast Web App

Next.js 16 dashboard for viewing and controlling SimCast simulator streams in realtime.

## Tech Stack

- **Next.js 16** with App Router and TypeScript strict mode
- **Tailwind CSS v4**
- **Supabase** for auth, Realtime, Storage signed URLs, and edge function invocation
- **LiveKit** for stream playback only
- **npm** as the package manager

## Structure

```text
src/
├── app/
│   ├── dashboard/
│   │   ├── DashboardClient.tsx
│   │   ├── StreamGrid.tsx
│   │   ├── SimulatorViewer.tsx
│   │   ├── ui.tsx
│   │   ├── components/
│   │   │   ├── ScreenView.tsx
│   │   │   ├── LogDrawer.tsx
│   │   │   ├── PushNotificationModal.tsx
│   │   │   └── ThemeSelector.tsx
│   │   ├── contexts/
│   │   │   └── PageVisibilityContext.tsx
│   │   ├── gallery/
│   │   │   ├── ScreenshotGallery.tsx
│   │   │   ├── RecordingGallery.tsx
│   │   │   ├── useScreenshots.ts
│   │   │   └── useRecordings.ts
│   │   └── hooks/
│   │       ├── useReconnectKey.ts
│   │       ├── useUserRealtimeChannel.ts
│   │       ├── useLiveKitConnection.ts
│   │       ├── useLogStream.ts
│   │       └── useVideoStats.ts
│   └── login/
├── lib/
│   ├── realtime-protocol.ts
│   ├── realtime.ts
│   ├── debug.ts
│   └── supabase/
└── proxy.ts
```

## Realtime Model

- The dashboard joins one shared Realtime channel: `user:{userId}`.
- It tracks lightweight **web presence** for command validation and session identity.
- It listens to authoritative **mac presence** for:
  - simulator inventory
  - `streaming_udids[]`
  - `presence_version` freshness
- It sends every simulator action as a Broadcast `command`.
- It expects:
  - `command_ack` within 5 seconds
  - `command_result` for explicit success/failure
  - mac presence confirmation for stream `start` / `stop`

## Important Hooks

### `useUserRealtimeChannel`
Owns the shared `user:{userId}` channel:
- tracks web presence
- derives simulator cards from mac presence
- manages pending commands and ack/result timeouts
- exposes `syncState: syncing | live | stale | offline`
- routes realtime logs to the dashboard log store
- treats ack/result/log traffic as liveness signals for the mac app

### `useReconnectKey`
Central reconnect coordinator:
- registers active realtime channels
- requests reconnects when channels error/close/time out
- forces channel recreation after focus / visibility restoration when needed

### `useLiveKitConnection`
- fetches viewer tokens via the `livekit-token` edge function using the simulator UDID
- only connects when a selected simulator is actually streaming
- clears viewer state immediately when the stream stops to avoid LiveKit teardown races

### `useLogStream`
- keeps a capped in-memory log history
- stores simulator UDID with each log entry
- lets the UI filter by the currently watched simulator without destroying history

## Command Semantics

All commands go through Supabase Broadcast on `user:{userId}`.

| Kind | Trigger | Completion |
|------|---------|------------|
| `start`, `stop` | `StreamGrid` | `command_ack` + `command_result` + mac presence update |
| `tap`, `swipe`, `button`, `gesture`, `text`, `push`, `open_url`, `clear_logs` | `ScreenView` / dashboard controls | explicit `command_result` |
| `app_list` | Push modal bootstrap | `command_result` with app payload |
| `screenshot`, `start_recording`, `stop_recording` | Media controls | explicit `command_result`; gallery continues through DB media state |

## Media Gallery

- `screenshots` and `recordings` are subscribed via Postgres realtime `INSERT` + `UPDATE`
- gallery items can be:
  - `pending`: placeholder card
  - `ready`: signed URL requested and rendered
  - `failed`: failed placeholder with error state
- the gallery also normalizes legacy rows that do not have `status` / `error_message` yet, treating them as ready

## UI Notes

- The dashboard has a realtime badge in the header and stale/offline states in the simulator grid.
- `StreamGrid` guards against overlapping per-simulator start/stop actions and only mutates pending state when it actually changes.
- `ScreenView` resets simulator-scoped local state on UDID changes to avoid stale recording/app-list UI.
- `ScreenView` also guards high-frequency pointer and stats updates to avoid React update-depth issues.
- The log drawer preserves history across simulator switches and filters the visible log list by the currently watched simulator.
- The page pause model is simple:
  - hidden tab → pause video subscription/rendering
  - visible tab → auto-resume

## Auth + Routing

- `proxy.ts` protects all non-login routes.
- Browser auth uses `@supabase/ssr`.
- Sign-out clears the session and redirects back to `/login`.

## Verification

```bash
cd apps/web
npx tsc --noEmit
```

Use `npm run build` as an additional check when the environment can fetch fonts and external assets normally.
