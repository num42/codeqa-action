import Foundation

enum PaymentMethod {
    case creditCard(last4: String)
    case bankTransfer(accountNumber: String)
    case digitalWallet(provider: String)
}

enum PaymentStatus {
    case pending, authorized, captured, refunded, failed
}

// Primary type definition — only core stored properties and init
struct PaymentTransaction {
    let id: String
    let amount: Decimal
    let currency: String
    let method: PaymentMethod
    var status: PaymentStatus
    let createdAt: Date
    var completedAt: Date?
    var failureReason: String?
}

// MARK: - Equatable conformance in its own extension
extension PaymentTransaction: Equatable {
    static func == (lhs: PaymentTransaction, rhs: PaymentTransaction) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable conformance in its own extension
extension PaymentTransaction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CustomStringConvertible in its own extension
extension PaymentTransaction: CustomStringConvertible {
    var description: String {
        return "PaymentTransaction(id: \(id), amount: \(amount) \(currency), status: \(status))"
    }
}

// MARK: - Codable in its own extension
extension PaymentTransaction: Codable {
    enum CodingKeys: String, CodingKey {
        case id, amount, currency, status, createdAt, completedAt, failureReason
    }
}
