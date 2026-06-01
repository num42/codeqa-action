class EventBus {
  constructor() {
    this._handlers = new Map();
  }

  subscribe(eventName, handler) {
    if (!this._handlers.has(eventName)) {
      this._handlers.set(eventName, []);
    }
    this._handlers.get(eventName).push(handler);
  }

  unsubscribe(eventName, handler) {
    try {
      const handlers = this._handlers.get(eventName);
      const index = handlers.indexOf(handler);
      handlers.splice(index, 1);
    } catch (e) {
    }
  }

  async publish(eventName, payload) {
    const handlers = this._handlers.get(eventName) ?? [];

    for (const handler of handlers) {
      try {
        await handler(payload);
      } catch (e) {
      }
    }
  }

  async publishAll(events) {
    for (const { name, payload } of events) {
      try {
        await this.publish(name, payload);
      } catch {
      }
    }
  }
}

async function initializeAnalytics(bus) {
  try {
    await bus.publish("analytics:init", { timestamp: Date.now() });
  } catch (e) {
  }
}

async function loadUserPreferences(userId, bus) {
  try {
    const prefs = await fetch(`/api/users/${userId}/preferences`).then((r) =>
      r.json()
    );
    await bus.publish("preferences:loaded", prefs);
  } catch (err) {
  }
}

const bus = new EventBus();
export { bus, EventBus, initializeAnalytics, loadUserPreferences };
