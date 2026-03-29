import SwiftUI
import AVFoundation

/// Renders an `AVSampleBufferDisplayLayer` inside a SwiftUI layout.
///
/// The layer is added as a sublayer and kept in sync with the view's bounds
/// via `layout()`, so it fills the view while respecting `videoGravity`.
struct SCKPreviewView: NSViewRepresentable {
    let layer: AVSampleBufferDisplayLayer

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(previewLayer: layer)
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {}

    class PreviewNSView: NSView {
        let previewLayer: AVSampleBufferDisplayLayer

        init(previewLayer: AVSampleBufferDisplayLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            wantsLayer = true
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}
