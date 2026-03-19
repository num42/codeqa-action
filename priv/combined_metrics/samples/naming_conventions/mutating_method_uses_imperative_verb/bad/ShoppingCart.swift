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

    // Should be addItem — "adding" is gerund, not imperative
    mutating func adding(_ item: CartItem) {
        if let index = items.firstIndex(where: { $0.productID == item.productID }) {
            items[index].quantity += item.quantity
        } else {
            items.append(item)
        }
    }

    // Should be removeItem — "deletion" is a noun, not an imperative
    mutating func deletion(productID: String) {
        items.removeAll { $0.productID == productID }
    }

    // Should be applyCoupon — "couponApplication" is a noun phrase
    mutating func couponApplication(_ code: String) {
        appliedCouponCode = code
    }

    // Should be clear — "clearing" is gerund, not imperative
    mutating func clearing() {
        items.removeAll()
        appliedCouponCode = nil
    }

    var subtotal: Decimal {
        items.reduce(.zero) { $0 + $1.unitPrice * Decimal($1.quantity) }
    }

    // Should be sorted(by:) — "sort" implies mutation; non-mutating should use past tense
    func sort(by keyPath: KeyPath<CartItem, String>) -> [CartItem] {
        return items.sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }

    func item(for productID: String) -> CartItem? {
        return items.first { $0.productID == productID }
    }
}
