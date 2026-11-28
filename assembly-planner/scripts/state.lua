-- Everything this mod persists, which is deliberately almost nothing: each player's last
-- planner choices, the chain's cells, plus one transient flag (`chooser_maybe_open`, owned by
-- gui.lua) that lives and dies with the open modal. Plans are never stored -- Place designs
-- one, bakes it into the blueprint it hands over, and forgets it.
--
-- `choices` is the root cell's and the chain's; `cells[item]` is one ingredient cell's own --
-- `on` while ticked, plus the choice keys it owns (chain.lua). Each a table of flat values
-- only -- strings, numbers, booleans -- never a { name, quality } table.

local state = {}

local proto = require("scripts.proto")
local chain = require("scripts.chain")

function state.init()
  storage.players = {}
end

function state.of(player_index)
  local entry = storage.players[player_index]
  if not entry then
    entry = { choices = {}, cells = {} }
    storage.players[player_index] = entry
  end
  -- Entries from before production chains have no cells.
  if not entry.cells then entry.cells = {} end
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

-- One table of choices made for `item`: the root's, or an ingredient cell's own.
local function prune_choices(c, item)
  if c.recipe and not (item and proto.contains(proto.recipes_for_item(item), c.recipe)) then
    c.recipe = nil
  end
  for key, test in pairs(MEMBERSHIP) do
    if c[key] and not test(c[key]) then c[key] = nil end
  end
  if c.count ~= nil and chain.count_of(c.count) ~= c.count then c.count = nil end

  -- A per-ingredient amount belongs to the item's recipes; one whose ingredient none of them
  -- takes any more goes. Every recipe counts, not only the remembered one: which recipe a
  -- player gets by default depends on research, and a prune has no business guessing it.
  local wanted = {}
  for _, name in pairs(item and proto.recipes_for_item(item) or {}) do
    for _, ingredient in pairs((proto.item_ingredients(prototypes.recipe[name]))) do
      wanted[ingredient.name] = true
    end
  end
  for key, value in pairs(c) do
    local ingredient = key:match("^request_(.+)$")
    if ingredient then
      if not wanted[ingredient] then c[key] = nil end
    elseif key:match("_quality$") and not proto.is_quality(value) then
      c[key] = nil
    end
  end
end

-- Drops any choice that no longer QUALIFIES, not merely one that no longer exists: a mod
-- update can keep a name while changing what the prototype is, and prototypes only ever change
-- on a configuration change -- which is exactly when this runs. A cell whose item no cell can
-- make any more goes whole; with no root item left, so does the chain.
function state.prune()
  if not storage.players then return end
  for _, entry in pairs(storage.players) do
    local c = entry.choices
    if c.item and not proto.has_cell_recipe(c.item) then c.item = nil end
    prune_choices(c, c.item)
    if not c.item then entry.cells = {} end
    for item, cell in pairs(entry.cells or {}) do
      if not proto.has_cell_recipe(item) then
        entry.cells[item] = nil
      else
        prune_choices(cell, item)
      end
    end
  end
end

return state
