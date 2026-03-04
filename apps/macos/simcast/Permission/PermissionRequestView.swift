import SwiftUI

struct PermissionRequestView: View {
    let permission: ScreenCapturePermission
    @State private var pollingEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Spacer()

                appIcon

                VStack(spacing: 12) {
                    Text("Enable Screen Recording")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("SimCast needs to capture the iOS Simulator window to stream it live. Grant access in **System Settings → Privacy & Security → Screen Recording**.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Placeholder — replace with a screenshot image later
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.10))
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .overlay(
                        Text("Screenshot placeholder")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    )

                Spacer()
            }
            .padding(.horizontal, 40)

            Button("Allow Access") {
                pollingEnabled = true
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 40)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { permission.checkSilently() }
        .task(id: pollingEnabled) {
            guard pollingEnabled else { return }
            await permission.pollUntilGranted()
        }
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 36, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
        }
    }
}

#Preview {
    PermissionRequestView(permission: ScreenCapturePermission())
        .frame(width: 540, height: 740)
}
