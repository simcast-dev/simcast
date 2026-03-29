import Observation
import ScreenCaptureKit

/// Coordinates `WindowService` and `SimctlService` to produce a matched list of
/// `Simulator` values — each pairing a live `SCWindow` with its `SimctlDevice`.
///
/// ## Refresh lifecycle
///
/// `refresh()` runs both fetches concurrently via `async let`, then calls `match(_:_:)`.
/// A re-entrancy guard prevents overlapping executions: a second call while one is in
/// flight is a no-op.
///
/// `simctlService` and `windowService` are public so callers can observe their individual
/// states (e.g. to surface a "simctl failed" message or iterate raw windows).
///
/// ## Error handling
///
/// - `simctlService` failures are surfaced through `simctlService.state` (.failed).
///   `bootedDevices` returns `[]` on failure, so `match` simply produces no results.
/// - `windowService` failures (e.g. screen-recording permission denied) cause
///   `simulators` to be set to `[]`. The underlying error is available via
///   `windowService` if callers need to distinguish "no simulators" from "fetch failed".
@Observable
@MainActor
final class SimulatorService {
    private(set) var simulators: [Simulator] = []
    private(set) var isLoading = false
    let simctlService = SimctlService()
    let windowService = WindowService()

    private var refreshTask: Task<Void, Never>?

    /// Fetches windows and devices concurrently, then matches them.
    ///
    /// Re-entrant calls while a refresh is in flight are ignored — the in-flight
    /// refresh will update `simulators` when it completes.
    func refresh() async {
        if let existing = refreshTask {
            await existing.value
            return
        }
        await runRefresh()
    }

    func forceRefresh() async {
        if let existing = refreshTask {
            existing.cancel()
            refreshTask = nil
        }
        await runRefresh()
    }

    private func runRefresh() async {
        let task = Task {
            defer { refreshTask = nil }

            isLoading = true
            defer { isLoading = false }

            do {
                async let windowsTask: Void = windowService.refresh()
                await simctlService.refresh()
                try await windowsTask

                simulators = match(windows: windowService.windows, devices: simctlService.bootedDevices)
            } catch {
                simulators = []
            }
        }
        refreshTask = task
        await task.value
    }

    // MARK: - Private

    /// Matches SCWindows to SimctlDevices using two passes, from most-specific to least.
    ///
    /// The Simulator app titles windows differently depending on whether multiple
    /// devices with the same name are booted simultaneously:
    ///
    ///   - One "iPhone 16 Pro" booted on iOS 26.0:
    ///       window title → "iPhone 16 Pro"
    ///
    ///   - Two "iPhone 16 Pro" booted, one on iOS 26.0, one on iOS 18.4:
    ///       window titles → "iPhone 16 Pro – iOS 26.0"
    ///                        "iPhone 16 Pro – iOS 18.4"
    ///
    /// **Pass 1 — name + OS suffix (most specific)**
    ///
    /// Handles the disambiguated case. `parseWindowSuffix` splits on ` – ` to extract
    /// device name and OS label, then looks for an exact match in `bootedDevices`.
    ///
    ///   parseWindowSuffix("iPhone 16 Pro – iOS 26.0")  → ("iPhone 16 Pro", "iOS 26.0")
    ///   parseWindowSuffix("iPhone 16 Pro – iOS 18.4")  → ("iPhone 16 Pro", "iOS 18.4")
    ///   parseWindowSuffix("iPhone 16 Pro")             → nil  (no separator → falls to Pass 2)
    ///
    /// **Pass 2 — exact name match (less specific)**
    ///
    /// Handles the common single-device case. A window whose title has no ` – ` separator
    /// is matched against `bootedDevices` by name, but only when exactly one device has
    /// that name. If two devices share the same name and neither has an OS suffix in its
    /// title, both are left unmatched (ambiguous; this state is transient while Simulator
    /// is still rendering the disambiguated titles).
    ///
    /// Windows and devices that survive both passes are silently dropped — no `Simulator`
    /// is created for them.
    private func match(windows: [SCWindow], devices: [SimctlDevice]) -> [Simulator] {
        var unmatchedWindows = windows
        var unmatchedDevices = devices
        var result: [Simulator] = []

        // Pass 1: name + OS suffix — "iPhone 16 Pro – iOS 26.0"
        var remaining: [SCWindow] = []
        for window in unmatchedWindows {
            guard
                let title = window.title,
                let (deviceName, osLabel) = parseWindowSuffix(title),
                let device = unmatchedDevices.first(where: { $0.name == deviceName && $0.osLabel == osLabel })
            else {
                remaining.append(window)
                continue
            }
            result.append(Simulator(window: window, device: device, isAmbiguous: false))
            unmatchedDevices.removeAll { $0.udid == device.udid }
        }
        unmatchedWindows = remaining

        // Pass 2: exact name match — "iPhone 16 Pro" — only when unambiguous (one device).
        // Windows with a ` – ` separator that went unmatched in Pass 1 are skipped here;
        // they represent a device that simctl didn't report as booted.
        // Empty-titled windows (title == "") produce no devicesByName hit and are dropped.
        let windowsByTitle = Dictionary(grouping: unmatchedWindows, by: { $0.title ?? "" })
        let devicesByName = Dictionary(grouping: unmatchedDevices, by: { $0.name })

        for (title, windowGroup) in windowsByTitle {
            guard
                !title.contains(" \u{2013} "),
                let deviceGroup = devicesByName[title],
                deviceGroup.count == 1
            else { continue }

            result.append(Simulator(window: windowGroup[0], device: deviceGroup[0], isAmbiguous: false))
            unmatchedDevices.removeAll { $0.udid == deviceGroup[0].udid }
        }

        return result.sorted {
            if $0.title != $1.title { return $0.title < $1.title }
            let aOS = $0.osVersion ?? ""; let bOS = $1.osVersion ?? ""
            if aOS != bOS { return aOS < bOS }
            return ($0.udid ?? "") < ($1.udid ?? "")
        }
    }

    /// Splits a disambiguated Simulator window title into device name and OS label.
    ///
    /// Simulator appends ` – <OS> <version>` when multiple devices with the same name
    /// are booted. The split uses the last occurrence of ` – ` so device names that
    /// themselves contain ` – ` (unusual but possible) are preserved intact.
    ///
    ///   "iPhone 16 Pro – iOS 26.0"          → ("iPhone 16 Pro", "iOS 26.0")
    ///   "iPhone 16 Pro – iOS 18.4"          → ("iPhone 16 Pro", "iOS 18.4")
    ///   "iPad Pro 13-inch – iPadOS 26.0"    → ("iPad Pro 13-inch", "iPadOS 26.0")
    ///   "iPhone 16 Pro"                     → nil
    private func parseWindowSuffix(_ title: String) -> (String, String)? {
        let separator = " \u{2013} "
        guard let range = title.range(of: separator, options: .backwards) else { return nil }
        return (String(title[..<range.lowerBound]), String(title[range.upperBound...]))
    }
}
