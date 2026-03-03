import ScreenCaptureKit
import AVFoundation
import CoreMedia

@MainActor
final class SimulatorStream: NSObject, SCStreamOutput, SCStreamDelegate {

    nonisolated(unsafe) let displayLayer = AVSampleBufferDisplayLayer()

    // Read from layout() on main thread; written from @MainActor — safe without locks.
    nonisolated(unsafe) var windowFrame: CGRect = .zero
    var onFrameChanged: (() -> Void)?

    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "com.simcast.stream.output", qos: .userInteractive)
    private var trackerTask: Task<Void, Never>?
    private var trackedWindowID: CGWindowID?

    func start(window: SCWindow) async {
        guard
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
            let display = content.displays.first(where: {
                $0.frame.contains(CGPoint(x: window.frame.midX, y: window.frame.midY))
            }) ?? content.displays.first
        else { return }

        // Capture just this window, independent of position and what's in front of it.
        // This avoids position-lag artifacts when the window moves and renders content
        // even when the window is partially behind the Dock or other system chrome.
        let filter = SCContentFilter(desktopIndependentWindow: window)

        windowFrame = window.frame

        let scaleFactor = CGFloat(display.width) / display.frame.width
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * scaleFactor)
        config.height = Int(window.frame.height * scaleFactor)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = false

        do {
            stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
            try await stream?.startCapture()
            trackedWindowID = window.windowID
            startTracking()
            onFrameChanged?()
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
        displayLayer.sampleBufferRenderer.flush()
    }

    private func startTracking() {
        trackerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                self?.updateWindowFrame()
            }
        }
    }

    // CGWindowListCopyWindowInfo is a lightweight WindowServer query (~0.1ms).
    // Using it instead of SCShareableContent lets us poll at 50ms without overhead.
    private func updateWindowFrame() {
        guard let windowID = trackedWindowID else { return }
        guard
            let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
            let info = list.first,
            let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
            let newFrame = CGRect(dictionaryRepresentation: boundsDict),
            newFrame != windowFrame
        else { return }

        windowFrame = newFrame
        onFrameChanged?()
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed { renderer.flush() }
        renderer.enqueue(sampleBuffer)
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {}
}
