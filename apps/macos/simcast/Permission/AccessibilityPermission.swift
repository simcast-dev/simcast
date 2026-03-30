import ApplicationServices
import Observation

@Observable
final class AccessibilityPermission {
    private(set) var status: Status = .undetermined

    enum Status {
        case undetermined
        case granted
    }

    func checkSilently() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            status = .granted
        }
    }

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func pollUntilGranted() async {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        while !Task.isCancelled {
            if AXIsProcessTrustedWithOptions(options) {
                status = .granted
                break
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
