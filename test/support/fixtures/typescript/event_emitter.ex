defmodule Test.Fixtures.TypeScript.EventEmitter do
  @moduledoc false
  use Test.LanguageFixture, language: "typescript event_emitter"

  @code ~S'''
  interface EventMap {
    [event: string]: unknown;
  }

  interface Listener<T> {
    callback: (data: T) => void;
    once: boolean;
  }

  class EventEmitter<T extends EventMap> {
    private listeners: Map<keyof T, Array<Listener<unknown>>>;

    constructor() {
      this.listeners = new Map();
    }

    on<K extends keyof T>(event: K, callback: (data: T[K]) => void): this {
      if (!this.listeners.has(event)) {
        this.listeners.set(event, []);
      }
      this.listeners.get(event)!.push({ callback: callback as (data: unknown) => void, once: false });
      return this;
    }

    once<K extends keyof T>(event: K, callback: (data: T[K]) => void): this {
      if (!this.listeners.has(event)) {
        this.listeners.set(event, []);
      }
      this.listeners.get(event)!.push({ callback: callback as (data: unknown) => void, once: true });
      return this;
    }

    off<K extends keyof T>(event: K, callback: (data: T[K]) => void): this {
      const list = this.listeners.get(event);
      if (list) {
        this.listeners.set(event, list.filter(function(l) { return l.callback !== callback; }));
      }
      return this;
    }

    emit<K extends keyof T>(event: K, data: T[K]): boolean {
      const list = this.listeners.get(event);
      if (!list || list.length === 0) return false;
      list.forEach(function(listener) { listener.callback(data); });
      this.listeners.set(event, list.filter(function(l) { return !l.once; }));
      return true;
    }

    removeAllListeners(event?: keyof T): this {
      if (event) {
        this.listeners.delete(event);
      } else {
        this.listeners.clear();
      }
      return this;
    }
  }

  function createEmitter<T extends EventMap>(): EventEmitter<T> {
    return new EventEmitter<T>();
  }
  '''
end
