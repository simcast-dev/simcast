//
//  DeviceStatusMenu.swift
//  simdock
//

import SwiftUI

struct DeviceStatusMenu: View {
    @Binding var selectedDevice: SimulatedDevice

    var body: some View {
        Menu {
            Picker("Simulator", selection: $selectedDevice) {
                ForEach(SimulatedDevice.allCases) { device in
                    Label(device.title, systemImage: device.symbolName)
                        .tag(device)
                }
            }
        } label: {
            HStack(spacing: 6) {
                LiveDot()

                Text(selectedDevice.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(selectedDevice.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 240)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Simulator")
        .accessibilityValue("\(selectedDevice.title), \(selectedDevice.statusText)")
    }
}
