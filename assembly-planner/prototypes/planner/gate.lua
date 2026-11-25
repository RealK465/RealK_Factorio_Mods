-- Which technology the planner's shortcut waits for: the earliest one that makes a requester
-- chest. Vanilla's answer is `logistic-system` (behind space science in Space Age), but a mod
-- can hand requesters out sooner, or add requesters of its own -- so the gate is read off the
-- finished data: every requester-mode logistic container, the items that place one, the
-- recipes that make those items, and the technologies that unlock those recipes. The one with
-- the fewest prerequisites wins. A recipe enabled from the start means no gate at all.
--
-- A recycling recipe or a Factoriopedia-hidden one never counts as a way to build something:
-- recycling hands back what it grinds, and cheat tools ship their free recipes hidden.
--
-- Pure over a data.raw-shaped table, so tests/pure/gate_spec.lua runs it on host Lua too.

local gate = {}

local function contains(list, wanted)
  for _, value in pairs(list or {}) do
    if value == wanted then return true end
  end
  return false
end

-- In the data stage hidden_in_factoriopedia defaults to hidden; the runtime reads it resolved.
local function hidden_in_factoriopedia(prototype)
  if prototype.hidden_in_factoriopedia ~= nil then return prototype.hidden_in_factoriopedia end
  return prototype.hidden == true
end

-- Every technology standing before this one, each counted once however many paths reach it.
local function prerequisite_count(technologies, name)
  local seen, stack, count = { [name] = true }, { name }, 0
  while #stack > 0 do
    local technology = technologies[stack[#stack]]
    stack[#stack] = nil
    for _, prerequisite in pairs(technology and technology.prerequisites or {}) do
      if not seen[prerequisite] then
        seen[prerequisite] = true
        count = count + 1
        stack[#stack + 1] = prerequisite
      end
    end
  end
  return count
end

-- raw is data.raw or a table shaped like it; item_types the item prototype types to look in,
-- keyed by type (defines.prototypes.item in the game). Returns the technology's name, false
-- when a requester can be built from the start, or nil when nothing builds one at all --
-- which leaves the shortcut's own gate standing.
function gate.technology(raw, item_types)
  local requesters = {}
  for name, entity in pairs(raw["logistic-container"] or {}) do
    if entity.logistic_mode == "requester" then requesters[name] = true end
  end

  local items = {}
  for kind in pairs(item_types) do
    for name, item in pairs(raw[kind] or {}) do
      if item.place_result and requesters[item.place_result] then items[name] = true end
    end
  end

  local recipes = {}
  for name, recipe in pairs(raw.recipe or {}) do
    if not contains(recipe.categories, "recycling") and not hidden_in_factoriopedia(recipe) then
      for _, result in pairs(recipe.results or {}) do
        if result.type == "item" and items[result.name] then
          if recipe.enabled ~= false then return false end
          recipes[name] = true
        end
      end
    end
  end

  -- A technology disabled at the start ranks behind every enabled one: the player cannot
  -- research it, though a scenario still might. Ties go to the name, so the pick never rests
  -- on iteration order.
  local best, best_rank
  for name, technology in pairs(raw.technology or {}) do
    for _, effect in pairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and recipes[effect.recipe] then
        local rank = prerequisite_count(raw.technology, name)
          + (technology.enabled == false and 1e9 or 0)
        if not best or rank < best_rank or (rank == best_rank and name < best) then
          best, best_rank = name, rank
        end
        break
      end
    end
  end
  return best
end

return gate
