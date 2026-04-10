import Foundation
import Supabase

let realtimeProtocolVersion = 1

struct SessionPresence: Codable {
    let sessionType: String
    let sessionId: String
    let userEmail: String
    let startedAt: String
    let simulators: [SimulatorInfo]
    let streamingUdids: [String]
    let presenceVersion: Int

    enum CodingKeys: String, CodingKey {
        case sessionType = "session_type"
        case sessionId = "session_id"
        case userEmail = "user_email"
        case startedAt = "started_at"
        case simulators
        case streamingUdids = "streaming_udids"
        case presenceVersion = "presence_version"
    }
}

struct WebDashboardPresence: Codable {
    let sessionType: String
    let dashboardSessionId: String?

    enum CodingKeys: String, CodingKey {
        case sessionType = "session_type"
        case dashboardSessionId = "dashboard_session_id"
    }
}

struct SimulatorInfo: Codable {
    let udid: String
    let name: String
    let osVersion: String
    let deviceTypeIdentifier: String
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case udid
        case name
        case osVersion = "os_version"
        case deviceTypeIdentifier = "device_type_identifier"
        case orderIndex = "order_index"
    }
}

enum RealtimeCommandKind: String, CaseIterable, Sendable {
    case start
    case stop
    case tap
    case swipe
    case button
    case gesture
    case text
    case push
    case appList = "app_list"
    case screenshot
    case startRecording = "start_recording"
    case stopRecording = "stop_recording"
    case openURL = "open_url"
    case clearLogs = "clear_logs"
}

struct RealtimeCommandEnvelope: Codable, Sendable {
    let protocolVersion: Int
    let commandId: String
    let dashboardSessionId: String
    let kind: String
    let udid: String?
    let payload: JSONObject
    let sentAt: String

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case commandId = "command_id"
        case dashboardSessionId = "dashboard_session_id"
        case kind
        case udid
        case payload
        case sentAt = "sent_at"
    }

    var parsedKind: RealtimeCommandKind? {
        RealtimeCommandKind(rawValue: kind)
    }

    func decodePayload<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try payload.decode(as: T.self)
    }
}

struct RealtimeCommandAck: Codable, Sendable {
    let protocolVersion: Int
    let commandId: String
    let dashboardSessionId: String
    let status: String
    let reason: String?
    let receivedAt: String

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case commandId = "command_id"
        case dashboardSessionId = "dashboard_session_id"
        case status
        case reason
        case receivedAt = "received_at"
    }
}

struct RealtimeCommandResult: Codable, Sendable {
    let protocolVersion: Int
    let commandId: String
    let dashboardSessionId: String
    let kind: String
    let udid: String?
    let status: String
    let reason: String?
    let payload: JSONObject?
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case commandId = "command_id"
        case dashboardSessionId = "dashboard_session_id"
        case kind
        case udid
        case status
        case reason
        case payload
        case completedAt = "completed_at"
    }
}

struct RealtimeLogPayload: Codable, Sendable {
    let protocolVersion: Int
    let udid: String
    let category: String
    let message: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case udid
        case category
        case message
        case timestamp
    }
}

struct TapCommandPayload: Codable, Sendable {
    let x: Double?
    let y: Double?
    let vw: Double?
    let vh: Double?
    let longPress: Bool?
    let duration: Double?
    let label: String?
}

struct ButtonCommandPayload: Codable, Sendable {
    let button: String
}

struct GestureCommandPayload: Codable, Sendable {
    let gesture: String
}

struct SwipeCommandPayload: Codable, Sendable {
    let startX: Double
    let startY: Double
    let endX: Double
    let endY: Double
    let vw: Double
    let vh: Double
}

struct TextCommandPayload: Codable, Sendable {
    let text: String
}

struct PushCommandPayload: Codable, Sendable {
    let bundleId: String
    let title: String?
    let subtitle: String?
    let body: String?
    let badge: Int?
    let sound: String?
    let category: String?
    let contentAvailable: Bool?
}

struct OpenURLCommandPayload: Codable, Sendable {
    let url: String
}

struct AppListResultPayload: Codable, Sendable {
    let apps: [AppListItem]
}

struct AppListItem: Codable, Sendable {
    let bundleId: String
    let name: String
}

struct EmptyResultPayload: Codable, Sendable {}
