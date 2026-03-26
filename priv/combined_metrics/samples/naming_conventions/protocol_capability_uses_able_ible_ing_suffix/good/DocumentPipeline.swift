import Foundation

// Capability protocols using -able / -ible / -ing suffixes

protocol Exportable {
    func exportedData(format: ExportFormat) -> Data
}

protocol Filterable {
    associatedtype Element
    func filtered(by predicate: (Element) -> Bool) -> Self
}

protocol Indexing {
    associatedtype Key: Hashable
    associatedtype Value
    subscript(key: Key) -> Value? { get }
}

protocol Archivable {
    func archive() throws -> Data
    static func unarchive(from data: Data) throws -> Self
}

enum ExportFormat {
    case json, csv, xml
}

struct Document: Exportable, Archivable {
    let id: String
    var title: String
    var content: String
    var tags: [String]

    func exportedData(format: ExportFormat) -> Data {
        switch format {
        case .json:
            let dict: [String: Any] = ["id": id, "title": title, "content": content]
            return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
        case .csv:
            return "\(id),\(title),\(content)".data(using: .utf8) ?? Data()
        case .xml:
            return "<doc><id>\(id)</id><title>\(title)</title></doc>".data(using: .utf8) ?? Data()
        }
    }

    func archive() throws -> Data {
        let dict: [String: String] = ["id": id, "title": title, "content": content]
        return try JSONSerialization.data(withJSONObject: dict)
    }

    static func unarchive(from data: Data) throws -> Document {
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] ?? [:]
        return Document(id: dict["id"] ?? "", title: dict["title"] ?? "", content: dict["content"] ?? "", tags: [])
    }
}
