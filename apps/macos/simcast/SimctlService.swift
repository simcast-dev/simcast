import Foundation

struct SimctlDevice {
    let udid: String
    let name: String
    let osName: String
    let osVersion: String
    let deviceTypeIdentifier: String

    var osLabel: String { "\(osName) \(osVersion)" }
}

enum SimctlService {
    static func bootedDevices() async -> [SimctlDevice] {
        guard let data = await runSimctl() else { return [] }
        return parse(data)
    }

    private static func runSimctl() async -> Data? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "list", "devices", "--json"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data.isEmpty ? nil : data)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func parse(_ data: Data) -> [SimctlDevice] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else { return [] }

        var result: [SimctlDevice] = []

        for (runtimeKey, deviceList) in devices {
            guard let (osName, osVersion) = parseRuntimeKey(runtimeKey) else { continue }

            for device in deviceList {
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

    // "com.apple.CoreSimulator.SimRuntime.iOS-26-2" → ("iOS", "26.2")
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
