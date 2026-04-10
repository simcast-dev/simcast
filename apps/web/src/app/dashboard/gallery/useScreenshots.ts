"use client";

import { useState, useEffect, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";
import { logDebug, logDebugError } from "@/lib/debug";
import { shouldReconnectForStatus, type ChannelHealth } from "@/lib/realtime";

export type ScreenshotStatus = "pending" | "ready" | "failed";

export type Screenshot = {
  id: string;
  storage_path: string;
  simulator_name: string | null;
  simulator_udid: string | null;
  width: number | null;
  height: number | null;
  created_at: string;
  status: ScreenshotStatus;
  error_message: string | null;
  signedUrl?: string;
};

function normalizeScreenshot(item: Partial<Screenshot> & Pick<Screenshot, "id" | "storage_path" | "created_at">): Screenshot {
  return {
    id: item.id,
    storage_path: item.storage_path,
    simulator_name: item.simulator_name ?? null,
    simulator_udid: item.simulator_udid ?? null,
    width: item.width ?? null,
    height: item.height ?? null,
    created_at: item.created_at,
    status: item.status ?? "ready",
    error_message: item.error_message ?? null,
  };
}

function mergeById(items: Screenshot[], item: Screenshot) {
  const next = new Map(items.map((existing) => [existing.id, existing]));
  next.set(item.id, item);
  return Array.from(next.values()).sort((a, b) => b.created_at.localeCompare(a.created_at));
}

async function withSignedUrl(supabase: ReturnType<typeof createClient>, screenshot: Screenshot): Promise<Screenshot> {
  if (screenshot.status !== "ready") {
    return { ...screenshot, signedUrl: undefined };
  }

  const { data } = await supabase.storage
    .from("screenshots")
    .createSignedUrl(screenshot.storage_path, 3600);

  return { ...screenshot, signedUrl: data?.signedUrl };
}

export function useScreenshots(userId: string, onNewItem?: (item: Screenshot) => void, channelHealth?: ChannelHealth) {
  const [screenshots, setScreenshots] = useState<Screenshot[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);

  const PAGE_SIZE = 24;

  const fetchScreenshots = useCallback(async (offset = 0) => {
    const supabase = createClient();
    const { data, error: fetchError } = await supabase
      .from("screenshots")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .range(offset, offset + PAGE_SIZE - 1);

    if (fetchError) {
      setError(fetchError.message);
      setLoading(false);
      return;
    }

    if (data) {
      const withUrls = await Promise.all(data.map((item) => withSignedUrl(supabase, normalizeScreenshot(item as Screenshot))));
      if (offset === 0) {
        setScreenshots(withUrls);
      } else {
        setScreenshots((prev) => [...prev, ...withUrls]);
      }
      setHasMore(data.length === PAGE_SIZE);
    }
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    let cancelled = false;
    void fetchScreenshots();

    const supabase = createClient();
    const channel = supabase.channel("screenshots-realtime");
    channelHealth?.register(channel);
    channel
      .on(
        "postgres_changes" as never,
        { event: "INSERT", schema: "public", table: "screenshots", filter: `user_id=eq.${userId}` },
        async (payload: { new: Screenshot }) => {
          const item = await withSignedUrl(supabase, normalizeScreenshot(payload.new));
          if (cancelled) return;
          setScreenshots((prev) => mergeById(prev, item));
          if (item.status === "ready") {
            onNewItem?.(item);
          }
        },
      )
      .on(
        "postgres_changes" as never,
        { event: "UPDATE", schema: "public", table: "screenshots", filter: `user_id=eq.${userId}` },
        async (payload: { new: Screenshot }) => {
          const item = await withSignedUrl(supabase, normalizeScreenshot(payload.new));
          if (cancelled) return;
          setScreenshots((prev) => {
            const existing = prev.find((entry) => entry.id === item.id);
            if (item.status === "ready" && existing?.status !== "ready") {
              onNewItem?.(item);
            }
            return mergeById(prev, item);
          });
        },
      )
      .subscribe((status, err) => {
        if (err) {
          logDebugError("gallery", "screenshots channel reported an error", err, {
            userId,
            status,
            topic: channel.topic,
          });
          channelHealth?.requestReconnect("screenshots-channel-error", {
            userId,
            status,
            topic: channel.topic,
          });
          return;
        }

        logDebug("gallery", "screenshots channel status changed", {
          userId,
          status,
          topic: channel.topic,
        });
        if (shouldReconnectForStatus(status)) {
          channelHealth?.requestReconnect("screenshots-channel-status", {
            userId,
            status,
            topic: channel.topic,
          });
        }
      });

    return () => {
      cancelled = true;
      channelHealth?.unregister(channel);
      void channel.unsubscribe();
      supabase.removeChannel(channel);
    };
  }, [fetchScreenshots, onNewItem, userId, channelHealth?.reconnectKey]);

  const loadMore = useCallback(() => {
    void fetchScreenshots(screenshots.length);
  }, [fetchScreenshots, screenshots.length]);

  const deleteScreenshot = useCallback(async (id: string, storagePath: string, status: ScreenshotStatus) => {
    const supabase = createClient();
    if (status === "ready") {
      await supabase.storage.from("screenshots").remove([storagePath]);
    }
    await supabase.from("screenshots").delete().eq("id", id);
    setScreenshots((prev) => prev.filter((item) => item.id !== id));
  }, []);

  const deleteMultiple = useCallback(async (items: Array<{ id: string; storagePath: string; status: ScreenshotStatus }>) => {
    const supabase = createClient();
    const readyPaths = items.filter((item) => item.status === "ready").map((item) => item.storagePath);
    const ids = items.map((item) => item.id);
    if (readyPaths.length > 0) {
      await supabase.storage.from("screenshots").remove(readyPaths);
    }
    await supabase.from("screenshots").delete().in("id", ids);
    setScreenshots((prev) => prev.filter((item) => !ids.includes(item.id)));
  }, []);

  const refresh = useCallback(() => {
    setLoading(true);
    setError(null);
    setScreenshots([]);
    void fetchScreenshots();
  }, [fetchScreenshots]);

  return { screenshots, loading, error, hasMore, loadMore, deleteScreenshot, deleteMultiple, refresh };
}
