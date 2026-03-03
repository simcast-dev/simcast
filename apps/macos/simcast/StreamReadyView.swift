import SwiftUI
import ScreenCaptureKit

struct StreamReadyView: View {
    @State private var service = SimulatorService()
    @State private var streamingIds: Set<CGWindowID> = []

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
        }
        .animation(.easeInOut(duration: 0.2), value: isEmpty)
    }
}

struct SimulatorRow: View {
    let simulator: Simulator
    let isStreaming: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // Column 1: title + streaming badge, then play + stop below
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(simulator.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    if isStreaming {
                        StreamingBadge()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }

                HStack(spacing: 4) {
                    Button(action: {
                        onPlay()
                        Task { await captureSnapshot() }
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(isStreaming ? Color.secondary : .green)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isStreaming)

                    Button(action: {
                        onStop()
                        thumbnail = nil
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

            // Column 3: simulator screenshot
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(thumbnail.size.width / thumbnail.size.height, contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isStreaming)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: thumbnail != nil)
    }

    private func captureSnapshot() async {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else { return }

        let windowFrame = simulator.window.frame
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)

        guard let display = content.displays.first(where: { $0.frame.contains(windowCenter) }) ?? content.displays.first else { return }

        let simulatorApps = content.applications.filter { $0.bundleIdentifier == "com.apple.iphonesimulator" }
        let filter = SCContentFilter(display: display, including: simulatorApps, exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(
            x: windowFrame.minX - display.frame.minX,
            y: windowFrame.minY - display.frame.minY,
            width: windowFrame.width,
            height: windowFrame.height
        )
        config.width = Int(windowFrame.width)
        config.height = Int(windowFrame.height)

        guard let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return }
        thumbnail = NSImage(cgImage: cgImage, size: windowFrame.size)
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
