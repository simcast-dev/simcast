//
//  StreamPreview.swift
//  simdock
//

import SwiftUI

struct StreamPreview<Overlay: View>: View {
    var device: SimulatedDevice
    var onCanvasTap: () -> Void
    @ViewBuilder var overlay: (_ deviceSize: CGSize) -> Overlay

    init(
        device: SimulatedDevice,
        onCanvasTap: @escaping () -> Void = {},
        @ViewBuilder overlay: @escaping (_ deviceSize: CGSize) -> Overlay
    ) {
        self.device = device
        self.onCanvasTap = onCanvasTap
        self.overlay = overlay
    }

    var body: some View {
        GeometryReader { proxy in
            let maxHeight = proxy.size.height
            let maxWidth = proxy.size.width
            let deviceHeight = min(maxHeight, maxWidth / device.displayAspectRatio)
            let deviceWidth = deviceHeight * device.displayAspectRatio
            let deviceSize = CGSize(width: deviceWidth, height: deviceHeight)
            let overlayWidth = min(maxWidth, 244)
            let canvasTrailingX = maxWidth / 2 + deviceWidth / 2
            let railWidth: CGFloat = 48
            let overlayRightX = min(maxWidth - 2, canvasTrailingX + 8 + railWidth)

            ZStack {
                Color.clear

                StreamCanvas(cornerRadius: canvasCornerRadius(for: device))
                    .frame(width: deviceWidth, height: deviceHeight)
                    .contentShape(RoundedRectangle(cornerRadius: canvasCornerRadius(for: device), style: .continuous))
                    .onTapGesture(perform: onCanvasTap)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(device.fullName) simulator stream")

                overlay(deviceSize)
                    .frame(width: overlayWidth, alignment: .trailing)
                    .position(x: overlayRightX - overlayWidth / 2, y: maxHeight / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 260)
    }

    private func canvasCornerRadius(for device: SimulatedDevice) -> CGFloat {
        max(16, min(device.cornerRadius - 16, 28))
    }
}

extension StreamPreview where Overlay == EmptyView {
    init(device: SimulatedDevice, onCanvasTap: @escaping () -> Void = {}) {
        self.device = device
        self.onCanvasTap = onCanvasTap
        self.overlay = { _ in EmptyView() }
    }
}
