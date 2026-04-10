import Observation
import ServiceManagement

@Observable
@MainActor
final class LaunchAtLoginService {
    var isEnabled = false
    var requiresApproval = false
    var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        let status = SMAppService.mainApp.status
        if enabled, status == .enabled || status == .requiresApproval {
            refresh()
            return
        }

        if !enabled, status == .notRegistered {
            refresh()
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refresh()
    }
}
