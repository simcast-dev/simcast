import SwiftUI

struct ContentView: View {
    @State private var screenCapture = ScreenCapturePermission()
    @State private var accessibility = AccessibilityPermission()
    @AppStorage("permissionsCompleted") private var permissionsCompleted = false
    @State private var hasResolvedPermissions = false

    private var allGranted: Bool {
        screenCapture.status == .granted && accessibility.status == .granted
    }

    var body: some View {
        Group {
            if !hasResolvedPermissions {
                AppLaunchView(
                    title: "Preparing SimCast",
                    message: "Checking local permissions and simulator access."
                )
            } else if allGranted && permissionsCompleted {
                StreamReadyView()
            } else {
                PermissionsView(
                    screenCapture: screenCapture,
                    accessibility: accessibility,
                    onContinue: { permissionsCompleted = true }
                )
            }
        }
        .task {
            guard !hasResolvedPermissions else { return }
            screenCapture.checkSilently()
            accessibility.checkSilently()
            hasResolvedPermissions = true
        }
    }
}

#Preview {
    ContentView()
}
