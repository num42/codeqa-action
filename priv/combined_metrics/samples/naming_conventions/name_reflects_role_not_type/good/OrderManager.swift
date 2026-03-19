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
    private var orders: [String: Order] = [:]

    func place(_ order: Order) {
        var confirmed = order
        confirmed.status = .confirmed
        orders[confirmed.id] = confirmed
    }

    func cancel(orderID: String, reason: String) -> Bool {
        guard var existing = orders[orderID], existing.status == .pending else {
            return false
        }
        existing.status = .cancelled
        orders[orderID] = existing
        return true
    }

    func pendingOrders(for customerID: String) -> [Order] {
        return orders.values.filter {
            $0.customerID == customerID && $0.status == .pending
        }
    }

    func totalRevenue(in dateRange: ClosedRange<Date>) -> Decimal {
        return orders.values
            .filter { dateRange.contains($0.placedAt) && $0.status != .cancelled }
            .reduce(Decimal.zero) { subtotal, order in
                subtotal + order.items.reduce(Decimal.zero) { lineTotal, item in
                    lineTotal + item.unitPrice * Decimal(item.quantity)
                }
            }
    }

    func greeting(for customerID: String) -> String {
        let count = pendingOrders(for: customerID).count
        return count > 0 ? "You have \(count) pending order(s)." : "No pending orders."
    }
}
