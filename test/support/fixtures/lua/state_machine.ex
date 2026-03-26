defmodule Test.Fixtures.Lua.StateMachine do
  @moduledoc false
  use Test.LanguageFixture, language: "lua state_machine"

  @code ~S'''
  function StateMachine(config)
  local self = {
    current = config.initial,
    states = config.states or {},
    transitions = config.transitions or {},
    history = {},
    listeners = {},
  }

  function self:can(event)
    local key = self.current .. ":" .. event
    return self.transitions[key] ~= nil
  end

  function self:transition(event, data)
    local key = self.current .. ":" .. event
    local target = self.transitions[key]
    if not target then
      error("No transition from '" .. self.current .. "' on event '" .. event .. "'")
    end
    local from = self.current
    local stateConfig = self.states[from] or {}
    if stateConfig.onExit then stateConfig.onExit(from, event, data) end
    table.insert(self.history, { state = from, event = event })
    self.current = target
    local targetConfig = self.states[target] or {}
    if targetConfig.onEnter then targetConfig.onEnter(target, event, data) end
    for _, cb in ipairs(self.listeners) do
      cb(from, event, target, data)
    end
    return self
  end

  function self:onTransition(callback)
    table.insert(self.listeners, callback)
    return self
  end

  function self:getHistory()
    return self.history
  end

  function self:reset()
    self.current = config.initial
    self.history = {}
    return self
  end

  return self
  end

  function buildTransitionTable(transitions)
  local tbl = {}
  for _, t in ipairs(transitions) do
    local key = t.from .. ":" .. t.event
    tbl[key] = t.to
  end
  return tbl
  end

  function validateMachine(machine, requiredStates)
  for _, state in ipairs(requiredStates) do
    if not machine.states[state] then
      return false, "Missing state: " .. state
    end
  end
  return true, nil
  end
  '''
end
