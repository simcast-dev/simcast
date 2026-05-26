//
//  TapCommandSubmenu.swift
//  simdock
//

import SwiftUI

struct TapCommandSubmenu: View {
    @Binding var longPressEnabled: Bool
    @Binding var labelText: String
    var addCommand: CommandHandler

    var body: some View {
        VStack(spacing: 8) {
            CommandSubmenuButton(
                title: longPressEnabled ? "Hold On" : "Hold",
                systemImage: "hand.raised",
                isActive: longPressEnabled,
                action: toggleLongPress
            )

            CommandPanelDivider()

            VStack(alignment: .leading, spacing: 5) {
                CommandPanelTitle(title: "Tap by label")

                HStack(spacing: 5) {
                    TextField("e.g. Safari", text: $labelText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.caption)
                        .padding(.horizontal, 7)
                        .frame(height: 30)
                        .background(Color(.systemBackground).opacity(0.56), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                        .onSubmit(sendLabelTap)

                    Button(action: sendLabelTap) {
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .frame(width: 30, height: 30)
                            .foregroundStyle(labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.green)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemBackground).opacity(0.45) : Color.green.opacity(0.12))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.primary.opacity(0.08) : Color.green.opacity(0.26), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Tap by label")
                }
            }
        }
    }

    private func toggleLongPress() {
        longPressEnabled.toggle()
        addCommand("tap", longPressEnabled ? "long press enabled" : "long press disabled")
    }

    private func sendLabelTap() {
        let label = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }

        addCommand("tap", "label \(label)")
        labelText = ""
    }
}
