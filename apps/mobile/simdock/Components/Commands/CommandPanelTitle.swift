//
//  CommandPanelTitle.swift
//  simdock
//

import SwiftUI

struct CommandPanelTitle: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
