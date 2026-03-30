import SwiftUI

struct ContentView: View {
    @State private var screenCapture = ScreenCapturePermission()
    @State private var accessibility = AccessibilityPermission()
    @AppStorage("permissionsCompleted") private var permissionsCompleted = false

    private var allGranted: Bool {
        screenCapture.status == .granted && accessibility.status == .granted
    }

    var body: some View {
        if allGranted && permissionsCompleted {
            StreamReadyView()
        } else {
            PermissionsView(
                screenCapture: screenCapture,
                accessibility: accessibility,
                onContinue: { permissionsCompleted = true }
            )
        }
    }
}

#Preview {
    ContentView()
}
