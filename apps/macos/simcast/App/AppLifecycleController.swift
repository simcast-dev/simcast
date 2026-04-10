import AppKit
import Observation

@Observable
@MainActor
final class AppLifecycleController: NSObject, NSWindowDelegate {
    static let shared = AppLifecycleController()
    static let mainWindowID = "main"

    private(set) var launchedAtLogin = false

    private weak var mainWindow: NSWindow?
    private var hasCenteredMainWindow = false

    func markLaunchedAtLogin() {
        launchedAtLogin = true
    }

    func applyActivationPolicy() {
        let policy: NSApplication.ActivationPolicy =
            AppAppearancePreferences.storedHideDockIcon() ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }

    func configureMainWindow(_ window: NSWindow) {
        let isNewWindow = mainWindow !== window

        mainWindow = window
        window.identifier = NSUserInterfaceItemIdentifier(Self.mainWindowID)
        window.delegate = self

        if !hasCenteredMainWindow {
            window.center()
            hasCenteredMainWindow = true
        }

        if isNewWindow, launchedAtLogin {
            window.orderOut(nil)
        }
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.windows
            .first(where: { $0.identifier?.rawValue == Self.mainWindowID })?
            .makeKeyAndOrderFront(nil)
    }

    func hideMainWindow() {
        mainWindow?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender.identifier?.rawValue == Self.mainWindowID else { return true }
        sender.orderOut(nil)
        return false
    }
}
