import Foundation

enum SubscriptionTier {
    case free, standard, premium, enterprise
}

struct Subscription {
    let identifier: String
    var tier: SubscriptionTier
    var startDate: Date
    var expirationDate: Date
    var isAutoRenewing: Bool
    var maximumDevices: Int
}

class SubscriptionManager {
    private var subscriptions: [String: Subscription] = [:]

    func register(_ subscription: Subscription, for userIdentifier: String) {
        subscriptions[userIdentifier] = subscription
    }

    func subscription(for userIdentifier: String) -> Subscription? {
        return subscriptions[userIdentifier]
    }

    func isExpired(for userIdentifier: String, referenceDate: Date = Date()) -> Bool {
        guard let subscription = subscriptions[userIdentifier] else { return true }
        return subscription.expirationDate < referenceDate
    }

    func upgrade(userIdentifier: String, to tier: SubscriptionTier) -> Bool {
        guard var subscription = subscriptions[userIdentifier] else { return false }
        subscription.tier = tier
        subscriptions[userIdentifier] = subscription
        return true
    }

    func remainingDays(for userIdentifier: String, referenceDate: Date = Date()) -> Int? {
        guard let subscription = subscriptions[userIdentifier] else { return nil }
        let components = Calendar.current.dateComponents([.day], from: referenceDate, to: subscription.expirationDate)
        return components.day.map { max(0, $0) }
    }

    func activeSubscriptions(referenceDate: Date = Date()) -> [Subscription] {
        return subscriptions.values.filter { $0.expirationDate >= referenceDate }
    }
}
