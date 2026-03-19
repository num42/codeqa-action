import Foundation

enum AuthError: Error {
    case invalidCredentials
    case accountLocked(until: Date)
    case networkUnavailable
    case tokenExpired
    case insufficientPermissions(required: String)
}

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

    func login(with credentials: Credentials) throws -> AuthToken {
        guard !credentials.username.isEmpty, !credentials.password.isEmpty else {
            throw AuthError.invalidCredentials
        }

        let attempts = failedAttempts[credentials.username, default: 0]
        if attempts >= maxAttempts {
            let lockoutEnd = Date().addingTimeInterval(15 * 60)
            throw AuthError.accountLocked(until: lockoutEnd)
        }

        guard isReachable() else {
            throw AuthError.networkUnavailable
        }

        guard validateCredentials(credentials) else {
            failedAttempts[credentials.username, default: 0] += 1
            throw AuthError.invalidCredentials
        }

        failedAttempts.removeValue(forKey: credentials.username)
        return AuthToken(
            value: generateToken(),
            expiresAt: Date().addingTimeInterval(3600),
            userID: credentials.username
        )
    }

    func validateToken(_ token: AuthToken) throws {
        guard token.expiresAt > Date() else {
            throw AuthError.tokenExpired
        }
    }

    func requirePermission(_ permission: String, for token: AuthToken) throws {
        guard hasPermission(permission, userID: token.userID) else {
            throw AuthError.insufficientPermissions(required: permission)
        }
    }

    private func validateCredentials(_ credentials: Credentials) -> Bool { true }
    private func generateToken() -> String { UUID().uuidString }
    private func isReachable() -> Bool { true }
    private func hasPermission(_ permission: String, userID: String) -> Bool { true }
}
