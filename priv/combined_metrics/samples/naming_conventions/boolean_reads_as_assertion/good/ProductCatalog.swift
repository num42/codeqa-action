import Foundation

struct Product {
    let id: String
    let name: String
    var price: Decimal
    var stockQuantity: Int
    var tags: Set<String>
    var isArchived: Bool
    var isFeatured: Bool
}

class ProductCatalog {
    private var products: [String: Product] = [:]

    var isEmpty: Bool {
        return products.isEmpty
    }

    var hasFeaturedProducts: Bool {
        return products.values.contains { $0.isFeatured }
    }

    func isAvailable(_ productID: String) -> Bool {
        guard let product = products[productID] else { return false }
        return product.stockQuantity > 0 && !product.isArchived
    }

    func intersects(_ otherCatalog: ProductCatalog) -> Bool {
        let ownIDs = Set(products.keys)
        let otherIDs = Set(otherCatalog.products.keys)
        return !ownIDs.isDisjoint(with: otherIDs)
    }

    func matches(tag: String) -> Bool {
        return products.values.contains { $0.tags.contains(tag) }
    }

    func product(for id: String) -> Product? {
        return products[id]
    }

    func add(_ product: Product) {
        products[product.id] = product
    }

    func archive(_ productID: String) {
        products[productID]?.isArchived = true
    }
}
