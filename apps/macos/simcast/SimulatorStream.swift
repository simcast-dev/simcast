import ScreenCaptureKit
import AVFoundation
import CoreMedia

@MainActor
final class SimulatorStream: NSObject, SCStreamOutput, SCStreamDelegate {

    nonisolated(unsafe) let displayLayer = AVSampleBufferDisplayLayer()

    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "com.simcast.stream.output", qos: .userInteractive)
    private var trackerTask: Task<Void, Never>?
    private var trackedWindowID: CGWindowID?
    private var lastSourceRect: CGRect = .zero

    func start(window: SCWindow) async {
        guard
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
            let display = content.displays.first(where: {
                $0.frame.contains(CGPoint(x: window.frame.midX, y: window.frame.midY))
            }) ?? content.displays.first
        else { return }

        let simulatorApps = content.applications.filter { $0.bundleIdentifier == "com.apple.iphonesimulator" }
        let filter = SCContentFilter(display: display, including: simulatorApps, exceptingWindows: [])

        let sourceRect = Self.sourceRect(for: window, in: display)
        let config = streamConfig(sourceRect: sourceRect, size: window.frame.size)

        do {
            stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
            try await stream?.startCapture()
            trackedWindowID = window.windowID
            lastSourceRect = sourceRect
            startTracking()
        } catch {
            stream = nil
        }
    }

    func stop() async {
        trackerTask?.cancel()
        trackerTask = nil
        trackedWindowID = nil
        try? await stream?.stopCapture()
        stream = nil
        displayLayer.flush()
    }

    private func startTracking() {
        trackerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                await self?.updateSourceRectIfNeeded()
            }
        }
    }

    private func updateSourceRectIfNeeded() async {
        guard
            let windowID = trackedWindowID,
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
            let window = content.windows.first(where: { $0.windowID == windowID }),
            let display = content.displays.first(where: {
                $0.frame.contains(CGPoint(x: window.frame.midX, y: window.frame.midY))
            }) ?? content.displays.first
        else { return }

        let newRect = Self.sourceRect(for: window, in: display)
        guard newRect != lastSourceRect else { return }

        lastSourceRect = newRect
        try? await stream?.updateConfiguration(streamConfig(sourceRect: newRect, size: window.frame.size))
    }

    private func streamConfig(sourceRect: CGRect, size: CGSize) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(size.width)
        config.height = Int(size.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = false
        return config
    }

    private static func sourceRect(for window: SCWindow, in display: SCDisplay) -> CGRect {
        CGRect(
            x: window.frame.minX - display.frame.minX,
            y: window.frame.minY - display.frame.minY,
            width: window.frame.width,
            height: window.frame.height
        )
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(sampleBuffer)
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {}
}
