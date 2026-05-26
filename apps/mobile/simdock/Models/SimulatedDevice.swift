//
//  SimulatedDevice.swift
//  simdock
//

import CoreGraphics
import Foundation

enum SimulatedDevice: String, CaseIterable, Identifiable {
    case iPhone16Pro
    case iPhone16
    case iPhoneSE

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iPhone16Pro: "iPhone 16 Pro"
        case .iPhone16: "iPhone 16"
        case .iPhoneSE: "iPhone SE"
        }
    }

    var fullName: String { title }

    var osVersion: String {
        switch self {
        case .iPhone16Pro, .iPhone16: "iOS 18.6"
        case .iPhoneSE: "iOS 18.0"
        }
    }

    var statusText: String {
        switch self {
        case .iPhone16Pro: "Streaming"
        case .iPhone16: "Ready"
        case .iPhoneSE: "Booted"
        }
    }

    var connectionSummary: String {
        switch self {
        case .iPhone16Pro: "Live stream"
        case .iPhone16: "Waiting for stream"
        case .iPhoneSE: "Idle"
        }
    }

    var latencyText: String {
        switch self {
        case .iPhone16Pro: "32 ms"
        case .iPhone16: "—"
        case .iPhoneSE: "—"
        }
    }

    var frameRateText: String {
        switch self {
        case .iPhone16Pro: "60 fps"
        case .iPhone16: "Ready"
        case .iPhoneSE: "Booted"
        }
    }

    var hostText: String {
        "Mac mini"
    }

    var identifierText: String {
        switch self {
        case .iPhone16Pro: "iPhone-16-Pro"
        case .iPhone16: "iPhone-16"
        case .iPhoneSE: "iPhone-SE"
        }
    }

    var symbolName: String {
        "iphone"
    }

    var displayAspectRatio: CGFloat {
        0.46
    }

    var cornerRadius: CGFloat {
        44
    }
}
