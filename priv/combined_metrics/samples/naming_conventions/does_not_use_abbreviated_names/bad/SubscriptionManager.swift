import Foundation

enum SubscriptionTier {
    case free, std, prem, ent  // "std", "prem", "ent" are non-standard abbreviations
}

struct Subscription {
    let id: String            // "id" is widely established — acceptable
    var tier: SubscriptionTier
    var startDt: Date         // "Dt" is a non-standard abbreviation for "Date"
    var expDt: Date           // "exp" is ambiguous: expiration? experience?
    var autoRenew: Bool       // "autoRenew" omits "is" prefix and abbreviates concept
    var maxDevs: Int          // "maxDevs" abbreviates "maximumDevices"
}

class SubscriptionManager {
    // "subs" is an abbreviation for "subscriptions"
    private var subs: [String: Subscription] = [:]

    // "uid" is a non-standard abbreviation (use "userIdentifier" or "userID")
    func reg(_ sub: Subscription, for uid: String) {
        subs[uid] = sub
    }

    // "sub" for subscription is unclear to new readers
    func sub(for uid: String) -> Subscription? {
        return subs[uid]
    }

    func isExp(for uid: String, refDt: Date = Date()) -> Bool {
        guard let sub = subs[uid] else { return true }
        return sub.expDt < refDt
    }

    // "upgr" is an unclear abbreviation
    func upgr(uid: String, to tier: SubscriptionTier) -> Bool {
        guard var sub = subs[uid] else { return false }
        sub.tier = tier
        subs[uid] = sub
        return true
    }

    // "remDays" abbreviates "remainingDays"
    func remDays(for uid: String, refDt: Date = Date()) -> Int? {
        guard let sub = subs[uid] else { return nil }
        let comps = Calendar.current.dateComponents([.day], from: refDt, to: sub.expDt)
        return comps.day.map { max(0, $0) }
    }

    func activeSubs(refDt: Date = Date()) -> [Subscription] {
        return subs.values.filter { $0.expDt >= refDt }
    }
}
