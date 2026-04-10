import SwiftUI

struct SettingsView: View {
    let appearancePreferences: AppAppearancePreferences
    let launchAtLoginService: LaunchAtLoginService
    let auth: AuthManager

    var body: some View {
        TabView {
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

                Section("Account") {
                    LabeledContent("Status", value: accountStatus)

                    if let email = auth.currentUserEmail {
                        LabeledContent("Signed In As", value: email)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 460, height: 320)
        .scenePadding()
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
}
