import Foundation

/// Represents the current status of a shipment in the delivery pipeline.
enum ShipmentStatus {
    /// The order has been placed but not yet picked up by a carrier.
    case pending
    /// The package is in transit between facilities.
    case inTransit(currentLocation: String)
    /// The package has been delivered to the destination address.
    case delivered(at: Date)
    /// Delivery was attempted but the recipient was unavailable.
    case attemptedDelivery(attemptedAt: Date)
    /// The shipment was returned to the sender.
    case returned(reason: String)
}

/// Encapsulates all tracking information for a single shipment.
struct Shipment {
    /// The unique tracking number assigned by the carrier.
    let trackingNumber: String
    /// The destination address.
    let destinationAddress: String
    /// The estimated delivery date provided at the time of dispatch.
    let estimatedDeliveryDate: Date
    /// The current status of the shipment.
    var status: ShipmentStatus
    /// The carrier responsible for delivery (e.g., "FedEx", "UPS").
    let carrier: String
}

/// Manages shipment creation, tracking updates, and delivery confirmation.
///
/// Use this service as the single point of contact for all shipping operations.
/// It maintains an in-memory registry of active shipments.
class ShippingService {
    private var shipments: [String: Shipment] = [:]

    /// Registers a new shipment and begins tracking it.
    ///
    /// - Parameter shipment: The shipment to register. The `trackingNumber` must be unique.
    /// - Returns: `true` if registration succeeded; `false` if the tracking number already exists.
    @discardableResult
    func register(_ shipment: Shipment) -> Bool {
        guard shipments[shipment.trackingNumber] == nil else { return false }
        shipments[shipment.trackingNumber] = shipment
        return true
    }

    /// Returns the shipment with the given tracking number, if it exists.
    ///
    /// - Parameter trackingNumber: The carrier-assigned tracking number.
    /// - Returns: The matching `Shipment`, or `nil` if not found.
    func shipment(for trackingNumber: String) -> Shipment? {
        return shipments[trackingNumber]
    }

    /// Updates the status of an existing shipment.
    ///
    /// - Parameters:
    ///   - trackingNumber: The tracking number of the shipment to update.
    ///   - status: The new status to apply.
    /// - Returns: `true` if the update was applied; `false` if the tracking number was not found.
    @discardableResult
    func updateStatus(for trackingNumber: String, to status: ShipmentStatus) -> Bool {
        guard shipments[trackingNumber] != nil else { return false }
        shipments[trackingNumber]?.status = status
        return true
    }

    /// Returns all shipments that are currently overdue based on their estimated delivery date.
    ///
    /// A shipment is considered overdue if it has not been delivered and its estimated
    /// delivery date is in the past.
    ///
    /// - Parameter referenceDate: The date to compare against. Defaults to the current date.
    /// - Returns: An array of overdue shipments, sorted by estimated delivery date ascending.
    func overdueShipments(referenceDate: Date = Date()) -> [Shipment] {
        return shipments.values
            .filter { shipment in
                if case .delivered = shipment.status { return false }
                return shipment.estimatedDeliveryDate < referenceDate
            }
            .sorted { $0.estimatedDeliveryDate < $1.estimatedDeliveryDate }
    }
}
