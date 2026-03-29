"use client";

import { useState, useEffect, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";

export type Recording = {
  id: string;
  storage_path: string;
  simulator_name: string | null;
  simulator_udid: string | null;
  duration_seconds: number;
  file_size_bytes: number;
  width: number | null;
  height: number | null;
  created_at: string;
  signedUrl?: string;
};

export function useRecordings(userId: string, onNewItem?: (item: Recording) => void) {
  const [recordings, setRecordings] = useState<Recording[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);

  const PAGE_SIZE = 24;

  const fetchRecordings = useCallback(async (offset = 0) => {
    const supabase = createClient();
    const { data, error: fetchError } = await supabase
      .from("recordings")
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
        data.map(async (r: Recording) => {
          const { data: urlData } = await supabase.storage
            .from("recordings")
            .createSignedUrl(r.storage_path, 3600);
          return { ...r, signedUrl: urlData?.signedUrl };
        })
      );

      if (offset === 0) {
        setRecordings(withUrls);
      } else {
        setRecordings(prev => [...prev, ...withUrls]);
      }
      setHasMore(data.length === PAGE_SIZE);
    }
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    fetchRecordings();

    const supabase = createClient();
    const channel = supabase
      .channel("recordings-realtime")
      .on(
        "postgres_changes" as never,
        { event: "INSERT", schema: "public", table: "recordings", filter: `user_id=eq.${userId}` },
        async (payload: { new: Recording }) => {
          const row = payload.new;
          const { data: urlData } = await supabase.storage
            .from("recordings")
            .createSignedUrl(row.storage_path, 3600);
          const item = { ...row, signedUrl: urlData?.signedUrl };
          setRecordings(prev => [item, ...prev]);
          onNewItem?.(item);
        }
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [fetchRecordings, userId]);

  const loadMore = useCallback(() => {
    fetchRecordings(recordings.length);
  }, [fetchRecordings, recordings.length]);

  const deleteRecording = useCallback(async (id: string, storagePath: string) => {
    const supabase = createClient();
    await supabase.storage.from("recordings").remove([storagePath]);
    await supabase.from("recordings").delete().eq("id", id);
    setRecordings(prev => prev.filter(r => r.id !== id));
  }, []);

  const deleteMultiple = useCallback(async (items: Array<{ id: string; storagePath: string }>) => {
    const supabase = createClient();
    const paths = items.map(i => i.storagePath);
    const ids = items.map(i => i.id);
    await supabase.storage.from("recordings").remove(paths);
    await supabase.from("recordings").delete().in("id", ids);
    setRecordings(prev => prev.filter(r => !ids.includes(r.id)));
  }, []);

  const refresh = useCallback(() => {
    setLoading(true);
    setRecordings([]);
    fetchRecordings();
  }, [fetchRecordings]);

  return { recordings, loading, error, hasMore, loadMore, deleteRecording, deleteMultiple, refresh };
}
