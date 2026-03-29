# Stream Pause on Browser Tab Switch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pause video streams when the browser tab becomes hidden, showing a "Stream Paused" overlay with a play button to resume.

**Architecture:** A `usePageVisibility` hook detects browser tab visibility. A `PageVisibilityContext` provider manages `isPaused` state (set on hide, cleared on explicit resume). ScreenView reads this context to pause video and show the overlay.

**Tech Stack:** React context, Page Visibility API, existing CSS custom properties

---

### Task 1: Create `usePageVisibility` hook

**Files:**
- Create: `apps/web/src/app/dashboard/hooks/usePageVisibility.ts`

- [ ] **Step 1: Create the hook**

```typescript
"use client";

import { useEffect, useState } from "react";

export function usePageVisibility(): boolean {
  const [isVisible, setIsVisible] = useState(() =>
    typeof document !== "undefined" ? !document.hidden : true
  );

  useEffect(() => {
    const handler = () => setIsVisible(!document.hidden);
    document.addEventListener("visibilitychange", handler);
    return () => document.removeEventListener("visibilitychange", handler);
  }, []);

  return isVisible;
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/app/dashboard/hooks/usePageVisibility.ts
git commit -m "feat(web): add usePageVisibility hook"
```

---

### Task 2: Create `PageVisibilityContext`

**Files:**
- Create: `apps/web/src/app/dashboard/contexts/PageVisibilityContext.tsx`

- [ ] **Step 1: Create context provider and consumer hook**

```tsx
"use client";

import React, { createContext, useContext, useEffect, useState, useCallback } from "react";
import { usePageVisibility } from "../hooks/usePageVisibility";

type PagePauseState = {
  isPaused: boolean;
  resume: () => void;
};

const PageVisibilityContext = createContext<PagePauseState>({
  isPaused: false,
  resume: () => {},
});

export function PageVisibilityProvider({ children }: { children: React.ReactNode }) {
  const isVisible = usePageVisibility();
  const [isPaused, setIsPaused] = useState(false);

  useEffect(() => {
    if (!isVisible) {
      setIsPaused(true);
    }
  }, [isVisible]);

  const resume = useCallback(() => setIsPaused(false), []);

  return (
    <PageVisibilityContext.Provider value={{ isPaused, resume }}>
      {children}
    </PageVisibilityContext.Provider>
  );
}

export function usePagePause(): PagePauseState {
  return useContext(PageVisibilityContext);
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/app/dashboard/contexts/PageVisibilityContext.tsx
git commit -m "feat(web): add PageVisibilityContext with isPaused state and resume"
```

---

### Task 3: Wrap dashboard in `PageVisibilityProvider` and remove conflicting effect

**Files:**
- Modify: `apps/web/src/app/dashboard/DashboardClient.tsx`

- [ ] **Step 1: Add import**

Add to imports at top of `DashboardClient.tsx`:

```typescript
import { PageVisibilityProvider } from "./contexts/PageVisibilityContext";
```

- [ ] **Step 2: Remove the existing video pause/play `useEffect`**

Remove the `useEffect` at lines 28-36 that does `document.querySelectorAll("video")` and calls `play()`/`pause()` based on `activeView`. This is being replaced by ScreenView's own effect that respects both `isActive` and `isPagePaused`.

```typescript
// DELETE this entire block:
useEffect(() => {
  const videos = document.querySelectorAll("video");
  if (activeView === "stream") {
    videos.forEach(v => v.play().catch(() => {}));
  } else {
    videos.forEach(v => v.pause());
  }
}, [activeView]);
```

- [ ] **Step 3: Wrap the root div's children**

Wrap the contents of the root `<div>` (background blooms, header, main content, footer) with `<PageVisibilityProvider>`:

```tsx
// In the return statement, wrap inside the root div:
<PageVisibilityProvider>
  {/* Background blooms */}
  ...existing content...
  {/* Footer */}
  ...existing footer...
</PageVisibilityProvider>
```

The root `<div>` with `flex flex-col` and `height: 100vh` stays as the outermost element. `PageVisibilityProvider` wraps everything inside it.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/app/dashboard/DashboardClient.tsx
git commit -m "feat(web): wrap dashboard in PageVisibilityProvider"
```

---

### Task 4: Add pause overlay to ScreenView

**Files:**
- Modify: `apps/web/src/app/dashboard/components/ScreenView.tsx:195` (function signature, imports)
- Modify: `apps/web/src/app/dashboard/components/ScreenView.tsx:524-540` (existing pause overlay)

- [ ] **Step 1: Add import for `usePagePause`**

Add to imports at top of `ScreenView.tsx`:

```typescript
import { usePagePause } from "../contexts/PageVisibilityContext";
```

- [ ] **Step 2: Use the hook inside ScreenView**

Inside the `ScreenView` function body (around line 195, after existing state declarations), add:

```typescript
const { isPaused: isPagePaused, resume } = usePagePause();
```

- [ ] **Step 3: Add video pause/play effect**

Add a `useEffect` that pauses/plays the video element based on both `isActive` and `isPagePaused`:

```typescript
useEffect(() => {
  if (!containerRef.current) return;
  const video = containerRef.current.querySelector("video");
  if (!video) return;
  if (isPagePaused || !isActive) {
    video.pause();
  } else {
    video.play().catch(() => {});
  }
}, [isPagePaused, isActive]);
```

- [ ] **Step 4: Replace the existing pause overlay**

Replace the existing pause overlay block (lines 524-540, the `{!isActive && (...)}` block) with a combined overlay that handles both pause states:

```tsx
{(!isActive || isPagePaused) && (
  <div
    style={{
      position: "absolute",
      inset: 0,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      gap: 16,
      background: "#0a0a0a",
      zIndex: 10,
    }}
  >
    {isPagePaused ? (
      <>
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#555" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
          <line x1="8" y1="21" x2="16" y2="21" />
          <line x1="12" y1="17" x2="12" y2="21" />
        </svg>
        <span style={{ color: "#888", fontSize: 15, fontWeight: 500 }}>
          Stream Paused
        </span>
        <button
          onClick={resume}
          aria-label="Resume stream"
          style={{
            marginTop: 4,
            width: 44,
            height: 44,
            borderRadius: "50%",
            background: "rgba(255,255,255,0.1)",
            border: "none",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            cursor: "pointer",
          }}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="#fff">
            <polygon points="6,3 20,12 6,21" />
          </svg>
        </button>
        <span style={{ color: "#555", fontSize: 12 }}>
          Click to resume
        </span>
      </>
    ) : (
      <p style={{ color: "var(--text-2)", fontSize: "var(--font-size-sm)", letterSpacing: "var(--tracking-normal)" }}>
        Stream paused. Resuming…
      </p>
    )}
  </div>
)}
```

This shows the "Play to Resume" overlay when the page is hidden, and falls back to the existing "Resuming…" text when only the internal tab is switched.

- [ ] **Step 5: Verify the build**

```bash
cd apps/web && npm run build
```

Expected: no TypeScript errors.

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/app/dashboard/components/ScreenView.tsx
git commit -m "feat(web): pause stream on browser tab switch with resume overlay"
```
