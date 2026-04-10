import SwiftUI

struct StreamReadyHeader: View {
    @Environment(AuthManager.self) private var auth
    @Environment(SimulatorService.self) private var simulatorService
    @Environment(SCKManager.self) private var sckManager

    private var recordingCount: Int {
        sckManager.sessions.values.filter(\.isRecording).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Simulators")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your local operator console for streaming and control.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let email = auth.currentUserEmail {
                    Text(email)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                StatusPill(
                    title: "\(simulatorService.simulators.count) detected",
                    tint: .secondary
                )
                StatusPill(
                    title: "\(sckManager.streamingUdids.count) live",
                    tint: sckManager.streamingUdids.isEmpty ? .secondary : .green
                )
                StatusPill(
                    title: "\(recordingCount) recording",
                    tint: recordingCount == 0 ? .secondary : .red
                )
            }
        }
    }
}

private struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(tint.opacity(0.18))
            }
    }
}
