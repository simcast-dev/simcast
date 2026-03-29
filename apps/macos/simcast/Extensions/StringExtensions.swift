import Foundation

extension String {
    func shortId() -> String {
        String(prefix(8)).uppercased()
    }
}
