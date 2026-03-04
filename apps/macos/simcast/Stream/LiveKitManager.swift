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
        let newTrack = LocalVideoTrack.createMacOSScreenShareTrack(
            source: source,
            options: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                fps: 60,
                showCursor: false
            )
        )
        track = newTrack

        let url = UserDefaults.standard.string(forKey: "liveKitUrl") ?? ""
        let token = UserDefaults.standard.string(forKey: "liveKitToken") ?? ""
        let roomOptions = RoomOptions(
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                fps: 60,
                showCursor: false
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                simulcast: true,
                preferredCodec: .h264
            ),
            adaptiveStream: true
        )
        try await room.connect(url: url, token: token, roomOptions: roomOptions)
        try await room.localParticipant.publish(
            videoTrack: newTrack,
            options: VideoPublishOptions(
                simulcast: true,
                preferredCodec: .h264
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
