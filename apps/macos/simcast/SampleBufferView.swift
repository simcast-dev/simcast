import SwiftUI
import AVFoundation

struct SampleBufferView: NSViewRepresentable {
    let stream: SimulatorStream

    func makeNSView(context: Context) -> StreamNSView {
        let view = StreamNSView(stream: stream)
        stream.onFrameChanged = { [weak view] in view?.needsLayout = true }
        return view
    }

    func updateNSView(_ nsView: StreamNSView, context: Context) {
        nsView.needsLayout = true
    }
}

final class StreamNSView: NSView {
    private let stream: SimulatorStream

    // Intermediate layer owned by us — AppKit only manages the backing layer, not this one,
    // so masksToBounds stays true between layout calls.
    private let clipLayer = CALayer()

    init(stream: SimulatorStream) {
        self.stream = stream
        super.init(frame: .zero)
        wantsLayer = true
        clipLayer.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        guard let root = layer else { return }

        if clipLayer.superlayer !== root {
            root.addSublayer(clipLayer)
        }

        let displayLayer = stream.displayLayer
        if displayLayer.superlayer !== clipLayer {
            displayLayer.videoGravity = .resize
            clipLayer.addSublayer(displayLayer)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clipLayer.frame = bounds
        displayLayer.frame = bounds
        CATransaction.commit()
    }
}
