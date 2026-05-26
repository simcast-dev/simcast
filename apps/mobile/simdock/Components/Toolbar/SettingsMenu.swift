//
//  SettingsMenu.swift
//  simdock
//

import SwiftUI

struct SettingsMenu: View {
    @Binding var showsTouches: Bool
    @Binding var prefersLowLatency: Bool
    var reconnect: () -> Void

    var body: some View {
        Menu {
            Toggle("Show touches", isOn: $showsTouches)
            Toggle("Prefer low latency", isOn: $prefersLowLatency)
            Divider()
            Button("Reconnect stream", action: reconnect)
        } label: {
            Image(systemName: "gearshape")
                .font(.title3.weight(.semibold))
                .frame(width: 48, height: 48)
                .contentShape(.circle)
                .simDockGlass(cornerRadius: 24, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }
}
