-- Both beacon whitelists are settled here rather than in data.lua, because
-- both need the full list of module categories and mods keep adding them right
-- up to this stage. A mod whose own final-fixes runs after ours can still
-- introduce a category neither list knows about -- nothing can be done about
-- that from here.
--
-- allowed_module_categories is unset on almost every beacon, and unset means
-- "all of them". So excluding one category takes materialising the whole list
-- and leaving that category out of it, not appending to anything.

local defs = require("prototypes.modules.definitions")
local carries = require("prototypes.shared.beacon-effects")

-- Sorted, because pairs() order over data.raw is not something to bake into a
-- prototype every client has to agree on.
local function every_category()
  local names = {}
  for name in pairs(data.raw["module-category"]) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

local function without(names, blocked)
  local kept = {}
  for _, name in ipairs(names) do
    if not blocked[name] then
      kept[#kept + 1] = name
    end
  end
  return kept
end

-- The Pure beacon: everything except the effects it is set not to transmit.
-- A module that gets in but whose effect is not in allowed_effects would sit
-- there doing nothing, which reads as a bug rather than a setting.
local blocked_from_pure = {}
if not carries.productivity then
  blocked_from_pure["productivity"] = true
  blocked_from_pure["pure-productivity"] = true
end
if not carries.quality then
  blocked_from_pure["quality"] = true
  blocked_from_pure["pure-quality"] = true
end

local pure_beacon = data.raw["beacon"]["pure-beacon"]
if pure_beacon and next(blocked_from_pure) then
  pure_beacon.allowed_module_categories = without(every_category(), blocked_from_pure)
end

-- Every other beacon: no Pure modules. Machines are untouched -- this only
-- ever writes to beacon prototypes.
if settings.startup["pure-modules-realk-restrict-to-pure-beacon"].value then
  local pure_categories = {}
  for _, def in pairs(defs) do
    pure_categories[def.category] = true
  end

  for name, beacon in pairs(data.raw["beacon"]) do
    if name ~= "pure-beacon" then
      beacon.allowed_module_categories =
        without(beacon.allowed_module_categories or every_category(), pure_categories)
    end
  end
end
