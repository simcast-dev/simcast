import SwiftUI

struct LoginView: View {
    let auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: LoginField?

    var body: some View {
        SetupPage(
            title: "Sign In",
            subtitle: "Sign in with your SimCast account to start streaming.",
            continueLabel: "Sign In",
            canContinue: canSubmit,
            onContinue: { Task { await signIn() } }
        ) {
            VStack(spacing: 12) {
                LoginTextField(placeholder: "Email", text: $email, isFocused: focusedField == .email)
                    .focused($focusedField, equals: .email)
                    .autocorrectionDisabled()

                LoginSecureField(placeholder: "Password", text: $password, isFocused: focusedField == .password)
                    .focused($focusedField, equals: .password)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 4)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 48)
        }
    }

    private var canSubmit: Bool { !isLoading && !email.isEmpty && !password.isEmpty }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Field helpers

private struct LoginTextField: View {
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

private struct LoginSecureField: View {
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool

    var body: some View {
        SecureField(placeholder, text: $text)
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

private enum LoginField: Hashable { case email, password }

#Preview {
    LoginView(auth: AuthManager())
        .frame(width: 540, height: 460)
}
