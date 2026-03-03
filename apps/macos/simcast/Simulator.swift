import ScreenCaptureKit

struct Simulator: Identifiable {
    let id: CGWindowID
    let title: String
    let window: SCWindow

    init(window: SCWindow) {
        self.id = window.windowID
        self.window = window
        self.title = window.title ?? "Simulator"
    }
}
