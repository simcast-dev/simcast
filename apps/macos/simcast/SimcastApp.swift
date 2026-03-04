//
//  SimcastApp.swift
//  simcast
//
//  Created by Ioan-Florin Matincă on 03.03.2026.
//

import SwiftUI
import AppKit

@main
struct SimcastApp: App {
    @State private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .background(WindowCenterer())
        }
        .commands {
            CommandMenu("User") {
                Button("Log Out") {
                    auth.signOut()
                }
                .disabled(auth.status == .unauthenticated)
            }
        }
        .windowResizability(.contentSize)
    }
}

private struct WindowCenterer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.center()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
