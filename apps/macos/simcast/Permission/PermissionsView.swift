import SwiftUI

struct PermissionsView: View {
    let screenCapture: ScreenCapturePermission
    let accessibility: AccessibilityPermission
    let onContinue: () -> Void

    @State private var pollingScreenCapture = false
    @State private var pollingAccessibility = false

    private var allGranted: Bool {
        screenCapture.status == .granted && accessibility.status == .granted
    }

    var body: some View {
        SetupPage(
            title: "Permissions",
            subtitle: "SimCast requires the following permissions to capture and interact with the iOS Simulator.",
            continueLabel: "Continue",
            canContinue: allGranted,
            onContinue: onContinue
        ) {
            VStack(spacing: 0) {
                PermissionRow(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Capture the iOS Simulator window to stream it live.",
                    isGranted: screenCapture.status == .granted,
                    onAllow: {
                        screenCapture.requestAccess()
                        pollingScreenCapture = true
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                        )
                    }
                )

                Divider()
                    .padding(.horizontal, 16)

                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Detect the Simulator display area and inject touch input from the web.",
                    isGranted: accessibility.status == .granted,
                    onAllow: {
                        accessibility.requestAccess()
                        pollingAccessibility = true
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                )
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 48)

            Text("No need to quit the application — permissions take effect immediately.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.horizontal, 48)
        }
        .onAppear {
            screenCapture.checkSilently()
            accessibility.checkSilently()
        }
        .task(id: pollingScreenCapture) {
            guard pollingScreenCapture else { return }
            await screenCapture.pollUntilGranted()
        }
        .task(id: pollingAccessibility) {
            guard pollingAccessibility else { return }
            await accessibility.pollUntilGranted()
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onAllow: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
            } else {
                Button("Allow") { onAllow() }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    PermissionsView(
        screenCapture: ScreenCapturePermission(),
        accessibility: AccessibilityPermission(),
        onContinue: {}
    )
    .frame(width: 540, height: 460)
}
