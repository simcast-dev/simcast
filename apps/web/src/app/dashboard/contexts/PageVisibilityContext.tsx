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
    } else {
      setIsPaused(false);
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
