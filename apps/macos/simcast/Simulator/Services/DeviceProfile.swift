import Foundation

/// Resolves the physical screen dimensions (in device points) for a given
/// `deviceTypeIdentifier` by reading CoreSimulator device-type profile plists.
///
/// AXe's HID event coordinates are in device points, not macOS screen points.
/// The Simulator window's AX frame varies with zoom level, so we need the true
/// device dimensions for accurate coordinate mapping.
enum DeviceProfile {

    /// Screen size in device points (e.g. 402×874 for iPhone 16 Pro).
    struct ScreenSize {
        let width: CGFloat
        let height: CGFloat
    }

    private static let profilesDirectory = "/Library/Developer/CoreSimulator/Profiles/DeviceTypes"

    private static var cache: [String: ScreenSize] = [:]

    /// Returns the screen size in device points for the given `deviceTypeIdentifier`,
    /// e.g. `"com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"`.
    static func screenSize(for deviceTypeIdentifier: String) -> ScreenSize? {
        if let cached = cache[deviceTypeIdentifier] { return cached }
        loadAllProfiles()
        return cache[deviceTypeIdentifier]
    }

    // MARK: - Private

    /// Scans all `.simdevicetype` bundles once and populates the cache.
    private static func loadAllProfiles() {
        guard cache.isEmpty else { return }

        let fm = FileManager.default
        let url = URL(fileURLWithPath: profilesDirectory)
        guard let bundles = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }

        for bundle in bundles where bundle.pathExtension == "simdevicetype" {
            let infoPlist = bundle.appendingPathComponent("Contents/Info.plist")
            let profilePlist = bundle.appendingPathComponent("Contents/Resources/profile.plist")

            guard let infoData = try? Data(contentsOf: infoPlist),
                  let infoDict = try? PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any],
                  let identifier = infoDict["CFBundleIdentifier"] as? String,
                  let profileData = try? Data(contentsOf: profilePlist),
                  let profileDict = try? PropertyListSerialization.propertyList(from: profileData, format: nil) as? [String: Any],
                  let pixelWidth = profileDict["mainScreenWidth"] as? Int,
                  let pixelHeight = profileDict["mainScreenHeight"] as? Int,
                  let scale = profileDict["mainScreenScale"] as? Int,
                  scale > 0
            else { continue }

            cache[identifier] = ScreenSize(
                width: CGFloat(pixelWidth) / CGFloat(scale),
                height: CGFloat(pixelHeight) / CGFloat(scale)
            )
        }
    }
}
