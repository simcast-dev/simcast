# Per-Simulator Channel Isolation

## Problem

All Supabase Realtime communication (presence, logs, clear_logs, stream_commands) flows through a single `user:{userId}` channel. When multiple simulators stream simultaneously, logs from all simulators are interleaved with no way to attribute or filter by simulator. Clear logs affects all simulators at once.

## Design

### Channel Topology

**Before:**
```
user:{userId}  →  presence, stream_commands, log broadcast, clear_logs broadcast
```

**After:**
```
user:{userId}        →  presence (simulator list + streamingUdids), stream_commands
simulator:{udid}     →  log broadcast, clear_logs broadcast
```

- The user channel remains the "directory" — it lists available simulators and their streaming state.
- Per-simulator channels (`simulator:{udid}`) carry logs and clear_logs for that specific simulator.
- Stream commands stay on the user channel (they already carry a UDID for routing, and <=5 simulators makes N listeners unnecessary overhead).

### macOS Changes

**SyncService:**
- New `simulatorChannels: [String: RealtimeChannelV2]` dictionary.
- `updateSimulators()` manages simulator channel lifecycle: subscribes to new channels, unsubscribes from removed ones.
- `broadcastLog(category:message:udid:)` gains a required `udid` parameter. Routes the broadcast to `simulator:{udid}` channel.
- Per-simulator `clear_logs` listeners (one per channel) replace the single listener on the user channel. Each triggers `onClearLogsReceived`.
- `stop()` unsubscribes all simulator channels.

**AppLogger:**
- `log(_ category:, _ message:, udid: String? = nil)` gains an optional `udid` parameter.
- When `udid` is provided, passes it to `SyncService.broadcastLog`. When nil, the log is not broadcast to web (stays local on macOS).

**Call site updates:**
- `SCKManager` — all calls have `udid` in scope, pass it through.
- `LiveKitProvider` — stores its `roomName` (which equals the UDID) and passes it.
- `SimulatorInputService` — all methods already receive `udid`, pass it to logger.
- `StreamReadyView` — command handler has `cmd.udid`, pass it.
- `SyncService` internal logs (channel subscribed, presence synced) — app-level, no UDID, not broadcast.

### Web Changes

**New `useSimulatorChannel(udid, onLogReceived)` hook:**
- Subscribes to `simulator:{udid}` channel when `udid` is non-null.
- Listens for `log` broadcast events, calls `onLogReceived`.
- Returns a `sendClearLogs()` function for the web to broadcast `clear_logs` on that simulator's channel.
- Unsubscribes when `udid` changes or component unmounts.

**`usePresenceSubscription`:**
- Remove the `log` broadcast listener and `onLogReceived` callback. Presence hook only handles presence.

**`DashboardClient`:**
- Uses `useSimulatorChannel(watchingUdid, addLog)` to receive logs scoped to the watched simulator.
- `clearLogs` clears local state and sends `clear_logs` on the simulator channel.
- Logs reset when switching between simulators (new channel = fresh log stream).

**`StreamGrid`:**
- Remove `onLogReceived` and `onClearLogsChannel` props (no longer routes through user channel).

### Behavior

- Watching simulator A shows only simulator A's logs.
- Switching to simulator B: subscribe to B's channel, see B's logs from that point forward.
- Clear logs on web clears the web's log display and broadcasts `clear_logs` on the current simulator's channel, which clears the macOS log panel.
- macOS log panel remains a single unified view of all logs (per-simulator isolation is web-facing).
