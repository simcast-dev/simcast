import CoreMedia
import LiveKit

/// Bridges `SCKManager` frame output to a LiveKit `LocalVideoTrack`.
///
/// Creates a `LocalVideoTrack` backed by LiveKit's `BufferCapturer`, which
/// accepts raw `CMSampleBuffer` frames. The track is published to the LiveKit
/// room by `LiveKitManager` after the stream starts.
///
/// `onStop` is set by `LiveKitManager` to handle room teardown when the
/// capture session ends (macOS "Stop Sharing", window close, etc.).
final class LiveKitReceiver: VideoFrameReceiver {

    let track: LocalVideoTrack
    private let capturer: BufferCapturer

    var onStop: (@Sendable () async -> Void)?

    init(dimensions: Dimensions, fps: Int = 60) {
        track = LocalVideoTrack.createBufferTrack(
            options: BufferCaptureOptions(dimensions: dimensions, fps: fps)
        )
        // Force cast is safe: createBufferTrack guarantees a BufferCapturer instance.
        capturer = track.capturer as! BufferCapturer
    }

    // MARK: - VideoFrameReceiver

    func sckManager(didOutput sampleBuffer: CMSampleBuffer) {
        capturer.capture(sampleBuffer)
    }

    func sckManagerDidStop() {
        Task { await onStop?() }
    }
}
