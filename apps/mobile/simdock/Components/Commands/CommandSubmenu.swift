//
//  CommandSubmenu.swift
//  simdock
//

import SwiftUI

struct CommandSubmenu: View {
    var command: SimulatorCommand
    @Binding var longPressEnabled: Bool
    @Binding var labelText: String
    @Binding var typedText: String
    @Binding var linkText: String
    var addCommand: CommandHandler

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(width: 176)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        }
        .simDockGlass(cornerRadius: 18)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var content: some View {
        switch command {
        case .tap:
            TapCommandSubmenu(
                longPressEnabled: $longPressEnabled,
                labelText: $labelText,
                addCommand: addCommand
            )
        case .scroll:
            ScrollCommandSubmenu(addCommand: addCommand)
        case .type:
            TypeCommandSubmenu(text: $typedText, addCommand: addCommand)
        case .push:
            PushCommandSubmenu(addCommand: addCommand)
        case .link:
            LinkCommandSubmenu(linkText: $linkText, addCommand: addCommand)
        case .home, .lock, .side, .record, .screenshot:
            EmptyView()
        }
    }
}
