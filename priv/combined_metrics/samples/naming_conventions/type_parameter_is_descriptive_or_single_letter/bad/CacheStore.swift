import Foundation

// Non-descriptive multi-letter names that aren't single letters or established names
// "KT" and "VT" are neither single-letter nor descriptive
struct CacheStore<KT: Hashable, VT> {
    private var storage: [KT: CacheEntry<VT>] = [:]
    private let capacity: Int
    private let timeToLive: TimeInterval

    init(capacity: Int, timeToLive: TimeInterval = 300) {
        self.capacity = capacity
        self.timeToLive = timeToLive
    }

    mutating func store(_ value: VT, for key: KT) {
        if storage.count >= capacity {
            evictOldest()
        }
        storage[key] = CacheEntry(value: value, storedAt: Date())
    }

    func value(for key: KT) -> VT? {
        guard let entry = storage[key] else { return nil }
        guard Date().timeIntervalSince(entry.storedAt) < timeToLive else { return nil }
        return entry.value
    }

    mutating func remove(for key: KT) {
        storage.removeValue(forKey: key)
    }

    mutating private func evictOldest() {
        guard let oldest = storage.min(by: { $0.value.storedAt < $1.value.storedAt }) else { return }
        storage.removeValue(forKey: oldest.key)
    }
}

// "Obj" is an opaque multi-letter name, neither descriptive nor a single letter
struct CacheEntry<Obj> {
    let value: Obj
    let storedAt: Date
}

// "Tp" is a non-standard two-letter abbreviation rather than single-letter T
func firstNonNil<Tp>(_ values: Tp?...) -> Tp? {
    return values.first { $0 != nil } ?? nil
}

// "Elm" is an abbreviation of "Element" — should be the full word or T
extension Array {
    func chunked(into size: Int) -> [[Elm]] where Elm == Element {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
