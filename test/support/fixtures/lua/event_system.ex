defmodule Test.Fixtures.Lua.EventSystem do
  @moduledoc false
  use Test.LanguageFixture, language: "lua event_system"

  @code ~S'''
  function EventEmitter()
  local self = { listeners = {}, onceListeners = {} }

  function self:on(event, callback)
    if not self.listeners[event] then
      self.listeners[event] = {}
    end
    table.insert(self.listeners[event], callback)
    return self
  end

  function self:once(event, callback)
    if not self.onceListeners[event] then
      self.onceListeners[event] = {}
    end
    table.insert(self.onceListeners[event], callback)
    return self
  end

  function self:off(event, callback)
    if self.listeners[event] then
      for i, cb in ipairs(self.listeners[event]) do
        if cb == callback then
          table.remove(self.listeners[event], i)
          return self
        end
      end
    end
    return self
  end

  function self:emit(event, ...)
    local listeners = self.listeners[event] or {}
    for _, cb in ipairs(listeners) do
      cb(...)
    end
    local onceListeners = self.onceListeners[event] or {}
    self.onceListeners[event] = {}
    for _, cb in ipairs(onceListeners) do
      cb(...)
    end
    return self
  end

  function self:removeAllListeners(event)
    if event then
      self.listeners[event] = nil
      self.onceListeners[event] = nil
    else
      self.listeners = {}
      self.onceListeners = {}
    end
    return self
  end

  return self
  end

  function pipe(emitter1, event, emitter2, targetEvent)
  emitter1:on(event, function(...)
    emitter2:emit(targetEvent or event, ...)
  end)
  end

  function broadcast(emitters, event, ...)
  for _, emitter in ipairs(emitters) do
    emitter:emit(event, ...)
  end
  end
  '''
end
