import CoreGraphics
import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @State private var permission = ScreenCapturePermission()

    var body: some View {
        switch auth.status {
        case .unauthenticated:
            LoginView(auth: auth)
                .frame(width: 540, height: 740)
        case .authenticated:
            switch permission.status {
            case .undetermined:
                PermissionRequestView(permission: permission)
                    .frame(width: 540, height: 740)
            case .granted:
                StreamReadyView()
                    .frame(width: 540, height: 740)
            }
        }
    }
}

#Preview {
    ContentView()
}
