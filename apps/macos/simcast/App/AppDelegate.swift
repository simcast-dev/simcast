import AppKit
import CoreServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appLifecycle = AppLifecycleController.shared

    override init() {
        super.init()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplication(event:replyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }

    deinit {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        appLifecycle.applyActivationPolicy()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        appLifecycle.showMainWindow()
        return true
    }

    @objc
    private func handleOpenApplication(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        if event.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem)) != nil {
            appLifecycle.markLaunchedAtLogin()
        }
    }
}
