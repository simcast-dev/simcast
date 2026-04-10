"use client";

import React, { useState, useCallback, useMemo, useEffect } from "react";
import type { ChannelHealth } from "@/lib/realtime";
import { useRecordings, type Recording } from "./useRecordings";
import VideoPreviewModal from "./VideoPreviewModal";

type SimulatorGroup = {
  key: string;
  name: string;
  isIPad: boolean;
  items: Recording[];
};

function groupBySimulator(items: Recording[]): SimulatorGroup[] {
  const map = new Map<string, SimulatorGroup>();
  for (const item of items) {
    const key = item.simulator_udid ?? "unknown";
    if (!map.has(key)) {
      map.set(key, {
        key,
        name: item.simulator_name ?? "Unknown Device",
        isIPad: (item.simulator_name ?? "").toLowerCase().includes("ipad"),
        items: [],
      });
    }
    map.get(key)!.items.push(item);
  }
  const groups = Array.from(map.values());
  const unknownIdx = groups.findIndex(g => g.key === "unknown");
  if (unknownIdx > 0) groups.push(groups.splice(unknownIdx, 1)[0]);
  return groups;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" }) +
    ", " +
    d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function downloadBlob(url: string, filename: string) {
  fetch(url)
    .then(r => r.blob())
    .then(blob => {
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      a.click();
      URL.revokeObjectURL(a.href);
    });
}

function VideoThumbnail({ src }: { src: string }) {
  const canvasRef = React.useRef<HTMLCanvasElement>(null);
  const [ready, setReady] = React.useState(false);

  React.useEffect(() => {
    const video = document.createElement("video");
    video.crossOrigin = "anonymous";
    video.muted = true;
    video.preload = "metadata";
    video.src = src;

    const handleSeeked = () => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      canvas.getContext("2d")?.drawImage(video, 0, 0);
      setReady(true);
      video.removeEventListener("seeked", handleSeeked);
      video.src = "";
    };

    video.addEventListener("loadedmetadata", () => {
      video.currentTime = 0.1;
    });
    video.addEventListener("seeked", handleSeeked);

    return () => {
      video.removeEventListener("seeked", handleSeeked);
      video.src = "";
    };
  }, [src]);

  return (
    <canvas
      ref={canvasRef}
      style={{
        width: "100%",
        height: "100%",
        objectFit: "cover",
        display: ready ? "block" : "none",
      }}
    />
  );
}

function SkeletonGrid() {
  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
        gap: 16,
      }}
    >
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={i}
          style={{
            borderRadius: "var(--radius-lg)",
            background: "var(--skeleton-bg)",
            border: "1px solid var(--border-subtle)",
            overflow: "hidden",
          }}
        >
          <div
            className="animate-pulse"
            style={{ width: "100%", aspectRatio: "16/9", background: "var(--skeleton-pulse)" }}
          />
          <div style={{ padding: "10px 12px", display: "flex", flexDirection: "column", gap: 6 }}>
            <div className="animate-pulse" style={{ height: 12, width: "60%", borderRadius: 4, background: "var(--skeleton-pulse)" }} />
            <div className="animate-pulse" style={{ height: 10, width: "40%", borderRadius: 4, background: "var(--skeleton-bg)" }} />
          </div>
        </div>
      ))}
    </div>
  );
}

