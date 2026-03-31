"use client";

import { useState, useEffect, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";
import type { RealtimeChannel } from "@supabase/supabase-js";


export type Screenshot = {
  id: string;
  storage_path: string;
  simulator_name: string | null;
  simulator_udid: string | null;
  width: number | null;
  height: number | null;
  created_at: string;
  signedUrl?: string;
};

export function useScreenshots(userId: string, onNewItem?: (item: Screenshot) => void, channelHealth?: { reconnectKey: number; register: (ch: RealtimeChannel) => void; unregister: (ch: RealtimeChannel) => void }) {
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
      const withUrls = await Promise.all(
        data.map(async (s: Screenshot) => {
          const { data: urlData } = await supabase.storage
            .from("screenshots")
            .createSignedUrl(s.storage_path, 3600);
          return { ...s, signedUrl: urlData?.signedUrl };
        })
      );

      if (offset === 0) {
        setScreenshots(withUrls);
      } else {
        setScreenshots(prev => [...prev, ...withUrls]);
      }
      setHasMore(data.length === PAGE_SIZE);
    }
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    fetchScreenshots();

    const supabase = createClient();
    const channel = supabase.channel("screenshots-realtime");
    channelHealth?.register(channel);
    channel.on(
        "postgres_changes" as never,
        { event: "INSERT", schema: "public", table: "screenshots", filter: `user_id=eq.${userId}` },
        async (payload: { new: Screenshot }) => {
          const row = payload.new;
          const { data: urlData } = await supabase.storage
            .from("screenshots")
            .createSignedUrl(row.storage_path, 3600);
          const item = { ...row, signedUrl: urlData?.signedUrl };
          setScreenshots(prev => [item, ...prev]);
          onNewItem?.(item);
        }
      )
      .subscribe();

    return () => {
      channelHealth?.unregister(channel);
      supabase.removeChannel(channel);
    };
  }, [fetchScreenshots, userId, channelHealth?.reconnectKey]);

  const loadMore = useCallback(() => {
    fetchScreenshots(screenshots.length);
  }, [fetchScreenshots, screenshots.length]);

  const deleteScreenshot = useCallback(async (id: string, storagePath: string) => {
    const supabase = createClient();
    await supabase.storage.from("screenshots").remove([storagePath]);
    await supabase.from("screenshots").delete().eq("id", id);
    setScreenshots(prev => prev.filter(s => s.id !== id));
  }, []);

  const deleteMultiple = useCallback(async (items: Array<{ id: string; storagePath: string }>) => {
    const supabase = createClient();
    const paths = items.map(i => i.storagePath);
    const ids = items.map(i => i.id);
    await supabase.storage.from("screenshots").remove(paths);
    await supabase.from("screenshots").delete().in("id", ids);
    setScreenshots(prev => prev.filter(s => !ids.includes(s.id)));
  }, []);

  const refresh = useCallback(() => {
    setLoading(true);
    setScreenshots([]);
    fetchScreenshots();
  }, [fetchScreenshots]);

  return { screenshots, loading, error, hasMore, loadMore, deleteScreenshot, deleteMultiple, refresh };
}
