import SwiftUI

struct AccessibilityRequestView: View {
    let permission: AccessibilityPermission
    @State private var pollingEnabled = false

    var body: some View {
        SetupPage(
            title: "Accessibility",
            subtitle: "SimCast needs Accessibility access to detect the Simulator display area and inject touch input from the web.\nGo to System Settings → Privacy & Security → Accessibility and enable SimCast.",
            continueLabel: "Open System Settings",
            onContinue: openSettings
        ) {
            VStack(spacing: 16) {
                Image(systemName: "accessibility")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(.secondary)

                if pollingEnabled {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Waiting for permission…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { permission.checkSilently() }
        .task(id: pollingEnabled) {
            guard pollingEnabled else { return }
            await permission.pollUntilGranted()
        }
    }

    private func openSettings() {
        pollingEnabled = true
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }
}

#Preview {
    AccessibilityRequestView(permission: AccessibilityPermission())
        .frame(width: 540, height: 460)
}
