"use client";

import { useState, useEffect, useCallback } from "react";
import { createClient } from "@/lib/supabase/client";
import { logDebug, logDebugError } from "@/lib/debug";
import { shouldReconnectForStatus, type ChannelHealth } from "@/lib/realtime";

export type RecordingStatus = "pending" | "ready" | "failed";

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
  status: RecordingStatus;
  error_message: string | null;
  signedUrl?: string;
};

function normalizeRecording(item: Partial<Recording> & Pick<Recording, "id" | "storage_path" | "created_at">): Recording {
  return {
    id: item.id,
    storage_path: item.storage_path,
    simulator_name: item.simulator_name ?? null,
    simulator_udid: item.simulator_udid ?? null,
    duration_seconds: item.duration_seconds ?? 0,
    file_size_bytes: item.file_size_bytes ?? 0,
    width: item.width ?? null,
    height: item.height ?? null,
    created_at: item.created_at,
    status: item.status ?? "ready",
    error_message: item.error_message ?? null,
  };
}

function mergeById(items: Recording[], item: Recording) {
  const next = new Map(items.map((existing) => [existing.id, existing]));
  next.set(item.id, item);
  return Array.from(next.values()).sort((a, b) => b.created_at.localeCompare(a.created_at));
}

async function withSignedUrl(supabase: ReturnType<typeof createClient>, recording: Recording): Promise<Recording> {
  if (recording.status !== "ready") {
    return { ...recording, signedUrl: undefined };
  }

  const { data } = await supabase.storage
    .from("recordings")
    .createSignedUrl(recording.storage_path, 3600);

  return { ...recording, signedUrl: data?.signedUrl };
}

export function useRecordings(userId: string, onNewItem?: (item: Recording) => void, channelHealth?: ChannelHealth) {
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
      const withUrls = await Promise.all(data.map((item) => withSignedUrl(supabase, normalizeRecording(item as Recording))));
      if (offset === 0) {
        setRecordings(withUrls);
      } else {
        setRecordings((prev) => [...prev, ...withUrls]);
      }
      setHasMore(data.length === PAGE_SIZE);
    }
    setLoading(false);
  }, [userId]);

  useEffect(() => {
    let cancelled = false;
    void fetchRecordings();

    const supabase = createClient();
    const channel = supabase.channel("recordings-realtime");
    channelHealth?.register(channel);
    channel
      .on(
        "postgres_changes" as never,
        { event: "INSERT", schema: "public", table: "recordings", filter: `user_id=eq.${userId}` },
        async (payload: { new: Recording }) => {
          const item = await withSignedUrl(supabase, normalizeRecording(payload.new));
          if (cancelled) return;
          setRecordings((prev) => mergeById(prev, item));
          if (item.status === "ready") {
            onNewItem?.(item);
          }
        },
      )
      .on(
        "postgres_changes" as never,
        { event: "UPDATE", schema: "public", table: "recordings", filter: `user_id=eq.${userId}` },
        async (payload: { new: Recording }) => {
          const item = await withSignedUrl(supabase, normalizeRecording(payload.new));
          if (cancelled) return;
          setRecordings((prev) => {
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
          logDebugError("gallery", "recordings channel reported an error", err, {
            userId,
            status,
            topic: channel.topic,
          });
          channelHealth?.requestReconnect("recordings-channel-error", {
            userId,
            status,
            topic: channel.topic,
          });
          return;
        }

        logDebug("gallery", "recordings channel status changed", {
          userId,
          status,
          topic: channel.topic,
        });
        if (shouldReconnectForStatus(status)) {
          channelHealth?.requestReconnect("recordings-channel-status", {
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
  }, [fetchRecordings, onNewItem, userId, channelHealth?.reconnectKey]);

  const loadMore = useCallback(() => {
    void fetchRecordings(recordings.length);
  }, [fetchRecordings, recordings.length]);

  const deleteRecording = useCallback(async (id: string, storagePath: string, status: RecordingStatus) => {
    const supabase = createClient();
    if (status === "ready") {
      await supabase.storage.from("recordings").remove([storagePath]);
    }
    await supabase.from("recordings").delete().eq("id", id);
    setRecordings((prev) => prev.filter((item) => item.id !== id));
  }, []);

  const deleteMultiple = useCallback(async (items: Array<{ id: string; storagePath: string; status: RecordingStatus }>) => {
    const supabase = createClient();
    const readyPaths = items.filter((item) => item.status === "ready").map((item) => item.storagePath);
    const ids = items.map((item) => item.id);
    if (readyPaths.length > 0) {
      await supabase.storage.from("recordings").remove(readyPaths);
    }
    await supabase.from("recordings").delete().in("id", ids);
    setRecordings((prev) => prev.filter((item) => !ids.includes(item.id)));
  }, []);

  const refresh = useCallback(() => {
    setLoading(true);
    setError(null);
    setRecordings([]);
    void fetchRecordings();
  }, [fetchRecordings]);

  return { recordings, loading, error, hasMore, loadMore, deleteRecording, deleteMultiple, refresh };
}
