import Foundation

struct CartItem {
    let productID: String
    let name: String
    var quantity: Int
    var unitPrice: Decimal
}

struct ShoppingCart {
    private(set) var items: [CartItem] = []
    private(set) var appliedCouponCode: String?

    // Mutating method: imperative verb
    mutating func addItem(_ item: CartItem) {
        if let index = items.firstIndex(where: { $0.productID == item.productID }) {
            items[index].quantity += item.quantity
        } else {
            items.append(item)
        }
    }

    // Mutating method: imperative verb
    mutating func removeItem(productID: String) {
        items.removeAll { $0.productID == productID }
    }

    // Mutating method: imperative verb
    mutating func applyCoupon(_ code: String) {
        appliedCouponCode = code
    }

    // Mutating method: imperative verb
    mutating func clear() {
        items.removeAll()
        appliedCouponCode = nil
    }

    // Non-mutating: noun describing the result
    var subtotal: Decimal {
        items.reduce(.zero) { $0 + $1.unitPrice * Decimal($1.quantity) }
    }

    // Non-mutating: past tense — returns a new value without side effects
    func sorted(by keyPath: KeyPath<CartItem, String>) -> [CartItem] {
        return items.sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }

    // Non-mutating: noun
    func item(for productID: String) -> CartItem? {
        return items.first { $0.productID == productID }
    }
}
