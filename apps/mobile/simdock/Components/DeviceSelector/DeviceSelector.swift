//
//  DeviceSelector.swift
//  simdock
//

import SwiftUI

struct DeviceSelector: View {
    @Binding var selectedDevice: SimulatedDevice
    @State private var isExpanded = false

    var body: some View {
        DeviceSelectorButton(
            selectedDevice: selectedDevice,
            isExpanded: isExpanded,
            toggle: toggleExpanded
        )
        .overlay(alignment: .top) {
            if isExpanded {
                DeviceDropdownList(
                    selectedDevice: $selectedDevice,
                    collapse: collapse
                )
                .offset(y: 62)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isExpanded)
        .zIndex(isExpanded ? 10 : 0)
        .accessibilityElement(children: .contain)
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isExpanded.toggle()
        }
    }

    private func collapse() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isExpanded = false
        }
    }
}
