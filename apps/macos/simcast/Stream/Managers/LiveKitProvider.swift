import CoreMedia
import LiveKit
import Supabase
import Observation

@Observable
@MainActor
final class LiveKitProvider: StreamingProvider {

    private(set) var isConnected = false
    var onDisconnected: (() -> Void)?

    var onTapReceived: ((Double, Double, Double?) -> Void)?
    var onLabelTapReceived: ((String) -> Void)?
    var onSwipeReceived: ((Double, Double, Double, Double) -> Void)?
    var onScreenshotRequested: (() async -> Void)?
    var onButtonReceived: ((String) -> Void)?
    var onGestureReceived: ((String) -> Void)?
    var onTextReceived: ((String) -> Void)?
    var onPushReceived: ((String, String?, String?, String?, Int?, String?, String?, Bool) -> Void)?
    var onAppListRequested: (() async -> Void)?
    var onStartRecordingRequested: (() -> Void)?
    var onStopRecordingRequested: (() async -> Void)?
    var onOpenURLReceived: ((String) -> Void)?

    private let supabase: SupabaseClient
    private let logger: AppLogger
    @ObservationIgnored nonisolated(unsafe) private var liveKitReceiver: LiveKitReceiver?
    private var room: Room?
    private var udid: String?

    init(supabase: SupabaseClient, logger: AppLogger) {
        self.supabase = supabase
        self.logger = logger
    }

    // MARK: - StreamingProvider

    func prepare(size: CGSize) {
        liveKitReceiver = LiveKitReceiver(dimensions: Dimensions(
            width: Int32(size.width),
            height: Int32(size.height)
        ))
    }

    func connect(roomName: String) async throws {
        guard let lkReceiver = liveKitReceiver else { return }
        self.udid = roomName
        logger.log(.liveKit, "fetching token · room=\(roomName.shortId())", udid: roomName)
        let (url, token) = try await fetchToken(roomName: roomName)
        let room = Room()
        // Fixed 8Mbps H.264: high bitrate prioritizes visual quality for a dev tool;
        // simulcast disabled because there's typically one viewer; H.264 for broad
        // browser compatibility.
        let roomOptions = RoomOptions(
            defaultVideoPublishOptions: VideoPublishOptions(
                screenShareEncoding: VideoEncoding(maxBitrate: 8_000_000, maxFps: 60),
                simulcast: false,
                preferredCodec: .h264
            ),
            adaptiveStream: false
        )
        room.add(delegate: self)
        self.room = room
        do {
            try await room.connect(url: url, token: token, roomOptions: roomOptions)
            logger.log(.liveKit, "connected · room=\(roomName.shortId())", udid: roomName)
            try await room.localParticipant.publish(
                videoTrack: lkReceiver.track,
                options: VideoPublishOptions(
                    screenShareEncoding: VideoEncoding(maxBitrate: 8_000_000, maxFps: 60),
                    simulcast: false,
                    preferredCodec: .h264
                )
            )
            logger.log(.liveKit, "track published", udid: roomName)
            isConnected = true
        } catch {
            self.room = nil
            await room.disconnect()
            logger.log(.error, "connect failed · \(error.localizedDescription)", udid: roomName)
            throw error
        }
    }

    func disconnect() async {
        isConnected = false
        let r = room
        room = nil
        onDisconnected = nil
        await r?.disconnect()
    }

    // MARK: - VideoFrameReceiver

    nonisolated func sckManager(didOutput sampleBuffer: CMSampleBuffer) {
        liveKitReceiver?.sckManager(didOutput: sampleBuffer)
    }

    // MARK: - Private

    func publishAppList(_ apps: [(bundleId: String, name: String)]) async {
        let items = apps.map { ["bundleId": $0.bundleId, "name": $0.name] }
        guard let data = try? JSONSerialization.data(withJSONObject: items) else { return }
        try? await room?.localParticipant.publish(data: data, options: DataPublishOptions(topic: "simulator_app_list_result", reliable: true))
    }

    func uploadAndPublishScreenshot(_ data: Data, simulatorName: String, simulatorUdid: String) async {
        do {
            let userId = try await supabase.auth.session.user.id.uuidString.lowercased()
            let path = "\(userId)/\(UUID().uuidString).png"
            try await supabase.storage.from("screenshots").upload(path: path, file: data, options: FileOptions(contentType: "image/png", upsert: false))

            try await supabase.from("screenshots").insert(ScreenshotRecord(
                user_id: userId,
                storage_path: path,
                simulator_name: simulatorName,
                simulator_udid: simulatorUdid
            )).execute()

            let signedURL = try await supabase.storage.from("screenshots").createSignedURL(path: path, expiresIn: 300)
            let payload = Data(signedURL.absoluteString.utf8)
            try await room?.localParticipant.publish(data: payload, options: DataPublishOptions(topic: "simulator_screenshot_result", reliable: true))
        } catch {
            logger.log(.error, "screenshot upload failed · \(error.localizedDescription)", udid: simulatorUdid)
            print("[screenshot] upload failed: \(error)")
        }
    }

