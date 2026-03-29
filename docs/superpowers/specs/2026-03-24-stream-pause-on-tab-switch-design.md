# Stream Pause on Browser Tab Switch

Pause active video streams when the user navigates away from the browser tab, showing a placeholder overlay with a manual resume action.

## Context

The web dashboard already pauses video elements when switching between internal tabs (stream/screenshots/recordings) in `DashboardClient`. However, there is no handling for browser-level visibility changes — when the user switches to another browser tab or minimizes the window, streams continue consuming bandwidth and resources in the background.

## Requirements

- Detect browser tab visibility changes using the Page Visibility API
- When the tab becomes hidden: pause all active video streams and show a placeholder overlay
- When the tab becomes visible again: keep streams paused until the user explicitly resumes
- Resume is global — clicking any play button resumes all viewers at once
- LiveKit connection stays alive — only video playback is paused
- Applies to all ScreenView instances (single viewer and grid)

## Architecture

### New Files

**`apps/web/src/app/dashboard/hooks/usePageVisibility.ts`**

Thin hook wrapping the Page Visibility API:
- Listens to `document.visibilitychange`
- Returns `isPageVisible: boolean`
- Initializes from `document.hidden` on mount (handles tabs opened in background)
- Cleans up listener on unmount

**`apps/web/src/app/dashboard/contexts/PageVisibilityContext.tsx`**

React context provider + consumer hook:
- Provider holds `isPaused: boolean` state
- When `isPageVisible` transitions to `false` → sets `isPaused = true`
- When `isPageVisible` transitions to `true` → no-op (waits for explicit resume)
- Exposes `resume()` function that sets `isPaused = false`
- Consumer hook: `usePagePause()` returns `{ isPaused, resume }`

### Integration Points

**`DashboardClient.tsx`**
- Wrap dashboard children with `<PageVisibilityProvider>`

**`ScreenView.tsx`**
- Read `{ isPaused, resume }` from `usePagePause()`
- When `isPaused` is `true`:
  - Pause the video element via DOM query on the container ref (same pattern as existing `DashboardClient` logic using `querySelectorAll("video")`, but scoped to the ScreenView container)
  - Render the pause overlay on top of the video
- When `isPaused` becomes `false`:
  - Play the video element (only if `isActive` is also `true` — guards against conflict with internal-tab pause)
  - Remove the overlay

### Interaction with Existing Pause Logic

The existing internal-tab pause logic in `DashboardClient` (which pauses videos when `activeView !== "stream"`) operates independently. The two pause mechanisms coexist:
- Internal tab switch → existing logic pauses/resumes videos directly
- Browser tab switch → new context sets `isPaused`, ScreenView reacts

**Guard rule:** ScreenView should only call `video.play()` when BOTH `isActive` (internal tab is on "stream") AND `isPaused` is `false`. This prevents the resume action from unpausing a video that should be hidden by the internal tab state.

If both are active (user switches internal tab while browser tab is hidden), the video stays paused. Resume from page visibility pause only affects the page-visibility state, not the internal tab state.

### StreamGrid

StreamGrid renders simulator presence cards but does not contain video elements — it is not affected by this feature. Only ScreenView instances render `<VideoTrack>`.

## Overlay Design (Style C — Play to Resume)

Visual composition centered vertically and horizontally, using existing theme tokens where available and falling back to static values for the dark stream container:

1. **Monitor icon** — SVG, muted stroke, 48×48
2. **"Stream Paused"** — muted text, 15px, medium weight
3. **Play button** — 44×44 circular container with subtle background, white filled play triangle SVG inside. This is the resume action — clicking it calls `resume()`. Must have `aria-label="Resume stream"` and be keyboard-accessible (focusable, activatable via Enter/Space).
4. **"Click to resume"** — hint text below the play button, smallest size

The overlay is absolutely positioned over the video container with `inset: 0`, using flexbox centering.

## Scope Boundaries

- **No LiveKit disconnect/reconnect** — the WebRTC connection stays alive, only video element playback is paused
- **No auto-resume** — strictly manual via the play button
- **No settings or preferences** — always active, no opt-out
- **Resume button is non-functional beyond setting state** — no additional side effects planned for now
- **Dashboard only** — does not apply to the future `/watch` guest viewer route (can be extended later)
- **No per-viewer granularity** — pause and resume are global across all active viewers
