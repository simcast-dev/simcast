"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export function useLiveKitConnection(
  udid: string | null,
  userId: string,
  enabled: boolean,
  retryKey: number = 0,
) {
  const [connection, setConnection] = useState<{ token: string; url: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!udid || !enabled) {
      setConnection(null);
      setError(null);
      return;
    }

    // Prevents setting state on unmounted component when user switches simulators quickly
    let cancelled = false;
    setConnection(null);
    setError(null);

    const supabase = createClient();
    supabase.functions
      .invoke("livekit-token", {
        body: {
          udid,
          room_name: `user:${userId}:sim:${udid}`,
          participant_identity: `web-viewer-${userId}-${crypto.randomUUID().slice(0, 8)}`,
          // Web viewers only consume video; macOS is the sole publisher
          can_publish: false,
        },
      })
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) {
          setError(error.message);
        } else if (data) {
          setConnection({ token: data.token, url: data.livekit_url });
        } else {
          setError("No data returned from token endpoint");
        }
      })
      .catch((err) => {
        if (cancelled) return;
        setError(err?.message ?? String(err));
      });

    return () => { cancelled = true; };
  }, [udid, enabled, retryKey, userId]);

  return { connection, error };
}
