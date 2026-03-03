import CoreGraphics
import SwiftUI

struct ContentView: View {
    @State private var permission = ScreenCapturePermission()

    var body: some View {
        ZStack {
            switch permission.status {
            case .granted:
                StreamReadyView()
            case .undetermined, .denied:
                PermissionRequestView(permission: permission)
            }
        }
        .frame(width: 540, height: 740)
    }
}

#Preview {
    ContentView()
}
