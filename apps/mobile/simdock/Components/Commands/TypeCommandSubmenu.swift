//
//  TypeCommandSubmenu.swift
//  simdock
//

import SwiftUI

struct TypeCommandSubmenu: View {
    @Binding var text: String
    var addCommand: CommandHandler

    var body: some View {
        VStack(spacing: 6) {
            TextField("Type here...", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption)
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(Color(.systemBackground).opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .onSubmit(send)

            Button(action: send) {
                Text("SEND")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .foregroundStyle(canSend ? Color.green : Color.secondary)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(canSend ? Color.green.opacity(0.12) : Color(.systemBackground).opacity(0.45))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(canSend ? Color.green.opacity(0.26) : Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        addCommand("text", value)
        text = ""
    }
}
