import ApplicationServices
import Observation
import ScreenCaptureKit

@Observable
@MainActor
final class WindowService {

    private(set) var windows: [SCWindow] = []

    func window(for windowID: CGWindowID) -> SCWindow? {
        windows.first { $0.windowID == windowID }
    }

    func refresh() async throws {
        windows = try await fetchSimulatorWindows()
    }
  
    static func findSimDisplayFrame(pid: pid_t) -> CGRect? {
        findSimDisplayFrame(in: AXUIElementCreateApplication(pid))
    }

    /// Scoped variant: narrows the AX search to the window matching `windowFrame`
    /// so that the correct `iOSContentGroup` is returned when multiple simulators
    /// share the same Simulator process.
    static func findSimDisplayFrame(pid: pid_t, windowFrame: CGRect) -> CGRect? {
        let app = AXUIElementCreateApplication(pid)
        if let axWindow = findAXWindow(in: app, matching: windowFrame),
           let frame = findSimDisplayFrame(in: axWindow) {
            return frame
        }
        return findSimDisplayFrame(in: app)
    }

    // Recursively searches for "iOSContentGroup" subrole — this is the Simulator's
    // actual iOS display area, excluding window chrome, toolbar, and bezels.
    static func findSimDisplayFrame(in element: AXUIElement) -> CGRect? {
        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef) == .success,
           let subrole = subroleRef as? String, subrole == "iOSContentGroup" {
            var frameRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &frameRef) == .success,
               let axValue = frameRef, CFGetTypeID(axValue) == AXValueGetTypeID() {
                var frame = CGRect.zero
                AXValueGetValue(axValue as! AXValue, .cgRect, &frame)
                return frame
            }
        }
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        for child in children {
            if let frame = findSimDisplayFrame(in: child) { return frame }
        }
        return nil
    }

    // MARK: - AX Window Matching

    /// Finds the AX window whose frame matches `targetFrame` within a small tolerance.
    /// Both SCWindow.frame and AXPosition/AXSize use Quartz display coordinates (top-left origin).
    private static func findAXWindow(in app: AXUIElement, matching targetFrame: CGRect) -> AXUIElement? {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return nil }

        let tolerance: CGFloat = 2.0

        for axWindow in axWindows {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posRef) == .success,
                  AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef) == .success,
                  let posValue = posRef, CFGetTypeID(posValue) == AXValueGetTypeID(),
                  let sizeValue = sizeRef, CFGetTypeID(sizeValue) == AXValueGetTypeID()
            else { continue }

            var position = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

            if abs(position.x - targetFrame.origin.x) <= tolerance,
               abs(position.y - targetFrame.origin.y) <= tolerance,
               abs(size.width - targetFrame.width) <= tolerance,
               abs(size.height - targetFrame.height) <= tolerance {
                return axWindow
            }
        }
        return nil
    }

    // MARK: - Private

    private func fetchSimulatorWindows() async throws -> [SCWindow] {
        // Both flags false: include desktop windows and off-screen windows so we
        // capture Simulator windows regardless of their visibility state.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false )
        return content.windows
            .filter { $0.owningApplication?.bundleIdentifier == "com.apple.iphonesimulator" }
            .filter { $0.frame.width >= 50 && $0.frame.height >= 50 }
    }
}
