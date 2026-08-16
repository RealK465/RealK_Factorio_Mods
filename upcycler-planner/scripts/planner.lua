-- Everything the GUI needs to know about prototypes: which items can be looped at all, which
-- machines can craft them, which quality tiers exist, and which modules and building materials
-- the player has unlocked.
--
-- All of it is derived from prototypes.* -- never from storage -- so every client computes the
-- same answers and the memo tables below can be thrown away and rebuilt on load, which is what
-- happens naturally because this file is required fresh each time. Nothing here is persisted.

local planner = {}

local layout = require("scripts.layout")
local poles = require("scripts.poles")

local memo = {}

-- THE 2.0 FORK. This file and these two helpers are most of the branch's divergence from
-- main: 2.0's LuaRecipePrototype has `category`/`additional_categories` where 2.1 has
-- `categories`, and no runtime mirror of `allow_quality` -- data-final-fixes.lua, a file this
-- branch alone carries, records that flag into mod-data instead. A cherry-pick from main that
-- touches these reads has to be rewritten, not merged; the evidence is
-- .ai-support/analysis/factorio-2.0.md.
local function recipe_categories(recipe)
  local categories = { recipe.category }
  for _, category in pairs(recipe.additional_categories or {}) do
    categories[#categories + 1] = category
  end
  return categories
end

local function recipe_can_set_quality(recipe)
  local blocked = prototypes.mod_data["upl-no-quality-recipes"]
  return not (blocked and blocked.get(recipe.name))
end

-- Guard against a quality chain that loops back on itself; prototypes.quality.next is a
-- linked list and a malformed mod could make it circular.
local MAX_QUALITY_TIERS = 32

-- Picks the highest-scoring entry out of a table and returns its KEY; `score_of(key, value)`
-- returns nil to reject one. Used for every "best the player has researched" question below,
-- so the comparison that decides them all lives in exactly one place.
--
-- Returning the key means callers must pass a table keyed by prototype name -- which
-- prototypes.entity and prototypes.item already are. Handing it a plain array gives back an
-- index, which then looks like a name until something indexes a prototype table with it.
local function best_by(candidates, score_of)
  local best, best_score
  for key, value in pairs(candidates) do
    local score = score_of(key, value)
    if score and (not best_score or score > best_score) then
      best, best_score = key, score
    end
  end
  return best
end

-- Positions and vectors arrive from the API in array form (documented "will always provide
-- the array format"); the x/y arm covers hand-written tables.
local function xy(v)
  return v[1] or v.x, v[2] or v.y
end

-- Quality tiers

-- normal first, then upward, skipping hidden tiers ("quality-unknown" is one of them).
function planner.quality_chain()
  if memo.qualities then return memo.qualities end

  -- Bounded by iterations, not by #chain: a malformed cycle of entirely HIDDEN tiers would
  -- never grow the chain, and a #chain bound would spin forever.
  local chain = {}
  local quality = prototypes.quality["normal"]
  for _ = 1, MAX_QUALITY_TIERS do
    if not quality then break end
    if not quality.hidden then chain[#chain + 1] = quality.name end
    quality = quality.next
  end

  memo.qualities = chain
  return chain
end

-- What the player may aim for. Upcycling to normal is a contradiction, so the first tier is
-- not offered.
function planner.target_qualities()
  if memo.targets then return memo.targets end

  local targets = {}
  local chain = planner.quality_chain()
  for i = 2, #chain do targets[#targets + 1] = chain[i] end

  memo.targets = targets
  return targets
end

-- The tiers a loop aiming at `target` climbs through, normal first.
function planner.tiers_up_to(target)
  local tiers = {}
  for _, name in pairs(planner.quality_chain()) do
    tiers[#tiers + 1] = name
    if name == target then return tiers end
  end
  return nil
end

-- Recipes

-- A loop can only be planned around a recipe with exactly one item product of a fixed amount:
-- anything else has no single thing to recycle back.
local function single_item_product(recipe)
  local found
  for _, product in pairs(recipe.products) do
    if product.type ~= "item" then return nil end
    if found then return nil end
    if not product.amount then return nil end
    found = product
  end
  return found
end

function planner.item_ingredients(recipe)
  local items, has_fluid = {}, false
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "fluid" then
      has_fluid = true
    else
      items[#items + 1] = ingredient
    end
  end
  return items, has_fluid
end

function planner.recycling_recipe(product_name)
  return prototypes.recipe[product_name .. "-recycling"]
end

-- The one check that makes the whole picker correct. The recycler mod generates
-- <item>-recycling from ONE canonical recipe, so if the player picked a different recipe for
-- the same product, recycling would hand back somebody else's ingredients and the loop would
-- leak. Requiring an exact set match also rejects, for free, the lossy self-recycling fallback
-- (which returns the item itself) and anything with no reversal at all.
local function recycling_closes_the_loop(recipe, product)
  local recycling = planner.recycling_recipe(product.name)
  if not recycling then return false end

  local wanted = {}
  for _, ingredient in pairs(planner.item_ingredients(recipe)) do
    wanted[ingredient.name] = true
  end
  local wanted_count = table_size(wanted)
  if wanted_count == 0 then return false end

  local matched = 0
  for _, result in pairs(recycling.products) do
    if result.type ~= "item" then return false end
    if not wanted[result.name] then return false end
    matched = matched + 1
  end

  return matched == wanted_count
end

local function is_recycling(recipe)
  for _, category in pairs(recipe_categories(recipe)) do
    if category == "recycling" then return true end
  end
  return false
end

function planner.is_upcyclable(recipe)
  if not recipe_can_set_quality(recipe) then return false end
  -- Two different rules with confusingly similar names: can_set_quality is whether the recipe
  -- can be CRAFTED at a quality, allow_quality (via allowed_effects) is whether quality modules
  -- work on it at all. Both have to hold: without the second, every machine in the loop carries
  -- an insert plan for a module it can never accept, while the recyclers keep rolling
  -- ingredients up regardless -- so the loop limps instead of stopping, which is worse to find.
  if not (recipe.allowed_effects and recipe.allowed_effects["quality"]) then return false end
  if recipe.hidden_from_player_crafting then return false end

  -- A recycling recipe would pass every test below by accident: it takes an item and returns
  -- that same item, which trivially "closes the loop" while producing nothing. The recycler
  -- mod excludes this category when generating recipes for the same reason.
  if is_recycling(recipe) then return false end

  local product = single_item_product(recipe)
  if not product then return false end

  local _, has_fluid = planner.item_ingredients(recipe)
  if has_fluid then return false end

  -- The recyclers carry quality modules too, so the RECYCLING recipe has to allow the effect
  -- for the same reason the crafting one does. Generated recipes inherit it, so this only ever
  -- bites when a mod restricts one by hand.
  local recycling = planner.recycling_recipe(product.name)
  if recycling and not (recycling.allowed_effects and recycling.allowed_effects["quality"]) then
    return false
  end

  return recycling_closes_the_loop(recipe, product)
end

-- The player picks an ITEM, not a recipe -- that is how the mod is described and it is also
-- the only thing the engine can filter a picker by, since RecipePrototypeFilter has no "name"
-- filter while ItemPrototypeFilter does. The recipe is then derived here.
--
-- Normally one recipe per item passes is_upcyclable, because recycling is generated from one
-- canonical recipe and the check demands an exact ingredient-set match -- but two recipes with
-- the same ingredient NAMES in different amounts would both pass, so first-found wins
-- (deterministic: pairs() iterates prototypes in a fixed order).
local function upcyclable()
  if memo.upcyclable then return memo.upcyclable end

  local items, recipe_for = {}, {}
  for name, recipe in pairs(prototypes.recipe) do
    if planner.is_upcyclable(recipe) then
      local product = single_item_product(recipe)
      if not recipe_for[product.name] then
        items[#items + 1] = product.name
        recipe_for[product.name] = name
      end
    end
  end

  memo.upcyclable = { items = items, recipe_for = recipe_for }
  return memo.upcyclable
end

function planner.upcyclable_items()
  return upcyclable().items
end

function planner.recipe_for_item(item_name)
  return item_name and upcyclable().recipe_for[item_name]
end

function planner.product_of(recipe)
  local product = single_item_product(recipe)
  return product and product.name
end

-- What the force can actually build

-- item name -> the recipes that produce it. Built once from prototypes so the "has the player
-- unlocked this?" test is a short lookup rather than a scan of every recipe each time.
--
-- Recycling recipes must not count as producers: researching the recycling technology unlocks
-- every generated *-recycling recipe at once, which would mark every grindable or
-- self-recycling item -- unresearched module tiers included -- as buildable. Neither must
-- Factoriopedia-hidden recipes: that is how cheat tools ship their free recipes (Editor
-- Extensions among them), and editor helpers force-enable those without any research.
local function producers()
  if memo.producers then return memo.producers end

  local map = {}
  for name, recipe in pairs(prototypes.recipe) do
    if not is_recycling(recipe) and not recipe.hidden_in_factoriopedia then
      for _, product in pairs(recipe.products) do
        if product.type == "item" then
          local list = map[product.name]
          if not list then list = {}; map[product.name] = list end
          list[#list + 1] = name
        end
      end
    end
  end

  memo.producers = map
  return map
end

function planner.is_unlocked(force, item_name)
  local recipes = producers()[item_name]
  if not recipes then return false end
  for _, recipe_name in pairs(recipes) do
    local recipe = force.recipes[recipe_name]
    if recipe and recipe.enabled then return true end
  end
  return false
end

-- An entity is placeable if any of the items that place it is unlocked.
local function entity_is_buildable(force, entity)
  local items = entity.items_to_place_this
  if not items then return false end
  for _, item in pairs(items) do
    if planner.is_unlocked(force, item.name) then return true end
  end
  return false
end

-- Candidate tables for the pickers, keyed name -> prototype so best_by returns the name.
-- Each predicate is pure prototype data, so the scan is memoised (identical on every client,
-- rebuilt on load, same as machine_candidates below); the FORCE checks -- buildability,
-- research -- stay inside each caller and run fresh per call, because research moves between
-- calls and a force-filtered result can never be memoised.
local function candidates(kind, accept)
  if memo[kind] then return memo[kind] end
  local map = {}
  for name, entity in pairs(prototypes.entity) do
    if accept(entity) then map[name] = entity end
  end
  memo[kind] = map
  return map
end

local function belt_candidates()
  return candidates("belts", function(entity) return entity.type == "transport-belt" end)
end

local function pole_candidates()
  return candidates("poles", function(entity) return entity.type == "electric-pole" end)
end

-- The layout stands every inserter between two adjacent rows, so its hands must reach exactly
-- one tile straight ahead. Without this gate the long-handed inserter -- reach 2, electric,
-- unlocked by the very first technology, and faster-rotating than the plain inserter -- wins
-- the pick for the whole early game and every inserter in the loop grabs from the wrong row.
local function reaches_adjacent_tiles(entity)
  local pickup, drop = entity.inserter_pickup_position, entity.inserter_drop_position
  if not (pickup and drop) then return false end
  local px, py = xy(pickup)
  local dx, dy = xy(drop)
  return math.abs(px) < 0.5 and py > -1.5 and py < -0.5
    and math.abs(dx) < 0.5 and dy > 0.5 and dy < 1.5
end

local function inserter_candidates()
  return candidates("inserters", function(entity)
    return entity.type == "inserter" and reaches_adjacent_tiles(entity)
  end)
end

-- Every chest position in the layout is one tile, so anything bigger is not a candidate --
-- AAI's 4x4 requester warehouse won the largest-inventory contest and the placed rows
-- overlapped into each other.
local function is_single_tile(entity)
  return entity.tile_width == 1 and entity.tile_height == 1
end

-- The subsets the pickers offer while "show all" is off. Force-filtered, so fresh on every
-- call; only the candidate scans above are memoised.

function planner.buildable(force, names)
  local out = {}
  for _, name in pairs(names) do
    local entity = prototypes.entity[name]
    if entity and entity_is_buildable(force, entity) then out[#out + 1] = name end
  end
  return out
end

function planner.unlocked_upcyclable_items(force)
  local items = {}
  for _, item in pairs(planner.upcyclable_items()) do
    local recipe = force.recipes[planner.recipe_for_item(item)]
    if recipe and recipe.enabled then items[#items + 1] = item end
  end
  return items
end

function planner.buildable_belts(force)
  local out = {}
  for name, entity in pairs(belt_candidates()) do
    if entity_is_buildable(force, entity) then out[#out + 1] = name end
  end
  return out
end

function planner.buildable_poles(force)
  local out = {}
  for name, entity in pairs(pole_candidates()) do
    if entity_is_buildable(force, entity) then out[#out + 1] = name end
  end
  return out
end

-- Membership tests for state.prune, exported so what prune keeps cannot drift from what
-- plan() accepts: is_belt is chosen_belt's own test, is_quality is membership in the chain
-- tiers_up_to walks.
function planner.is_belt(name)
  return belt_candidates()[name] ~= nil
end

function planner.is_pole(name)
  return pole_candidates()[name] ~= nil
end

function planner.is_quality(name)
  for _, quality in pairs(planner.quality_chain()) do
    if quality == name then return true end
  end
  return false
end

-- The quality a chosen building or module is placed at, as opposed to choices.quality, which is
-- the quality the loop PRODUCES. A remembered tier a mod has since removed reads as normal here
-- rather than erroring at placement time.
function planner.build_quality(name)
  if name and planner.is_quality(name) then return name end
  return "normal"
end

function planner.unlocked_targets(force)
  local out = {}
  for _, name in pairs(planner.target_qualities()) do
    if force.is_quality_unlocked(name) then out[#out + 1] = name end
  end
  return out
end

-- Machines and recyclers

-- Only assembling-machine types: a furnace picks its recipe from what is inserted, so there is
-- no way to pin one to a quality tier. Everything interesting -- electromagnetic plant,
-- foundry, biochamber, chemical plant -- is an assembling machine anyway.
--
-- The width floor is the layout's own (three distinct sub-columns per tier column), so it is
-- read from layout rather than restated here.
local function is_upcycling_machine(entity)
  -- Truthiness on allowed_effects["quality"], not ~= nil: a disallowed effect must read as
  -- excluded whether the runtime leaves it absent or materialises it as false.
  return entity.type == "assembling-machine"
    and entity.tile_width >= layout.MIN_MACHINE_WIDTH
    and (entity.module_inventory_size or 0) > 0
    and entity.allowed_effects and entity.allowed_effects["quality"]
    and entity.crafting_categories
    and entity.items_to_place_this ~= nil
end

-- Whether this machine's crafting categories include one of the recipe's. The GUI keeps the
-- pair consistent, but a snapshot or a remembered choice can outlive a mod update that changes
-- either side, and set_recipe on a ghost of a machine that cannot craft it is a hard error.
local function can_craft(entity, recipe)
  if not entity.crafting_categories then return false end
  for _, category in pairs(recipe_categories(recipe)) do
    if entity.crafting_categories[category] then return true end
  end
  return false
end

-- Every machine the mod could ever plan with, regardless of recipe. The machine picker's
-- filter before an item is chosen: an elem_filters of nil means NO filter, and the picker
-- would offer every entity in the game, belts and chests included.
function planner.machine_candidates()
  if memo.machine_candidates then return memo.machine_candidates end

  local names = {}
  for name, entity in pairs(prototypes.entity) do
    if is_upcycling_machine(entity) then names[#names + 1] = name end
  end

  memo.machine_candidates = names
  return names
end

function planner.machines_for(recipe)
  local names = {}
  for _, name in pairs(planner.machine_candidates()) do
    if can_craft(prototypes.entity[name], recipe) then names[#names + 1] = name end
  end
  return names
end

function planner.recyclers()
  if memo.recyclers then return memo.recyclers end

  local names = {}
  for name, entity in pairs(prototypes.entity) do
    if entity.crafting_categories and entity.crafting_categories["recycling"]
      and (entity.module_inventory_size or 0) > 0
      -- Truthiness, not ~= nil: a disallowed effect may be absent or materialised as false.
      and entity.allowed_effects and entity.allowed_effects["quality"]
      and entity.items_to_place_this
    then
      names[#names + 1] = name
    end
  end

  memo.recyclers = names
  return names
end

-- best_by wants a table keyed by prototype name (it returns the key); these lists arrive as
-- arrays of names.
local function entities_by_name(names)
  local map = {}
  for _, name in pairs(names) do map[name] = prototypes.entity[name] end
  return map
end

-- Fastest machine the force can build, so the default choice is the best one available rather
-- than whichever the prototype iteration happened to reach first. Falls back to the first
-- candidate so the GUI can still explain itself before anything is researched.
function planner.best_machine(force, recipe)
  local names = planner.machines_for(recipe)
  local best = best_by(entities_by_name(names), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.get_crafting_speed("normal")
  end)
  return best or names[1]
end

-- How a recycler must be rotated to serve this layout. The vanilla recycler throws its output
-- out of its north face, but the eject vector is per-prototype -- Age of Production's salvager
-- throws out of its EAST flank -- so the working rotation is computed, never assumed: it is
-- the one whose eject lands in the row of tiles directly above the footprint, which is the
-- machine's bottom row once the two stand tangent. The width floor is the layout's (the feed
-- inserter drops into the recycler's second column). Returns nil when no rotation works;
-- validate explains.
function planner.recycler_orientation(entity)
  local vector = entity.vector_to_place_result
  if not vector then return nil end
  local vx, vy = xy(vector)
  local w, h = entity.tile_width, entity.tile_height
  local rotations = {
    { direction = defines.direction.north, x = vx, y = vy, width = w, height = h },
    { direction = defines.direction.east, x = -vy, y = vx, width = h, height = w },
    { direction = defines.direction.south, x = -vx, y = -vy, width = w, height = h },
    { direction = defines.direction.west, x = vy, y = -vx, width = h, height = w },
  }
  for _, rot in pairs(rotations) do
    local col = math.floor(rot.x + rot.width / 2)
    local row = math.floor(rot.y + rot.height / 2)
    if row == -1 and col >= 0 and col < rot.width and rot.width >= layout.MIN_RECYCLER_WIDTH then
      return { direction = rot.direction, width = rot.width, height = rot.height, eject_col = col }
    end
  end
  return nil
end

-- Narrowest recycler the force can build that has a working rotation: the narrower it is, the
-- more machines it can pair with, since the layout needs the machine strictly wider than it.
function planner.best_recycler(force)
  local names = planner.recyclers()
  local best = best_by(entities_by_name(names), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    local orientation = planner.recycler_orientation(entity)
    if not orientation then return nil end
    return -orientation.width
  end)
  return best or names[1]
end

-- Modules and building materials

-- Items with a positive amount of the effect, name -> effect size. Pure prototype data, so
-- memoised like the entity candidate tables above.
local function module_candidates(effect)
  memo.modules = memo.modules or {}
  if memo.modules[effect] then return memo.modules[effect] end
  local map = {}
  for name, item in pairs(prototypes.item) do
    local value = item.module_effects and item.module_effects[effect]
    if value and value > 0 then map[name] = value end
  end
  memo.modules[effect] = map
  return map
end

-- Strongest unlocked module whose effect matters to us, by the size of that effect. Reading
-- the effect rather than the tier means a modded module slots in without being named here.
local function best_module(force, effect)
  return best_by(module_candidates(effect), function(name, value)
    if not planner.is_unlocked(force, name) then return nil end
    return value
  end)
end

-- Every quality module in the game: the picker's fallback filter, and prune's membership test.
function planner.quality_modules()
  if memo.quality_modules then return memo.quality_modules end
  local names = {}
  for name in pairs(module_candidates("quality")) do names[#names + 1] = name end
  memo.quality_modules = names
  return names
end

function planner.is_quality_module(name)
  return module_candidates("quality")[name] ~= nil
end

function planner.unlocked_quality_modules(force)
  local out = {}
  for _, name in pairs(planner.quality_modules()) do
    if planner.is_unlocked(force, name) then out[#out + 1] = name end
  end
  return out
end

-- allowed_module_categories is nil when everything is allowed and a name -> true dictionary
-- otherwise. Machines, recyclers and recipes all carry one, and all of them have to agree
-- before a module can go in.
local function accepts_module_category(holder, category)
  local allowed = holder.allowed_module_categories
  return not allowed or allowed[category] == true
end

-- The default pick, and what an emptied picker snaps back to -- the belt's own pattern.
function planner.quality_module(force)
  return best_module(force, "quality")
end

function planner.belt(force)
  return best_by(belt_candidates(), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.belt_speed
  end)
end

-- The default pole: the researched 1x1 with the largest supply area. 1x1 only -- a
-- substation or other multi-tile pole is a deliberate upgrade the player picks by hand,
-- never sprung on them -- though every width stays pickable through the button. Scored at
-- normal like best_machine, which also ranks identically at any quality: the quality bonus
-- (+level to the supply radius) lands on every pole alike.
function planner.pole(force)
  return best_by(pole_candidates(), function(_, entity)
    if not (is_single_tile(entity) and entity_is_buildable(force, entity)) then return nil end
    return entity.get_supply_area_distance("normal")
  end)
end

-- Bulk inserters move a whole stack per swing, which matters on a loop that is mostly moving
-- items between adjacent buildings. Filters are not optional: the harvest and extract
-- inserters both need one slot per ingredient. Fuelled inserters are excluded outright: the
-- loop is meant to run unattended, and a burner that runs dry stops the whole ring.
function planner.inserter(force, filters_needed)
  return best_by(inserter_candidates(), function(_, entity)
    if (entity.filter_count or 0) < filters_needed then return nil end
    if not entity_is_buildable(force, entity) then return nil end
    if entity.burner_prototype or entity.fluid_energy_source_prototype then return nil end
    -- A method, not the `rotation_speed` attribute -- that one is for cars and turrets and
    -- reads nil on an inserter.
    return (entity.bulk and 1000 or 0) + entity.get_inserter_rotation_speed("normal")
  end)
end

-- Same hunt without the fuel rule, so validate can tell "everything researched needs fuel"
-- apart from "nothing has enough filter slots" and say the right thing.
function planner.any_inserter(force, filters_needed)
  return best_by(inserter_candidates(), function(_, entity)
    return (entity.filter_count or 0) >= filters_needed
      and entity_is_buildable(force, entity) and 1 or nil
  end)
end

-- A plain container, not a logistic one: the buffers inside the loop must not talk to the
-- player's network, or the loop would compete with the base for its own intermediates.
function planner.container(force)
  local map = candidates("containers", function(entity)
    return entity.type == "container" and not entity.logistic_mode and is_single_tile(entity)
  end)
  return best_by(map, function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.get_inventory_size(defines.inventory.chest) or 0
  end)
end

-- Strictly the logistic-container type: infinity containers report a logistic_mode too, and a
-- chest that conjures items out of nothing is never a correct buffer in a loop whose whole job
-- is to conserve one population of items. Largest inventory wins so the choice is deterministic
-- rather than whatever prototype iteration happens to reach first.
function planner.logistic_container(force, mode)
  local map = candidates("logistic-" .. mode, function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == mode
      and is_single_tile(entity)
  end)
  return best_by(map, function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.get_inventory_size(defines.inventory.chest) or 0
  end)
end

-- Throughput

-- How many of an ingredient to keep in the feed chest: about a minute of crafting, capped at a
-- stack. The reference blueprints express the same thing as a parameter formula because they
-- cannot see the real recipe; we can.
function planner.request_count(ingredient, recipe)
  local per_minute = math.ceil(ingredient.amount / recipe.energy * 60)
  local stack = prototypes.item[ingredient.name].stack_size
  return math.max(1, math.min(stack, per_minute))
end

-- Building a plan

-- Quality can ADD module slots (quality_affects_module_slots -- off for every vanilla machine,
-- but a modded one may set it), and module_inventory_size is documented as the normal-quality
-- figure only. So the count is read at the quality the building will actually be placed at.
local function module_slots(entity, quality)
  return entity.get_inventory_size(defines.inventory.crafter_modules, quality)
    or entity.module_inventory_size
end

local function footprint_of(entity, quality)
  return {
    name = entity.name,
    quality = quality,
    width = entity.tile_width,
    height = entity.tile_height,
    module_slots = module_slots(entity, quality),
  }
end

-- The belt is the one building material with a player override: a slower ring is a legitimate
-- call (the fast belts are expensive and the ring is short), so a picked belt wins and the
-- fastest researched one is only the default. Anything that is not a real transport belt --
-- a stale name from a removed mod, say -- falls back rather than erroring.
local function chosen_belt(choices)
  if choices.belt and planner.is_belt(choices.belt) then return choices.belt end
  return nil
end

-- The quality module is the second material with a player override, for the same reason as the
-- belt: a cheaper module is a legitimate call. Anything that is not a real quality module -- a
-- stale name from a removed mod -- falls back rather than erroring.
local function chosen_quality_module(choices)
  if choices.quality_module and planner.is_quality_module(choices.quality_module) then
    return choices.quality_module
  end
  return nil
end

-- The pole is the one OPTIONAL build material: nil is a real answer ("place none"), not a
-- stale-name signal. choices.no_poles is what tells "cleared on purpose" apart from "never
-- touched" -- only the explicit clear suppresses the researched-best default.
local function chosen_pole(force, choices)
  if choices.no_poles then return nil end
  local name = choices.pole
  if not (name and planner.is_pole(name)) then name = planner.pole(force) end
  if not name then return nil end
  return name, planner.build_quality(choices.pole_quality)
end

-- Everything the layout needs, gathered in one place. `validate` below checks exactly the same
-- things, so a validated set of choices always produces a plan -- if the two ever drift apart,
-- the player gets a Place button that silently does nothing.
local function resources(force, recipe, machine, choices)
  local quality_module = chosen_quality_module(choices) or planner.quality_module(force)

  -- What the LAST machine gets. It crafts from ingredients already at the target, so quality
  -- modules have nothing left to roll into and it crafts for yield instead -- but productivity
  -- is refused far more often than it looks: allow_productivity defaults to FALSE and only a
  -- handful of vanilla intermediates opt in, and a machine can allow quality without allowing
  -- productivity. A refused module would sit in the insert plan forever, so those machines are
  -- left EMPTY rather than filled with something they cannot take.
  local terminal_module
  if recipe.allowed_effects and recipe.allowed_effects["productivity"]
    and machine.allowed_effects and machine.allowed_effects["productivity"]
  then
    -- A productivity module is a different module CATEGORY from the quality one, so the check
    -- validate runs on the quality module says nothing about this one. Gated here rather than
    -- in validate so the fallback below absorbs it and the two cannot drift apart.
    local productivity = best_module(force, "productivity")
    if productivity then
      local category = prototypes.item[productivity].category
      if not (accepts_module_category(machine, category)
        and accepts_module_category(recipe, category))
      then
        productivity = nil
      end
    end
    -- Not researched YET is a different question from not allowed at all: falling back to the
    -- quality module keeps the last tier rolling, a small loss of yield rather than a gap.
    terminal_module = productivity or quality_module
  end

  return {
    inserter = planner.inserter(force, #planner.item_ingredients(recipe)),
    belt = chosen_belt(choices) or planner.belt(force),
    container = planner.container(force),
    requester = planner.logistic_container(force, "requester"),
    provider = planner.logistic_container(force, "passive-provider"),
    quality_module = quality_module,
    terminal_module = terminal_module,
    -- One quality for every module the loop plans, so the player sets it once.
    module_quality = planner.build_quality(choices.quality_module_quality),
  }
end

-- How far a consumer's collision box sits inside its tile rect, taken on the LARGER axis so
-- the shrunken stand-in poles.lua tests against stays a subset of the real box whatever
-- rotation the layout placed the entity at. The engine powers on collision-box overlap
-- (api.md S10), so a subset can under-promise -- an extra pole, an over-honest warning --
-- but never claim power the game would not deliver. Vanilla: machines and the recycler
-- inset 0.3, inserters 0.35. Clamped short of half a tile so a degenerate collision box
-- cannot yield an empty stand-in nothing could ever cover.
local function consumer_margin(entity)
  local box = entity.collision_box
  local ltx, lty = xy(box.left_top)
  local rbx, rby = xy(box.right_bottom)
  local inset_x = (entity.tile_width - (rbx - ltx)) / 2
  local inset_y = (entity.tile_height - (rby - lty)) / 2
  return math.min(math.max(inset_x, inset_y, 0), 0.45)
end

-- Which of the plan's entity names draw electric power, and the stand-in margin for each --
-- checked once per distinct name, so poles.lua never touches prototypes. Belts and chests
-- have no electric energy source and drop out on their own; a modded burner machine drops
-- out too, and correctly so, since a pole cannot feed it.
local function electric_consumers(entities)
  local out = {}
  for _, e in pairs(entities) do
    if out[e.name] == nil then
      local entity = prototypes.entity[e.name]
      out[e.name] = (entity and entity.electric_energy_source_prototype ~= nil)
        and consumer_margin(entity) or false
    end
  end
  return out
end

-- `gathered` is the resources table validate() already collected in the same code path, so
-- gui.refresh does not pay for the scans twice; omitted, plan gathers its own.
function planner.plan(force, choices, gathered)
  if not choices then return nil end

  local recipe = choices.recipe and prototypes.recipe[choices.recipe]
  local machine = choices.machine and prototypes.entity[choices.machine]
  local recycler = choices.recycler and prototypes.entity[choices.recycler]
  if not (recipe and machine and recycler and choices.quality) then return nil end

  -- Any recycler width fits -- the layout widens its columns -- but the throw itself must
  -- land inside the machine, and both stand left-aligned, so the eject column caps out at
  -- the machine's width.
  local orientation = planner.recycler_orientation(recycler)
  if not orientation or orientation.eject_col >= machine.tile_width then return nil end

  -- The quality the BUILDINGS are placed at, which is nothing to do with choices.quality --
  -- that one is the quality the loop produces.
  local machine_quality = planner.build_quality(choices.machine_quality)
  local recycler_quality = planner.build_quality(choices.recycler_quality)

  local tiers = planner.tiers_up_to(choices.quality)
  if not tiers then return nil end

  local product = single_item_product(recipe)
  if not product then return nil end

  local ingredients = planner.item_ingredients(recipe)
  local requests = {}
  for _, ingredient in pairs(ingredients) do
    requests[ingredient.name] = planner.request_count(ingredient, recipe)
  end

  local r = gathered or resources(force, recipe, machine, choices)
  if not (r.inserter and r.belt and r.container and r.requester and r.provider and r.quality_module) then
    return nil
  end

  -- Qualities above the target: a moduled machine or recycler can roll past the target tier,
  -- and product at those qualities has no consumer anywhere in the loop -- it would circulate
  -- on the ring forever. The terminal catcher takes it into the provider instead. Clamped to
  -- the filter slots left after the target's own, nearest tiers first (a roll lands one tier
  -- up ten times more often than two), so a short-slotted inserter degrades instead of failing.
  local chain = planner.quality_chain()
  local extra_slots = (prototypes.entity[r.inserter].filter_count or 1) - 1
  local above_target = {}
  for i = #tiers + 1, math.min(#chain, #tiers + extra_slots) do
    above_target[#above_target + 1] = chain[i]
  end

  local layout_params = {
    recipe = { name = recipe.name, product = product.name, ingredients = ingredients },
    tiers = tiers,
    above_target = above_target,
    machine = footprint_of(machine, machine_quality),
    -- The recycler's footprint is the ROTATED one: the planner picks the rotation that makes
    -- its eject land in the machine above, and width and height swap with it.
    recycler = {
      name = recycler.name,
      quality = recycler_quality,
      width = orientation.width,
      height = orientation.height,
      module_slots = module_slots(recycler, recycler_quality),
      direction = orientation.direction,
    },
    belt = r.belt, inserter = r.inserter, container = r.container,
    requester = r.requester, provider = r.provider,
    -- `quality` here is the quality the module ITEMS are requested at; the two module names
    -- beside it are which module goes where.
    modules = {
      quality_module = r.quality_module,
      terminal_module = r.terminal_module,
      quality = r.module_quality,
    },
    requests = requests,
    -- One stack of the product in front of each recycler: enough to keep it busy through a
    -- gap on the belt, and self-limiting rather than hoarding.
    product_buffer = prototypes.item[product.name].stack_size,
  }
  local plan = layout.build(layout_params)

  -- The pole pass runs over the finished geometry: free tiles first, a widened re-run only
  -- when they cannot reach full coverage, best effort with a count when even that falls
  -- short. The pass needs the raw params too, so its growth retry rebuilds the layout
  -- rather than patching coordinates the gap columns would have shifted.
  local pole_name, pole_quality = chosen_pole(force, choices)
  if pole_name then
    local pole = prototypes.entity[pole_name]
    local result = poles.plan(layout_params, plan, {
      name = pole_name, quality = pole_quality,
      width = pole.tile_width, height = pole.tile_height,
      -- Quality genuinely grows a pole's reach (+level to the supply radius, +2*level to
      -- the wire reach), so the layout is computed at the quality the poles are placed at.
      supply_distance = pole.get_supply_area_distance(pole_quality),
      wire_distance = pole.get_max_wire_distance(pole_quality),
    }, electric_consumers(plan.entities))
    if result.layout then plan = result.layout end
    for _, entity in pairs(result.entities) do
      plan.entities[#plan.entities + 1] = entity
    end
    if result.unpowered > 0 then plan.unpowered = result.unpowered end
  end

  -- Carried on the plan rather than through the layout: which chests exist is geometry, whether
  -- their surplus is trashed is the player's call at Confirm. `~= false` keeps a snapshot from
  -- before the checkbox existed behaving as checked.
  plan.trash_unrequested = choices.trash_unrequested ~= false
  return plan
end

-- Validation

-- Returns ok, message. `ok` false disables Place; a message alongside ok true is a warning the
-- player can legitimately build through.
--
-- Every reason `planner.plan` can return nil must appear here too. A Place button that arms a
-- tool which then does nothing is the worst failure this GUI can have, because nothing tells
-- the player why.
function planner.validate(force, choices)
  if not choices.recipe then return false, { "upl-gui.pick-a-recipe" } end

  local recipe = prototypes.recipe[choices.recipe]
  if not recipe then return false, { "upl-gui.pick-a-recipe" } end

  local product = single_item_product(recipe)
  if not product then
    return false, { "upl-message.no-recycling-path", recipe.localised_name }
  end

  local ingredients, has_fluid = planner.item_ingredients(recipe)
  if has_fluid then return false, { "upl-message.fluid-not-supported" } end

  if not planner.recycling_recipe(product.name) then
    return false, { "upl-message.no-recycling-path", product.localised_name }
  end
  if not recycling_closes_the_loop(recipe, product) then
    return false, { "upl-message.recycling-mismatch", product.localised_name }
  end

  local machine = choices.machine and prototypes.entity[choices.machine]
  if not machine then return false, { "upl-message.no-machine-available" } end
  if (machine.module_inventory_size or 0) == 0 then
    return false, { "upl-message.no-module-slots", machine.localised_name }
  end
  if not (machine.allowed_effects and machine.allowed_effects["quality"]) then
    return false, { "upl-message.no-quality-effect", machine.localised_name }
  end
  -- The two checks above give specific reasons; this is the catch-all for the rest of the
  -- machine gate. The GUI cannot produce a mismatch, but a remembered name can outlive a mod
  -- update that changed the prototype under it, and set_recipe on such a ghost hard-errors.
  if not is_upcycling_machine(machine) or not can_craft(machine, recipe) then
    return false, { "upl-message.no-machine-available" }
  end

  local recycler = choices.recycler and prototypes.entity[choices.recycler]
  if not recycler then
    return false, { "upl-message.no-recycler" }
  end

  -- Same stale-name concern as the machine: an eject vector alone does not prove the thing
  -- still recycles, and the layout plans quality modules into it.
  if not (recycler.crafting_categories and recycler.crafting_categories["recycling"]) then
    return false, { "upl-message.no-recycler" }
  end
  if (recycler.module_inventory_size or 0) == 0 then
    return false, { "upl-message.no-module-slots", recycler.localised_name }
  end
  -- Mirrors the machine's gate above, and mirrors what planner.recyclers() now admits: slots
  -- the loop cannot put a quality module into are no use to it.
  if not (recycler.allowed_effects and recycler.allowed_effects["quality"]) then
    return false, { "upl-message.no-quality-effect", recycler.localised_name }
  end
  local orientation = planner.recycler_orientation(recycler)
  if not orientation then
    return false, { "upl-message.recycler-no-eject", recycler.localised_name }
  end
  -- The layout widens its columns to any recycler, but the throw must land inside the
  -- machine; both stand left-aligned, so that is a minimum machine width.
  if orientation.eject_col >= machine.tile_width then
    return false, {
      "upl-message.recycler-needs-wider-machine",
      recycler.localised_name, orientation.eject_col + 1,
    }
  end

  if not (choices.quality and prototypes.quality[choices.quality]) then
    return false, { "upl-gui.pick-a-recipe" }
  end
  if not planner.tiers_up_to(choices.quality) then
    return false, { "upl-gui.pick-a-recipe" }
  end

  -- The building materials the layout is made of. Each is a real research gate, so each gets
  -- its own message rather than one vague "something is missing". The gathered table rides on
  -- every ok return so plan() can reuse it instead of re-running the same scans.
  local r = resources(force, recipe, machine, choices)
  if not r.inserter then
    if planner.any_inserter(force, #ingredients) then
      return false, { "upl-message.only-fuelled-inserters" }
    end
    return false, { "upl-message.too-many-ingredients" }
  end
  if not r.belt then return false, { "upl-message.no-belt" } end
  if not r.container then return false, { "upl-message.no-chest" } end
  if not (r.requester and r.provider) then return false, { "upl-message.no-logistic-chest" } end
  if not r.quality_module then return false, { "upl-message.no-quality-module" } end

  -- The module is the player's pick now, so one that some building or the recipe refuses is
  -- reachable in a modded game -- and an insert plan for a refused module never gets filled.
  local chosen_module = prototypes.item[r.quality_module]
  for _, holder in pairs({ machine, recycler }) do
    if not accepts_module_category(holder, chosen_module.category) then
      return false, {
        "upl-message.module-not-accepted", chosen_module.localised_name, holder.localised_name,
      }
    end
  end
  if not accepts_module_category(recipe, chosen_module.category) then
    return false, { "upl-message.module-not-accepted-by-recipe", chosen_module.localised_name }
  end

  -- Warnings from here: planning ahead of research is legitimate, since the result is ghosts
  -- that bots will build once the technology lands.
  if not force.is_quality_unlocked(choices.quality) then
    return true, { "upl-message.quality-not-researched", prototypes.quality[choices.quality].localised_name }, r
  end
  -- The quality the buildings and modules are placed AT gets the same treatment as the target:
  -- ghosts of an unresearched tier are legal to place, nothing can build them yet.
  local pole_name, pole_quality = chosen_pole(force, choices)
  local build_qualities = {
    planner.build_quality(choices.machine_quality),
    planner.build_quality(choices.recycler_quality),
    r.module_quality,
  }
  -- The pole's build quality matters twice over: it gates who can build the ghosts, and it
  -- sets the reach the whole pole layout is computed at.
  if pole_name then build_qualities[#build_qualities + 1] = pole_quality end
  for _, quality in pairs(build_qualities) do
    if not force.is_quality_unlocked(quality) then
      return true, {
        "upl-message.build-quality-not-researched", prototypes.quality[quality].localised_name,
      }, r
    end
  end
  local force_recipe = force.recipes[recipe.name]
  if not force_recipe or not force_recipe.enabled then
    return true, { "upl-message.recipe-not-researched" }, r
  end

  -- Poles are optional, so a game where none is researched yet gets a warning rather than a
  -- refusal -- the loop itself is fine, it just arrives dark. Unreachable in vanilla: the
  -- small pole unlocks with the same technology as the electric inserter.
  if not choices.no_poles and not pole_name then
    return true, { "upl-message.no-pole-researched" }, r
  end

  return true, nil, r
end

return planner
