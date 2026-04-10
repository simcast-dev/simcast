import SwiftUI

struct AppLaunchView: View {
    let title: String
    let message: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 280, height: 280)
                .offset(x: -160, y: -120)

            Circle()
                .fill(Color.green.opacity(0.10))
                .frame(width: 220, height: 220)
                .offset(x: 170, y: 130)

            VStack(spacing: 22) {
                VStack(spacing: 14) {
                    Image("AppIconLarge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)

                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 27, weight: .bold))

                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                }

                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Just a moment…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
            }
            .padding(36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppLaunchView(
        title: "Preparing SimCast",
        message: "Checking local permissions and simulator access."
    )
    .frame(width: 540, height: 460)
}
