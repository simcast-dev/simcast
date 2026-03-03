import SwiftUI

struct StreamReadyView: View {
    @State private var service = SimulatorService()
    @State private var streamingIds: Set<CGWindowID> = []

    var body: some View {
        VStack(spacing: 0) {
            StreamReadyHeader(isLoading: service.isLoading, onRefresh: {
                Task { await service.refresh() }
            })
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Group {
                if service.isLoading && service.simulators.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.simulators.isEmpty {
                    ContentUnavailableView(
                        "No Simulators Found",
                        systemImage: "iphone.slash",
                        description: Text("Open a simulator in Xcode to see it here.")
                    )
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
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.93))
        .task { await service.refresh() }
    }
}

struct StreamReadyHeader: View {
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Available Simulators")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .symbolEffect(.rotate, options: .repeating, isActive: isLoading)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isLoading)
        }
    }
}

struct SimulatorRow: View {
    let simulator: Simulator
    let isStreaming: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: simulator.deviceType.icon)
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .frame(width: 44, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(simulator.deviceName)
                        .fontWeight(.bold)
                    if let osVersion = simulator.osVersion {
                        Text(osVersion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(isStreaming ? Color.secondary : .green)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isStreaming)

                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title)
                            .foregroundStyle(isStreaming ? .red : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isStreaming)
                }
            }

            if isStreaming {
                StreamingBadge()
                    .padding(.leading, 60)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
