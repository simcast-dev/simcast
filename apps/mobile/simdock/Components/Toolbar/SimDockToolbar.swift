//
//  SimDockToolbar.swift
//  simdock
//

import SwiftUI

struct SimDockToolbar: ToolbarContent {
    @Binding var selectedDevice: SimulatedDevice
    @Binding var showsTouches: Bool
    @Binding var prefersLowLatency: Bool
    var addCommand: CommandHandler

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            DeviceStatusMenu(selectedDevice: $selectedDevice)
        }

        ToolbarItem(placement: .topBarTrailing) {
            SettingsMenu(
                showsTouches: $showsTouches,
                prefersLowLatency: $prefersLowLatency,
                reconnect: reconnect
            )
        }
    }

    private func reconnect() {
        addCommand("livekit", "reconnect requested")
    }
}
