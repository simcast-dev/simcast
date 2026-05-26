//
//  LinkCommandSubmenu.swift
//  simdock
//

import SwiftUI

struct LinkCommandSubmenu: View {
    @Binding var linkText: String
    var addCommand: CommandHandler

    private let recentLinks = [
        "firstbites://today",
        "firstbites://shopping",
        "firstbites://recipe/42"
    ]

    var body: some View {
        VStack(spacing: 6) {
            TextField("myapp://path", text: $linkText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.caption)
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(Color(.systemBackground).opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .onSubmit(openLink)

            Button(action: openLink) {
                Text("OPEN")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .foregroundStyle(canOpen ? Color.green : Color.secondary)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(canOpen ? Color.green.opacity(0.12) : Color(.systemBackground).opacity(0.45))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(canOpen ? Color.green.opacity(0.26) : Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canOpen)

            CommandPanelDivider()

            VStack(alignment: .leading, spacing: 5) {
                CommandPanelTitle(title: "Recent")

                ForEach(recentLinks, id: \.self) { link in
                    Button(action: { linkText = link }) {
                        Text(link)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 7)
                            .frame(height: 24)
                            .foregroundStyle(.secondary)
                            .background(Color(.systemBackground).opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var canOpen: Bool {
        !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func openLink() {
        let value = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        addCommand("open_url", value)
        linkText = ""
    }
}
