import CoreGraphics
import CoreMedia

// Abstracts the streaming backend so capture logic doesn't depend on LiveKit
// directly — allows swapping providers without changing SCKManager.
@MainActor
protocol StreamingProvider: VideoFrameReceiver {
    var isConnected: Bool { get }
    var onDisconnected: (() -> Void)? { get set }
    func prepare(size: CGSize)
    func connect(udid: String) async throws
    func disconnect() async
}

extension StreamingProvider {
    func prepare(size: CGSize) {}
}
