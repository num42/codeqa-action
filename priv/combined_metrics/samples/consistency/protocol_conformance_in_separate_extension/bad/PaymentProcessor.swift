import Foundation

enum PaymentMethod {
    case creditCard(last4: String)
    case bankTransfer(accountNumber: String)
    case digitalWallet(provider: String)
}

enum PaymentStatus {
    case pending, authorized, captured, refunded, failed
}

// All protocol conformances declared inline with the primary type,
// making it harder to locate core logic vs. protocol implementations
struct PaymentTransaction: Equatable, Hashable, CustomStringConvertible, Codable {
    let id: String
    let amount: Decimal
    let currency: String
    let method: PaymentMethod
    var status: PaymentStatus
    let createdAt: Date
    var completedAt: Date?
    var failureReason: String?

    // Equatable mixed in with stored properties
    static func == (lhs: PaymentTransaction, rhs: PaymentTransaction) -> Bool {
        return lhs.id == rhs.id
    }

    // Hashable mixed in with stored properties
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // CustomStringConvertible mixed in with stored properties
    var description: String {
        return "PaymentTransaction(id: \(id), amount: \(amount) \(currency), status: \(status))"
    }

    // Codable CodingKeys mixed in with stored properties
    enum CodingKeys: String, CodingKey {
        case id, amount, currency, status, createdAt, completedAt, failureReason
    }

    // Business logic buried alongside protocol boilerplate
    func isRefundable() -> Bool {
        return status == .captured && completedAt != nil
    }

    func summary() -> String {
        return "\(currency) \(amount) via \(method)"
    }
}