    func uploadAndPublishRecording(_ fileURL: URL, simulatorName: String, simulatorUdid: String, duration: Double) async {
        do {
            let userId = try await supabase.auth.session.user.id.uuidString.lowercased()
            let fileData = try Data(contentsOf: fileURL)
            let path = "\(userId)/\(UUID().uuidString).mp4"
            try await supabase.storage.from("recordings").upload(path: path, file: fileData, options: FileOptions(contentType: "video/mp4", upsert: false))

            try await supabase.from("recordings").insert(RecordingRecord(
                user_id: userId,
                storage_path: path,
                simulator_name: simulatorName,
                simulator_udid: simulatorUdid,
                duration_seconds: duration,
                file_size_bytes: fileData.count
            )).execute()

            let signedURL = try await supabase.storage.from("recordings").createSignedURL(path: path, expiresIn: 300)
            let payload = Data(signedURL.absoluteString.utf8)
            try await room?.localParticipant.publish(data: payload, options: DataPublishOptions(topic: "simulator_recording_result", reliable: true))

            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            logger.log(.error, "recording upload failed · \(error.localizedDescription)", udid: simulatorUdid)
        }
    }

    // Token generated server-side via Supabase Edge Function to ensure only
    // authenticated users receive LiveKit access credentials.
    private func fetchToken(roomName: String) async throws -> (url: String, token: String) {
        struct Request: Encodable {
            let room_name: String
            let participant_identity: String
            let can_publish: Bool
        }
        struct TokenResponse: Decodable {
            let token: String
            let livekit_url: String
        }
        let session = try await supabase.auth.session
        let response: TokenResponse = try await supabase.functions.invoke(
            "livekit-token",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: Request(room_name: roomName, participant_identity: "mac-publisher", can_publish: true)
            )
        )
        return (response.livekit_url, response.token)
    }
}

private struct ScreenshotRecord: Encodable {
    let user_id: String
    let storage_path: String
    let simulator_name: String
    let simulator_udid: String
}

private struct RecordingRecord: Encodable {
    let user_id: String
    let storage_path: String
    let simulator_name: String
    let simulator_udid: String
    let duration_seconds: Double
    let file_size_bytes: Int
}

private struct OpenURLMessage: Decodable { let url: String }

private struct TapMessage: Decodable { let x: Double?; let y: Double?; let vw: Double?; let vh: Double?; let longPress: Bool?; let duration: Double?; let label: String? }
private struct ButtonMessage: Decodable { let button: String }
private struct GestureMessage: Decodable { let gesture: String }
private struct SwipeMessage: Decodable { let startX: Double; let startY: Double; let endX: Double; let endY: Double; let vw: Double; let vh: Double }
private struct TextMessage: Decodable { let text: String }
private struct PushMessage: Decodable { let bundleId: String; let title: String?; let subtitle: String?; let body: String?; let badge: Int?; let sound: String?; let category: String?; let contentAvailable: Bool? }

extension LiveKitProvider: RoomDelegate {
    nonisolated func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor in
            guard self.isConnected else { return }
            self.isConnected = false
            if let error {
                self.logger.log(.error, "room disconnected · \(error.localizedDescription)", udid: self.udid)
            } else {
                self.logger.log(.liveKit, "room disconnected", udid: self.udid)
            }
            self.onDisconnected?()
        }
    }

    // Topics separate control messages by type, allowing independent decoding
    // and handling of tap/gesture/text/button/screenshot/push commands.
    nonisolated func room(_ room: Room, participant: RemoteParticipant?,
                          didReceiveData data: Data, forTopic topic: String,
                          encryptionType: EncryptionType) {
        switch topic {
        case "simulator_tap":
            guard let msg = try? JSONDecoder().decode(TapMessage.self, from: data) else {
                print("[tap] decode failed: \(String(data: data, encoding: .utf8) ?? "<binary>")")
                return
            }
            if let label = msg.label {
                Task { @MainActor in self.onLabelTapReceived?(label) }
            } else if let x = msg.x, let y = msg.y {
                let holdDuration = msg.longPress == true ? msg.duration : nil
                Task { @MainActor in self.onTapReceived?(x, y, holdDuration) }
            }
        case "simulator_button":
            guard let msg = try? JSONDecoder().decode(ButtonMessage.self, from: data) else { return }
            Task { @MainActor in self.onButtonReceived?(msg.button) }
        case "simulator_gesture":
            guard let msg = try? JSONDecoder().decode(GestureMessage.self, from: data) else { return }
            Task { @MainActor in self.onGestureReceived?(msg.gesture) }
        case "simulator_swipe":
            guard let msg = try? JSONDecoder().decode(SwipeMessage.self, from: data) else { return }
            let startNX = msg.startX / msg.vw, startNY = msg.startY / msg.vh
            let endNX = msg.endX / msg.vw, endNY = msg.endY / msg.vh
            Task { @MainActor in self.onSwipeReceived?(startNX, startNY, endNX, endNY) }
        case "simulator_screenshot":
            Task { @MainActor in await self.onScreenshotRequested?() }
        case "simulator_app_list_request":
            Task { @MainActor in await self.onAppListRequested?() }
        case "simulator_text":
            guard let msg = try? JSONDecoder().decode(TextMessage.self, from: data) else { return }
            Task { @MainActor in self.onTextReceived?(msg.text) }
        case "simulator_push":
            guard let msg = try? JSONDecoder().decode(PushMessage.self, from: data) else { return }
            Task { @MainActor in self.onPushReceived?(msg.bundleId, msg.title, msg.subtitle, msg.body, msg.badge, msg.sound, msg.category, msg.contentAvailable == true) }
        case "simulator_start_recording":
            Task { @MainActor in self.onStartRecordingRequested?() }
        case "simulator_stop_recording":
            Task { @MainActor in await self.onStopRecordingRequested?() }
        case "simulator_open_url":
            guard let msg = try? JSONDecoder().decode(OpenURLMessage.self, from: data) else { return }
            Task { @MainActor in self.onOpenURLReceived?(msg.url) }
        default:
            break
        }
    }
}
