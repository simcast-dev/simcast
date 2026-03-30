import SwiftUI

struct ConfigurationView: View {
    let auth: AuthManager
    let onBack: (() -> Void)?

    @State private var url = ""
    @State private var anonKey = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    var body: some View {
        SetupPage(
            title: "Server Configuration",
            subtitle: "Enter the Supabase project URL and anonymous key for your SimCast backend.",
            canContinue: canSubmit,
            onBack: onBack,
            onContinue: configure
        ) {
            VStack(spacing: 12) {
                ConfigTextField(placeholder: "Supabase URL", text: $url, isFocused: focusedField == .url)
                    .focused($focusedField, equals: .url)
                    .autocorrectionDisabled()

                ConfigTextField(placeholder: "Supabase Anon Key", text: $anonKey, isFocused: focusedField == .anonKey)
                    .focused($focusedField, equals: .anonKey)
                    .autocorrectionDisabled()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 48)
        }
    }

    private var canSubmit: Bool { !url.isEmpty && !anonKey.isEmpty }

    private func configure() {
        errorMessage = nil
        do {
            try auth.configure(url: url, anonKey: anonKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Field helpers

private struct ConfigTextField: View {
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFocused ? Color.accentColor : Color(NSColor.separatorColor),
                            lineWidth: isFocused ? 2 : 1)
            )
    }
}

private enum Field: Hashable { case url, anonKey }

#Preview {
    ConfigurationView(auth: AuthManager(), onBack: nil)
        .frame(width: 540, height: 460)
}
