import Foundation

// No doc comment on the enum
enum ShipmentStatus {
    // No doc comment on cases
    case pending
    case inTransit(currentLocation: String)
    case delivered(at: Date)
    case attemptedDelivery(attemptedAt: Date)
    case returned(reason: String)
}

// No doc comment on the struct
struct Shipment {
    // No doc comment on properties
    let trackingNumber: String
    let destinationAddress: String
    let estimatedDeliveryDate: Date
    var status: ShipmentStatus
    let carrier: String
}

// No doc comment on the class
class ShippingService {
    private var shipments: [String: Shipment] = [:]

    // No doc comment — what does this return, and what are the failure conditions?
    @discardableResult
    func register(_ shipment: Shipment) -> Bool {
        guard shipments[shipment.trackingNumber] == nil else { return false }
        shipments[shipment.trackingNumber] = shipment
        return true
    }

    // No doc comment — unclear whether nil means "not found" or "error"
    func shipment(for trackingNumber: String) -> Shipment? {
        return shipments[trackingNumber]
    }

    // No doc comment — parameters and return value undocumented
    @discardableResult
    func updateStatus(for trackingNumber: String, to status: ShipmentStatus) -> Bool {
        guard shipments[trackingNumber] != nil else { return false }
        shipments[trackingNumber]?.status = status
        return true
    }

    // No doc comment — what counts as "overdue"? What is referenceDate for?
    func overdueShipments(referenceDate: Date = Date()) -> [Shipment] {
        return shipments.values
            .filter { shipment in
                if case .delivered = shipment.status { return false }
                return shipment.estimatedDeliveryDate < referenceDate
            }
            .sorted { $0.estimatedDeliveryDate < $1.estimatedDeliveryDate }
    }
}
