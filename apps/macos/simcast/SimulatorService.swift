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
            async let contentTask = SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            async let devicesTask = SimctlService.bootedDevices()

            let content = try await contentTask
            let devices = await devicesTask

            let windows = content.windows
                .filter { $0.owningApplication?.bundleIdentifier == "com.apple.iphonesimulator" }
                .filter { $0.title != nil && !$0.title!.isEmpty }

            simulators = match(windows: windows, devices: devices)
        } catch {
            simulators = []
        }
    }

    private func match(windows: [SCWindow], devices: [SimctlDevice]) -> [Simulator] {
        var unmatchedWindows = windows
        var unmatchedDevices = devices
        var result: [Simulator] = []

        // Pass 1: Exact unique name match.
        // Window title has no en-dash suffix AND exactly one window has that title AND
        // exactly one device has that name.
        let windowsByTitle = Dictionary(grouping: unmatchedWindows, by: { $0.title ?? "" })
        let devicesByName = Dictionary(grouping: unmatchedDevices, by: { $0.name })

        for (title, windowGroup) in windowsByTitle {
            guard
                !title.contains(" \u{2013} "),
                windowGroup.count == 1,
                let deviceGroup = devicesByName[title],
                deviceGroup.count == 1
            else { continue }

            let window = windowGroup[0]
            let device = deviceGroup[0]
            result.append(Simulator(window: window, device: device, isAmbiguous: false))
            unmatchedWindows.removeAll { $0.windowID == window.windowID }
            unmatchedDevices.removeAll { $0.udid == device.udid }
        }

        // Pass 2: Name + OS version suffix match.
        // Window title is "DeviceName – OSName OSVersion"; parse and match to device.
        var pass2Pairs: [(SCWindow, SimctlDevice)] = []

        for window in unmatchedWindows {
            guard
                let title = window.title,
                let (deviceName, osLabel) = parseWindowSuffix(title),
                let device = unmatchedDevices.first(where: { $0.name == deviceName && $0.osLabel == osLabel })
            else { continue }

            pass2Pairs.append((window, device))
        }

        for (window, device) in pass2Pairs {
            result.append(Simulator(window: window, device: device, isAmbiguous: false))
            unmatchedWindows.removeAll { $0.windowID == window.windowID }
            unmatchedDevices.removeAll { $0.udid == device.udid }
        }

        // Pass 3: Positional fallback for remaining unmatched windows.
        // Sort both lists consistently and pair by index; mark isAmbiguous.
        let sortedWindows = unmatchedWindows.sorted { $0.windowID < $1.windowID }
        let sortedDevices = unmatchedDevices.sorted { $0.udid < $1.udid }

        for (index, window) in sortedWindows.enumerated() {
            let device = index < sortedDevices.count ? sortedDevices[index] : nil
            result.append(Simulator(window: window, device: device, isAmbiguous: true))
        }

        return result
    }

    // "iPhone 17 Pro – iOS 26.2" → ("iPhone 17 Pro", "iOS 26.2")
    private func parseWindowSuffix(_ title: String) -> (String, String)? {
        let separator = " \u{2013} "
        guard let range = title.range(of: separator, options: .backwards) else { return nil }
        return (String(title[..<range.lowerBound]), String(title[range.upperBound...]))
    }
}
