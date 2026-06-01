import Foundation

enum DataLoaderError: Error {
    case fileNotFound(String)
    case decodingFailed(Error)
}

struct UserPreferences: Codable {
    var theme: String
    var notificationsEnabled: Bool
    var language: String
}

class DataLoader {
    private let fileManager: FileManager
    private let documentsURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func loadPreferences(from filename: String) -> UserPreferences {
        let fileURL = documentsURL.appendingPathComponent(filename)

        // try! crashes the app if the file is missing or malformed
        let data = try! Data(contentsOf: fileURL)
        return try! JSONDecoder().decode(UserPreferences.self, from: data)
    }

    func savePreferences(_ preferences: UserPreferences, to filename: String) {
        let fileURL = documentsURL.appendingPathComponent(filename)

        // try! crashes if encoding or writing fails
        let data = try! JSONEncoder().encode(preferences)
        try! data.write(to: fileURL, options: .atomic)
    }

    func loadJSON<T: Decodable>(from url: URL, as type: T.Type) -> T {
        // try! on remote or file URL will crash for any network/IO error
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(type, from: data)
    }

    func parseRegex(pattern: String) -> NSRegularExpression {
        // try! will crash for invalid regex patterns
        return try! NSRegularExpression(pattern: pattern, options: [])
    }
}
