//
//  PushControls.swift
//  simdock
//

import SwiftUI

struct PushControls: View {
    var addCommand: CommandHandler

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Push payload")
                    .font(.subheadline.weight(.semibold))

                Text("First Bites reminder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Send", action: send)
                .buttonStyle(.borderedProminent)
        }
    }

    private func send() {
        addCommand("push", "First Bites reminder")
    }
}
