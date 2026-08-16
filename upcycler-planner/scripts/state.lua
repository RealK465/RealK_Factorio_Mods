-- Everything this mod persists, which is deliberately almost nothing: the player's last GUI
-- choices, and a snapshot of them taken when Confirm is pressed and the tool goes into the
-- cursor. Plans are never stored -- they are rebuilt from the snapshot at click time, which is
-- cheap and means no half-finished plan can straddle a save.
--
-- Keyed per player from the start. Sharing one table between players is the mistake that only
-- shows up when someone opens a multiplayer game.

local state = {}

local util = require("util")
local planner = require("scripts.planner")

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

function state.forget(player_index)
  storage.players[player_index] = nil
end

-- Confirm's snapshot: a plain copy of the live choices, so reopening the modal while the tool
-- is in hand cannot change what is about to be placed. A copy loop rather than a named field
-- list, so a newly added choice cannot be silently left out of the snapshot.
function state.arm(player_index)
  local entry = state.of(player_index)
  local snapshot = {}
  for key, value in pairs(entry.choices) do snapshot[key] = value end
  entry.pending = snapshot
end

-- Drop any choice that no longer QUALIFIES, not merely one that no longer exists: a mod update
-- can keep a prototype's name while turning it into something the planner can no longer use
-- (a machine that lost its module slots, a "recycler" that stopped recycling), and prototypes
-- only ever change on a configuration change -- which is exactly when this runs. Membership in
-- the planner's own candidate lists is the test that cannot drift from what plan() accepts.
function state.prune()
  if not storage.players then return end
  local machines = util.list_to_map(planner.machine_candidates())
  local recyclers = util.list_to_map(planner.recyclers())
  for _, entry in pairs(storage.players) do
    local c = entry.choices
    local recipe = c.recipe and prototypes.recipe[c.recipe]
    if not (recipe and planner.is_upcyclable(recipe)) then c.recipe = nil end
    if c.machine and not machines[c.machine] then c.machine = nil end
    if c.recycler and not recyclers[c.recycler] then c.recycler = nil end
    if c.belt and not planner.is_belt(c.belt) then c.belt = nil end
    if c.quality and not planner.is_quality(c.quality) then c.quality = nil end
    if c.quality_module and not planner.is_quality_module(c.quality_module) then
      c.quality_module = nil
    end
    -- c.no_poles is a plain boolean, never a prototype reference -- nothing to prune there.
    if c.pole and not planner.is_pole(c.pole) then c.pole = nil end
    -- The qualities the buildings and modules are placed AT are choices in their own right,
    -- separate from the target above, and a mod can take a tier out from under any of them.
    for _, key in pairs({ "machine_quality", "recycler_quality", "quality_module_quality", "pole_quality" }) do
      if c[key] and not planner.is_quality(c[key]) then c[key] = nil end
    end
    entry.pending = nil
  end
end

return state
