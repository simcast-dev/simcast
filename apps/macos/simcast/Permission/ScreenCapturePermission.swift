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
