import AppKit
import SwiftUI

struct MenuBarView: View {
    let auth: AuthManager
    let appearancePreferences: AppAppearancePreferences
    let appLifecycle: AppLifecycleController
    let simulatorService: SimulatorService
    let sckManager: SCKManager?

    @Environment(\.openSettings) private var openSettings

    private var streamCount: Int {
        sckManager?.streamingUdids.count ?? 0
    }

    private var statusText: String {
        switch auth.status {
        case .launching:
            return "Starting up"
        case .unconfigured:
            return "Setup required"
        case .unauthenticated:
            return "Sign in required"
        case .authenticated:
            return streamCount == 0 ? "Ready" : "\(streamCount) live"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SimCast")
                    .font(.headline)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            statusRow(
                title: "Simulators",
                value: auth.status == .authenticated ? "\(simulatorService.simulators.count)" : "—"
            )
            statusRow(
                title: "Live Streams",
                value: auth.status == .authenticated ? "\(streamCount)" : "—"
            )

            if appearancePreferences.hideDockIcon {
                Text("Dock icon hidden until next relaunch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Open SimCast") {
                appLifecycle.showMainWindow()
            }

            Button("Settings…") {
                openSettings()
            }

            Button("Quit SimCast") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}
