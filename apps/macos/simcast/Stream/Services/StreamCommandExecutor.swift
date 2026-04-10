import Foundation
import ScreenCaptureKit

@MainActor
final class StreamCommandExecutor {
    private let simulatorService: SimulatorService
    private let sckManager: SCKManager
    private let syncService: SyncService
    private let logger: AppLogger
    private let inputService: SimulatorInputService

    init(
        simulatorService: SimulatorService,
        sckManager: SCKManager,
        syncService: SyncService,
        logger: AppLogger
    ) {
        self.simulatorService = simulatorService
        self.sckManager = sckManager
        self.syncService = syncService
        self.logger = logger
        self.inputService = SimulatorInputService(logger: logger)
    }

    func handle(_ command: RealtimeCommandEnvelope) async {
        guard let kind = command.parsedKind else { return }

        switch kind {
        case .start:
            await startStream(command)
        case .stop:
            await stopStream(command)
        case .clearLogs:
            logger.clear()
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        case .tap:
            await performTap(command)
        case .swipe:
            await performSwipe(command)
        case .button:
            await pressButton(command)
        case .gesture:
            await performGesture(command)
        case .text:
            await typeText(command)
        case .push:
            await sendPush(command)
        case .appList:
            await listApps(command)
        case .screenshot:
            await captureScreenshot(command)
        case .startRecording:
            await startRecording(command)
        case .stopRecording:
            await stopRecording(command)
        case .openURL:
            await openURL(command)
        }
    }

    private func startStream(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        if sckManager.sessions[udid] != nil {
            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
            return
        }

        await simulatorService.forceRefresh()
        guard let simulator = simulator(for: udid),
              let window = simulatorService.windowService.window(for: simulator.windowID) else {
            let knownUdids = simulatorService.simulators.compactMap(\.udid).map { $0.shortId() }.sorted()
            logger.log(
                .error,
                "start failed · simulator or window not found for \(udid.shortId()) · known=\(knownUdids)",
                udid: udid
            )
            await syncService.broadcastFailure(for: command, reason: "Simulator or window not found.")
            return
        }

        do {
            try await sckManager.start(window: window, udid: udid)
            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            logger.log(.error, "start failed · \(error.localizedDescription)", udid: udid)
            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func stopStream(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        await sckManager.stop(udid: udid)
        await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
        await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
    }

    private func performTap(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let payload = try command.decodePayload(as: TapCommandPayload.self)
            if let label = payload.label {
                try inputService.injectLabelTap(label: label, udid: udid)
                await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
                return
            }

            guard let x = payload.x, let y = payload.y else {
                await syncService.broadcastFailure(for: command, reason: "Tap payload is missing coordinates.")
                return
            }

            let holdDuration = payload.longPress == true ? payload.duration : nil
            try inputService.injectTap(
                normalizedX: x,
                normalizedY: y,
                holdDuration: holdDuration,
                pid: pid(for: udid),
                windowFrame: windowFrame(for: udid),
                deviceScreenSize: deviceScreenSize(for: udid),
                udid: udid
            )
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func performSwipe(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let payload = try command.decodePayload(as: SwipeCommandPayload.self)
            guard payload.vw > 0, payload.vh > 0 else {
                await syncService.broadcastFailure(for: command, reason: "Swipe payload has an invalid viewport.")
                return
            }

            try inputService.injectSwipe(
                startNX: payload.startX / payload.vw,
                startNY: payload.startY / payload.vh,
                endNX: payload.endX / payload.vw,
                endNY: payload.endY / payload.vh,
                pid: pid(for: udid),
                windowFrame: windowFrame(for: udid),
                deviceScreenSize: deviceScreenSize(for: udid),
                udid: udid
            )
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func pressButton(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let payload = try command.decodePayload(as: ButtonCommandPayload.self)
            try inputService.pressHardwareButton(payload.button, udid: udid)
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func performGesture(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let payload = try command.decodePayload(as: GestureCommandPayload.self)
            try inputService.performGesture(
                payload.gesture,
                pid: pid(for: udid),
                windowFrame: windowFrame(for: udid),
                deviceScreenSize: deviceScreenSize(for: udid),
                udid: udid
            )
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func typeText(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let payload = try command.decodePayload(as: TextCommandPayload.self)
            try inputService.typeText(payload.text, udid: udid)
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func sendPush(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let payload = try command.decodePayload(as: PushCommandPayload.self)
            try inputService.sendPushNotification(
                bundleId: payload.bundleId,
                title: payload.title,
                subtitle: payload.subtitle,
                body: payload.body,
                badge: payload.badge,
                sound: payload.sound,
                category: payload.category,
                silent: payload.contentAvailable == true,
                udid: udid
            )
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func listApps(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let apps = try inputService.listApps(udid: udid).map {
                AppListItem(bundleId: $0.bundleId, name: $0.name)
            }
            await syncService.broadcastResult(
                for: command,
                status: "ok",
                payload: AppListResultPayload(apps: apps)
            )
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func captureScreenshot(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        guard let session = sckManager.sessions[udid],
              let simulator = simulator(for: udid) else {
            await syncService.broadcastFailure(for: command, reason: "Screenshot capture failed.")
            return
        }

        do {
            let data = try await inputService.captureScreenshot(udid: udid)
            try await session.liveKitProvider.uploadScreenshot(
                data,
                simulatorName: simulator.title,
                simulatorUdid: udid
            )
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func startRecording(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        guard sckManager.sessions[udid] != nil else {
            await syncService.broadcastFailure(for: command, reason: "Stream is not active for this simulator.")
            return
        }

        do {
            try sckManager.startRecording(udid: udid)
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func stopRecording(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        guard let session = sckManager.sessions[udid],
              let simulator = simulator(for: udid),
              let result = await sckManager.stopRecording(udid: udid) else {
            await syncService.broadcastFailure(for: command, reason: "Recording is not active for this simulator.")
            return
        }

        do {
            try await session.liveKitProvider.uploadRecording(
                result.url,
                simulatorName: simulator.title,
                simulatorUdid: udid,
                duration: result.duration
            )
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func openURL(_ command: RealtimeCommandEnvelope) async {
        guard let udid = command.udid else {
            await syncService.broadcastFailure(for: command, reason: "Simulator identifier missing.")
            return
        }

        do {
            let payload = try command.decodePayload(as: OpenURLCommandPayload.self)
            try inputService.openURL(payload.url, udid: udid)
            await syncService.broadcastResult(for: command, status: "ok", payload: EmptyResultPayload())
        } catch {
            await syncService.broadcastFailure(for: command, reason: error.localizedDescription)
        }
    }

    private func simulator(for udid: String) -> Simulator? {
        simulatorService.simulators.first(where: { $0.udid == udid })
    }

    private func pid(for udid: String) -> pid_t {
        guard let simulator = simulator(for: udid),
              let window = simulatorService.windowService.window(for: simulator.windowID),
              let pid = window.owningApplication?.processID else {
            return 0
        }
        return pid_t(pid)
    }

    private func windowFrame(for udid: String) -> CGRect? {
        guard let simulator = simulator(for: udid),
              let window = simulatorService.windowService.window(for: simulator.windowID) else {
            return nil
        }
        return window.frame
    }

    private func deviceScreenSize(for udid: String) -> DeviceProfile.ScreenSize? {
        guard let simulator = simulator(for: udid),
              let deviceType = simulator.deviceTypeIdentifier else {
            return nil
        }
        return DeviceProfile.screenSize(for: deviceType)
    }
}
