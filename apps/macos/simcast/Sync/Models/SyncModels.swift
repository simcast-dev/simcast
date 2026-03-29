import Foundation

struct SessionPresence: Codable {
    let sessionId: String
    let userEmail: String
    let startedAt: String
    let simulators: [SimulatorInfo]
    let streamingUdids: [String]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userEmail = "user_email"
        case startedAt = "started_at"
        case simulators
        case streamingUdids = "streaming_udids"
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
