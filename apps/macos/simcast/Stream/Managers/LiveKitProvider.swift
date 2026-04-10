import CoreMedia
import LiveKit
import Observation
import Supabase

@Observable
@MainActor
final class LiveKitProvider: StreamingProvider {

    private(set) var isConnected = false
    var onDisconnected: (() -> Void)?

    private let supabase: SupabaseClient
    private let logger: AppLogger
    @ObservationIgnored nonisolated(unsafe) private var liveKitReceiver: LiveKitReceiver?
    private var room: Room?
    private var udid: String?

    init(supabase: SupabaseClient, logger: AppLogger) {
        self.supabase = supabase
        self.logger = logger
    }

    func prepare(size: CGSize) {
        liveKitReceiver = LiveKitReceiver(dimensions: Dimensions(
            width: Int32(size.width),
            height: Int32(size.height)
        ))
    }

    func connect(udid: String) async throws {
        guard let lkReceiver = liveKitReceiver else { return }
        self.udid = udid
        logger.log(.liveKit, "fetching token · room=\(udid.shortId())", udid: udid)
        let (url, token) = try await fetchToken(udid: udid)
        let room = Room()
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
            logger.log(.liveKit, "connected · room=\(udid.shortId())", udid: udid)
            try await room.localParticipant.publish(
                videoTrack: lkReceiver.track,
                options: VideoPublishOptions(
                    screenShareEncoding: VideoEncoding(maxBitrate: 8_000_000, maxFps: 60),
                    simulcast: false,
                    preferredCodec: .h264
                )
            )
            logger.log(.liveKit, "track published", udid: udid)
            isConnected = true
        } catch {
            self.room = nil
            await room.disconnect()
            logger.log(.error, "connect failed · \(error.localizedDescription)", udid: udid)
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

    nonisolated func sckManager(didOutput sampleBuffer: CMSampleBuffer) {
        liveKitReceiver?.sckManager(didOutput: sampleBuffer)
    }

    func uploadScreenshot(_ data: Data, simulatorName: String, simulatorUdid: String) async throws {
        let userId = try await supabase.auth.session.user.id.uuidString.lowercased()
        let path = "\(userId)/\(UUID().uuidString).png"
        let usesLegacySchema: Bool

        do {
            try await supabase.from("screenshots").insert(ScreenshotRecord(
                user_id: userId,
                storage_path: path,
                simulator_name: simulatorName,
                simulator_udid: simulatorUdid,
                status: "pending",
                error_message: nil
            )).execute()
            usesLegacySchema = false
        } catch {
            guard Self.isMissingMediaStatusSchema(error) else {
                throw error
            }
            usesLegacySchema = true
            logger.log(.stream, "screenshots table is using legacy schema · continuing without placeholder status", udid: simulatorUdid)
        }

        if usesLegacySchema {
            do {
                try await supabase.storage
                    .from("screenshots")
                    .upload(path: path, file: data, options: FileOptions(contentType: "image/png", upsert: false))

                try await supabase.from("screenshots").insert(LegacyScreenshotRecord(
                    user_id: userId,
                    storage_path: path,
                    simulator_name: simulatorName,
                    simulator_udid: simulatorUdid
                )).execute()
            } catch {
                logger.log(.error, "legacy screenshot upload failed · \(error.localizedDescription)", udid: simulatorUdid)
                throw error
            }
            return
        }

        Task { @MainActor [supabase, logger] in
            do {
                try await supabase.storage
                    .from("screenshots")
                    .upload(path: path, file: data, options: FileOptions(contentType: "image/png", upsert: false))

                try await supabase
                    .from("screenshots")
                    .update(MediaStatusUpdate(status: "ready", error_message: nil))
                    .eq("storage_path", value: path)
                    .execute()
            } catch {
                try? await supabase
                    .from("screenshots")
                    .update(MediaStatusUpdate(status: "failed", error_message: error.localizedDescription))
                    .eq("storage_path", value: path)
                    .execute()
                logger.log(.error, "screenshot upload failed · \(error.localizedDescription)", udid: simulatorUdid)
            }
        }
    }

    func uploadRecording(_ fileURL: URL, simulatorName: String, simulatorUdid: String, duration: Double) async throws {
        let userId = try await supabase.auth.session.user.id.uuidString.lowercased()
        let fileData = try Data(contentsOf: fileURL)
        let path = "\(userId)/\(UUID().uuidString).mp4"
        let usesLegacySchema: Bool

        do {
            try await supabase.from("recordings").insert(RecordingRecord(
                user_id: userId,
                storage_path: path,
                simulator_name: simulatorName,
                simulator_udid: simulatorUdid,
                duration_seconds: duration,
                file_size_bytes: fileData.count,
                status: "pending",
                error_message: nil
            )).execute()
            usesLegacySchema = false
        } catch {
            guard Self.isMissingMediaStatusSchema(error) else {
                throw error
            }
            usesLegacySchema = true
            logger.log(.stream, "recordings table is using legacy schema · continuing without placeholder status", udid: simulatorUdid)
        }

        if usesLegacySchema {
            defer { try? FileManager.default.removeItem(at: fileURL) }

            do {
                try await supabase.storage
                    .from("recordings")
                    .upload(path: path, file: fileData, options: FileOptions(contentType: "video/mp4", upsert: false))

                try await supabase.from("recordings").insert(LegacyRecordingRecord(
                    user_id: userId,
                    storage_path: path,
                    simulator_name: simulatorName,
                    simulator_udid: simulatorUdid,
                    duration_seconds: duration,
                    file_size_bytes: fileData.count
                )).execute()
            } catch {
                logger.log(.error, "legacy recording upload failed · \(error.localizedDescription)", udid: simulatorUdid)
                throw error
            }
            return
        }

        Task { @MainActor [supabase, logger] in
            defer { try? FileManager.default.removeItem(at: fileURL) }

            do {
                try await supabase.storage
                    .from("recordings")
                    .upload(path: path, file: fileData, options: FileOptions(contentType: "video/mp4", upsert: false))

                try await supabase
                    .from("recordings")
                    .update(MediaStatusUpdate(status: "ready", error_message: nil))
                    .eq("storage_path", value: path)
                    .execute()
            } catch {
                try? await supabase
                    .from("recordings")
                    .update(MediaStatusUpdate(status: "failed", error_message: error.localizedDescription))
                    .eq("storage_path", value: path)
                    .execute()
                logger.log(.error, "recording upload failed · \(error.localizedDescription)", udid: simulatorUdid)
            }
        }
    }

    private func fetchToken(udid: String) async throws -> (url: String, token: String) {
        struct Request: Encodable {
            let udid: String
            let room_name: String
            let participant_identity: String
            let can_publish: Bool
        }
        struct TokenResponse: Decodable {
            let token: String
            let livekit_url: String
        }
        func invokeTokenEndpoint(using accessToken: String) async throws -> TokenResponse {
            let roomName = try await derivedRoomName(for: udid)
            return try await supabase.functions.invoke(
                "livekit-token",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(accessToken)"],
                    body: Request(
                        udid: udid,
                        room_name: roomName,
                        participant_identity: "mac-publisher",
                        can_publish: true
                    )
                )
            )
        }

        do {
            let session = try await supabase.auth.session
            let response = try await invokeTokenEndpoint(using: session.accessToken)
            return (response.livekit_url, response.token)
        } catch let FunctionsError.httpError(code, _) where code == 401 {
            logger.log(.liveKit, "token fetch returned 401 · refreshing auth session and retrying", udid: udid)
            let refreshedSession = try await supabase.auth.refreshSession()
            let response = try await invokeTokenEndpoint(using: refreshedSession.accessToken)
            return (response.livekit_url, response.token)
        } catch let FunctionsError.httpError(code, data) {
            let details = String(data: data, encoding: .utf8) ?? "no response body"
            logger.log(.error, "token fetch failed · status=\(code) · body=\(details)", udid: udid)
            throw FunctionsError.httpError(code: code, data: data)
        }
    }

