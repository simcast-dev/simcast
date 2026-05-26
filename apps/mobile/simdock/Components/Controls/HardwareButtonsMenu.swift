//
//  HardwareButtonsMenu.swift
//  simdock
//

import SwiftUI

struct HardwareButtonsMenu: View {
    var addCommand: CommandHandler

    var body: some View {
        Menu {
            Button("Home") { addCommand("button", "home") }
            Button("Lock") { addCommand("button", "lock") }
            Button("Side Button") { addCommand("button", "side button") }
        } label: {
            Label("Buttons", systemImage: "iphone.gen3")
        }
    }
}
