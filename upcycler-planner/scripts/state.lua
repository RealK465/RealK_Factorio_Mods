-- Everything this mod persists, which is deliberately almost nothing: the player's last GUI
-- choices, plus one transient flag (`chooser_maybe_open`, owned by gui.lua) that lives and
-- dies with the open modal. Plans are never stored -- Confirm designs one, bakes it into the
-- blueprint it hands over, and forgets it, so no half-finished plan can straddle a save and
-- reopening the modal cannot change what is already in the player's hand.
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

-- The entry without creating one. The GUI's event observer runs for every player's every
-- click, ours or not, and a player who never opened the planner must not gain an entry
-- from walking past someone else's buttons.
function state.peek(player_index)
  return storage.players[player_index]
end

function state.forget(player_index)
  storage.players[player_index] = nil
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
    if c.pipe and not planner.is_pipe(c.pipe) then c.pipe = nil end
    if c.quality and not planner.is_quality(c.quality) then c.quality = nil end
    if c.quality_module and not planner.is_quality_module(c.quality_module) then
      c.quality_module = nil
    end
    -- The split's productivity module prunes by ROLE like the quality module -- both are
    -- belt-shape pickers whose stale pick falls back to a default -- where the terminal and
    -- beacon modules below prune by mere module membership, their pickers offering any family.
    if c.productivity_module and not planner.is_productivity_module(c.productivity_module) then
      c.productivity_module = nil
    end
    -- c.no_poles is a plain boolean, never a prototype reference -- nothing to prune there.
    if c.pole and not planner.is_pole(c.pole) then c.pole = nil end
    -- A pruned beacon simply reads as off -- it has no default to fall back to. Its module is
    -- membership-only like the terminal module's; c.no_beacon_module is a boolean, left alone.
    if c.beacon and not planner.is_beacon(c.beacon) then c.beacon = nil end
    if c.beacon_module and not planner.is_module(c.beacon_module) then c.beacon_module = nil end
    if c.inserter and not planner.is_inserter(c.inserter) then c.inserter = nil end
    -- Membership only: whether the MACHINE and RECIPE accept it is validate's business, and a
    -- prune that guessed at it would silently drop a pick the modal is about to explain.
    -- c.no_terminal_module is a plain boolean, like c.no_poles -- nothing to prune.
    if c.terminal_module and not planner.is_module(c.terminal_module) then
      c.terminal_module = nil
    end
    -- The stock role prunes against the KIND the player's checkbox picks, so a pick left over
    -- from the other kind falls back the way a stale prototype does. c.buffer_stock itself is
    -- a plain boolean like no_poles -- nothing to prune.
    for _, role in pairs(planner.CHEST_ROLES) do
      if c[role] and not planner.is_chest(c[role], role, planner.stock_buffered(c)) then
        c[role] = nil
      end
    end
    -- The qualities the buildings and modules are placed AT are choices in their own right,
    -- separate from the target above, and a mod can take a tier out from under any of them.
    -- Matched by key rather than listed by name: a picker added later must not be able to keep
    -- a tier that no longer exists just because nobody remembered to add its key here. The
    -- target `quality` has no underscore, so it keeps its own test above.
    -- One pass, the precedence structural: a circuit reserve or cap prunes by the quality in
    -- its KEY (circuit_min_<quality> / circuit_max_<quality> hold numbers), and only what
    -- neither family claims falls through to the value test -- so a modded tier whose own
    -- name ends in _quality cannot trip the wrong sweep. circuit_enabled, circuit_paused and
    -- split_enabled are plain booleans and circuit_hand and feed_minutes plain numbers, like
    -- no_poles nothing to prune; the target `quality` has no underscore and keeps its own
    -- test above.
    -- The ingredient-amount overrides belong to the chosen recipe: request_<item> holds the
    -- player's number for one of ITS ingredients, so an override whose item left the recipe --
    -- or whose recipe was itself pruned above -- goes with it. The formula default needs no
    -- key to fall back to. Claimed structurally in the loop below, ahead of the _quality$
    -- sweep, for the circuit families' reason.
    local wanted = {}
    -- `recipe` is the prototype resolved at the top of this iteration; c.recipe survived its
    -- upcyclable check exactly when it is still set, so the pair answers "the kept recipe".
    if c.recipe then
      local items = planner.item_ingredients(recipe)
      for _, ingredient in pairs(items) do
        wanted[ingredient.name] = true
      end
    end
    for key, quality in pairs(c) do
      local tier = key:match("^circuit_min_(.+)$") or key:match("^circuit_max_(.+)$")
        or key:match("^split_prod_(.+)$") or key:match("^column_count_(.+)$")
      local item = key:match("^request_(.+)$")
      if tier then
        if not planner.is_quality(tier) then c[key] = nil end
      elseif item then
        if not wanted[item] then c[key] = nil end
      elseif key:match("_quality$") and not planner.is_quality(quality) then
        c[key] = nil
      end
    end
    -- Left by 0.3.1 and earlier, which snapshotted the choices when the placement tool went
    -- into the cursor. Nothing reads it now, and the first configuration change after the
    -- upgrade clears it -- after which this line is dead and can go at the next major bump.
    -- It earns its keep only so the promise at the top of this file is true of old saves too.
    entry.pending = nil
    -- Left by a dev build of 0.4.2 that positioned the settings window by inference; never
    -- shipped, and nothing reads them now.
    entry.modal_width, entry.modal_moved, entry.settings_moved = nil, nil, nil
  end
end

return state
