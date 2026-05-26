//
//  TypeControls.swift
//  simdock
//

import SwiftUI

struct TypeControls: View {
    @Binding var text: String
    var addCommand: CommandHandler

    var body: some View {
        HStack(spacing: 10) {
            TextField("Text to type", text: $text)
                .textFieldStyle(.roundedBorder)

            Button("Send", action: send)
                .buttonStyle(.borderedProminent)
        }
    }

    private func send() {
        let value = text.isEmpty ? "hello" : text
        addCommand("text", value)
        text = ""
    }
}
