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
