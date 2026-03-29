import CoreGraphics
import Observation
import ScreenCaptureKit

@Observable
final class ScreenCapturePermission {
    private(set) var status: Status = .undetermined

    enum Status {
        case undetermined
        case granted
    }

    func checkSilently() {
        if CGPreflightScreenCaptureAccess() {
            status = .granted
        }
    }

    // Polling because macOS doesn't provide a notification when screen capture
    // permission is granted; must check periodically until the user approves.
    func pollUntilGranted() async {
        while !Task.isCancelled {
            if await canCapture() {
                status = .granted
                break
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func canCapture() async -> Bool {
        await withCheckedContinuation { continuation in
            SCShareableContent.getWithCompletionHandler { content, _ in
                continuation.resume(returning: content != nil)
            }
        }
    }
}
