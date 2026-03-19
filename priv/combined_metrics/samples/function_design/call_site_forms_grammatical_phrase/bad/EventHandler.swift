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

typealias EventCallback = (AppEvent) -> Void

class EventBus {
    private var handlers: [String: [EventCallback]] = [:]
    private var filters: [String: (AppEvent) -> Bool] = [:]

    // Reads awkwardly: eventBus.handlerRegistration(callback, eventName: "purchase")
    func handlerRegistration(_ callback: @escaping EventCallback, eventName: String) {
        handlers[eventName, default: []].append(callback)
    }

    // Reads awkwardly: eventBus.handlerRemoval(eventName: "purchase")
    func handlerRemoval(eventName: String) {
        handlers.removeValue(forKey: eventName)
    }

    // Reads awkwardly: eventBus.eventPublishing(event)
    func eventPublishing(_ event: AppEvent) {
        guard let eventHandlers = handlers[event.name] else { return }
        let passes = filters[event.name].map { $0(event) } ?? true
        guard passes else { return }
        eventHandlers.forEach { $0(event) }
    }

    // Reads awkwardly: eventBus.filterAddition(predicate, eventName: "purchase")
    func filterAddition(_ predicate: @escaping (AppEvent) -> Bool, eventName: String) {
        filters[eventName] = predicate
    }

    // Reads awkwardly: eventBus.subscriptionCheck(eventName: "purchase")
    func subscriptionCheck(eventName: String) -> Bool {
        return handlers[eventName]?.isEmpty == false
    }

    // Reads awkwardly: eventBus.priorityFiltering(priority: .critical, log: events)
    func priorityFiltering(priority: EventPriority, log: [AppEvent]) -> [AppEvent] {
        return log.filter { $0.priority >= priority }
    }
}
