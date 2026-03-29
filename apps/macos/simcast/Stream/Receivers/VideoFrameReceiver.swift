import CoreMedia

/// A subscriber to video frames produced by `SCKManager`.
///
/// Implement this protocol to receive raw `CMSampleBuffer` frames from the
/// ScreenCaptureKit capture session and forward them to a streaming service.
///
/// ## Threading
/// `sckManager(didOutput:)` is called on a high-priority background queue for
/// every captured frame. Implementations must not block and must handle their
/// own thread safety. `sckManagerDidStop()` is called on `@MainActor`.
protocol VideoFrameReceiver: AnyObject {
    /// Called on a background queue for every captured frame.
    func sckManager(didOutput sampleBuffer: CMSampleBuffer)

    /// Called on `@MainActor` when the stream stops for any reason.
    func sckManagerDidStop()
}

extension VideoFrameReceiver {
    func sckManagerDidStop() {}
}
