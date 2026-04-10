import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class SyncService {
    private(set) var sessionId = UUID().uuidString
    var onCommand: ((RealtimeCommandEnvelope) -> Void)?

    private var channel: RealtimeChannelV2?
    private var commandListenerTask: Task<Void, Never>?
    private var presenceListenerTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private let supabase: SupabaseClient
    private let logger: AppLogger
    private var currentSimulators: [Simulator] = []
    private(set) var userId: String?
    private var userEmail: String?
    private var startedAt: String = ""
    private var currentStreamingUdids: [String] = []
    private var activeDashboardSessionIds: Set<String> = []
    private var isStopping = false
    private var lastHeartbeatAt = Date.distantPast
    private var isRealtimeReady = false
    private var presenceVersion = 0

    init(supabase: SupabaseClient, logger: AppLogger) {
        self.supabase = supabase
        self.logger = logger
    }

    deinit {
        MainActor.assumeIsolated {
            commandListenerTask?.cancel()
            presenceListenerTask?.cancel()
            if let ch = channel {
                Task { await ch.unsubscribe() }
            }
        }
    }

    func start(userId: String, email: String) async {
        isStopping = false
        self.userId = userId
        self.userEmail = email
        activeDashboardSessionIds = []
        if startedAt.isEmpty {
            startedAt = Date().ISO8601Format()
        }

        logger.log(.presence, "sync service starting · user=\(email) · session=\(sessionId)")

        let ch = supabase.realtimeV2.channel("user:\(userId)")
        channel = ch
        startPresenceListener(channel: ch)
        startCommandListener(channel: ch)

        do {
            try await ch.subscribeWithError()
        } catch {
            logger.log(.error, "channel subscribe failed: \(error.localizedDescription)")
            await tearDownRealtime()
            scheduleRestart(reason: "channel subscribe failed")
            return
        }

        isRealtimeReady = true
        logger.log(.presence, "realtime channel subscribed · topic=user:\(userId)")
        await track()
    }

    func stop() async {
        isStopping = true
        logger.log(.presence, "sync service stopping · session=\(sessionId)")
        restartTask?.cancel()
        restartTask = nil
        await tearDownRealtime()
        currentSimulators = []
        userId = nil
        userEmail = nil
        startedAt = ""
        currentStreamingUdids = []
        activeDashboardSessionIds = []
        lastHeartbeatAt = .distantPast
        presenceVersion = 0
        isStopping = false
    }

    func updateSimulators(_ simulators: [Simulator]) async {
        let syncable = simulators.filter { !$0.isAmbiguous && $0.udid != nil }
        let newUDIDs = Set(syncable.compactMap(\.udid))
        let oldUDIDs = Set(currentSimulators.compactMap(\.udid))
        guard newUDIDs != oldUDIDs else { return }
        currentSimulators = syncable

        let added = newUDIDs.subtracting(oldUDIDs)
        let removed = oldUDIDs.subtracting(newUDIDs)
        logger.log(
            .presence,
            "simulators changed · total=\(syncable.count) · added=\(added.map { $0.shortId() }.sorted()) · removed=\(removed.map { $0.shortId() }.sorted())"
        )

        await track()
    }

    func broadcastLog(category: String, message: String, udid: String) {
        guard let ch = channel, isRealtimeReady else { return }
        let payload = RealtimeLogPayload(
            protocolVersion: realtimeProtocolVersion,
            udid: udid,
            category: category,
            message: message,
            timestamp: Date().ISO8601Format()
        )
        Task {
            try? await ch.broadcast(event: "log", message: payload)
        }
    }

    func syncPresence(streamingUdids: [String]) async {
        currentStreamingUdids = streamingUdids
        logger.log(.presence, "presence synced · streamingUdids=\(streamingUdids)")
        await track()
    }

    func heartbeat() async {
        guard isRealtimeReady else { return }
        let now = Date()
        guard now.timeIntervalSince(lastHeartbeatAt) >= 10 else { return }
        lastHeartbeatAt = now
        await track(logSuccess: false)
    }

    func broadcastResult(
        for command: RealtimeCommandEnvelope,
        status: String,
        reason: String? = nil,
        payload: some Codable
    ) async {
        guard let ch = channel, isRealtimeReady else { return }
        let jsonPayload = try? JSONObject(payload)
        let result = RealtimeCommandResult(
            protocolVersion: realtimeProtocolVersion,
            commandId: command.commandId,
            dashboardSessionId: command.dashboardSessionId,
            kind: command.kind,
            udid: command.udid,
            status: status,
            reason: reason,
            payload: jsonPayload,
            completedAt: Date().ISO8601Format()
        )
        try? await ch.broadcast(event: "command_result", message: result)
        logger.log(
            .command,
            "cmd result sent · \(command.kind) · status=\(status)\(reason.map { " · \($0)" } ?? "")",
            udid: command.udid
        )
    }

    func broadcastFailure(for command: RealtimeCommandEnvelope, reason: String) async {
        guard let ch = channel, isRealtimeReady else { return }
        let result = RealtimeCommandResult(
            protocolVersion: realtimeProtocolVersion,
            commandId: command.commandId,
            dashboardSessionId: command.dashboardSessionId,
            kind: command.kind,
            udid: command.udid,
            status: "failed",
            reason: reason,
            payload: nil,
            completedAt: Date().ISO8601Format()
        )
        try? await ch.broadcast(event: "command_result", message: result)
        logger.log(.error, "cmd result sent · \(command.kind) · failed · \(reason)", udid: command.udid)
    }

    private func startPresenceListener(channel: RealtimeChannelV2) {
        presenceListenerTask?.cancel()
        presenceListenerTask = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.logger.log(.presence, "presence listener stopped")
                    self.scheduleRestart(reason: "presence listener ended")
                }
            }

            for await change in channel.presenceChange() {
                guard let self else { break }
                let joins = (try? change.decodeJoins(as: WebDashboardPresence.self)) ?? []
                let leaves = (try? change.decodeLeaves(as: WebDashboardPresence.self)) ?? []

                var joinedIds: [String] = []
                for presence in joins where presence.sessionType == "web" {
                    if let dashboardSessionId = presence.dashboardSessionId {
                        activeDashboardSessionIds.insert(dashboardSessionId)
                        joinedIds.append(dashboardSessionId)
                    }
                }

                var leftIds: [String] = []
                for presence in leaves where presence.sessionType == "web" {
                    if let dashboardSessionId = presence.dashboardSessionId {
                        activeDashboardSessionIds.remove(dashboardSessionId)
                        leftIds.append(dashboardSessionId)
                    }
                }

                if !joinedIds.isEmpty || !leftIds.isEmpty {
                    logger.log(
                        .presence,
                        "dashboard presence changed · active=\(activeDashboardSessionIds.count) · joined=\(joinedIds) · left=\(leftIds)"
                    )
                }
            }
        }
    }

    private func startCommandListener(channel: RealtimeChannelV2) {
        commandListenerTask?.cancel()
        commandListenerTask = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.logger.log(.presence, "command listener stopped")
                    self.scheduleRestart(reason: "command listener ended")
                }
            }

            for await message in channel.broadcastStream(event: "command") {
                guard let self else { break }

                do {
                    guard let payload = message["payload"] else {
                        logger.log(
                            .error,
                            "command decode failed · missing broadcast payload wrapper keys=\(Array(message.keys).sorted())"
                        )
                        continue
                    }

                    let command = try payload.decode(as: RealtimeCommandEnvelope.self)
                    try await handleIncomingCommand(command)
                } catch {
                    logger.log(.error, "command decode failed · \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleIncomingCommand(_ command: RealtimeCommandEnvelope) async throws {
        if command.protocolVersion != realtimeProtocolVersion {
            await broadcastAck(
                for: command,
                status: "rejected",
                reason: "Unsupported realtime protocol version."
            )
            logger.log(.error, "command rejected · protocol version mismatch", udid: command.udid)
            return
        }

        guard command.parsedKind != nil else {
            await broadcastAck(
                for: command,
                status: "rejected",
                reason: "Unknown command kind."
            )
            logger.log(.error, "command rejected · unknown kind=\(command.kind)", udid: command.udid)
            return
        }

        if !activeDashboardSessionIds.contains(command.dashboardSessionId) {
            activeDashboardSessionIds.insert(command.dashboardSessionId)
            logger.log(
                .command,
                "command accepted without prior dashboard presence · recovered session=\(command.dashboardSessionId)",
                udid: command.udid
            )
        }

        await broadcastAck(for: command, status: "received", reason: nil)
        logger.log(.command, "cmd received · \(command.kind) · \(command.udid?.shortId() ?? "-")")
        onCommand?(command)
    }

    private func broadcastAck(for command: RealtimeCommandEnvelope, status: String, reason: String?) async {
        guard let ch = channel, isRealtimeReady else { return }
        let ack = RealtimeCommandAck(
            protocolVersion: realtimeProtocolVersion,
            commandId: command.commandId,
            dashboardSessionId: command.dashboardSessionId,
            status: status,
            reason: reason,
            receivedAt: Date().ISO8601Format()
        )
        try? await ch.broadcast(event: "command_ack", message: ack)
        let message = status == "rejected"
            ? "cmd ack sent · \(command.kind) · rejected\(reason.map { " · \($0)" } ?? "")"
            : "cmd ack sent · \(command.kind) · \(status)"
        logger.log(status == "rejected" ? .error : .command, message, udid: command.udid)
    }

    private func track(logSuccess: Bool = true) async {
        guard isRealtimeReady, let channel, let email = userEmail else {
            if logSuccess {
                logger.log(.presence, "presence track skipped · realtime not ready")
            }
            return
        }
        guard !isStopping else {
            if logSuccess {
                logger.log(.presence, "presence track skipped · sync service stopping")
            }
            return
        }

        let sorted = currentSimulators
            .compactMap { sim -> (sim: Simulator, udid: String)? in
                guard let udid = sim.udid else { return nil }
                return (sim, udid)
            }
            .sorted {
                if $0.sim.title != $1.sim.title { return $0.sim.title < $1.sim.title }
                let aOS = $0.sim.osVersion ?? ""
                let bOS = $1.sim.osVersion ?? ""
                if aOS != bOS { return aOS < bOS }
                return $0.udid < $1.udid
            }

        presenceVersion += 1
        let payload = SessionPresence(
            sessionType: "mac",
            sessionId: sessionId,
            userEmail: email,
            startedAt: startedAt,
            simulators: sorted.enumerated().map { index, pair in
                SimulatorInfo(
                    udid: pair.udid,
                    name: pair.sim.title,
                    osVersion: pair.sim.osVersion ?? "",
                    deviceTypeIdentifier: pair.sim.deviceTypeIdentifier ?? "",
                    orderIndex: index
                )
            },
            streamingUdids: currentStreamingUdids,
            presenceVersion: presenceVersion
        )

        do {
            try await channel.track(payload)
            if logSuccess {
                logger.log(
                    .presence,
                    "presence tracked · version=\(presenceVersion) · simulators=\(payload.simulators.count) · streaming=\(payload.streamingUdids.map { $0.shortId() }.sorted())"
                )
            }
        } catch {
            logger.log(.error, "presence track failed · \(error.localizedDescription)")
            scheduleRestart(reason: "presence track failed")
        }
    }

    private func tearDownRealtime() async {
        isRealtimeReady = false
        commandListenerTask?.cancel()
        commandListenerTask = nil
        presenceListenerTask?.cancel()
        presenceListenerTask = nil

        if let ch = channel {
            await ch.unsubscribe()
            channel = nil
        }
    }

    private func scheduleRestart(reason: String) {
        guard !isStopping, restartTask == nil, let userId, let email = userEmail else { return }
        logger.log(.error, "realtime restart scheduled · \(reason)")

        restartTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.tearDownRealtime()
            await self.start(userId: userId, email: email)
            self.restartTask = nil
        }
    }
}
