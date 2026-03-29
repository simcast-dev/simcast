import ScreenCaptureKit
import Observation

@Observable
@MainActor
final class StreamSession: Identifiable {
    let id: String
    let udid: String

    private(set) var stream: SCStream?
    private(set) var proxy: SCKProxy?
    let liveKitProvider: LiveKitProvider
    let previewReceiver: PreviewReceiver
    private(set) var isCapturing: Bool = false
    var captureSize: CGSize = .zero

    var isConnected: Bool { liveKitProvider.isConnected }

    private(set) var isRecording: Bool = false
    private var fileRecordingReceiver: FileRecordingReceiver?

    init(udid: String, liveKitProvider: LiveKitProvider, previewReceiver: PreviewReceiver) {
        self.id = udid
        self.udid = udid
        self.liveKitProvider = liveKitProvider
        self.previewReceiver = previewReceiver
    }

    func setStream(_ stream: SCStream, proxy: SCKProxy) {
        self.stream = stream
        self.proxy = proxy
        self.isCapturing = true
    }

    func stopCapture() async {
        isCapturing = false
        if let stream {
            self.stream = nil
            try? await stream.stopCapture()
        }
        await liveKitProvider.disconnect()
        proxy = nil
    }

    func startRecording(captureSize: CGSize) throws {
        guard isCapturing, !isRecording else { return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("simcast_rec_\(UUID().uuidString).mp4")
        let receiver = FileRecordingReceiver(outputURL: url, dimensions: captureSize)
        try receiver.start()
        proxy?.addReceiver(receiver)
        fileRecordingReceiver = receiver
        isRecording = true
    }

    func stopRecording() async -> (url: URL, duration: Double)? {
        guard let receiver = fileRecordingReceiver else { return nil }
        isRecording = false
        fileRecordingReceiver = nil
        proxy?.removeReceiver(receiver)
        let duration = await receiver.stop()
        return (receiver.outputURL, duration)
    }
}
