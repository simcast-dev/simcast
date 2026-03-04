import Foundation
import Observation

@Observable
final class AuthManager {
    enum Status { case unauthenticated, authenticated }

    private(set) var status: Status

    init() {
        status = UserDefaults.standard.bool(forKey: "isAuthenticated") ? .authenticated : .unauthenticated
    }

    // Simulated — always succeeds. Replace with Supabase call later.
    func signIn(email: String, password: String) async throws {
        try await Task.sleep(for: .milliseconds(600))
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        status = .authenticated
    }

    func signOut() {
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        status = .unauthenticated
    }
}
