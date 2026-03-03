import SwiftUI
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

private enum PreviewMode: Equatable { case screenshot, stream }

struct SimulatorRow: View {
    let simulator: Simulator
    let isStreaming: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    @State private var thumbnail: NSImage?
    @State private var previewMode: PreviewMode = .screenshot
    @State private var liveStream: SimulatorStream?

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
                        previewMode = .screenshot
                        Task { await captureSnapshot() }
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
                        thumbnail = nil
                        previewMode = .screenshot
                        Task { await liveStream?.stop(); liveStream = nil }
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title)
                            .foregroundStyle(isStreaming ? .red : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!isStreaming)

                    // Mode toggle — only visible while streaming
                    if isStreaming {
                        Divider().frame(height: 20).padding(.horizontal, 6)

                        Button(action: {
                            guard previewMode != .screenshot else { return }
                            previewMode = .screenshot
                            Task { await liveStream?.stop(); liveStream = nil; await captureSnapshot() }
                        }) {
                            Image(systemName: previewMode == .screenshot ? "camera.fill" : "camera")
                                .font(.title)
                                .foregroundStyle(previewMode == .screenshot ? .primary : .secondary)
                        }
                        .buttonStyle(.borderless)

                        Button(action: {
                            guard previewMode != .stream else { return }
                            previewMode = .stream
                            thumbnail = nil
                            let stream = SimulatorStream()
                            liveStream = stream
                            Task { await stream.start(window: simulator.window) }
                        }) {
                            Image(systemName: previewMode == .stream ? "video.fill" : "video")
                                .font(.title)
                                .foregroundStyle(previewMode == .stream ? .primary : .secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 2: persistent container — size is fixed once streaming starts to avoid resize glitch
            if isStreaming {
                ZStack {
                    Color.green.opacity(0.06)
                    if previewMode == .screenshot, let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    }
                    if previewMode == .stream, let liveStream {
                        SampleBufferView(stream: liveStream)
                            .transition(.opacity)
                    }
                }
                .aspectRatio(simulator.window.frame.width / simulator.window.frame.height, contentMode: .fit)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .animation(.easeInOut(duration: 0.2), value: previewMode)
                .animation(.easeInOut(duration: 0.2), value: thumbnail != nil)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isStreaming)
        .animation(.easeInOut(duration: 0.2), value: previewMode)
    }

    private func captureSnapshot() async {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else { return }

        // Re-fetch the window from fresh content so its frame reflects the current position
        let window = content.windows.first(where: { $0.windowID == simulator.window.windowID }) ?? simulator.window
        let windowFrame = window.frame
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
