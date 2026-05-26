//
//  DeviceSelectorButton.swift
//  simdock
//

import SwiftUI

struct DeviceSelectorButton: View {
    var selectedDevice: SimulatedDevice
    var isExpanded: Bool
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: selectedDevice.symbolName)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .simDockGlass(cornerRadius: 17)

                Text(selectedDevice.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simDockGlass(cornerRadius: 24, interactive: true)
        .accessibilityLabel("Selected simulator")
        .accessibilityValue(selectedDevice.title)
    }
}
