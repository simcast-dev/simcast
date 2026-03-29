import SwiftUI

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

struct ConnectingBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.8)
            Text("Connecting")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.orange.opacity(0.75), in: Capsule())
    }
}
