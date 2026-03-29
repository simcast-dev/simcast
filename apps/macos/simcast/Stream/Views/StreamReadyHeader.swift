import SwiftUI

struct StreamReadyHeader: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        HStack {
            Text("Simulators")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            if let email = auth.currentUserEmail {
                Text(email)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Menu {
                Button("Log Out") { Task { await auth.signOut() } }
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
