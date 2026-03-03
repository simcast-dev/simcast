import Foundation
import LiveKit
import Observation

@Observable
@MainActor
final class LiveKitManager {
    let room = Room()
    private(set) var isConnected = false
    private var track: LocalVideoTrack?

    /// Creates a `LocalVideoTrack` backed by a `BufferCapturer` and returns that capturer
    /// so the caller can assign it to `SimulatorStream.bufferCapturer` before starting capture.
    func prepareTrack() -> BufferCapturer {
        let track = LocalVideoTrack.createBufferTrack()
        self.track = track
        // createBufferTrack() always installs a BufferCapturer — the force-cast is safe.
        return track.capturer as! BufferCapturer
    }

    /// Connect to LiveKit and publish the prepared track.
    /// Must be called after SCKit capture has started and at least one frame has been delivered
    /// (SDK requires resolved dimensions at publish time).
    func connectAndPublish() async throws {
        guard let track else { return }
        let url = UserDefaults.standard.string(forKey: "liveKitUrl") ?? ""
        let token = UserDefaults.standard.string(forKey: "liveKitToken") ?? ""
        try await room.connect(url: url, token: token)
        try await room.localParticipant.publish(videoTrack: track)
        isConnected = true
    }

    func stop() async {
        isConnected = false
        track = nil
        await room.disconnect()
    }
}
