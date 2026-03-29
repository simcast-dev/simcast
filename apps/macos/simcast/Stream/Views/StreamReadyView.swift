import SwiftUI
import ScreenCaptureKit

struct StreamReadyView: View {
    @Environment(SimulatorService.self) private var service
    @Environment(SCKManager.self) private var sckManager
    @Environment(SyncService.self) private var syncService
    @Environment(AppLogger.self) private var logger

    var body: some View {
        VStack(spacing: 0) {
            StreamReadyHeader()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            if service.simulators.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 48))
                        .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                        .foregroundStyle(.secondary)
                    Text("Searching for Simulators")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(service.simulators) { simulator in
                            let isCapturing = simulator.udid.flatMap({ sckManager.sessions[$0] }) != nil
                            SimulatorRow(simulator: simulator)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(
                                    isCapturing ? Color.green.opacity(0.06) : Color(NSColor.textBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCapturing)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .animation(.easeInOut(duration: 0.25), value: service.simulators.map(\.id))
                }
            }
            LogPanel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.93))
        .task {
            let inputService = SimulatorInputService(logger: logger)
            sckManager.inputService = inputService
            sckManager.simulatorService = service

            sckManager.onSessionStopped = { _ in
                Task { await syncService.syncPresence(streamingUdids: sckManager.streamingUdids) }
            }

            syncService.onClearLogsReceived = {
                logger.clear()
            }

            syncService.onStreamCommand = { cmd in
                Task { @MainActor in
                    switch cmd.action {
                    case .start:
                        if sckManager.sessions[cmd.udid] != nil {
                            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                            return
                        }
                        await service.forceRefresh()
                        guard let simulator = service.simulators.first(where: { $0.udid == cmd.udid }),
                              let window = service.windowService.window(for: simulator.windowID) else {
                            logger.log(.error, "start failed · simulator or window not found for \(cmd.udid.shortId())", udid: cmd.udid)
                            return
                        }
                        do {
                            try await sckManager.start(window: window, udid: cmd.udid)
                            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                        } catch {
                            logger.log(.error, "start failed · \(error.localizedDescription)", udid: cmd.udid)
                            await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                        }
                    case .stop:
                        await sckManager.stop(udid: cmd.udid)
                        await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                    }
                }
            }

            while !Task.isCancelled {
                await service.refresh()
                await syncService.updateSimulators(service.simulators)
                try? await Task.sleep(for: .seconds(3))
            }
        }
        .onChange(of: service.simulators.map(\.id)) { _, newIds in
            let newIdSet = Set(newIds)
            for udid in sckManager.streamingUdids where !newIdSet.contains(udid) {
                Task {
                    await sckManager.stop(udid: udid)
                    await syncService.syncPresence(streamingUdids: sckManager.streamingUdids)
                }
            }
        }
    }
}

#Preview {
    StreamReadyView()
        .frame(width: 540, height: 740)
}
