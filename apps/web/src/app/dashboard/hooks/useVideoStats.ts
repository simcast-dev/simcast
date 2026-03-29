"use client";

import { useEffect, useRef, useState } from "react";
import type { TrackReferenceOrPlaceholder } from "@livekit/components-react";

export type VideoStats = {
  bitrateKbps: number;
  fps: number;
  width: number;
  height: number;
  packetsLost: number;
  jitter: number;
};

export function useVideoStats(track: TrackReferenceOrPlaceholder | undefined): VideoStats | null {
  const [stats, setStats] = useState<VideoStats | null>(null);
  const prevRef = useRef<{ bytes: number; time: number; packetsLost: number } | null>(null);

  useEffect(() => {
    if (!track?.publication?.track) {
      setStats(null);
      prevRef.current = null;
      return;
    }
    // `as any`: LiveKit doesn't expose the underlying WebRTC receiver in its TypeScript types, but it's available at runtime
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const receiver = (track.publication.track as any).receiver as RTCRtpReceiver | undefined;
    if (!receiver) return;

    async function poll() {
      const report = await receiver!.getStats();
      report.forEach((entry) => {
        if (entry.type === "inbound-rtp" && entry.kind === "video") {
          const now = performance.now();
          const bytes = (entry as RTCInboundRtpStreamStats).bytesReceived ?? 0;
          const totalPacketsLost = (entry as RTCInboundRtpStreamStats).packetsLost ?? 0;
          const bitrateKbps = prevRef.current
            ? ((bytes - prevRef.current.bytes) * 8) / ((now - prevRef.current.time) / 1000) / 1000
            : 0;
          // delta packets lost since last poll, not cumulative total
          const packetsLost = prevRef.current
            ? Math.max(0, totalPacketsLost - prevRef.current.packetsLost)
            : 0;
          prevRef.current = { bytes, time: now, packetsLost: totalPacketsLost };
          setStats({
            bitrateKbps,
            fps: (entry as RTCInboundRtpStreamStats & { framesPerSecond?: number }).framesPerSecond ?? 0,
            width: (entry as RTCInboundRtpStreamStats & { frameWidth?: number }).frameWidth ?? 0,
            height: (entry as RTCInboundRtpStreamStats & { frameHeight?: number }).frameHeight ?? 0,
            packetsLost,
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            jitter: (entry as any).jitter ?? 0,
          });
        }
      });
    }

    // 1s poll: frequent enough for real-time monitoring, infrequent enough to not impact performance
    const id = setInterval(poll, 1000);
    return () => clearInterval(id);
  }, [track?.publication?.track]);

  return stats;
}
