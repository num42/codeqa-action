import Foundation

enum DataLoaderError: Error {
    case fileNotFound(String)
    case decodingFailed(Error)
    case encodingFailed(Error)
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

    func loadPreferences(from filename: String) -> Result<UserPreferences, DataLoaderError> {
        let fileURL = documentsURL.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .failure(.fileNotFound(filename))
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let preferences = try JSONDecoder().decode(UserPreferences.self, from: data)
            return .success(preferences)
        } catch let error as DecodingError {
            return .failure(.decodingFailed(error))
        } catch {
            return .failure(.decodingFailed(error))
        }
    }

    func savePreferences(_ preferences: UserPreferences, to filename: String) throws {
        let fileURL = documentsURL.appendingPathComponent(filename)
        do {
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw DataLoaderError.encodingFailed(error)
        }
    }

    func loadJSON<T: Decodable>(from url: URL, as type: T.Type) throws -> T {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw DataLoaderError.decodingFailed(error)
        }
    }
}
