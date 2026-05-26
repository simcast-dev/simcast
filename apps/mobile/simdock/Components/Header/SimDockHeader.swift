//
//  SimDockHeader.swift
//  simdock
//

import SwiftUI

struct SimDockHeader: View {
    @Binding var selectedDevice: SimulatedDevice

    var body: some View {
        GeometryReader { proxy in
            let selectorWidth = min(max(proxy.size.width - 148, 180), 420)

            ZStack {
                DeviceSelector(selectedDevice: $selectedDevice)
                    .frame(width: selectorWidth)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .frame(height: 54)
        .zIndex(20)
    }
}
