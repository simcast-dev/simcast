import Foundation
import Observation

@Observable
@MainActor
final class AppAppearancePreferences {
    static let shared = AppAppearancePreferences()
    static let hideDockIconKey = "hideDockIcon"

    var hideDockIcon: Bool {
        didSet {
            userDefaults.set(hideDockIcon, forKey: Self.hideDockIconKey)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        hideDockIcon = userDefaults.bool(forKey: Self.hideDockIconKey)
    }

    nonisolated static func storedHideDockIcon(in userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: hideDockIconKey)
    }
}
