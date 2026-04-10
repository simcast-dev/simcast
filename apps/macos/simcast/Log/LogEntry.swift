import SwiftUI

struct LogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: LogCategory
    let message: String
    let udid: String?

    init(category: LogCategory, message: String, udid: String? = nil) {
        self.id = UUID()
        self.timestamp = .now
        self.category = category
        self.message = message
        self.udid = udid
    }
}

enum LogCategory: String, CaseIterable, Sendable {
    case stream
    case liveKit = "livekit"
    case presence
    case command
    case error

    var symbol: String {
        switch self {
        case .stream:   return "●"
        case .liveKit:  return "↑"
        case .presence: return "⬡"
        case .command:  return "⚡"
        case .error:    return "✕"
        }
    }

    var label: String {
        switch self {
        case .stream:   return "stream  "
        case .liveKit:  return "livekit "
        case .presence: return "presence"
        case .command:  return "cmd     "
        case .error:    return "error   "
        }
    }

    var color: Color {
        switch self {
        case .stream:   return Color(red: 0.10, green: 0.60, blue: 0.30)
        case .liveKit:  return Color(red: 0.15, green: 0.45, blue: 0.85)
        case .presence: return Color(red: 0.75, green: 0.45, blue: 0.05)
        case .command:  return Color(red: 0.55, green: 0.25, blue: 0.85)
        case .error:    return Color(red: 0.85, green: 0.15, blue: 0.15)
        }
    }
}
