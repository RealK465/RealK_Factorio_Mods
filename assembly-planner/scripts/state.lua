-- Everything this mod persists, which is deliberately almost nothing: each player's last
-- planner choices, plus one transient flag (`chooser_maybe_open`, owned by gui.lua) that lives
-- and dies with the open modal. Plans are never stored -- Place designs one, bakes it into the
-- blueprint it hands over, and forgets it.
--
-- Flat values only -- strings, numbers, booleans -- never a { name, quality } table.

local state = {}

local proto = require("scripts.proto")

function state.init()
  storage.players = {}
end

function state.of(player_index)
  local entry = storage.players[player_index]
  if not entry then
    entry = { choices = {} }
    storage.players[player_index] = entry
  end
  return entry
end

-- The entry without creating one: the GUI's event observer runs for every player's every
-- click, and a player who never opened the planner must not gain an entry from it.
function state.peek(player_index)
  return storage.players[player_index]
end

function state.forget(player_index)
  storage.players[player_index] = nil
end

-- What each remembered prototype pick must still be, tested against the planner's own
-- candidate lists so the test cannot drift from what plan.build accepts.
local MEMBERSHIP = {
  machine = proto.is_machine,
  module = proto.is_module,
  inserter = proto.is_inserter,
  requester = proto.is_requester,
  output = proto.is_output_chest,
  pipe = proto.is_pipe,
  beacon = proto.is_beacon,
  beacon_module = proto.is_module,
  pole = proto.is_pole,
}

-- Drops any choice that no longer QUALIFIES, not merely one that no longer exists: a mod
-- update can keep a name while changing what the prototype is, and prototypes only ever change
-- on a configuration change -- which is exactly when this runs.
function state.prune()
  if not storage.players then return end
  for _, entry in pairs(storage.players) do
    local c = entry.choices
    if c.item and #proto.recipes_for_item(c.item) == 0 then c.item = nil end
    if c.recipe and not (c.item and proto.contains(proto.recipes_for_item(c.item), c.recipe)) then
      c.recipe = nil
    end
    for key, test in pairs(MEMBERSHIP) do
      if c[key] and not test(c[key]) then c[key] = nil end
    end

    -- A per-ingredient amount belongs to the item's recipes; one whose ingredient none of them
    -- takes any more goes. Every recipe counts, not only the remembered one: which recipe a
    -- player gets by default depends on research, and a prune has no business guessing it.
    local wanted = {}
    for _, name in pairs(c.item and proto.recipes_for_item(c.item) or {}) do
      for _, ingredient in pairs((proto.item_ingredients(prototypes.recipe[name]))) do
        wanted[ingredient.name] = true
      end
    end
    for key, value in pairs(c) do
      local item = key:match("^request_(.+)$")
      if item then
        if not wanted[item] then c[key] = nil end
      elseif key:match("_quality$") and not proto.is_quality(value) then
        c[key] = nil
      end
    end
  end
end

return state
