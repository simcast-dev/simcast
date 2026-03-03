import ScreenCaptureKit
import AVFoundation
import CoreMedia

@MainActor
final class SimulatorStream: NSObject, SCStreamOutput, SCStreamDelegate {

    nonisolated(unsafe) let displayLayer = AVSampleBufferDisplayLayer()

    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "com.simcast.stream.output", qos: .userInteractive)

    func start(window: SCWindow) async {
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        do {
            stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
            try await stream?.startCapture()
        } catch {
            stream = nil
        }
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
        displayLayer.flush()
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(sampleBuffer)
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {}
}
