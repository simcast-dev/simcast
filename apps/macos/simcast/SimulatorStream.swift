import ScreenCaptureKit
import AVFoundation
import CoreMedia

@MainActor
final class SimulatorStream: NSObject, SCStreamOutput, SCStreamDelegate {

    nonisolated(unsafe) let displayLayer = AVSampleBufferDisplayLayer()

    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "com.simcast.stream.output", qos: .userInteractive)

    func start(window: SCWindow) async {
        guard
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
            let display = content.displays.first(where: {
                $0.frame.contains(CGPoint(x: window.frame.midX, y: window.frame.midY))
            }) ?? content.displays.first
        else { return }

        let simulatorApps = content.applications.filter { $0.bundleIdentifier == "com.apple.iphonesimulator" }
        let filter = SCContentFilter(display: display, including: simulatorApps, exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(
            x: window.frame.minX - display.frame.minX,
            y: window.frame.minY - display.frame.minY,
            width: window.frame.width,
            height: window.frame.height
        )
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = false

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
