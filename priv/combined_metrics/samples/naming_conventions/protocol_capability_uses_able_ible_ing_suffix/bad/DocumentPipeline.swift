import Foundation

// Capability protocols with noun or adjective names that don't convey capability

// Should be Exportable — "Export" is a noun/verb, not a capability descriptor
protocol Export {
    func exportedData(format: ExportFormat) -> Data
}

// Should be Filterable — "Filter" reads as an action, not a capability
protocol Filter {
    associatedtype Element
    func filtered(by predicate: (Element) -> Bool) -> Self
}

// Should be Indexing — "Index" reads as a noun (an index), not a capability
protocol Index {
    associatedtype Key: Hashable
    associatedtype Value
    subscript(key: Key) -> Value? { get }
}

// Should be Archivable — "Archive" is a noun/verb, lacks capability suffix
protocol Archive {
    func archive() throws -> Data
    static func unarchive(from data: Data) throws -> Self
}

enum ExportFormat {
    case json, csv, xml
}

struct Document: Export, Archive {
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
