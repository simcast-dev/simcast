//
//  ControlMode.swift
//  simdock
//

import Foundation

enum ControlMode: String, CaseIterable, Identifiable {
    case tap = "Tap"
    case type = "Type"
    case push = "Push"
    case link = "Link"

    var id: String { rawValue }
}
