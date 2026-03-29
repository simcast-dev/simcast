import Foundation

/// Background actor that owns log storage.
/// All appending and capping happens off the main actor.
// Actor isolation prevents log writes from blocking the main thread/UI,
// which matters when high-frequency frame events generate many log entries.
actor LogWriter {
    private var entries: [LogEntry] = []
    private let cap = 500

    func append(_ entry: LogEntry) -> [LogEntry] {
        entries.append(entry)
        if entries.count > cap {
            entries.removeFirst(entries.count - cap)
        }
        return entries
    }

    func clear() {
        entries.removeAll()
    }
}
