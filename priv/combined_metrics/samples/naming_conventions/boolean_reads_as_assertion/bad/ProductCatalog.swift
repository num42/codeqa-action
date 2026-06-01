import Foundation

struct Product {
    let id: String
    let name: String
    var price: Decimal
    var stockQuantity: Int
    var tags: Set<String>
    // "archived" and "featured" don't read as assertions
    var archived: Bool
    var featured: Bool
}

class ProductCatalog {
    private var products: [String: Product] = [:]

    // "empty" doesn't read as an assertion the way "isEmpty" does
    var empty: Bool {
        return products.isEmpty
    }

    // "featuredProducts" sounds like a collection, not a boolean
    var featuredProducts: Bool {
        return products.values.contains { $0.featured }
    }

    // "available" without "is" prefix reads ambiguously
    func available(_ productID: String) -> Bool {
        guard let product = products[productID] else { return false }
        return product.stockQuantity > 0 && !product.archived
    }

    // "catalogIntersection" sounds like it returns a catalog, not a Bool
    func catalogIntersection(_ otherCatalog: ProductCatalog) -> Bool {
        let ownIDs = Set(products.keys)
        let otherIDs = Set(otherCatalog.products.keys)
        return !ownIDs.isDisjoint(with: otherIDs)
    }

    // "tagMatch" reads like a noun (a match object), not an assertion
    func tagMatch(tag: String) -> Bool {
        return products.values.contains { $0.tags.contains(tag) }
    }

    func product(for id: String) -> Product? {
        return products[id]
    }

    func add(_ product: Product) {
        products[product.id] = product
    }
}
