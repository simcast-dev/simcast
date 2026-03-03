import ScreenCaptureKit

struct Simulator: Identifiable {
    let id: CGWindowID
    let deviceName: String
    let osVersion: String?
    let deviceType: DeviceType
    let window: SCWindow

    enum DeviceType {
        case iPhone, iPad

        var icon: String {
            switch self {
            case .iPhone: "iphone"
            case .iPad:   "ipad"
            }
        }
    }

    init(window: SCWindow) {
        self.id = window.windowID
        self.window = window

        let title = window.title ?? "Simulator"
        let parts = title.components(separatedBy: " \u{2013} ")
        self.deviceName = parts.first ?? title
        self.osVersion = parts.count > 1 ? parts[1] : nil
        self.deviceType = title.contains("iPad") ? .iPad : .iPhone
    }
}
