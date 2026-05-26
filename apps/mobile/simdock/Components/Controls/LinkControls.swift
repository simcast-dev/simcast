//
//  LinkControls.swift
//  simdock
//

import SwiftUI

struct LinkControls: View {
    @Binding var linkText: String
    var addCommand: CommandHandler

    var body: some View {
        HStack(spacing: 10) {
            TextField("URL", text: $linkText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)

            Button("Open", action: open)
                .buttonStyle(.borderedProminent)
        }
    }

    private func open() {
        addCommand("link", linkText.isEmpty ? "firstbites://today" : linkText)
    }
}
