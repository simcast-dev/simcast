import Observation
import ScreenCaptureKit

@Observable
@MainActor
final class SimulatorService {
    private(set) var simulators: [Simulator] = []
    private(set) var isLoading = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            simulators = content.windows
                .filter { $0.owningApplication?.bundleIdentifier == "com.apple.iphonesimulator" }
                .filter { $0.title != nil && !$0.title!.isEmpty }
                .map { Simulator(window: $0) }
        } catch {
            simulators = []
        }
    }
}
