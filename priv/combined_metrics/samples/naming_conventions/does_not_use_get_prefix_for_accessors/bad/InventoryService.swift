import Foundation

struct StockRecord {
    let productID: String
    var quantity: Int
    var reservedQuantity: Int
    var warehouseLocation: String
}

class InventoryService {
    private var stock: [String: StockRecord] = [:]

    // Should be totalProducts — "get" prefix is redundant on computed properties
    var getTotalProducts: Int {
        return stock.count
    }

    // Should be totalUnitsAvailable — "get" prefix is not idiomatic Swift
    var getTotalUnitsAvailable: Int {
        return stock.values.reduce(0) { $0 + max(0, $1.quantity - $1.reservedQuantity) }
    }

    // Should be record(for:) — "get" is implicit in property/method access
    func getRecord(for productID: String) -> StockRecord? {
        return stock[productID]
    }

    // Should be availableQuantity(for:)
    func getAvailableQuantity(for productID: String) -> Int {
        guard let record = stock[productID] else { return 0 }
        return max(0, record.quantity - record.reservedQuantity)
    }

    // Should be warehouseLocation(of:)
    func getWarehouseLocation(of productID: String) -> String? {
        return stock[productID]?.warehouseLocation
    }

    // Should be lowStockProductIDs(threshold:)
    func getLowStockProductIDs(threshold: Int) -> [String] {
        return stock.compactMap { id, _ in
            getAvailableQuantity(for: id) < threshold ? id : nil
        }
    }

    func restock(productID: String, quantity: Int) {
        stock[productID]?.quantity += quantity
    }

    func reserve(productID: String, quantity: Int) -> Bool {
        guard let record = stock[productID],
              getAvailableQuantity(for: productID) >= quantity else { return false }
        stock[productID]?.reservedQuantity += quantity
        return true
    }
}
