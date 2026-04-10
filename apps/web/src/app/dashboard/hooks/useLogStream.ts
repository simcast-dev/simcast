"use client";

import { useState, useCallback } from "react";

export type LogCategory = "stream" | "livekit" | "presence" | "command" | "error";

export type LogEntry = {
  id: string;
  category: LogCategory;
  message: string;
  timestamp: string;
  udid?: string | null;
};

const LOG_CAP = 500;

let logCounter = 0;

export function useLogStream() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [errorCount, setErrorCount] = useState(0);

  const addLog = useCallback((payload: { category: string; message: string; timestamp: string; udid?: string | null }) => {
    const entry: LogEntry = {
      id: `log-${++logCounter}`,
      category: payload.category as LogCategory,
      message: payload.message,
      timestamp: payload.timestamp,
      udid: payload.udid ?? null,
    };
    setLogs(prev => {
      const next = [...prev, entry];
      return next.length > LOG_CAP ? next.slice(next.length - LOG_CAP) : next;
    });
    if (payload.category === "error") {
      setErrorCount(prev => prev + 1);
    }
  }, []);

  const clearLogs = useCallback(() => {
    setLogs([]);
    setErrorCount(0);
  }, []);

  return { logs, errorCount, addLog, clearLogs };
}