    private func derivedRoomName(for udid: String) async throws -> String {
        let session = try await supabase.auth.session
        return "user:\(session.user.id.uuidString.lowercased()):sim:\(udid)"
    }

    private static func isMissingMediaStatusSchema(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return (
            message.contains("could not find the 'status' column") ||
            message.contains("column \"status\" does not exist") ||
            message.contains("could not find the 'error_message' column") ||
            message.contains("column \"error_message\" does not exist")
        )
    }
}

private struct ScreenshotRecord: Encodable {
    let user_id: String
    let storage_path: String
    let simulator_name: String
    let simulator_udid: String
    let status: String
    let error_message: String?
}

private struct RecordingRecord: Encodable {
    let user_id: String
    let storage_path: String
    let simulator_name: String
    let simulator_udid: String
    let duration_seconds: Double
    let file_size_bytes: Int
    let status: String
    let error_message: String?
}

private struct MediaStatusUpdate: Encodable {
    let status: String
    let error_message: String?
}

private struct LegacyScreenshotRecord: Encodable {
    let user_id: String
    let storage_path: String
    let simulator_name: String
    let simulator_udid: String
}

private struct LegacyRecordingRecord: Encodable {
    let user_id: String
    let storage_path: String
    let simulator_name: String
    let simulator_udid: String
    let duration_seconds: Double
    let file_size_bytes: Int
}

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
}
