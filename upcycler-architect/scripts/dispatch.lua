-- GUI handler registry: flib's mechanism, hand-rolled at the size this mod needs.
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
local TAG = "ua_handler"

function dispatch.register(name, handler)
  handlers[name] = handler
end

-- Build the tags table for LuaGuiElement.add.
function dispatch.tags(name, extra)
  local tags = extra or {}
  tags[TAG] = name
  return tags
end

function dispatch.on_gui_event(event)
  local element = event.element
  -- flib skips the valid check; an element destroyed between the click and the handler is
  -- cheap to guard against and expensive to debug.
  if not (element and element.valid) then return end

  local name = element.tags[TAG]
  if not name then return end

  local handler = handlers[name]
  if handler then handler(event) end
end

return dispatch
