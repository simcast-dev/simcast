//
//  GesturePadButton.swift
//  simdock
//

import SwiftUI

struct GesturePadButton: View {
    var gesture: SimulatorGesture
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            gestureIcon
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.primary.opacity(0.78))
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.52))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(gesture.title)
    }

    @ViewBuilder
    private var gestureIcon: some View {
        switch gesture {
        case .scrollUp:
            Image(systemName: "arrow.up")
        case .scrollDown:
            Image(systemName: "arrow.down")
        case .scrollLeft:
            Image(systemName: "arrow.left")
        case .scrollRight:
            Image(systemName: "arrow.right")
        case .swipeFromTopEdge:
            Image(systemName: "arrow.down.to.line.compact")
        case .swipeFromBottomEdge:
            Image(systemName: "arrow.up.to.line.compact")
        case .swipeFromLeftEdge:
            Image(systemName: "arrow.right.to.line.compact")
        case .swipeFromRightEdge:
            Image(systemName: "arrow.left.to.line.compact")
        }
    }
}
