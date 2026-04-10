import SwiftUI

struct SimulatorRow: View {
    let simulator: Simulator
    @Environment(SCKManager.self) private var sckManager
    @Environment(SimulatorService.self) private var simulatorService
    @Environment(SyncService.self) private var syncService
    @State private var streamError: String?

    var session: StreamSession? { sckManager.sessions[simulator.udid ?? ""] }
    var isCapturingThis: Bool { session != nil }
    var isConnecting: Bool { isCapturingThis && !(session?.isConnected ?? false) }
    var isStreaming: Bool { isCapturingThis && (session?.isConnected ?? false) }
    var isRecording: Bool { session?.isRecording ?? false }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: simulator.systemImage)
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text(simulator.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    if isStreaming {
                        StreamingBadge()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else if isConnecting {
                        ConnectingBadge()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    if isRecording {
                        RecordingBadge()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }

                HStack(spacing: 6) {
                    if let osVersion = simulator.osVersion {
                        Text(osVersion)
                    }
                    if let udid = simulator.udid {
                        Text("·")
                        Text(String(udid.prefix(8)).uppercased())
                            .fontDesign(.monospaced)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let error = streamError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                }

                HStack(spacing: 4) {
                    Button(action: {
                        streamError = nil
                        Task {
                            guard let udid = simulator.udid else { return }
                            await simulatorService.forceRefresh()
                            guard let window = simulatorService.windowService.window(for: simulator.windowID) else {
                                streamError = "Simulator window is no longer available"
                                return
                            }
                            do {
                                try await sckManager.start(window: window, udid: udid)
                                await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                            } catch {
                                streamError = error.localizedDescription
                            }
                        }
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(isCapturingThis ? Color.secondary : .green)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isCapturingThis || simulator.udid == nil)

                    Button(action: {
                        Task {
                            guard let udid = simulator.udid else { return }
                            await sckManager.stop(udid: udid)
                            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                        }
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title)
                            .foregroundStyle(isCapturingThis ? .red : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isCapturingThis)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let session {
                SCKPreviewView(layer: session.previewReceiver.displayLayer)
                    .aspectRatio(
                        simulator.windowFrame.width / simulator.windowFrame.height,
                        contentMode: .fit
                    )
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCapturingThis)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isConnecting)
    }
}

private struct RecordingBadge: View {
    var body: some View {
        Label("REC", systemImage: "record.circle.fill")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.10), in: Capsule())
    }
}
