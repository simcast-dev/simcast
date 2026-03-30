import SwiftUI

struct SetupPage<Content: View>: View {
    let title: String
    let subtitle: String?
    let continueLabel: String
    let canContinue: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        continueLabel: String = "Continue",
        canContinue: Bool = true,
        onBack: (() -> Void)? = nil,
        onContinue: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.continueLabel = continueLabel
        self.canContinue = canContinue
        self.onBack = onBack
        self.onContinue = onContinue
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 48)

            Spacer()

            content()

            Spacer()

            Divider()

            HStack {
                if let onBack {
                    Button("Back") { onBack() }
                        .controlSize(.large)
                }
                Spacer()
                Button(continueLabel) { onContinue() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canContinue)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