export default function RecordingGallery({ userId, onNewItem, channelHealth }: { userId: string; onNewItem?: (item: Recording) => void; channelHealth?: ChannelHealth }) {
  const { recordings, loading, error, hasMore, loadMore, deleteRecording, deleteMultiple, refresh } = useRecordings(userId, onNewItem, channelHealth);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [preview, setPreview] = useState<Recording | null>(null);

  const groups = useMemo(() => groupBySimulator(recordings), [recordings]);
  const [expandedSections, setExpandedSections] = useState<Set<string>>(
    () => new Set(groups.map(g => g.key))
  );

  useEffect(() => {
    setExpandedSections(prev => {
      const next = new Set(prev);
      groups.forEach(g => { if (!next.has(g.key)) next.add(g.key); });
      return next;
    });
  }, [groups]);

  const toggleSection = useCallback((key: string) => {
    setExpandedSections(prev => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }, []);

  const toggleSelect = useCallback((id: string) => {
    setSelected(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const clearSelection = useCallback(() => setSelected(new Set()), []);

  const handleDeleteSelected = useCallback(async () => {
    const items = recordings
      .filter(r => selected.has(r.id))
      .map(r => ({ id: r.id, storagePath: r.storage_path }));
    await deleteMultiple(items);
    setSelected(new Set());
  }, [recordings, selected, deleteMultiple]);

  const handleDeleteSingle = useCallback(async (r: Recording) => {
    await deleteRecording(r.id, r.storage_path);
    setPreview(null);
  }, [deleteRecording]);

  if (loading && recordings.length === 0) {
    return (
      <div className="p-6">
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 20 }}>
          <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase", color: "var(--text-3)" }}>
            Recordings
          </span>
          <div style={{ flex: 1, height: 1, background: "var(--border-subtle)" }} />
        </div>
        <SkeletonGrid />
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div
          className="flex flex-col items-center justify-center py-20 rounded-3xl"
          style={{ border: "1px solid var(--error-border)", background: "var(--error-bg)" }}
        >
          <p className="font-semibold mb-2" style={{ color: "var(--error-text)" }}>Failed to load recordings</p>
          <p className="text-sm" style={{ color: "var(--text-2)" }}>{error}</p>
          <button
            onClick={refresh}
            className="mt-4 px-4 py-2 rounded-lg text-xs font-semibold"
            style={{ background: "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))", border: "1px solid var(--btn-primary-border)", color: "var(--btn-primary-text)", cursor: "pointer" }}
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  if (recordings.length === 0) {
    return (
      <div className="px-6 pt-6 pb-2 h-full">
        <div
          className="flex flex-col items-center justify-center rounded-3xl"
          style={{
            height: "calc(100% - 8px)",
            border: "1px solid var(--border-subtle)",
            background: "linear-gradient(135deg, var(--skeleton-bg) 0%, transparent 100%)",
          }}
        >
          <div
            className="w-14 h-14 rounded-2xl flex items-center justify-center mb-5"
            style={{ background: "var(--badge-bg)", border: "1px solid var(--badge-border)" }}
          >
            <svg viewBox="0 0 16 16" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" style={{ color: "var(--violet)" }}>
              <circle cx="8" cy="8" r="6" />
              <circle cx="8" cy="8" r="2.2" fill="currentColor" stroke="none" />
            </svg>
          </div>
          <p className="font-semibold mb-2" style={{ color: "var(--text)" }}>No recordings yet</p>
          <p className="text-sm text-center max-w-xs leading-relaxed" style={{ color: "var(--text-2)" }}>
            Use the record button while streaming to capture sessions.
          </p>
        </div>
      </div>
    );
  }

  const isSelecting = selected.size > 0;

  return (
    <div className="p-6">
      {/* Global header */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 24 }}>
        <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", letterSpacing: "var(--tracking-wide)", textTransform: "uppercase", color: "var(--text-3)" }}>
          Recordings
        </span>
        <span style={{
          fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)",
          background: "var(--badge-bg)", border: "1px solid var(--badge-border)",
          borderRadius: "var(--radius-sm)", padding: "1px 7px", color: "var(--badge-text)",
        }}>
          {recordings.length}
        </span>
        <div style={{ flex: 1, height: 1, background: "var(--border-subtle)" }} />

        {isSelecting && (
          <>
            <button
              onClick={clearSelection}
              className="text-xs font-semibold px-3 py-1.5 rounded-lg"
              style={{ background: "var(--btn-secondary-bg)", border: "1px solid var(--btn-secondary-border)", color: "var(--btn-secondary-text)", cursor: "pointer" }}
            >
              Cancel
            </button>
            <button
              onClick={handleDeleteSelected}
              className="text-xs font-semibold px-3 py-1.5 rounded-lg"
              style={{ background: "var(--btn-danger-bg)", border: "1px solid var(--btn-danger-border)", color: "var(--btn-danger-text)", cursor: "pointer" }}
            >
              Delete selected ({selected.size})
            </button>
          </>
        )}

        <button
          onClick={refresh}
          title="Refresh"
          className="rounded-lg p-1.5"
          style={{ background: "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))", border: "1px solid var(--btn-primary-border)", color: "var(--badge-text)", cursor: "pointer" }}
        >
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" className="w-3.5 h-3.5">
            <path d="M14 2v4h-4" />
            <path d="M2 14v-4h4" />
            <path d="M13.5 6A6 6 0 0 0 3.3 3.3L2 6" />
            <path d="M2.5 10a6 6 0 0 0 10.2 2.7L14 10" />
          </svg>
        </button>
      </div>

      {/* Simulator sections */}
      {groups.map(group => {
        const expanded = expandedSections.has(group.key);
        return (
          <div key={group.key} style={{ marginBottom: 32 }}>
            {/* Section header */}
            <button
              onClick={() => toggleSection(group.key)}
              style={{
                display: "flex", alignItems: "center", gap: 8,
                width: "100%", background: "none", border: "none",
                cursor: "pointer", padding: 0, marginBottom: 16,
              }}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="var(--badge-text)" strokeWidth="1.5"
                style={{ width: 16, height: 16, flexShrink: 0 }}>
                {group.isIPad ? (
                  <>
                    <rect x="4" y="2" width="16" height="20" rx="2.5" />
                    <circle cx="12" cy="18.5" r="0.75" fill="var(--badge-text)" stroke="none" />
                    <line x1="4" y1="4.5" x2="20" y2="4.5" strokeWidth="0.75" />
                  </>
                ) : (
                  <>
                    <rect x="6" y="2" width="12" height="20" rx="2.5" />
                    <circle cx="12" cy="18.5" r="0.75" fill="var(--badge-text)" stroke="none" />
                    <line x1="6" y1="4.5" x2="18" y2="4.5" strokeWidth="0.75" />
                  </>
                )}
              </svg>
              <span style={{ fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-semibold)", color: "var(--text)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: 240 }}>
                {group.name}
              </span>
              {group.key !== "unknown" && (
                <span style={{ fontSize: "var(--font-size-xs)", fontFamily: "monospace", color: "var(--text-3)", flexShrink: 0 }}>
                  {group.key.slice(0, 8).toUpperCase()}
                </span>
              )}
              <span style={{
                fontSize: "var(--font-size-xs)", fontWeight: "var(--font-weight-bold)", flexShrink: 0,
                background: "var(--badge-bg)", border: "1px solid var(--badge-border)",
                borderRadius: "var(--radius-sm)", padding: "1px 7px", color: "var(--badge-text)",
              }}>
                {group.items.length}
              </span>
              <div style={{ flex: 1, height: 1, background: "var(--border-subtle)" }} />
              <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5"
                style={{
                  width: 14, height: 14, color: "var(--text-3)", flexShrink: 0,
                  transform: expanded ? "rotate(0deg)" : "rotate(-90deg)",
                  transition: "transform 0.2s",
                }}>
                <path d="M4 6l4 4 4-4" />
              </svg>
            </button>

            {/* Grid */}
            {expanded && (
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
                  gap: 16,
                }}
              >
                {group.items.map(r => {
                  const isSelected = selected.has(r.id);
                  return (
                    <div
                      key={r.id}
                      className="group"
                      style={{
                        position: "relative",
                        borderRadius: "var(--radius-lg)",
                        backgroundColor: isSelected ? "var(--badge-bg)" : "transparent",
                        border: isSelected ? "1px solid var(--tab-active-border)" : "1px solid transparent",
                        overflow: "hidden",
                        cursor: "pointer",
                      }}
                      onMouseEnter={e => {
                        if (!isSelected) {
                          e.currentTarget.style.border = "1px solid var(--tab-hover-border)";
                          e.currentTarget.style.backgroundColor = "var(--tab-hover-bg)";
                        }
                      }}
                      onMouseLeave={e => {
                        if (!isSelected) {
                          e.currentTarget.style.border = "1px solid transparent";
                          e.currentTarget.style.backgroundColor = "transparent";
                        }
                      }}
                      onClick={() => {
                        if (isSelecting) {
                          toggleSelect(r.id);
                        } else {
                          setPreview(r);
                        }
                      }}
                    >
                      {/* Checkbox */}
                      <div
                        className="opacity-0 group-hover:opacity-100"
                        style={{
                          position: "absolute", top: 8, left: 8, zIndex: 2,
                          transition: "opacity 0.15s",
                          opacity: isSelecting ? 1 : undefined,
                        }}
                        onClick={e => { e.stopPropagation(); toggleSelect(r.id); }}
                      >
                        <div style={{
                          width: 22, height: 22, borderRadius: 6,
                          background: isSelected ? "var(--violet)" : "var(--checkbox-unchecked-bg)",
                          border: isSelected ? "2px solid var(--violet)" : "2px solid var(--checkbox-unchecked-border)",
                          backdropFilter: "blur(4px)",
                          display: "flex", alignItems: "center", justifyContent: "center",
                        }}>
                          {isSelected && (
                            <svg viewBox="0 0 12 12" fill="none" stroke="white" strokeWidth="2" className="w-3 h-3">
                              <path d="M2 6l3 3 5-5" />
                            </svg>
                          )}
                        </div>
                      </div>

                      {/* Video thumbnail */}
                      <div style={{
                        width: "100%",
                        aspectRatio: "16/9",
                        background: "var(--skeleton-bg)",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        position: "relative",
                        overflow: "hidden",
                      }}>
                        {r.signedUrl && <VideoThumbnail src={r.signedUrl} />}
                        <div style={{
                          position: "absolute",
                          width: 48, height: 48, borderRadius: "50%",
                          background: "var(--badge-bg)",
                          border: "1px solid var(--badge-border)",
                          display: "flex", alignItems: "center", justifyContent: "center",
                          opacity: 0.85,
                        }}>
                          <svg viewBox="0 0 24 24" width="24" height="24" fill="var(--violet)" stroke="none">
                            <polygon points="9,6 18,12 9,18" />
                          </svg>
                        </div>
                        {/* Duration badge */}
                        <div style={{
                          position: "absolute", bottom: 8, right: 8,
                          background: "var(--overlay-bg)",
                          backdropFilter: "blur(4px)",
                          borderRadius: 6,
                          padding: "2px 8px",
                          fontSize: "var(--font-size-xs)",
                          fontWeight: "var(--font-weight-semibold)",
                          color: "var(--text)",
                          letterSpacing: "var(--tracking-tight)",
                        }}>
                          {formatDuration(r.duration_seconds)}
                        </div>
                      </div>

                      {/* Info */}
                      <div style={{ padding: "10px 12px" }}>
                        <p className="text-[10px]" style={{ color: "var(--text-3)" }}>
                          {formatDate(r.created_at)}
                          {" \u00B7 "}
                          {formatFileSize(r.file_size_bytes)}
                          {r.width && r.height ? ` \u00B7 ${r.width}\u00D7${r.height}` : ""}
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        );
      })}

      {/* Load more */}
      {hasMore && (
        <div style={{ display: "flex", justifyContent: "center", marginTop: 24 }}>
          <button
            onClick={loadMore}
            className="px-6 py-2.5 rounded-xl text-xs font-semibold"
            style={{
              background: "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))",
              border: "1px solid var(--btn-primary-border)",
              color: "var(--btn-primary-text)",
              cursor: "pointer",
              transition: "background 0.15s",
            }}
          >
            Load more
          </button>
        </div>
      )}

      {/* Preview modal */}
      {preview && preview.signedUrl && (
        <VideoPreviewModal
          url={preview.signedUrl}
          filename={`${preview.simulator_name ?? "recording"}-${preview.created_at}.mp4`}
          durationSeconds={preview.duration_seconds}
          fileSizeBytes={preview.file_size_bytes}
          onClose={() => setPreview(null)}
          onDelete={() => handleDeleteSingle(preview)}
          onDownload={() => downloadBlob(preview.signedUrl!, `${preview.simulator_name ?? "recording"}-${preview.created_at}.mp4`)}
        />
      )}
    </div>
  );
}
