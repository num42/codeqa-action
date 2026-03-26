import Foundation

struct Order {
    let id: String
    var items: [OrderItem]
    var status: OrderStatus
    let placedAt: Date
    var customerID: String
}

struct OrderItem {
    let productID: String
    var quantity: Int
    var unitPrice: Decimal
}

enum OrderStatus {
    case pending, confirmed, shipped, delivered, cancelled
}

class OrderManager {
    // Name repeats type ("Dictionary") instead of describing its role
    private var orderDictionary: [String: Order] = [:]

    func place(_ order: Order) {
        // Name repeats type ("Order") instead of describing role ("confirmed")
        var orderObject = order
        orderObject.status = .confirmed
        orderDictionary[orderObject.id] = orderObject
    }

    func cancel(orderID: String, reason: String) -> Bool {
        // "boolResult" repeats the type, not the meaning
        var boolResult = false
        if var existing = orderDictionary[orderID], existing.status == .pending {
            existing.status = .cancelled
            orderDictionary[orderID] = existing
            boolResult = true
        }
        return boolResult
    }

    func pendingOrders(for customerID: String) -> [Order] {
        // "arrayResult" tells us nothing about what's in the array
        let arrayResult = orderDictionary.values.filter {
            $0.customerID == customerID && $0.status == .pending
        }
        return arrayResult
    }

    func totalRevenue(in dateRange: ClosedRange<Date>) -> Decimal {
        // "decimalValue" describes the type, not what the decimal represents
        let decimalValue = orderDictionary.values
            .filter { dateRange.contains($0.placedAt) && $0.status != .cancelled }
            .reduce(Decimal.zero) { acc, order in
                acc + order.items.reduce(Decimal.zero) { a, item in
                    a + item.unitPrice * Decimal(item.quantity)
                }
            }
        return decimalValue
    }

    func greeting(for customerID: String) -> String {
        let intCount = pendingOrders(for: customerID).count
        // "string" tells us the type but not what message this is
        let string = intCount > 0 ? "You have \(intCount) pending order(s)." : "No pending orders."
        return string
    }
}
