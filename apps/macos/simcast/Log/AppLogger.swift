import Observation

/// Observable log store for the UI layer.
/// Writing is dispatched to `LogWriter` (background actor); the published
/// `entries` array is only updated on the main actor.
@Observable
final class AppLogger {
    private(set) var entries: [LogEntry] = []

    weak var syncService: SyncService?

    private let writer = LogWriter()

    var errorCount: Int { entries.filter { $0.category == .error }.count }
    var lastEntry: LogEntry? { entries.last }

    func log(_ category: LogCategory, _ message: String, udid: String? = nil) {
        let entry = LogEntry(category: category, message: message, udid: udid)
        Task {
            let updated = await writer.append(entry)
            entries = updated
        }
        if let udid {
            syncService?.broadcastLog(category: category.rawValue, message: message, udid: udid)
        }
    }

    func clear() {
        Task {
            await writer.clear()
            entries = []
        }
    }
}
