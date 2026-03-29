import ApplicationServices

@MainActor
final class SimulatorInputService {
    private let logger: AppLogger

    init(logger: AppLogger) {
        self.logger = logger
    }

    func injectTap(normalizedX: Double, normalizedY: Double, holdDuration: Double? = nil,
                   pid: pid_t, windowFrame: CGRect? = nil,
                   deviceScreenSize: DeviceProfile.ScreenSize? = nil, udid: String) {
        guard let size = resolveTargetSize(deviceScreenSize: deviceScreenSize, pid: pid, windowFrame: windowFrame) else { return }
        let (x, y) = absoluteCoordinates(nx: normalizedX, ny: normalizedY, in: size)

        // axe over simctl: axe supports richer gestures (long-press with duration,
        // multi-touch, edge swipes) that simctl doesn't offer.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        if let duration = holdDuration {
            proc.arguments = ["touch", "-x", "\(x)", "-y", "\(y)", "--down", "--up", "--delay", "\(duration)", "--udid", udid]
        } else {
            proc.arguments = ["tap", "-x", "\(x)", "-y", "\(y)", "--udid", udid]
        }
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Tap injection failed: \(error.localizedDescription)", udid: udid)
        }
    }

    func injectSwipe(startNX: Double, startNY: Double, endNX: Double, endNY: Double,
                     pid: pid_t, windowFrame: CGRect? = nil,
                     deviceScreenSize: DeviceProfile.ScreenSize? = nil, udid: String) {
        guard let size = resolveTargetSize(deviceScreenSize: deviceScreenSize, pid: pid, windowFrame: windowFrame) else { return }
        let (sx, sy) = absoluteCoordinates(nx: startNX, ny: startNY, in: size)
        let (ex, ey) = absoluteCoordinates(nx: endNX, ny: endNY, in: size)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        proc.arguments = ["swipe", "--start-x", "\(sx)", "--start-y", "\(sy)",
                          "--end-x", "\(ex)", "--end-y", "\(ey)", "--udid", udid]
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Swipe injection failed: \(error.localizedDescription)", udid: udid)
        }
    }

    func captureScreenshot(udid: String) async -> Data? {
        let path = NSTemporaryDirectory() + "simcast_shot_\(udid).png"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        proc.arguments = ["screenshot", "--udid", udid, "--output", path]
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Screenshot capture failed: \(error.localizedDescription)", udid: udid)
            return nil
        }
        proc.waitUntilExit()
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    func injectLabelTap(label: String, udid: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        proc.arguments = ["tap", "--label", label, "--udid", udid]
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Label tap injection failed: \(error.localizedDescription)", udid: udid)
        }
    }

    func typeText(_ text: String, udid: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        proc.arguments = ["type", text, "--udid", udid]
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Text injection failed: \(error.localizedDescription)", udid: udid)
        }
    }

    func performGesture(_ gesture: String, pid: pid_t, windowFrame: CGRect? = nil,
                        deviceScreenSize: DeviceProfile.ScreenSize? = nil, udid: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        var args = ["gesture", gesture]
        if let size = resolveTargetSize(deviceScreenSize: deviceScreenSize, pid: pid, windowFrame: windowFrame) {
            args += ["--screen-width", "\(Int(size.width))", "--screen-height", "\(Int(size.height))"]
        }
        args += ["--udid", udid]
        proc.arguments = args
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Gesture injection failed: \(error.localizedDescription)", udid: udid)
        }
    }

    func pressHardwareButton(_ button: String, udid: String) {
        // Map web button IDs to axe button type names.
        let axeButton: String? = switch button {
        case "home":      "home"
        case "lock":      "lock"
        case "side":      "side-button"
        case "siri":      "siri"
        case "apple_pay": "apple-pay"
        default:           nil
        }
        guard let axeButton else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        proc.arguments = ["button", axeButton, "--udid", udid]
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Hardware button press failed: \(error.localizedDescription)", udid: udid)
        }
    }

    func listApps(udid: String) -> [(bundleId: String, name: String)] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = ["simctl", "listapps", udid]
        let pipe = Pipe()
        proc.standardOutput = pipe
        do {
            try proc.run()
        } catch {
            logger.log(.error, "List apps failed: \(error.localizedDescription)", udid: udid)
            return []
        }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return []
        }
        return plist.compactMap { bundleId, value -> (bundleId: String, name: String)? in
            guard !bundleId.hasPrefix("com.apple") else { return nil }
            let info = value as? [String: Any]
            let name = (info?["CFBundleDisplayName"] as? String)
                ?? (info?["CFBundleName"] as? String)
                ?? bundleId
            return (bundleId, name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func openURL(_ url: String, udid: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = ["simctl", "openurl", udid, url]
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Open URL failed: \(error.localizedDescription)", udid: udid)
        }
        proc.waitUntilExit()
    }

    func sendPushNotification(bundleId: String, title: String?, subtitle: String?, body: String?, badge: Int?, sound: String?, category: String?, silent: Bool, udid: String) {
        var aps: [String: Any] = [:]
        if !silent, let body {
            var alert: [String: String] = ["body": body]
            if let title { alert["title"] = title }
            if let subtitle { alert["subtitle"] = subtitle }
            aps["alert"] = alert
        }
        if silent { aps["content-available"] = 1 }
        if let badge { aps["badge"] = badge }
        if let sound { aps["sound"] = sound }
        if let category { aps["category"] = category }
        let payload: [String: Any] = ["aps": aps]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let path = NSTemporaryDirectory() + "simcast_push_\(UUID().uuidString).json"
        guard (try? data.write(to: URL(fileURLWithPath: path))) != nil else { return }
        defer { try? FileManager.default.removeItem(atPath: path) }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        proc.arguments = ["simctl", "push", udid, bundleId, path]
        do {
            try proc.run()
        } catch {
            logger.log(.error, "Push notification send failed: \(error.localizedDescription)", udid: udid)
            return
        }
        proc.waitUntilExit()
    }

    /// Returns the target coordinate space for axe HID events.
    /// Prefers device screen size (true device points) over AX frame (screen points that vary with zoom).
    private func resolveTargetSize(deviceScreenSize: DeviceProfile.ScreenSize?, pid: pid_t, windowFrame: CGRect?) -> CGSize? {
        if let deviceScreenSize {
            return CGSize(width: deviceScreenSize.width, height: deviceScreenSize.height)
        }
        if let windowFrame {
            return WindowService.findSimDisplayFrame(pid: pid, windowFrame: windowFrame)?.size
        }
        return WindowService.findSimDisplayFrame(pid: pid)?.size
    }

    private func absoluteCoordinates(nx: Double, ny: Double, in size: CGSize) -> (x: Int, y: Int) {
        (Int(nx * size.width), Int(ny * size.height))
    }
}
