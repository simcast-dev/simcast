import ScreenCaptureKit

struct Simulator: Identifiable {
    let id: String          // udid when matched; "\(windowID)" otherwise
    let udid: String?
    let title: String       // device name only, en-dash suffix stripped
    let osVersion: String?  // "iOS 26.2" — shown when disambiguation is needed
    let window: SCWindow
    let isAmbiguous: Bool   // true when matched by positional fallback

    init(window: SCWindow, device: SimctlDevice?, isAmbiguous: Bool) {
        self.window = window
        self.udid = device?.udid
        self.id = device?.udid ?? "\(window.windowID)"
        self.isAmbiguous = isAmbiguous
        self.osVersion = device.map { "\($0.osName) \($0.osVersion)" }

        let rawTitle = window.title ?? "Simulator"
        if let range = rawTitle.range(of: " \u{2013} ", options: .backwards) {
            self.title = String(rawTitle[..<range.lowerBound])
        } else {
            self.title = rawTitle
        }
    }
}
