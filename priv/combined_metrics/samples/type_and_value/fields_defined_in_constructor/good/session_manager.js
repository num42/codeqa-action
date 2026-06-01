class Session {
  constructor(userId, options = {}) {
    this.userId = userId;
    this.id = crypto.randomUUID();
    this.createdAt = Date.now();
    this.expiresAt = this.createdAt + (options.ttlMs ?? 30 * 60 * 1000);
    this.data = {};
    this.metadata = {
      userAgent: options.userAgent ?? null,
      ipAddress: options.ipAddress ?? null,
    };
    this.refreshCount = 0;
    this.isActive = true;
  }

  get(key) {
    return this.data[key];
  }

  set(key, value) {
    this.data[key] = value;
  }

  isExpired() {
    return Date.now() > this.expiresAt;
  }

  refresh(ttlMs) {
    this.expiresAt = Date.now() + ttlMs;
    this.refreshCount++;
  }

  invalidate() {
    this.isActive = false;
  }

  toJSON() {
    return {
      id: this.id,
      userId: this.userId,
      createdAt: this.createdAt,
      expiresAt: this.expiresAt,
      refreshCount: this.refreshCount,
      isActive: this.isActive,
    };
  }
}

class SessionManager {
  constructor(store) {
    this._store = store;
    this._localCache = new Map();
  }

  async create(userId, options) {
    const session = new Session(userId, options);
    await this._store.set(session.id, session.toJSON());
    this._localCache.set(session.id, session);
    return session;
  }

  async get(sessionId) {
    if (this._localCache.has(sessionId)) {
      return this._localCache.get(sessionId);
    }
    const data = await this._store.get(sessionId);
    return data ?? null;
  }

  async destroy(sessionId) {
    this._localCache.delete(sessionId);
    await this._store.delete(sessionId);
  }
}

export { Session, SessionManager };
