-- The circuit stack by role: the limits combinator and, under a cap, the two status lamps
-- and the display panel -- absent keys for what a plan did not stand. Shared by the pure
-- layout and circuits specs and the in-game plan spec, which each carried the four names
-- independently until this owner appeared. Pure by construction: standard Lua only.
local circuit_stack = {}

circuit_stack.ROLES = { limits = true, lamp_done = true, lamp_running = true, panel = true }

-- entities: a plan's or a built layout's entity array. Returns the stack keyed by role,
-- and how many of the four were found.
function circuit_stack.of(entities)
  local out, count = {}, 0
  for _, e in pairs(entities) do
    if circuit_stack.ROLES[e.circuit_role] then
      out[e.circuit_role] = e
      count = count + 1
    end
  end
  return out, count
end

return circuit_stack
