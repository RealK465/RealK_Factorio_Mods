-- The reachable set over a parent-pointer wire field, walked undirected: which entity
-- indices one wire component actually joins. Shared by the pure pole and circuit specs --
-- both pin CONNECTIVITY rather than wire values, per the suite's own discipline (a rewired
-- tree that still connects everything is a valid answer), and each carried this walk
-- independently until the third copy appeared. blueprint_spec's walker stays its own: it
-- walks live ghost connectors, not a plan field. Pure by construction: standard Lua only.
local function component(entities, start, field)
  local adjacent = {}
  local function edge(a, b)
    adjacent[a] = adjacent[a] or {}
    adjacent[a][#adjacent[a] + 1] = b
  end
  for index, entity in pairs(entities) do
    local to = entity[field]
    if to then
      edge(index, to)
      edge(to, index)
    end
  end
  local seen, stack = { [start] = true }, { start }
  while #stack > 0 do
    local index = stack[#stack]
    stack[#stack] = nil
    for _, other in pairs(adjacent[index] or {}) do
      if not seen[other] then
        seen[other] = true
        stack[#stack + 1] = other
      end
    end
  end
  return seen
end

return component
