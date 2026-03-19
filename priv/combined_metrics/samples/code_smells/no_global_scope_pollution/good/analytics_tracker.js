const SESSION_KEY = "analytics_session";
const MAX_QUEUE_SIZE = 100;

class AnalyticsTracker {
  constructor(config) {
    this._endpoint = config.endpoint;
    this._apiKey = config.apiKey;
    this._queue = [];
    this._sessionId = this._loadOrCreateSession();
    this._flushTimer = null;
  }

  track(eventName, properties = {}) {
    if (this._queue.length >= MAX_QUEUE_SIZE) {
      this._flushQueue();
    }

    this._queue.push({
      event: eventName,
      properties,
      sessionId: this._sessionId,
      timestamp: Date.now(),
    });

    this._scheduleFlush();
  }

  identify(userId, traits = {}) {
    this.track("$identify", { userId, ...traits });
  }

  async flush() {
    await this._flushQueue();
  }

  _scheduleFlush() {
    if (this._flushTimer) return;
    this._flushTimer = setTimeout(() => {
      this._flushTimer = null;
      this._flushQueue();
    }, 2000);
  }

  async _flushQueue() {
    if (this._queue.length === 0) return;
    const events = this._queue.splice(0, this._queue.length);
    await fetch(this._endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Api-Key": this._apiKey },
      body: JSON.stringify({ events }),
    });
  }

  _loadOrCreateSession() {
    const stored = sessionStorage.getItem(SESSION_KEY);
    if (stored) return stored;
    const id = crypto.randomUUID();
    sessionStorage.setItem(SESSION_KEY, id);
    return id;
  }
}

const tracker = new AnalyticsTracker({
  endpoint: "/api/analytics",
  apiKey: process.env.ANALYTICS_API_KEY,
});

export { tracker, AnalyticsTracker };
