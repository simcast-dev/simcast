import AppKit
import CoreGraphics
import Observation

@Observable
final class ScreenCapturePermission {
    private(set) var status: Status = .undetermined

    enum Status {
        case undetermined
        case granted
        case denied
    }

    func check() {
        if CGPreflightScreenCaptureAccess() {
            status = .granted
        }
    }

    func request() {
        if CGRequestScreenCaptureAccess() {
            status = .granted
        } else {
            status = .denied
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}
