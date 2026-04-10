import Foundation
import Observation
import Supabase

@Observable
final class AuthManager {
    enum Status { case launching, unconfigured, unauthenticated, authenticated }

    private(set) var status: Status
    private(set) var currentUserEmail: String?
    private(set) var userId: String?
    private(set) var supabase: SupabaseClient?
    private(set) var launchMessage: String

    init() {
        status = .launching
        if let urlString = KeychainService.read(key: "supabase_url"),
           let url = URL(string: urlString),
           let key = KeychainService.read(key: "supabase_anon_key"),
           !key.isEmpty {
            supabase = SupabaseClient(supabaseURL: url, supabaseKey: key)
            launchMessage = "Restoring your saved session."
        } else {
            supabase = nil
            launchMessage = "Checking your SimCast setup."
        }
    }

    func bootstrap() async {
        guard status == .launching else { return }

        guard let supabase else {
            status = .unconfigured
            return
        }

        do {
            let session = try await supabase.auth.session
            currentUserEmail = session.user.email
            userId = session.user.id.uuidString.lowercased()
            status = .authenticated
        } catch {
            currentUserEmail = nil
            userId = nil
            status = .unauthenticated
        }
    }

    func configure(url: String, anonKey: String) throws {
        guard let parsedURL = URL(string: url), parsedURL.scheme == "https" else {
            throw ConfigError.invalidURL
        }
        guard !anonKey.isEmpty else {
            throw ConfigError.emptyKey
        }
        KeychainService.save(key: "supabase_url", value: url)
        KeychainService.save(key: "supabase_anon_key", value: anonKey)
        supabase = SupabaseClient(supabaseURL: parsedURL, supabaseKey: anonKey)
        launchMessage = "Checking your SimCast setup."
        status = .unauthenticated
    }

    func signIn(email: String, password: String) async throws {
        guard let supabase else { return }
        let session = try await supabase.auth.signIn(email: email, password: password)
        currentUserEmail = session.user.email
        userId = session.user.id.uuidString.lowercased()
        status = .authenticated
    }

    func signOut(eraseConfiguration: Bool = false) async {
        try? await supabase?.auth.signOut()
        currentUserEmail = nil
        userId = nil
        if eraseConfiguration {
            KeychainService.deleteAll()
            supabase = nil
            launchMessage = "Checking your SimCast setup."
            status = .unconfigured
        } else {
            status = .unauthenticated
        }
    }

    func eraseConfiguration() {
        KeychainService.deleteAll()
        supabase = nil
        currentUserEmail = nil
        userId = nil
        launchMessage = "Checking your SimCast setup."
        status = .unconfigured
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

enum ConfigError: LocalizedError {
    case invalidURL
    case emptyKey

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Enter a valid HTTPS URL"
        case .emptyKey: "Anon key cannot be empty"
        }
    }
}
