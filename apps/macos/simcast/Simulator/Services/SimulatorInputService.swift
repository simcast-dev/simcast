import ApplicationServices

enum SimulatorInputError: LocalizedError {
    case targetUnavailable
    case unsupportedButton(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .targetUnavailable:
            return "Simulator target is unavailable."
        case .unsupportedButton(let button):
            return "Unsupported hardware button: \(button)."
        case .processFailed(let message):
            return message
        }
    }
}

@MainActor
final class SimulatorInputService {
    private let logger: AppLogger

    init(logger: AppLogger) {
        self.logger = logger
    }

    func injectTap(
        normalizedX: Double,
        normalizedY: Double,
        holdDuration: Double? = nil,
        pid: pid_t,
        windowFrame: CGRect? = nil,
        deviceScreenSize: DeviceProfile.ScreenSize? = nil,
        udid: String
    ) throws {
        guard let size = resolveTargetSize(
            deviceScreenSize: deviceScreenSize,
            pid: pid,
            windowFrame: windowFrame
        ) else {
            throw SimulatorInputError.targetUnavailable
        }

        let (x, y) = absoluteCoordinates(nx: normalizedX, ny: normalizedY, in: size)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        if let duration = holdDuration {
            process.arguments = [
                "touch", "-x", "\(x)", "-y", "\(y)",
                "--down", "--up", "--delay", "\(duration)", "--udid", udid
            ]
        } else {
            process.arguments = ["tap", "-x", "\(x)", "-y", "\(y)", "--udid", udid]
        }

        try runProcess(process, failurePrefix: "Tap injection failed", udid: udid)
    }

    func injectSwipe(
        startNX: Double,
        startNY: Double,
        endNX: Double,
        endNY: Double,
        pid: pid_t,
        windowFrame: CGRect? = nil,
        deviceScreenSize: DeviceProfile.ScreenSize? = nil,
        udid: String
    ) throws {
        guard let size = resolveTargetSize(
            deviceScreenSize: deviceScreenSize,
            pid: pid,
            windowFrame: windowFrame
        ) else {
            throw SimulatorInputError.targetUnavailable
        }

        let (sx, sy) = absoluteCoordinates(nx: startNX, ny: startNY, in: size)
        let (ex, ey) = absoluteCoordinates(nx: endNX, ny: endNY, in: size)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        process.arguments = [
            "swipe",
            "--start-x", "\(sx)",
            "--start-y", "\(sy)",
            "--end-x", "\(ex)",
            "--end-y", "\(ey)",
            "--udid", udid
        ]

        try runProcess(process, failurePrefix: "Swipe injection failed", udid: udid)
    }

    func captureScreenshot(udid: String) async throws -> Data {
        let path = NSTemporaryDirectory() + "simcast_shot_\(udid).png"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        process.arguments = ["screenshot", "--udid", udid, "--output", path]
        try runProcess(process, failurePrefix: "Screenshot capture failed", udid: udid)

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            throw SimulatorInputError.processFailed(
                "Screenshot capture failed: the generated file could not be read."
            )
        }

        return data
    }

    func injectLabelTap(label: String, udid: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        process.arguments = ["tap", "--label", label, "--udid", udid]
        try runProcess(process, failurePrefix: "Label tap injection failed", udid: udid)
    }

    func typeText(_ text: String, udid: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        process.arguments = ["type", text, "--udid", udid]
        try runProcess(process, failurePrefix: "Text injection failed", udid: udid)
    }

    func performGesture(
        _ gesture: String,
        pid: pid_t,
        windowFrame: CGRect? = nil,
        deviceScreenSize: DeviceProfile.ScreenSize? = nil,
        udid: String
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        var arguments = ["gesture", gesture]
        if let size = resolveTargetSize(
            deviceScreenSize: deviceScreenSize,
            pid: pid,
            windowFrame: windowFrame
        ) {
            arguments += ["--screen-width", "\(Int(size.width))", "--screen-height", "\(Int(size.height))"]
        }
        arguments += ["--udid", udid]
        process.arguments = arguments

        try runProcess(process, failurePrefix: "Gesture injection failed", udid: udid)
    }

    func pressHardwareButton(_ button: String, udid: String) throws {
        let axeButton: String? = switch button {
        case "home": "home"
        case "lock": "lock"
        case "side": "side-button"
        case "siri": "siri"
        case "apple_pay": "apple-pay"
        default: nil
        }

        guard let axeButton else {
            throw SimulatorInputError.unsupportedButton(button)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/axe")
        process.arguments = ["button", axeButton, "--udid", udid]
        try runProcess(process, failurePrefix: "Hardware button press failed", udid: udid)
    }

    func listApps(udid: String) throws -> [(bundleId: String, name: String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "listapps", udid]
        let output = try runProcess(
            process,
            failurePrefix: "List apps failed",
            udid: udid,
            captureStdout: true
        )

        guard
            let output,
            let plist = try? PropertyListSerialization.propertyList(
                from: output,
                options: [],
                format: nil
            ) as? [String: Any]
        else {
            throw SimulatorInputError.processFailed(
                "List apps failed: the response could not be decoded."
            )
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

    func openURL(_ url: String, udid: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "openurl", udid, url]
        try runProcess(process, failurePrefix: "Open URL failed", udid: udid)
    }

    func sendPushNotification(
        bundleId: String,
        title: String?,
        subtitle: String?,
        body: String?,
        badge: Int?,
        sound: String?,
        category: String?,
        silent: Bool,
        udid: String
    ) throws {
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
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            throw SimulatorInputError.processFailed(
                "Push notification send failed: payload encoding failed."
            )
        }

        let path = NSTemporaryDirectory() + "simcast_push_\(UUID().uuidString).json"
        guard (try? data.write(to: URL(fileURLWithPath: path))) != nil else {
            throw SimulatorInputError.processFailed(
                "Push notification send failed: temporary payload could not be written."
            )
        }

        defer { try? FileManager.default.removeItem(atPath: path) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "push", udid, bundleId, path]
        try runProcess(process, failurePrefix: "Push notification send failed", udid: udid)
    }

    private func resolveTargetSize(
        deviceScreenSize: DeviceProfile.ScreenSize?,
        pid: pid_t,
        windowFrame: CGRect?
    ) -> CGSize? {
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

    @discardableResult
    private func runProcess(
        _ process: Process,
        failurePrefix: String,
        udid: String,
        captureStdout: Bool = false
    ) throws -> Data? {
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            let message = "\(failurePrefix): \(error.localizedDescription)"
            logger.log(.error, message, udid: udid)
            throw SimulatorInputError.processFailed(message)
        }

        process.waitUntilExit()
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let stderrText = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let stdoutText = String(data: stdoutData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = [stderrText, stdoutText]
                .compactMap { $0 }
                .first(where: { !$0.isEmpty }) ?? "exit code \(process.terminationStatus)"
            let message = "\(failurePrefix): \(detail)"
            logger.log(.error, message, udid: udid)
            throw SimulatorInputError.processFailed(message)
        }

        return captureStdout ? stdoutData : nil
    }
}
