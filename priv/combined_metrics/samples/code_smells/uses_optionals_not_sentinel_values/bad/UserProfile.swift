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
    // Sentinel: -1 means "not provided" instead of using Int?
    var age: Int = -1
    // Sentinel: "" means "not provided" instead of using String?
    var phoneNumber: String = ""
    // Sentinel: "" means no bio
    var bio: String = ""
    // Sentinel: 0.0/0.0 means no location instead of using optional struct
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    // Sentinel: -1 means "not enrolled" instead of Int?
    var loyaltyPoints: Int = -1
    // Sentinel: .distantPast means "never logged in" instead of Date?
    var lastLoginDate: Date = .distantPast

    var isPhoneVerified: Bool = false
    var isPremiumMember: Bool = false

    func formattedAge() -> String {
        // Magic number check instead of nil check
        if age == -1 {
            return "Age not provided"
        }
        return "\(age) years old"
    }

    func contactSummary() -> String {
        var parts: [String] = [email]
        // Empty string check instead of nil check
        if !phoneNumber.isEmpty {
            parts.append(phoneNumber)
        }
        return parts.joined(separator: " | ")
    }

    func loyaltySummary() -> String {
        // Magic number check throughout codebase
        if loyaltyPoints == -1 {
            return "Not enrolled in loyalty program"
        }
        return "\(loyaltyPoints) points"
    }

    func hasLocation() -> Bool {
        // Magic value comparison: 0/0 is technically a real coordinate
        return latitude != 0.0 || longitude != 0.0
    }
}
