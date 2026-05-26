//
//  CommandSubmenuButton.swift
//  simdock
//

import SwiftUI

struct CommandSubmenuButton: View {
    var title: String
    var systemImage: String?
    var dashboardIcon: DashboardCommandIcon?
    var isActive = false
    var action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        dashboardIcon: DashboardCommandIcon? = nil,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.dashboardIcon = dashboardIcon
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let dashboardIcon {
                    dashboardIcon
                        .frame(width: 16, height: 16)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(width: 16, height: 16)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .foregroundStyle(isActive ? Color.green : Color.primary.opacity(0.82))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.green.opacity(0.12) : Color(.systemBackground).opacity(0.5))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? Color.green.opacity(0.26) : Color.primary.opacity(0.08), lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
