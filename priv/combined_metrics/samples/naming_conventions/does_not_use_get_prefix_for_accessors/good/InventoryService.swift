import Foundation

struct StockRecord {
    let productID: String
    var quantity: Int
    var reservedQuantity: Int
    var warehouseLocation: String
}

class InventoryService {
    private var stock: [String: StockRecord] = [:]

    var totalProducts: Int {
        return stock.count
    }

    var totalUnitsAvailable: Int {
        return stock.values.reduce(0) { $0 + max(0, $1.quantity - $1.reservedQuantity) }
    }

    func record(for productID: String) -> StockRecord? {
        return stock[productID]
    }

    func availableQuantity(for productID: String) -> Int {
        guard let record = stock[productID] else { return 0 }
        return max(0, record.quantity - record.reservedQuantity)
    }

    func warehouseLocation(of productID: String) -> String? {
        return stock[productID]?.warehouseLocation
    }

    func lowStockProductIDs(threshold: Int) -> [String] {
        return stock.compactMap { id, record in
            availableQuantity(for: id) < threshold ? id : nil
        }
    }

    func restock(productID: String, quantity: Int) {
        stock[productID]?.quantity += quantity
    }

    func reserve(productID: String, quantity: Int) -> Bool {
        guard let record = stock[productID],
              availableQuantity(for: productID) >= quantity else { return false }
        stock[productID]?.reservedQuantity += quantity
        return true
    }
}
