//
//  SimDockScreen.swift
//  simdock
//

import SwiftUI

struct SimDockScreen: View {
    @State private var selectedDevice: SimulatedDevice = .iPhone16Pro
    @State private var expandedCommand: SimulatorCommand?
    @State private var longPressEnabled = false
    @State private var isRecording = false
    @State private var showsTouches = true
    @State private var prefersLowLatency = true
    @State private var labelText = ""
    @State private var typedText = ""
    @State private var linkText = "firstbites://today"

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 10) {
                SimDockHeader(selectedDevice: $selectedDevice)

                StreamPreview(device: selectedDevice, onCanvasTap: addCenterTapCommand) { _ in
                    FloatingCommandPanel(
                        expandedCommand: $expandedCommand,
                        longPressEnabled: $longPressEnabled,
                        isRecording: $isRecording,
                        labelText: $labelText,
                        typedText: $typedText,
                        linkText: $linkText,
                        showsTouches: $showsTouches,
                        prefersLowLatency: $prefersLowLatency,
                        reconnect: reconnect,
                        addCommand: addCommand
                    )
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, horizontalPadding(for: proxy.size.width))
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width < 420 ? 12 : 18
    }

    private func addCenterTapCommand() {
        addCommand("tap", detail: "\(selectedDevice.title) center")
    }

    private func addCommand(_ kind: String, detail: String) {
        // UI-only mock hook for future command logging or haptics.
    }

    private func reconnect() {
        addCommand("livekit", detail: "reconnect requested")
    }
}
