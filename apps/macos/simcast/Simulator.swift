import SwiftUI

struct Simulator: Identifiable {
    let id: String
    let name: String
    let deviceType: DeviceType
    let osVersion: String
    let isBooted: Bool

    enum DeviceType {
        case iPhone, iPad

        var icon: String {
            switch self {
            case .iPhone: "iphone"
            case .iPad:   "ipad"
            }
        }
    }
}

extension Simulator {
    static let mocks: [Simulator] = [
        Simulator(id: "1", name: "iPhone 16 Pro",               deviceType: .iPhone, osVersion: "iOS 18.3",     isBooted: true),
        Simulator(id: "2", name: "iPad Pro 13-inch (M4)",       deviceType: .iPad,   osVersion: "iPadOS 18.3",  isBooted: true),
        Simulator(id: "3", name: "iPhone 15",                   deviceType: .iPhone, osVersion: "iOS 17.5",     isBooted: false),
        Simulator(id: "4", name: "iPhone SE (3rd generation)",  deviceType: .iPhone, osVersion: "iOS 18.1",     isBooted: false),
        Simulator(id: "5", name: "iPad mini (A17 Pro)",         deviceType: .iPad,   osVersion: "iPadOS 18.3",  isBooted: false),
    ]
}

#Preview {
    Text(Simulator.mocks.map(\.name).joined(separator: "\n"))
}
