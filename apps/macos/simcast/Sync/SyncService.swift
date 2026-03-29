import Foundation
import Observation
import Supabase

struct StreamCommand: Sendable {
    enum Action: String, Sendable { case start, stop }
    let action: Action
    let udid: String
}

@Observable
@MainActor
final class SyncService {
    private(set) var sessionId = UUID().uuidString
    var onStreamCommand: ((StreamCommand) -> Void)?
    var onClearLogsReceived: (() -> Void)?

    private var channel: RealtimeChannelV2?
    private var commandListenerTask: Task<Void, Never>?
    private var simulatorChannels: [String: RealtimeChannelV2] = [:]
    private var simulatorClearLogsTasks: [String: Task<Void, Never>] = [:]
    private let supabase: SupabaseClient
    private let logger: AppLogger
    private var currentSimulators: [Simulator] = []
    private(set) var userId: String?
    private var userEmail: String?
    private var startedAt: String = ""
    private var currentStreamingUdids: [String] = []

    init(supabase: SupabaseClient, logger: AppLogger) {
        self.supabase = supabase
        self.logger = logger
    }

    deinit {
        // deinit may run on any thread, but channel references are MainActor-isolated;
        // assumeIsolated bridges this safely since the object graph guarantees main thread.
        MainActor.assumeIsolated {
            commandListenerTask?.cancel()
            for task in simulatorClearLogsTasks.values { task.cancel() }
            if let ch = channel {
                Task { await ch.unsubscribe() }
            }
            for ch in simulatorChannels.values {
                Task { await ch.unsubscribe() }
            }
        }
    }

    func start(userId: String, email: String) async {
        self.userId = userId
        self.userEmail = email
        self.startedAt = Date().ISO8601Format()

        // Per-user channel isolates each user's simulator state and prevents
        // cross-user data leakage.
        let ch = supabase.realtimeV2.channel("user:\(userId)")

        // Filters must be registered before subscribe(): Supabase Realtime V2
        // sends all filters in the subscription payload; adding them after has no effect.
        let changes = ch.postgresChange(InsertAction.self, schema: "public", table: "stream_commands")

        do {
            try await ch.subscribeWithError()
        } catch {
            logger.log(.error, "channel subscribe failed: \(error.localizedDescription)")
            return
        }
        self.channel = ch
        logger.log(.presence, "realtime channel subscribed")
        await track()

        commandListenerTask = Task { [weak self] in
            for await change in changes {
                let record = change.record
                guard let self,
                      let actionStr = record["action"]?.stringValue,
                      let action = StreamCommand.Action(rawValue: actionStr),
                      let udid = record["udid"]?.stringValue else { continue }
                let cmd = StreamCommand(action: action, udid: udid)
                logger.log(.command, "cmd received · \(action.rawValue) · \(udid.shortId())")
                await MainActor.run { self.onStreamCommand?(cmd) }
            }
        }
    }

    func stop() async {
        commandListenerTask?.cancel()
        commandListenerTask = nil
        for (_, task) in simulatorClearLogsTasks { task.cancel() }
        simulatorClearLogsTasks.removeAll()
        for (_, ch) in simulatorChannels { await ch.unsubscribe() }
        simulatorChannels.removeAll()
        for udid in currentStreamingUdids {
            try? await supabase.from("streams").delete().eq("room_name", value: udid).execute()
        }
        if let ch = channel {
            await ch.unsubscribe()
            self.channel = nil
        }
        currentSimulators = []
        userId = nil
        userEmail = nil
        startedAt = ""
        currentStreamingUdids = []
    }

    func updateSimulators(_ simulators: [Simulator]) async {
        let syncable = simulators.filter { !$0.isAmbiguous && $0.udid != nil }
        let newUDIDs = Set(syncable.compactMap(\.udid))
        let oldUDIDs = Set(currentSimulators.compactMap(\.udid))
        guard newUDIDs != oldUDIDs else { return }
        currentSimulators = syncable

        let added = newUDIDs.subtracting(oldUDIDs)
        let removed = oldUDIDs.subtracting(newUDIDs)

        for udid in removed {
            simulatorClearLogsTasks[udid]?.cancel()
            simulatorClearLogsTasks.removeValue(forKey: udid)
            if let ch = simulatorChannels.removeValue(forKey: udid) {
                await ch.unsubscribe()
            }
        }

        for udid in added {
            await subscribeSimulatorChannel(udid: udid)
        }

        await track()
    }

    func broadcastLog(category: String, message: String, udid: String) {
        guard let ch = simulatorChannels[udid] else { return }
        Task {
            await ch.broadcast(
                event: "log",
                message: [
                    "category": .string(category),
                    "message": .string(message),
                    "timestamp": .string(Date().ISO8601Format())
                ]
            )
        }
    }

    func syncPresence(streamingUdids: [String]) async {
        currentStreamingUdids = streamingUdids
        logger.log(.presence, "presence synced · streamingUdids=\(streamingUdids)")
        await track()
    }

    private func subscribeSimulatorChannel(udid: String) async {
        let ch = supabase.realtimeV2.channel("simulator:\(udid)")
        do {
            try await ch.subscribeWithError()
        } catch {
            logger.log(.error, "simulator channel subscribe failed: \(udid.shortId()) · \(error.localizedDescription)")
            return
        }
        simulatorChannels[udid] = ch

        simulatorClearLogsTasks[udid] = Task { [weak self] in
            for await _ in ch.broadcastStream(event: "clear_logs") {
                await MainActor.run { self?.onClearLogsReceived?() }
            }
        }
    }

    private func track() async {
        guard let channel, let email = userEmail else { return }
        let sorted = currentSimulators
            .compactMap { sim -> (sim: Simulator, udid: String)? in
                guard let udid = sim.udid else { return nil }
                return (sim, udid)
            }
            .sorted {
                if $0.sim.title != $1.sim.title { return $0.sim.title < $1.sim.title }
                let aOS = $0.sim.osVersion ?? ""; let bOS = $1.sim.osVersion ?? ""
                if aOS != bOS { return aOS < bOS }
                return $0.udid < $1.udid
            }
        let payload = SessionPresence(
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
            streamingUdids: currentStreamingUdids
        )
        try? await channel.track(payload)
    }
}

