import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("AppIconLarge")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)

            Text("SimCast")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 20)

            Text("Stream your iOS Simulators over the web.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            Divider()

            HStack {
                Spacer()
                Button("Continue") { onContinue() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    WelcomeView(onContinue: {})
        .frame(width: 540, height: 460)
}
