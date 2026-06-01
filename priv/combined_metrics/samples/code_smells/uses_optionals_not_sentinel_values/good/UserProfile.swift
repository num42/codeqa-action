import Foundation

struct Address {
    let street: String
    let city: String
    let postalCode: String
    let country: String
}

struct UserProfile {
    let id: String
    var displayName: String
    var email: String
    var age: Int?
    var phoneNumber: String?
    var bio: String?
    var address: Address?
    var loyaltyPoints: Int?
    var lastLoginDate: Date?

    var isPhoneVerified: Bool
    var isPremiumMember: Bool

    func formattedAge() -> String {
        guard let age = age else {
            return "Age not provided"
        }
        return "\(age) years old"
    }

    func contactSummary() -> String {
        var parts: [String] = [email]
        if let phone = phoneNumber {
            parts.append(phone)
        }
        return parts.joined(separator: " | ")
    }

    func loyaltySummary() -> String {
        guard let points = loyaltyPoints else {
            return "Not enrolled in loyalty program"
        }
        return "\(points) points"
    }
}

class UserProfileRepository {
    private var profiles: [String: UserProfile] = [:]

    func profile(for userID: String) -> UserProfile? {
        return profiles[userID]
    }

    func update(_ profile: UserProfile) {
        profiles[profile.id] = profile
    }
}
