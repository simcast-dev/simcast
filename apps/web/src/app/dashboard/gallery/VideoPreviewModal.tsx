"use client";

import React from "react";
import { createPortal } from "react-dom";

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function VideoPreviewModal({
  url,
  filename,
  durationSeconds,
  fileSizeBytes,
  onClose,
  onDelete,
  onDownload,
}: {
  url: string;
  filename: string;
  durationSeconds: number;
  fileSizeBytes: number;
  onClose: () => void;
  onDelete?: () => void;
  onDownload: () => void;
}) {
  return createPortal(
    <div
      style={{ position: "fixed", inset: 0, zIndex: 1000, display: "flex", alignItems: "center", justifyContent: "center" }}
    >
      {/* Backdrop */}
      <div
        onClick={onClose}
        style={{ position: "absolute", inset: 0, background: "var(--overlay-bg)", backdropFilter: "blur(8px)" }}
      />

      {/* Content */}
      <div style={{ position: "relative", maxWidth: "90vw", maxHeight: "90vh", display: "flex", flexDirection: "column", gap: 12 }}>
        <video
          src={url}
          controls
          autoPlay
          style={{ maxWidth: "90vw", maxHeight: "80vh", borderRadius: "var(--radius-md)", border: "1px solid var(--btn-primary-border)" }}
        />

        {/* Actions bar */}
        <div style={{ display: "flex", justifyContent: "center", alignItems: "center", gap: 8 }}>
          <span style={{ fontSize: "var(--font-size-sm)", color: "var(--text-3)", marginRight: 8 }}>
            {formatDuration(durationSeconds)} &middot; {formatFileSize(fileSizeBytes)}
          </span>
          <button
            onClick={onDownload}
            style={{
              padding: "8px 20px", borderRadius: "var(--radius-sm)",
              background: "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))", border: "1px solid var(--btn-primary-border)",
              color: "var(--btn-primary-text)", fontSize: "var(--font-size-base)", fontWeight: "var(--font-weight-semibold)", cursor: "pointer",
            }}
          >
            Download
          </button>
          {onDelete && (
            <button
              onClick={onDelete}
              style={{
                padding: "8px 20px", borderRadius: "var(--radius-sm)",
                background: "var(--btn-danger-bg)", border: "1px solid var(--btn-danger-border)",
                color: "var(--btn-danger-text)", fontSize: "var(--font-size-base)", fontWeight: "var(--font-weight-semibold)", cursor: "pointer",
              }}
            >
              Delete
            </button>
          )}
          <button
            onClick={onClose}
            style={{
              padding: "8px 20px", borderRadius: "var(--radius-sm)",
              background: "var(--btn-secondary-bg)", border: "1px solid var(--btn-secondary-border)",
              color: "var(--btn-secondary-text)", fontSize: "var(--font-size-base)", cursor: "pointer",
            }}
          >
            Close
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
}
