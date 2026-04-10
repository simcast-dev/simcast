import AppKit
import SwiftUI

struct MainWindowBridge: NSViewRepresentable {
    let appLifecycle: AppLifecycleController

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            appLifecycle.configureMainWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            appLifecycle.configureMainWindow(window)
        }
    }
}
