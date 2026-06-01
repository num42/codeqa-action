import logger from "./logger.js";

class EventBus {
  constructor() {
    this._handlers = new Map();
    this._deadLetterQueue = [];
  }

  subscribe(eventName, handler) {
    if (!this._handlers.has(eventName)) {
      this._handlers.set(eventName, []);
    }
    this._handlers.get(eventName).push(handler);
  }

  unsubscribe(eventName, handler) {
    const handlers = this._handlers.get(eventName);
    if (!handlers) return;
    const index = handlers.indexOf(handler);
    if (index !== -1) {
      handlers.splice(index, 1);
    }
  }

  async publish(eventName, payload) {
    const handlers = this._handlers.get(eventName) ?? [];

    for (const handler of handlers) {
      try {
        await handler(payload);
      } catch (err) {
        logger.error(
          `EventBus: handler for '${eventName}' threw an error`,
          err
        );
        this._deadLetterQueue.push({ eventName, payload, error: err, ts: Date.now() });
      }
    }
  }

  async publishOrFail(eventName, payload) {
    const handlers = this._handlers.get(eventName) ?? [];

    for (const handler of handlers) {
      await handler(payload);
    }
  }

  drainDeadLetterQueue() {
    const items = [...this._deadLetterQueue];
    this._deadLetterQueue.length = 0;
    return items;
  }
}

async function initializeAnalytics(bus) {
  try {
    await bus.publish("analytics:init", { timestamp: Date.now() });
  } catch (err) {
    // Analytics is non-critical; log and continue application startup
    logger.warn("Analytics initialization failed, proceeding without it", err);
  }
}

const bus = new EventBus();
export { bus, EventBus, initializeAnalytics };
