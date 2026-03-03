import SwiftUI

struct PermissionRequestView: View {
    let permission: ScreenCapturePermission

    var body: some View {
        VStack(spacing: 40) {
            PermissionRequestHeader()
            PermissionRequestReasons()
            PermissionRequestCTA(permission: permission)
        }
        .padding(48)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { permission.check() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permission.check()
        }
    }
}

struct PermissionRequestHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 44, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
            }

            Text("Screen Recording Access")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("SimCast captures the iOS Simulator window to stream it live over WebRTC — nothing else is ever recorded.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PermissionRequestReasons: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PermissionReason(
                icon: "iphone",
                tint: .blue,
                title: "Simulator window only",
                detail: "Only the selected iOS Simulator window is captured. Your desktop, other apps, and other windows remain private."
            )
            Divider()
            PermissionReason(
                icon: "dot.radiowaves.forward",
                tint: .orange,
                title: "Real-time H.264 stream",
                detail: "Frames are hardware-encoded and published via LiveKit. Sub-second latency for remote reviewers."
            )
            Divider()
            PermissionReason(
                icon: "hand.tap",
                tint: .green,
                title: "Remote touch support",
                detail: "Viewers can interact with the Simulator. Touch events are forwarded back and injected into the running session."
            )
        }
        .padding(24)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct PermissionRequestCTA: View {
    let permission: ScreenCapturePermission

    var body: some View {
        VStack(spacing: 8) {
            Button("Grant Screen Recording Access") {
                permission.request()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Text("macOS will ask you to confirm\nscreen recording access.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PermissionReason: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    PermissionRequestView(permission: ScreenCapturePermission())
        .frame(width: 540, height: 740)
}
