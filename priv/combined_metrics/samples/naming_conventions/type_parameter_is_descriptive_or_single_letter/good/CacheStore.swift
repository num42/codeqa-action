import Foundation

// Descriptive type parameter: "Key" and "Value" describe the roles clearly
struct CacheStore<Key: Hashable, Value> {
    private var storage: [Key: CacheEntry<Value>] = [:]
    private let capacity: Int
    private let timeToLive: TimeInterval

    init(capacity: Int, timeToLive: TimeInterval = 300) {
        self.capacity = capacity
        self.timeToLive = timeToLive
    }

    mutating func store(_ value: Value, for key: Key) {
        if storage.count >= capacity {
            evictOldest()
        }
        storage[key] = CacheEntry(value: value, storedAt: Date())
    }

    func value(for key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }
        guard Date().timeIntervalSince(entry.storedAt) < timeToLive else { return nil }
        return entry.value
    }

    mutating func remove(for key: Key) {
        storage.removeValue(forKey: key)
    }

    mutating private func evictOldest() {
        guard let oldest = storage.min(by: { $0.value.storedAt < $1.value.storedAt }) else { return }
        storage.removeValue(forKey: oldest.key)
    }
}

struct CacheEntry<Value> {
    let value: Value
    let storedAt: Date
}

// Single-letter T is acceptable when there is no meaningful relationship to express
func firstNonNil<T>(_ values: T?...) -> T? {
    return values.first { $0 != nil } ?? nil
}

// Descriptive name "Element" when the relationship to a sequence is meaningful
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
