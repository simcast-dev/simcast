"use client";

type DebugScope = "presence" | "command" | "reconnect" | "simulator-channel" | "gallery";

export function logDebug(scope: DebugScope, message: string, details?: Record<string, unknown>) {
  const timestamp = new Date().toISOString();

  if (details && Object.keys(details).length > 0) {
    console.info(`[simcast:web][${scope}] ${timestamp} ${message}`, details);
    return;
  }

  console.info(`[simcast:web][${scope}] ${timestamp} ${message}`);
}

export function logDebugError(scope: DebugScope, message: string, error: unknown, details?: Record<string, unknown>) {
  const timestamp = new Date().toISOString();
  const payload = {
    ...details,
    error: error instanceof Error ? error.message : String(error),
  };
  console.error(`[simcast:web][${scope}] ${timestamp} ${message}`, payload);
}
