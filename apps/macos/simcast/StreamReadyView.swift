import SwiftUI

struct StreamReadyView: View {
    @State private var simulators: [Simulator] = Simulator.mocks
    @State private var streamingIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            StreamReadyHeader(onRefresh: {})
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(simulators) { simulator in
                        SimulatorRow(
                            simulator: simulator,
                            isStreaming: streamingIds.contains(simulator.id),
                            onPlay: { streamingIds.insert(simulator.id) },
                            onStop: { streamingIds.remove(simulator.id) }
                        )
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.93))
    }
}

struct StreamReadyHeader: View {
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Available Simulators")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }
}

struct SimulatorRow: View {
    let simulator: Simulator
    let isStreaming: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: simulator.deviceType.icon)
                .font(.system(size: 36))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .frame(width: 44, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(simulator.name)
                    .fontWeight(.bold)
                Text(simulator.osVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
    }
}

#Preview {
    StreamReadyView()
        .frame(width: 540, height: 740)
}
