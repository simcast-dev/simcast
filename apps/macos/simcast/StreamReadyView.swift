import SwiftUI
import LiveKit
import ScreenCaptureKit

struct StreamReadyView: View {
    @State private var service = SimulatorService()
    @State private var streamingIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            StreamReadyHeader(isEmpty: service.simulators.isEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            if service.simulators.isEmpty {
                ContentUnavailableView(
                    "No Simulators Found",
                    systemImage: "iphone.slash",
                    description: Text("Open a simulator in Xcode to see it here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(service.simulators) { simulator in
                            let isStreaming = streamingIds.contains(simulator.id)
                            SimulatorRow(
                                simulator: simulator,
                                isStreaming: isStreaming,
                                onPlay: { streamingIds.insert(simulator.id) },
                                onStop: { streamingIds.remove(simulator.id) }
                            )
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                isStreaming ? Color.green.opacity(0.06) : Color(NSColor.textBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isStreaming)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .animation(.easeInOut(duration: 0.25), value: service.simulators.map(\.id))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.93))
        .task {
            while !Task.isCancelled {
                await service.refresh()
                try? await Task.sleep(for: .seconds(3))
            }
        }
        .onChange(of: service.simulators.map(\.id)) { _, newIds in
            let active = Set(newIds)
            streamingIds = streamingIds.filter { active.contains($0) }
        }
    }
}

struct StreamReadyHeader: View {
    let isEmpty: Bool
    @State private var showingSettings = false

    var body: some View {
        HStack {
            Text(isEmpty ? "Searching for Simulators" : "Available Simulators")
                .font(.title2)
                .fontWeight(.bold)
                .animation(.easeInOut(duration: 0.2), value: isEmpty)

            Spacer()

            if isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            }

            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                StreamSettingsPopover()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEmpty)
    }
}

private struct StreamSettingsPopover: View {
    @AppStorage("liveKitUrl") private var url = ""
    @AppStorage("liveKitToken") private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LiveKit Settings")
                .font(.headline)

            LabeledContent("Server URL") {
                TextField("wss://project.livekit.cloud", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }

            LabeledContent("Token") {
                TextField("eyJ…", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }
        }
        .padding(16)
        .frame(minWidth: 400)
    }
}

struct SimulatorRow: View {
    let simulator: Simulator
    let isStreaming: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    @State private var liveKitManager = LiveKitManager()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // Column 1: title + streaming badge, then buttons below
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

                HStack(spacing: 4) {
                    // Play
                    Button(action: {
                        onPlay()
                        Task { try? await liveKitManager.startStreaming(window: simulator.window) }
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(isStreaming ? Color.secondary : .green)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isStreaming)

                    // Stop
                    Button(action: {
                        onStop()
                        Task { await liveKitManager.stop() }
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title)
                            .foregroundStyle(isStreaming ? .red : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isStreaming)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isStreaming, let track = liveKitManager.track {
                SwiftUIVideoView(track, layoutMode: .fit)
                    .aspectRatio(
                        simulator.window.frame.width / simulator.window.frame.height,
                        contentMode: .fit
                    )
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isStreaming)
    }
}

struct StreamingBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                .font(.caption)

            Text("Streaming")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.green, in: Capsule())
    }
}

#Preview {
    StreamReadyView()
        .frame(width: 540, height: 740)
}
