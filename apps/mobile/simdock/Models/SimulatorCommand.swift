//
//  SimulatorCommand.swift
//  simdock
//

import Foundation

enum SimulatorCommand: String, CaseIterable, Identifiable {
    case home
    case lock
    case side
    case tap
    case scroll
    case type
    case push
    case link
    case record
    case screenshot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .lock: "Lock"
        case .side: "Side"
        case .tap: "Tap"
        case .scroll: "Scroll"
        case .type: "Type"
        case .push: "Push"
        case .link: "Link"
        case .record: "Record"
        case .screenshot: "Screenshot"
        }
    }

    var compactTitle: String {
        switch self {
        case .tap: "TAP"
        case .scroll: "SCROLL"
        case .type: "TYPE"
        case .push: "PUSH"
        case .link: "LINK"
        case .record: "REC"
        case .screenshot: "SHOT"
        default: title
        }
    }

    var hasSubmenu: Bool {
        switch self {
        case .tap, .scroll, .type, .push, .link:
            true
        case .home, .lock, .side, .record, .screenshot:
            false
        }
    }

    static let hardwareCommands: [SimulatorCommand] = [.home, .lock, .side]
    static let interactiveCommands: [SimulatorCommand] = [.tap, .scroll, .type, .push, .link]
    static let mediaCommands: [SimulatorCommand] = [.record, .screenshot]
}
