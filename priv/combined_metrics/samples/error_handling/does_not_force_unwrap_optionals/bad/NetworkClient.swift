import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let statusCode: Int
}

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingFailed(Error)
}

class NetworkClient {
    private let session: URLSession
    private let baseURL: URL

    init(baseURL: URL, session: URLSession = .shared) {
        self.session = session
        self.baseURL = baseURL
    }

    func fetch<T: Decodable>(
        path: String,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        // Force unwrap: crashes if path is not a valid URL
        let url = URL(string: path, relativeTo: baseURL)!

        session.dataTask(with: url) { data, response, error in
            // Force unwrap: crashes if data is nil
            let responseData = data!

            do {
                let decoded = try JSONDecoder().decode(T.self, from: responseData)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingFailed(error)))
            }
        }.resume()
    }

    func buildURL(for path: String) -> URL {
        // Force unwrap: crashes on invalid input
        return URL(string: path, relativeTo: baseURL)!
    }

    func headerValue(for key: String, in response: HTTPURLResponse) -> String {
        // Force unwrap: crashes if header is absent
        return response.value(forHTTPHeaderField: key)!
    }

    func firstComponent(of url: URL) -> String {
        // Force unwrap: crashes if pathComponents is empty
        return url.pathComponents.first!
    }
}
