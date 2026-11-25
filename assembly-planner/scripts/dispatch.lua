-- GUI handler registry: flib's mechanism, hand-rolled at the size this mod needs (copied from
-- Upcycler Planner).
--
-- The rule it exists to keep is that only NAME STRINGS ever reach saved state. A function in
-- element.tags or in storage throws on save; a table with a metatable loses the metatable
-- silently, which is worse. So the handlers live in a module-local table -- rebuilt identically
-- on every load because this file is required at control.lua's top level -- and the element
-- carries nothing but the string that looks one up.

local dispatch = {}

local handlers = {}

-- Namespaced so a stray element is traceable to this mod, and so it cannot collide with
-- another mod's tag on an element we did not create.
local TAG = "apl_handler"
dispatch.TAG = TAG

function dispatch.register(name, handler)
  handlers[name] = handler
end

-- The one observer that sees every event before tag routing, ours or not -- gui.lua uses it to
-- watch for the engine's element chooser, whose open and close the API never announces.
local observer

function dispatch.observe(fn)
  observer = fn
end

function dispatch.tags(name, extra)
  local tags = extra or {}
  tags[TAG] = name
  return tags
end

function dispatch.on_gui_event(event)
  -- Before the valid check on purpose: the observer's job includes noticing events on other
  -- mods' elements and on elements that died in flight.
  if observer then observer(event) end

  local element = event.element
  if not (element and element.valid) then return end

  local name = element.tags[TAG]
  if not name then return end

  local handler = handlers[name]
  if handler then handler(event) end
end

return dispatch
