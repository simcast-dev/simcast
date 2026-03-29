import AVFoundation
import CoreMedia
import Observation

/// Displays captured frames locally using `AVSampleBufferDisplayLayer`.
///
/// Register with `SCKManager` before calling `start`. The display layer is
/// meant to be embedded in an `SCKPreviewView`.
@Observable
final class PreviewReceiver: VideoFrameReceiver {

    let displayLayer = AVSampleBufferDisplayLayer()

    init() {
        displayLayer.videoGravity = .resizeAspect
    }

    // AVSampleBufferDisplayLayer provides zero-copy local preview without
    // re-encoding — frames go directly from capture to display.
    func sckManager(didOutput sampleBuffer: CMSampleBuffer) {
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed {
            renderer.flush()
        }
        renderer.enqueue(sampleBuffer)
    }

    func sckManagerDidStop() {
        displayLayer.sampleBufferRenderer.flush()
    }
}
