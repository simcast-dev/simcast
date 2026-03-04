import Foundation
import LiveKit
import ScreenCaptureKit
import Observation

@Observable
@MainActor
final class LiveKitManager {
    let room = Room()
    private(set) var isConnected = false
    private(set) var track: LocalVideoTrack?

    func startStreaming(window: SCWindow) async throws {
        let sources = try await MacOSScreenCapturer.windowSources()
        guard let source = sources.first(where: { $0.windowID == window.windowID }) else {
            throw StreamError.windowNotFound
        }
        let captureOptions = ScreenShareCaptureOptions(
            dimensions: .h1080_169,
            fps: 60,
            showCursor: false
        )
        let newTrack = LocalVideoTrack.createMacOSScreenShareTrack(
            source: source,
            options: captureOptions
        )
        track = newTrack
        try await newTrack.start()

        let url = UserDefaults.standard.string(forKey: "liveKitUrl") ?? ""
        let token = UserDefaults.standard.string(forKey: "liveKitToken") ?? ""
        try await room.connect(url: url, token: token)
        try await room.localParticipant.publish(
            videoTrack: newTrack,
            options: VideoPublishOptions(
                screenShareEncoding: VideoEncoding(maxBitrate: 6_000_000, maxFps: 60),
                simulcast: false
            )
        )
        isConnected = true
    }

    func stop() async {
        isConnected = false
        try? await track?.stop()
        track = nil
        await room.disconnect()
    }

    enum StreamError: Error {
        case windowNotFound
    }
}
