//
//  CommandRail.swift
//  simdock
//

import SwiftUI

struct CommandRail: View {
    @Binding var expandedCommand: SimulatorCommand?
    @Binding var isRecording: Bool
    @Binding var showsTouches: Bool
    @Binding var prefersLowLatency: Bool
    var reconnect: () -> Void
    var addCommand: CommandHandler

    var body: some View {
        VStack(spacing: 6) {
            ForEach(SimulatorCommand.hardwareCommands) { command in
                CommandRailButton(
                    command: command,
                    isActive: false,
                    label: command.compactTitle,
                    action: { runImmediate(command) }
                )
            }

            CommandRailGap()

            ForEach(SimulatorCommand.interactiveCommands) { command in
                CommandRailButton(
                    command: command,
                    isActive: expandedCommand == command,
                    label: command.compactTitle,
                    action: { toggle(command) }
                )
            }

            CommandRailGap()

            ForEach(SimulatorCommand.mediaCommands) { command in
                CommandRailButton(
                    command: command,
                    isActive: command == .record && isRecording,
                    label: mediaLabel(for: command),
                    action: { runImmediate(command) }
                )
            }

            CommandRailGap()

            SettingsMenu(
                showsTouches: $showsTouches,
                prefersLowLatency: $prefersLowLatency,
                reconnect: reconnect
            )
        }
    }

    private func toggle(_ command: SimulatorCommand) {
        if expandedCommand == command {
            expandedCommand = nil
        } else {
            expandedCommand = command
        }
    }

    private func runImmediate(_ command: SimulatorCommand) {
        switch command {
        case .home:
            addCommand("button", "home")
        case .lock:
            addCommand("button", "lock")
        case .side:
            addCommand("button", "side")
        case .record:
            isRecording.toggle()
            addCommand("record", isRecording ? "recording started" : "recording stopped")
        case .screenshot:
            addCommand("capture", "screenshot saved")
        case .tap, .scroll, .type, .push, .link:
            toggle(command)
        }
    }

    private func mediaLabel(for command: SimulatorCommand) -> String {
        if command == .record, isRecording {
            return "STOP"
        }

        return command.compactTitle
    }
}
