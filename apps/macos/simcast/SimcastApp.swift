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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var auth: AuthManager
    @State private var appearancePreferences: AppAppearancePreferences
    @State private var appLifecycle: AppLifecycleController
    @State private var launchAtLoginService: LaunchAtLoginService
    @State private var syncService: SyncService?
    @State private var simulatorService = SimulatorService()
    @State private var sckManager: SCKManager?
    @State private var appLogger: AppLogger
    @State private var showWelcome = true

    init() {
        let auth = AuthManager()
        let logger = AppLogger()
        let appearancePreferences = AppAppearancePreferences.shared
        let appLifecycle = AppLifecycleController.shared
        let launchAtLoginService = LaunchAtLoginService()
        _auth = State(initialValue: auth)
        _appearancePreferences = State(initialValue: appearancePreferences)
        _appLifecycle = State(initialValue: appLifecycle)
        _launchAtLoginService = State(initialValue: launchAtLoginService)
        _appLogger = State(initialValue: logger)
        _showWelcome = State(initialValue: auth.status == .unconfigured)
    }

    var body: some Scene {
        WindowGroup("SimCast", id: AppLifecycleController.mainWindowID) {
            contentView
                .environment(auth)
                .environment(appearancePreferences)
                .environment(appLifecycle)
                .environment(simulatorService)
                .environment(appLogger)
                .background(MainWindowBridge(appLifecycle: appLifecycle))
                .animation(.easeInOut(duration: 0.2), value: auth.status)
                .task {
                    await auth.bootstrap()
                }
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
                        case .launching:
                            break
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
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open SimCast") {
                    appLifecycle.showMainWindow()
                }
            }

            CommandGroup(after: .appInfo) {
                Divider()
                Button("Open SimCast") {
                    appLifecycle.showMainWindow()
                }

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

        MenuBarExtra {
            MenuBarView(
                auth: auth,
                appearancePreferences: appearancePreferences,
                appLifecycle: appLifecycle,
                simulatorService: simulatorService,
                sckManager: sckManager
            )
            .environment(appLogger)
        } label: {
            Label("SimCast", systemImage: "dot.radiowaves.left.and.right")
        }

        Settings {
            SettingsView(
                appearancePreferences: appearancePreferences,
                launchAtLoginService: launchAtLoginService,
                auth: auth
            )
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch auth.status {
        case .launching:
            AppLaunchView(
                title: "Opening SimCast",
                message: auth.launchMessage
            )
            .frame(width: 540, height: 460)
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
            } else {
                AppLaunchView(
                    title: "Preparing Workspace",
                    message: "Connecting the realtime bridge and local simulator services."
                )
                .frame(width: 540, height: 460)
            }
        }
    }
}
