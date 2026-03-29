import Foundation
import Observation
import Supabase

@Observable
final class AuthManager {
    enum Status { case unauthenticated, authenticated }

    private(set) var status: Status = .unauthenticated
    private(set) var currentUserEmail: String?
    private(set) var userId: String?

    let supabase: SupabaseClient = {
        let info = Bundle.main.infoDictionary ?? [:]
        guard
            let urlString = info["SupabaseURL"] as? String,
            let url = URL(string: urlString),
            let key = info["SupabaseAnonKey"] as? String,
            !key.isEmpty
        else {
            fatalError("Missing or invalid Supabase configuration — check SupabaseURL and SupabaseAnonKey in Info.plist and xcconfig")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        currentUserEmail = session.user.email
        userId = session.user.id.uuidString.lowercased()
        status = .authenticated
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        clearSession()
    }

    func updateSession(_ session: Session?) {
        guard let session else { return }
        status = .authenticated
        currentUserEmail = session.user.email
        userId = session.user.id.uuidString.lowercased()
    }

    func clearSession() {
        status = .unauthenticated
        currentUserEmail = nil
        userId = nil
    }
}
