//
//  PushCommandSubmenu.swift
//  simdock
//

import SwiftUI

struct PushCommandSubmenu: View {
    var addCommand: CommandHandler

    var body: some View {
        VStack(spacing: 6) {
            CommandSubmenuButton(
                title: "Demo Alert",
                systemImage: "bell.badge",
                action: { addCommand("push", "demo alert") }
            )

            CommandSubmenuButton(
                title: "Silent Push",
                systemImage: "bell.slash",
                action: { addCommand("push", "silent notification") }
            )

            CommandPanelDivider()

            CommandSubmenuButton(
                title: "Reload Apps",
                systemImage: "arrow.clockwise",
                action: { addCommand("app_list", "reload app targets") }
            )
        }
    }
}
