//
//  SimcastApp.swift
//  simcast
//
//  Created by Ioan-Florin Matincă on 03.03.2026.
//

import SwiftUI
import AppKit
import Supabase

@main
struct SimcastApp: App {
    // @State preserves object identity across SwiftUI view updates, preventing
    // services from being recreated when the App struct re-evaluates its body.
    @State private var auth: AuthManager
    @State private var syncService: SyncService
    @State private var simulatorService = SimulatorService()
    @State private var sckManager: SCKManager
    @State private var appLogger = AppLogger()

    // Flat initialization order matters: services are created in dependency order
    // so each can receive its dependencies as constructor arguments.
    init() {
        let auth = AuthManager()
        let logger = AppLogger()
        let sckManager = SCKManager(supabase: auth.supabase, logger: logger)
        _auth = State(initialValue: auth)
        _syncService = State(initialValue: SyncService(supabase: auth.supabase, logger: logger))
        _sckManager = State(initialValue: sckManager)
        _appLogger = State(initialValue: logger)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .environment(syncService)
                .environment(simulatorService)
                .environment(sckManager)
                .environment(appLogger)
                .background(WindowCenterer())
                // authStateChanges is an AsyncSequence that delivers auth lifecycle events,
                // letting us react to token refreshes and external sign-outs without polling.
                .task {
                    for await (event, session) in auth.supabase.auth.authStateChanges {
                        switch event {
                        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                            auth.updateSession(session)
                        case .signedOut:
                            auth.clearSession()
                        default:
                            break
                        }
                    }
                }
                .onChange(of: auth.status) { _, newStatus in
                    Task {
                        switch newStatus {
                        case .authenticated:
                            if let userId = auth.userId, let email = auth.currentUserEmail {
                                await syncService.start(userId: userId, email: email)
                                appLogger.syncService = syncService
                            }
                        case .unauthenticated:
                            appLogger.syncService = nil
                            await syncService.stop()
                        }
                    }
                }
        }
        .commands {
            CommandMenu("User") {
                Button("Log Out") {
                    Task { await auth.signOut() }
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
