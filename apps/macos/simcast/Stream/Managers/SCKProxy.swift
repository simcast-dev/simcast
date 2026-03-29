import CoreMedia
import ScreenCaptureKit

/// Bridges `SCStreamOutput` and `SCStreamDelegate` (background-thread callbacks)
/// to the registered receivers. Holds a snapshot of receivers taken at stream
/// start — frame delivery never touches `@MainActor`-isolated state.
///
// @unchecked Sendable because SCStream delivers frames on its own background queue;
// the proxy bridges these callbacks to receivers which handle thread safety themselves.
final class SCKProxy: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var receivers: [any VideoFrameReceiver]
    private let lock = NSLock()
    private let onStop: () -> Void

    init(receivers: [any VideoFrameReceiver], onStop: @escaping () -> Void) {
        self.receivers = receivers
        self.onStop = onStop
    }

    func addReceiver(_ receiver: any VideoFrameReceiver) {
        lock.lock()
        receivers.append(receiver)
        lock.unlock()
    }

    func removeReceiver(_ receiver: any VideoFrameReceiver) {
        lock.lock()
        receivers.removeAll { $0 === receiver }
        lock.unlock()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else { return }
        lock.lock()
        let current = receivers
        lock.unlock()
        for receiver in current {
            receiver.sckManager(didOutput: sampleBuffer)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop()
    }
}
