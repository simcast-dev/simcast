import SwiftUI

struct SettingsView: View {
    let appearancePreferences: AppAppearancePreferences
    let launchAtLoginService: LaunchAtLoginService
    let auth: AuthManager

    @State private var serverURL = ""
    @State private var anonKey = ""
    @State private var serverMessage: String?
    @State private var serverMessageIsError = false
    @State private var didLoadServerConfiguration = false
    @FocusState private var focusedField: Field?

    var body: some View {
        TabView {
            generalTab
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }

            serverTab
                .tabItem {
                    Label("Server", systemImage: "server.rack")
                }
        }
        .task {
            guard !didLoadServerConfiguration else { return }
            loadServerConfiguration()
        }
        .frame(width: 560, height: 380)
        .scenePadding()
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLoginService.isEnabled },
                        set: { launchAtLoginService.setEnabled($0) }
                    )
                )

                Text("When enabled, SimCast starts quietly in the menu bar after you sign in to macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if launchAtLoginService.requiresApproval {
                    Text("macOS still needs approval for this login item in System Settings > General > Login Items.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let errorMessage = launchAtLoginService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Appearance") {
                Toggle("Hide Dock Icon", isOn: Bindable(appearancePreferences).hideDockIcon)

                Text("When enabled, SimCast runs as a menu-bar-first app. This change applies the next time you launch SimCast.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var accountTab: some View {
        Form {
            Section("Session") {
                LabeledContent("Status", value: accountStatus)
                LabeledContent("User ID", value: auth.userId ?? "—")

                if let email = auth.currentUserEmail {
                    LabeledContent("Signed In As", value: email)
                } else {
                    LabeledContent("Signed In As", value: "—")
                }
            }

            Section("Actions") {
                Button("Sign Out") {
                    Task { await auth.signOut() }
                }
                .disabled(auth.status != .authenticated)
            }
        }
        .formStyle(.grouped)
    }

    private var serverTab: some View {
        Form {
            Section("Backend") {
                SettingsTextField(placeholder: "Supabase URL", text: $serverURL, isFocused: focusedField == .url)
                    .focused($focusedField, equals: .url)
                    .autocorrectionDisabled()

                SettingsTextField(placeholder: "Supabase Anon Key", text: $anonKey, isFocused: focusedField == .anonKey)
                    .focused($focusedField, equals: .anonKey)
                    .autocorrectionDisabled()

                Text("Update the Supabase project URL and anonymous key used by this Mac app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let serverMessage {
                    Text(serverMessage)
                        .font(.caption)
                        .foregroundStyle(serverMessageIsError ? .red : .secondary)
                }
            }

            Section("Actions") {
                HStack {
                    Button("Reload Saved Values") {
                        loadServerConfiguration()
                    }

                    Spacer()

                    Button("Clear Configuration") {
                        auth.eraseConfiguration()
                        loadServerConfiguration()
                        serverMessage = "Saved configuration removed."
                        serverMessageIsError = false
                    }
                    .disabled(auth.configuredSupabaseURL == nil && auth.configuredAnonKey == nil)

                    Button("Save Configuration") {
                        saveServerConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(serverURL.isEmpty || anonKey.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var accountStatus: String {
        switch auth.status {
        case .launching:
            return "Starting"
        case .unconfigured:
            return "Setup Required"
        case .unauthenticated:
            return "Signed Out"
        case .authenticated:
            return "Signed In"
        }
    }

    private func loadServerConfiguration() {
        serverURL = auth.configuredSupabaseURL ?? ""
        anonKey = auth.configuredAnonKey ?? ""
        didLoadServerConfiguration = true
        serverMessage = nil
        serverMessageIsError = false
    }

    private func saveServerConfiguration() {
        serverMessage = nil

        do {
            try auth.configure(url: serverURL, anonKey: anonKey)
            serverMessage = "Server configuration saved."
            serverMessageIsError = false
        } catch {
            serverMessage = error.localizedDescription
            serverMessageIsError = true
        }
    }
}

private struct SettingsTextField: View {
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.accentColor : Color(NSColor.separatorColor),
                            lineWidth: isFocused ? 2 : 1)
            )
    }
}

private enum Field: Hashable {
    case url
    case anonKey
}
