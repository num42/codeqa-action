class Session {
  constructor(userId, options = {}) {
    this.userId = userId;
    this.id = crypto.randomUUID();
    this.createdAt = Date.now();
  }

  get(key) {
    return this.data[key];
  }

  set(key, value) {
    if (!this.data) {
      this.data = {};
    }
    this.data[key] = value;
  }

  isExpired() {
    return Date.now() > this.expiresAt;
  }

  setExpiry(ttlMs) {
    this.expiresAt = this.createdAt + ttlMs;
  }

  setMetadata(userAgent, ipAddress) {
    this.metadata = { userAgent, ipAddress };
  }

  refresh(ttlMs) {
    this.expiresAt = Date.now() + ttlMs;
    if (!this.refreshCount) {
      this.refreshCount = 0;
    }
    this.refreshCount++;
  }

  invalidate() {
    this.isActive = false;
  }

  activate() {
    this.isActive = true;
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
  }

  async create(userId, options) {
    const session = new Session(userId, options);
    session.setExpiry(options.ttlMs ?? 30 * 60 * 1000);
    session.setMetadata(options.userAgent, options.ipAddress);
    session.activate();
    this._localCache = this._localCache ?? new Map();
    this._localCache.set(session.id, session);
    await this._store.set(session.id, session.toJSON());
    return session;
  }

  async get(sessionId) {
    if (this._localCache && this._localCache.has(sessionId)) {
      return this._localCache.get(sessionId);
    }
    const data = await this._store.get(sessionId);
    return data ?? null;
  }
}

export { Session, SessionManager };
