//
//  SimulatorGesture.swift
//  simdock
//

import Foundation

enum SimulatorGesture: String, Identifiable {
    case scrollUp = "scroll-up"
    case scrollDown = "scroll-down"
    case scrollLeft = "scroll-left"
    case scrollRight = "scroll-right"
    case swipeFromTopEdge = "swipe-from-top-edge"
    case swipeFromBottomEdge = "swipe-from-bottom-edge"
    case swipeFromLeftEdge = "swipe-from-left-edge"
    case swipeFromRightEdge = "swipe-from-right-edge"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scrollUp: "Scroll Up"
        case .scrollDown: "Scroll Down"
        case .scrollLeft: "Scroll Left"
        case .scrollRight: "Scroll Right"
        case .swipeFromTopEdge: "Top Edge"
        case .swipeFromBottomEdge: "Bottom Edge"
        case .swipeFromLeftEdge: "Left Edge"
        case .swipeFromRightEdge: "Right Edge"
        }
    }
}
