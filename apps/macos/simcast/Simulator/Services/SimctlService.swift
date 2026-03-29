import Foundation

/// A booted iOS Simulator device as reported by `simctl list devices --json`.
struct SimctlDevice {
    let udid: String
    let name: String
    let osName: String
    let osVersion: String
    let deviceTypeIdentifier: String

    /// Human-readable OS label, e.g. "iOS 26.2".
    var osLabel: String { "\(osName) \(osVersion)" }
}

/// Errors that can occur when running or decoding `simctl list devices --json`.
enum SimctlError: LocalizedError {
    case processLaunchFailed(Error)
    case noOutput
    case parseFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .processLaunchFailed(let error): "Failed to launch simctl: \(error.localizedDescription)"
        case .noOutput: "simctl produced no output — is Xcode installed?"
        case .parseFailed: "simctl output could not be parsed"
        case .timeout: "simctl timed out — CoreSimulator may be unresponsive"
        }
    }
}

/// The lifecycle state of a `SimctlService` fetch.
///
/// Using a single enum makes invalid combinations — such as a populated device list
/// coexisting with an error — unrepresentable by construction.
enum SimctlState {
    /// No fetch has been attempted yet (initial value).
    case idle
    /// A fetch is in progress.
    case loading
    /// The last fetch succeeded; the array may be empty if no simulators are booted.
    case ready([SimctlDevice])
    /// The last fetch failed with a typed error; no device list is available.
    case failed(SimctlError)
}

/// Wraps `xcrun simctl list devices --json` and exposes the result as observable state.
///
/// `SimctlService` owns the full lifecycle of a simctl query: it launches the subprocess,
/// decodes the JSON, filters to booted devices only, and publishes the result via `state`.
/// Callers observe `state` (or the convenience `bootedDevices`) rather than calling an async
/// function directly, so SwiftUI views re-render automatically whenever the list changes.
///
/// Concurrent `refresh()` calls are safe — each new call cancels the previous in-flight fetch
/// and replaces it, so only one `xcrun` process is ever running at a time.
///
/// All mutations happen on `@MainActor`, so `state` is safe to read from the main thread
/// without additional synchronisation.
@Observable
@MainActor
final class SimctlService {

    private(set) var state: SimctlState = .idle

    /// Convenience accessor for callers that only need the happy path.
    var bootedDevices: [SimctlDevice] {
        if case .ready(let devices) = state { return devices }
        return []
    }

    private var currentTask: Task<Void, Never>?

    init() {
        Task { await refresh() }
    }

    /// Re-runs `simctl list devices --json` and updates `state`.
    ///
    /// If a fetch is already in progress it is cancelled first; the new fetch then takes over.
    /// `state` transitions through `.loading` before settling on `.ready` or `.failed`.
    func refresh() async {
        currentTask?.cancel()

        let task = Task {
            state = .loading
            do {
                let devices = try await fetchBootedDevices()
                guard !Task.isCancelled else { return }
                state = .ready(devices)
            } catch is CancellationError {
                // A newer refresh superseded this one — leave state unchanged
            } catch let error as SimctlError {
                state = .failed(error)
            } catch {
                state = .failed(.processLaunchFailed(error))
            }
        }
        currentTask = task
        await task.value
    }

    // MARK: - Private

    /// Runs `runSimctl()` with a 10-second deadline.
    ///
    /// Uses `withThrowingTaskGroup` to race the real fetch against a sleep task.
    /// Whichever child task finishes first wins; the other is immediately cancelled.
    /// Throws `SimctlError.timeout` if CoreSimulator stalls past the deadline.
    // Timeout needed because simctl can hang indefinitely on first invocation
    // while Xcode indexes; without it the entire app would block.
    private func fetchBootedDevices() async throws -> [SimctlDevice] {
        try await withThrowingTaskGroup(of: [SimctlDevice].self) { group in
            group.addTask { try await self.runSimctl() }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw SimctlError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Launches `xcrun simctl list devices --json` and parses the result.
    ///
    /// Bridges the `Process` termination callback to async/await via
    /// `withCheckedThrowingContinuation`. If the enclosing task is cancelled,
    /// `withTaskCancellationHandler` calls `process.terminate()` to avoid leaving
    /// a zombie `xcrun` process running in the background.
    private func runSimctl() async throws -> [SimctlDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        // JSON output for reliable machine parsing vs fragile text parsing.
        process.arguments = ["simctl", "list", "devices", "--json"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        let data: Data = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { _ in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if data.isEmpty {
                        continuation.resume(throwing: SimctlError.noOutput)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: SimctlError.processLaunchFailed(error))
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        return try parseBootedDevices(from: data)
    }

    /// Decodes the JSON blob from `simctl list devices --json` into a flat list of booted devices.
    ///
    /// The JSON structure groups devices by CoreSimulator runtime key:
    /// ```json
    /// { "devices": { "com.apple.CoreSimulator.SimRuntime.iOS-26-2": [ { … }, … ] } }
    /// ```
    private func parseBootedDevices(from data: Data) throws -> [SimctlDevice] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else {
            throw SimctlError.parseFailed
        }

        var result: [SimctlDevice] = []

        for (runtimeKey, deviceList) in devices {
            guard let (osName, osVersion) = Self.parseRuntimeKey(runtimeKey) else { continue }

            for device in deviceList {
                // Individual device entries with missing fields are silently skipped —
                // one malformed entry should not hide the rest of the list
                guard
                    let udid = device["udid"] as? String,
                    let name = device["name"] as? String,
                    let state = device["state"] as? String,
                    state == "Booted",
                    let deviceTypeIdentifier = device["deviceTypeIdentifier"] as? String
                else { continue }

                result.append(SimctlDevice(
                    udid: udid,
                    name: name,
                    osName: osName,
                    osVersion: osVersion,
                    deviceTypeIdentifier: deviceTypeIdentifier
                ))
            }
        }

        return result
    }

    /// Extracts the OS name and version from a CoreSimulator runtime key.
    ///
    /// Example: `"com.apple.CoreSimulator.SimRuntime.iOS-26-2"` → `("iOS", "26.2")`
    private static func parseRuntimeKey(_ key: String) -> (String, String)? {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        guard key.hasPrefix(prefix) else { return nil }
        var parts = String(key.dropFirst(prefix.count)).split(separator: "-").map(String.init)
        guard parts.count >= 2 else { return nil }
        let osName = parts.removeFirst()
        let osVersion = parts.joined(separator: ".")
        return (osName, osVersion)
    }
}
