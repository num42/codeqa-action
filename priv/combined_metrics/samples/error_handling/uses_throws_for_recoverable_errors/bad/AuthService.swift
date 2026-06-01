import Foundation

struct AuthToken {
    let value: String
    let expiresAt: Date
    let userID: String
}

struct Credentials {
    let username: String
    let password: String
}

class AuthService {
    private var failedAttempts: [String: Int] = [:]
    private let maxAttempts = 5

    // Returns nil for all failure modes — caller cannot distinguish between
    // invalid credentials, account locked, network error, etc.
    func login(with credentials: Credentials) -> AuthToken? {
        guard !credentials.username.isEmpty, !credentials.password.isEmpty else {
            return nil
        }

        let attempts = failedAttempts[credentials.username, default: 0]
        if attempts >= maxAttempts {
            return nil
        }

        guard isReachable() else {
            return nil
        }

        guard validateCredentials(credentials) else {
            failedAttempts[credentials.username, default: 0] += 1
            return nil
        }

        failedAttempts.removeValue(forKey: credentials.username)
        return AuthToken(
            value: generateToken(),
            expiresAt: Date().addingTimeInterval(3600),
            userID: credentials.username
        )
    }

    // Returns nil with no way to tell if expired or invalid
    func validateToken(_ token: AuthToken) -> Bool? {
        guard token.expiresAt > Date() else {
            return nil
        }
        return true
    }

    // Returns false for both "no permission" and "token invalid"
    func requirePermission(_ permission: String, for token: AuthToken) -> Bool {
        guard token.expiresAt > Date() else { return false }
        return hasPermission(permission, userID: token.userID)
    }

    private func validateCredentials(_ credentials: Credentials) -> Bool { true }
    private func generateToken() -> String { UUID().uuidString }
    private func isReachable() -> Bool { true }
    private func hasPermission(_ permission: String, userID: String) -> Bool { true }
}
