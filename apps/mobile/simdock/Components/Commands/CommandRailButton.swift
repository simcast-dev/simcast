//
//  CommandRailButton.swift
//  simdock
//

import SwiftUI

struct CommandRailButton: View {
    var command: SimulatorCommand
    var isActive: Bool
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                DashboardCommandIcon(command: command, size: command == .record ? 17 : 21)
                    .frame(width: 24, height: 24)
            }
            .frame(width: 48, height: 48)
            .foregroundStyle(isActive ? Color.green : Color.primary.opacity(0.78))
            .background {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.12) : Color(.secondarySystemGroupedBackground).opacity(0.82))
            }
            .overlay {
                Circle()
                    .stroke(isActive ? Color.green.opacity(0.32) : Color.white.opacity(0.28), lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simDockGlass(cornerRadius: 24, interactive: true)
        .hoverEffect(.lift)
        .accessibilityLabel(command.title)
        .accessibilityHint(label)
    }
}
