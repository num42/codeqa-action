defmodule Test.Fixtures.Lua.ClassSystem do
  @moduledoc false
  use Test.LanguageFixture, language: "lua class_system"

  @code ~S'''
  function class(parent)
  local cls = {}
  cls.__index = cls
  if parent then
    setmetatable(cls, { __index = parent })
  end
  cls.new = function(...)
    local instance = setmetatable({}, cls)
    if instance.init then
      instance:init(...)
    end
    return instance
  end
  cls.isInstanceOf = function(self, klass)
    local mt = getmetatable(self)
    while mt do
      if mt == klass then return true end
      mt = getmetatable(mt)
    end
    return false
  end
  return cls
  end

  function mixin(target, source)
  for key, value in pairs(source) do
    if type(value) == "function" and not target[key] then
      target[key] = value
    end
  end
  return target
  end

  function interface(...)
  local methods = { ... }
  return function(obj)
    for _, method in ipairs(methods) do
      if type(obj[method]) ~= "function" then
        error("Missing method: " .. method)
      end
    end
    return true
  end
  end

  function extend(parent, definition)
  local cls = class(parent)
  for k, v in pairs(definition) do
    cls[k] = v
  end
  return cls
  end

  function implements(obj, iface)
  return pcall(iface, obj)
  end
  '''
end
