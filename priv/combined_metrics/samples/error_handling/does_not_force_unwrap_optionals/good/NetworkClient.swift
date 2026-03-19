import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T
    let statusCode: Int
}

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case unexpectedStatusCode(Int)
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
        guard let url = URL(string: path, relativeTo: baseURL) else {
            completion(.failure(.invalidURL))
            return
        }

        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.decodingFailed(error)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                completion(.failure(.unexpectedStatusCode(httpResponse.statusCode)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingFailed(error)))
            }
        }.resume()
    }

    func buildURL(for path: String) -> URL? {
        return URL(string: path, relativeTo: baseURL)
    }

    func headerValue(for key: String, in response: HTTPURLResponse) -> String? {
        return response.value(forHTTPHeaderField: key)
    }
}
