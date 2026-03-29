import SwiftUI

struct LoginView: View {
    let auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: LoginField?

    var body: some View {
        VStack(spacing: 0) {
            heroSection

            VStack(spacing: 10) {
                LoginTextField(placeholder: "e-mail", text: $email, isFocused: focusedField == .email)
                    .focused($focusedField, equals: .email)
                    .autocorrectionDisabled()

                LoginSecureField(placeholder: "password", text: $password, isFocused: focusedField == .password)
                    .focused($focusedField, equals: .password)

                Text("Don't have an account yet?")
                    .font(.system(size: 19))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Spacer()

            loginButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Hero

    private var heroSection: some View {
        Image("HeroAbstract")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .clipped()
    }

    // MARK: - Login button

    private var loginButton: some View {
        Button {
            Task { await signIn() }
        } label: {
            ZStack {
                Text("Login")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canSubmit ? Color.accentColor : Color.accentColor.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .keyboardShortcut(.defaultAction)
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
            .font(.system(size: 15, weight: .bold))
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
            .font(.system(size: 15, weight: .bold))
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
        .frame(width: 540, height: 740)
}
