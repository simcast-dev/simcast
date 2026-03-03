import SwiftUI

struct StreamReadyView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 44, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
            }

            Text("Ready to Stream")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select an iOS Simulator window to begin.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    StreamReadyView()
        .frame(width: 540, height: 740)
}
