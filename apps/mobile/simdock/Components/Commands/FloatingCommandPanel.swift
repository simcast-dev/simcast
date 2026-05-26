//
//  FloatingCommandPanel.swift
//  simdock
//

import SwiftUI

struct FloatingCommandPanel: View {
    @Binding var expandedCommand: SimulatorCommand?
    @Binding var longPressEnabled: Bool
    @Binding var isRecording: Bool
    @Binding var labelText: String
    @Binding var typedText: String
    @Binding var linkText: String
    @Binding var showsTouches: Bool
    @Binding var prefersLowLatency: Bool
    var reconnect: () -> Void
    var addCommand: CommandHandler

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let expandedCommand, expandedCommand.hasSubmenu {
                CommandSubmenu(
                    command: expandedCommand,
                    longPressEnabled: $longPressEnabled,
                    labelText: $labelText,
                    typedText: $typedText,
                    linkText: $linkText,
                    addCommand: addCommand
                )
                .transition(.opacity)
            }

            CommandRail(
                expandedCommand: $expandedCommand,
                isRecording: $isRecording,
                showsTouches: $showsTouches,
                prefersLowLatency: $prefersLowLatency,
                reconnect: reconnect,
                addCommand: addCommand
            )
        }
        .frame(width: 244, alignment: .trailing)
        .animation(.easeInOut(duration: 0.16), value: expandedCommand)
        .accessibilityElement(children: .contain)
    }
}
