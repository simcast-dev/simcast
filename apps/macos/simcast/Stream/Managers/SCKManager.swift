import AppKit
import ApplicationServices
import CoreMedia
import ScreenCaptureKit
import Observation
import Supabase

enum StreamError: LocalizedError {
    case invalidWindow(String)
    var errorDescription: String? {
        switch self {
        case .invalidWindow(let detail): return detail
        }
    }
}

@Observable
@MainActor
final class SCKManager {

    private(set) var sessions: [String: StreamSession] = [:]
    var onSessionStopped: ((String) -> Void)?

    var isCapturing: Bool { !sessions.isEmpty }
    var streamingUdids: [String] { Array(sessions.keys) }

    private let supabase: SupabaseClient
    private let logger: AppLogger
    var simulatorService: SimulatorService?

    init(supabase: SupabaseClient, logger: AppLogger) {
        self.supabase = supabase
        self.logger = logger
    }

    func start(window: SCWindow, udid: String) async throws {
        if sessions[udid] != nil { await stop(udid: udid) }

        logger.log(.stream, "starting · \(udid.shortId()) · windowID=\(window.windowID) · title=\"\(window.title ?? "nil")\" · frame=\(Int(window.frame.width))×\(Int(window.frame.height))", udid: udid)

        guard window.frame.width >= 50, window.frame.height >= 50 else {
            throw StreamError.invalidWindow("Window too small: \(Int(window.frame.width))×\(Int(window.frame.height))")
        }

        let scaleFactor = NSScreen.screens.first(where: {
            $0.frame.intersects(window.frame)
        })?.backingScaleFactor ?? 1.0

        let captureRect: CGRect
        if let pid = window.owningApplication?.processID,
           let simFrame = WindowService.findSimDisplayFrame(pid: pid_t(pid), windowFrame: window.frame) {
            captureRect = CGRect(
                x: simFrame.origin.x - window.frame.origin.x,
                y: simFrame.origin.y - window.frame.origin.y,
                width: simFrame.width,
                height: simFrame.height
            )
        } else {
            captureRect = CGRect(origin: .zero, size: window.frame.size)
            logger.log(.stream, "SimDisplayRenderableView not found, capturing full window", udid: udid)
        }

        guard captureRect.width > 0, captureRect.height > 0 else {
            throw StreamError.invalidWindow("Capture area is empty: \(Int(captureRect.width))×\(Int(captureRect.height))")
        }

        logger.log(.stream, "capture config · rect=\(Int(captureRect.origin.x)),\(Int(captureRect.origin.y)) \(Int(captureRect.width))×\(Int(captureRect.height)) · scale=\(scaleFactor) · output=\(Int(captureRect.width * scaleFactor))×\(Int(captureRect.height * scaleFactor))", udid: udid)

        let config = SCStreamConfiguration()
        config.sourceRect = captureRect
        config.width = Int(captureRect.width * scaleFactor)
        config.height = Int(captureRect.height * scaleFactor)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(60))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        config.queueDepth = 5

        let size = CGSize(width: captureRect.width * scaleFactor, height: captureRect.height * scaleFactor)

        let provider = LiveKitProvider(supabase: supabase, logger: logger)
        let preview = PreviewReceiver()
        let session = StreamSession(udid: udid, liveKitProvider: provider, previewReceiver: preview)
        session.captureSize = size

        provider.prepare(size: size)

        let proxy = SCKProxy(receivers: [preview, provider], onStop: { [weak self] in
            Task { @MainActor in
                guard let self, self.sessions[udid] != nil else { return }
                await self.stop(udid: udid)
                self.onSessionStopped?(udid)
            }
        })

        var captureWindow = window
        var stream: SCStream
        do {
            stream = SCStream(
                filter: SCContentFilter(desktopIndependentWindow: captureWindow),
                configuration: config,
                delegate: proxy
            )
            try stream.addStreamOutput(proxy, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream.startCapture()
        } catch {
            logger.log(.stream, "first capture attempt failed, retrying with fresh window · \(error.localizedDescription)", udid: udid)
            try? await simulatorService?.windowService.refresh()
            guard let freshWindow = simulatorService?.windowService.window(for: window.windowID) else {
                throw StreamError.invalidWindow("Window no longer available after retry")
            }
            captureWindow = freshWindow
            stream = SCStream(
                filter: SCContentFilter(desktopIndependentWindow: captureWindow),
                configuration: config,
                delegate: proxy
            )
            try stream.addStreamOutput(proxy, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream.startCapture()
        }

        session.setStream(stream, proxy: proxy)
        logger.log(.stream, "capture started · \(udid.shortId())", udid: udid)

        do {
            provider.onDisconnected = { [weak self] in
                Task { @MainActor in
                    guard let self, self.sessions[udid] != nil else { return }
                    await self.stop(udid: udid)
                    self.onSessionStopped?(udid)
                }
            }
            try await provider.connect(udid: udid)
            sessions[udid] = session
        } catch {
            await session.stopCapture()
            logger.log(.error, "stream failed · \(error.localizedDescription)", udid: udid)
            throw error
        }
    }

    func stop(udid: String) async {
        guard let session = sessions.removeValue(forKey: udid) else { return }
        if session.isRecording { _ = await session.stopRecording() }
        await session.stopCapture()
        session.previewReceiver.sckManagerDidStop()
        logger.log(.stream, "stream stopped · \(udid.shortId())", udid: udid)
    }

    func stopAll() async {
        for udid in Array(sessions.keys) { await stop(udid: udid) }
    }

    func startRecording(udid: String) throws {
        guard let session = sessions[udid] else {
            throw StreamError.invalidWindow("Stream session not found.")
        }
        do {
            try session.startRecording(captureSize: session.captureSize)
            logger.log(.stream, "recording started · \(udid.shortId())", udid: udid)
        } catch {
            logger.log(.error, "recording start failed · \(error.localizedDescription)", udid: udid)
            throw error
        }
    }

    func stopRecording(udid: String) async -> (url: URL, duration: Double)? {
        guard let session = sessions[udid] else { return nil }
        let result = await session.stopRecording()
        if let result {
            logger.log(.stream, "recording stopped · \(String(format: "%.1f", result.duration))s", udid: udid)
        }
        return result
    }
}
