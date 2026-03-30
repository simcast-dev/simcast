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
    @State private var auth: AuthManager
    @State private var syncService: SyncService?
    @State private var simulatorService = SimulatorService()
    @State private var sckManager: SCKManager?
    @State private var appLogger: AppLogger
    @State private var showWelcome = true

    init() {
        let auth = AuthManager()
        let logger = AppLogger()
        _auth = State(initialValue: auth)
        _appLogger = State(initialValue: logger)
        _showWelcome = State(initialValue: auth.status == .unconfigured)
    }

    var body: some Scene {
        WindowGroup {
            contentView
                .environment(auth)
                .environment(simulatorService)
                .environment(appLogger)
                .background(WindowCenterer())
                .task(id: auth.supabase != nil) {
                    guard let supabase = auth.supabase else { return }
                    for await (event, session) in supabase.auth.authStateChanges {
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
                            if let supabase = auth.supabase {
                                if syncService == nil {
                                    syncService = SyncService(supabase: supabase, logger: appLogger)
                                }
                                if sckManager == nil {
                                    sckManager = SCKManager(supabase: supabase, logger: appLogger)
                                }
                            }
                            if let userId = auth.userId, let email = auth.currentUserEmail {
                                await syncService?.start(userId: userId, email: email)
                                appLogger.syncService = syncService
                            }
                        case .unauthenticated:
                            appLogger.syncService = nil
                            await syncService?.stop()
                        case .unconfigured:
                            appLogger.syncService = nil
                            await syncService?.stop()
                            await sckManager?.stopAll()
                            syncService = nil
                            sckManager = nil
                            showWelcome = true
                        }
                    }
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Sign Out") {
                    Task { await auth.signOut() }
                }
                .disabled(auth.status != .authenticated)

                Button("Remove Server Configuration") {
                    auth.eraseConfiguration()
                }
                .disabled(auth.status == .unconfigured)
            }
        }
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var contentView: some View {
        switch auth.status {
        case .unconfigured:
            if showWelcome {
                WelcomeView(onContinue: { showWelcome = false })
                    .frame(width: 540, height: 460)
            } else {
                ConfigurationView(auth: auth, onBack: { showWelcome = true })
                    .frame(width: 540, height: 460)
            }
        case .unauthenticated:
            LoginView(auth: auth)
                .frame(width: 540, height: 460)
        case .authenticated:
            if let syncService, let sckManager {
                ContentView()
                    .environment(syncService)
                    .environment(sckManager)
                    .frame(width: 540, height: 460)
            }
        }
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
