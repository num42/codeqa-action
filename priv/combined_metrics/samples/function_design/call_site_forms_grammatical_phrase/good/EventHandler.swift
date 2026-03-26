import Foundation

enum EventPriority: Int, Comparable {
    case low = 0, normal = 1, high = 2, critical = 3

    static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct AppEvent {
    let name: String
    let payload: [String: Any]
    let priority: EventPriority
    let occurredAt: Date
}

typealias EventHandler = (AppEvent) -> Void

class EventBus {
    private var handlers: [String: [EventHandler]] = [:]
    private var filters: [String: (AppEvent) -> Bool] = [:]

    // Reads naturally: eventBus.register(handler, for: "purchase")
    func register(_ handler: @escaping EventHandler, for eventName: String) {
        handlers[eventName, default: []].append(handler)
    }

    // Reads naturally: eventBus.remove(handlers, for: "purchase")
    func removeHandlers(for eventName: String) {
        handlers.removeValue(forKey: eventName)
    }

    // Reads naturally: eventBus.publish(event)
    func publish(_ event: AppEvent) {
        guard let eventHandlers = handlers[event.name] else { return }
        let passesFiler = filters[event.name].map { $0(event) } ?? true
        guard passesFiler else { return }
        eventHandlers.forEach { $0(event) }
    }

    // Reads naturally: eventBus.addFilter(predicate, for: "purchase")
    func addFilter(_ predicate: @escaping (AppEvent) -> Bool, for eventName: String) {
        filters[eventName] = predicate
    }

    // Reads naturally: eventBus.isSubscribed(to: "purchase")
    func isSubscribed(to eventName: String) -> Bool {
        return handlers[eventName]?.isEmpty == false
    }

    // Reads naturally: eventBus.events(with priority: .critical)
    func events(with priority: EventPriority, from log: [AppEvent]) -> [AppEvent] {
        return log.filter { $0.priority >= priority }
    }
}
