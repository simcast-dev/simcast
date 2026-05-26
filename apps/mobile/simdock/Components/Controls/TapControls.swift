//
//  TapControls.swift
//  simdock
//

import SwiftUI

struct TapControls: View {
    @Binding var isRecording: Bool
    var addCommand: CommandHandler

    var body: some View {
        ControlGroup {
            Button(action: tap) {
                Label("Tap", systemImage: "hand.tap")
            }

            Button(action: swipe) {
                Label("Swipe", systemImage: "arrow.right")
            }

            Button(action: screenshot) {
                Label("Screenshot", systemImage: "camera")
            }

            Button(action: toggleRecording) {
                Label(isRecording ? "Stop" : "Record", systemImage: isRecording ? "stop.circle.fill" : "record.circle")
            }

            HardwareButtonsMenu(addCommand: addCommand)
        }
        .controlGroupStyle(.compactMenu)
    }

    private func tap() {
        addCommand("tap", "tap center")
    }

    private func swipe() {
        addCommand("swipe", "left edge")
    }

    private func screenshot() {
        addCommand("capture", "screenshot saved")
    }

    private func toggleRecording() {
        isRecording.toggle()
        addCommand("record", isRecording ? "recording started" : "recording stopped")
    }
}
