"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import { usePageVisibility } from "../hooks/usePageVisibility";

type PagePauseState = {
  isPaused: boolean;
};

const PageVisibilityContext = createContext<PagePauseState>({
  isPaused: false,
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

  return (
    <PageVisibilityContext.Provider value={{ isPaused }}>
      {children}
    </PageVisibilityContext.Provider>
  );
}

export function usePagePause(): PagePauseState {
  return useContext(PageVisibilityContext);
}
