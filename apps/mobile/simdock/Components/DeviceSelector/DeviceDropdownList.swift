//
//  DeviceDropdownList.swift
//  simdock
//

import SwiftUI

struct DeviceDropdownList: View {
    @Binding var selectedDevice: SimulatedDevice
    var collapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CurrentDeviceInfoCard(device: selectedDevice)

            if !otherDevices.isEmpty {
                Text("Other Simulators")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }

            ForEach(otherDevices) { device in
                DeviceDropdownRow(
                    device: device,
                    isSelected: false,
                    select: {
                        selectedDevice = device
                        collapse()
                    }
                )
            }
        }
        .padding(.vertical, 6)
        .simDockGlass(cornerRadius: 22)
    }

    private var otherDevices: [SimulatedDevice] {
        SimulatedDevice.allCases.filter { $0 != selectedDevice }
    }
}
