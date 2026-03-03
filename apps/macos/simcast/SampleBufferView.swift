import SwiftUI
import AVFoundation

struct SampleBufferView: NSViewRepresentable {
    let stream: SimulatorStream

    func makeNSView(context: Context) -> StreamNSView {
        StreamNSView(displayLayer: stream.displayLayer)
    }

    func updateNSView(_ nsView: StreamNSView, context: Context) {}
}

final class StreamNSView: NSView {
    private let displayLayer: AVSampleBufferDisplayLayer

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func makeBackingLayer() -> CALayer {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = NSColor.clear.cgColor
        return displayLayer
    }
}
