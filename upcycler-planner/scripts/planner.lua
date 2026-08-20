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
  local items, fluids = {}, {}
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "fluid" then
      fluids[#fluids + 1] = ingredient
    else
      items[#items + 1] = ingredient
    end
  end
  return items, fluids
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
  for _, category in pairs(recipe.categories) do
    if category == "recycling" then return true end
  end
  return false
end

function planner.is_upcyclable(recipe)
  if not recipe.can_set_quality then return false end
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

  -- One fluid is a pipe header the layout knows how to build; two would need two separate
  -- networks for one vanilla recipe whose product another recipe already covers.
  local _, fluids = planner.item_ingredients(recipe)
  if #fluids > 1 then return false end

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

-- The keys of a candidate map, as an array, memoised in turn. Five pickers want a list where the
-- scans are keyed by name, and five hand-written copies of this loop is five chances to leave the
-- wrong memo key behind -- which returns the wrong picker's list with no error at all.
local function names_of(key, map)
  if memo[key] then return memo[key] end
  local names = {}
  for name in pairs(map) do names[#names + 1] = name end
  memo[key] = names
  return names
end

local function belt_candidates()
  return candidates("belts", function(entity) return entity.type == "transport-belt" end)
end

local function pole_candidates()
  return candidates("poles", function(entity) return entity.type == "electric-pole" end)
end

local function pipe_candidates()
  return candidates("pipes", function(entity) return entity.type == "pipe" end)
end

-- The crossing pair dives under the top ring belt: entry and exit centres sit two tiles
-- apart, so anything reaching that far serves. Vanilla's pipe-to-ground reaches 10.
local MIN_UNDERGROUND_SPAN = 2

local function pipe_to_ground_candidates()
  return candidates("pipes-to-ground", function(entity)
    return entity.type == "pipe-to-ground"
      and (entity.max_underground_distance or 0) >= MIN_UNDERGROUND_SPAN
  end)
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

-- Belt-stacking inserters (Space Age's stack inserter) are never candidates: a stacking hand
-- holds out for a full belt stack of ONE item-and-quality, and a quality loop trickles dozens
-- of item/quality combinations past every position, so the hand starves while the building
-- behind it backs up. `bulk` alone cannot tell them from the safe bulk inserter -- the two
-- otherwise tie the pick outright -- but only stackers carry a belt stack size above one.
-- items_to_place_this is the machine list's "a player could ever build this" gate, and both
-- picker lists need it for the same reason: without it a picker offers entities no item places
-- the moment show-all is on.
local function is_loop_inserter(entity)
  return entity.type == "inserter" and reaches_adjacent_tiles(entity)
    and (entity.inserter_max_belt_stack_size or 1) <= 1
    and entity.items_to_place_this ~= nil
end

local function inserter_candidates()
  return candidates("inserters", is_loop_inserter)
end

-- What the picker offers, and the only inserters planner.inserter scores over: the rules above
-- plus electric-only. The loop runs unattended and nothing in the plan delivers fuel, so a
-- burner must never reach the picker -- while inserter_candidates keeps them, which is what lets
-- any_inserter tell "everything researched needs fuel" apart from "nothing has enough filters".
local function electric_inserter_candidates()
  if memo["electric-inserters"] then return memo["electric-inserters"] end
  -- Filtered from the table above rather than scanned again: this is a subset of it by
  -- definition, and that scan walks every entity prototype in the game.
  local map = {}
  for name, entity in pairs(inserter_candidates()) do
    if not (entity.burner_prototype or entity.fluid_energy_source_prototype) then
      map[name] = entity
    end
  end
  memo["electric-inserters"] = map
  return map
end

-- Every chest position in the layout is one tile, so anything bigger is not a candidate --
-- AAI's 4x4 requester warehouse won the largest-inventory contest and the placed rows
-- overlapped into each other.
local function is_single_tile(entity)
  return entity.tile_width == 1 and entity.tile_height == 1
end

-- The four chest roles the layout builds with, one predicate each. Keyed rather than written out
-- four times, because everything downstream -- the picker's list, the default pick, prune's
-- membership test -- is the same question asked once per role. The order is the one the modal
-- shows them in: what feeds the loop, what relieves it, what it hands back to the base, and what
-- it hands away.
--
-- `container` is deliberately a PLAIN chest: the buffers inside the loop must not talk to the
-- player's network, or the loop would compete with the base for its own intermediates. The three
-- logistic roles test `type` strictly, because an infinity chest reports a logistic_mode too and
-- a chest that conjures items out of nothing is never a correct buffer in a loop whose whole job
-- is to conserve one population of items.
--
-- `overflow` is the one role that has to be an ACTIVE provider rather than the player's pick of
-- logistic chest. It is the loop's only unbounded sink -- bots take its contents away -- and a
-- passive provider or a plain chest would merely fill, at which point the ring saturates again a
-- few hours later. `logistic-system` unlocks it alongside the requester chest, so it costs no
-- research the mod did not already require.
planner.CHEST_ROLES = { "requester", "container", "provider", "overflow" }

local CHEST_ACCEPTS = {
  container = function(entity)
    return entity.type == "container" and not entity.logistic_mode
  end,
  requester = function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == "requester"
  end,
  provider = function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == "passive-provider"
  end,
  overflow = function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == "active-provider"
  end,
}

-- Placeability is load-bearing here, not defensive: base ships 1x1 CONTAINERS for the crash
-- site and the tips-and-tricks simulations (red-chest, blue-chest, crash-site-chest-1/2) that no
-- item can place, so a footprint test alone puts scenery in the picker (analysis/api.md S15).
local function chest_candidates(role)
  local accepts = CHEST_ACCEPTS[role]
  return candidates("chest-" .. role, function(entity)
    return accepts(entity) and is_single_tile(entity) and entity.items_to_place_this ~= nil
  end)
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

-- The two families whose offered set cannot be written as a prototype TYPE filter: an inserter
-- has to reach exactly one tile and never build belt stacks, a chest has to be one tile in the
-- right logistic role. Handed to the GUI as names, so those rules hold with show-all on too.
-- Memoised like the candidate scans they read, since neither list depends on a force.
function planner.inserters()
  return names_of("inserter_names", electric_inserter_candidates())
end

-- Pipes as names, for the picker's own reason rather than the chests': the list's LENGTH decides
-- whether a pipe picker is worth showing at all, and a type filter cannot be counted.
function planner.pipes()
  return names_of("pipe_names", pipe_candidates())
end

function planner.chests(role)
  return names_of("chest_names_" .. role, chest_candidates(role))
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

function planner.is_pipe(name)
  return pipe_candidates()[name] ~= nil
end

function planner.is_inserter(name)
  return electric_inserter_candidates()[name] ~= nil
end

function planner.is_chest(name, role)
  return chest_candidates(role)[name] ~= nil
end

-- How many filter slots a plan for this recipe needs, and whether it plumbs anything. Both are
-- the planner's rules, asked by the modal so a picker can be sized or hidden before a plan
-- exists -- which is why they take a recipe that may be nil and answer for "nothing picked yet".
-- Written out rather than `and ... or 1`: a recipe with no item ingredients counts 0, and 0 or 1
-- is 0.
function planner.filters_needed(recipe)
  if not recipe then return 1 end
  return #planner.item_ingredients(recipe)
end

function planner.needs_pipe(recipe)
  if not recipe then return false end
  local _, fluids = planner.item_ingredients(recipe)
  return #fluids == 1
end

-- Whether a plan for this target needs the overflow tap: true when the quality chain carries a
-- tier above it. At the top tier nothing can roll past the target, so there is nothing to catch.
--
-- Deliberately blind to research. Rolls cannot exceed the qualities a force has unlocked, so a
-- tap built today may sit idle -- but researching a new tier is precisely what clogs a loop built
-- before it, and two entities is cheaper than re-stamping every loop in the base afterwards.
function planner.needs_overflow_tap(target)
  local tiers = target and planner.tiers_up_to(target)
  return tiers ~= nil and #planner.quality_chain() > #tiers
end

-- Filter slots on a chosen inserter, nil when nothing valid is chosen. One slot per ingredient is
-- a hard requirement of the harvest and relief positions, and every vanilla inserter carries
-- five, so only a modded recipe can outrun a pick.
function planner.inserter_filter_count(name)
  if not (name and planner.is_inserter(name)) then return nil end
  return prototypes.entity[name].filter_count or 0
end

-- Membership in the chain as a set: build_quality asks this once per quality-carrying material
-- on every refresh, and prune once per stored key, so the linear scan is memoised away.
function planner.is_quality(name)
  local set = memo.quality_set
  if not set then
    set = {}
    for _, quality in pairs(planner.quality_chain()) do set[quality] = true end
    memo.quality_set = set
  end
  return set[name] == true
end

-- The quality a chosen building or module is placed at, as opposed to choices.quality, which is
-- the quality the loop PRODUCES. A remembered tier a mod has since removed reads as normal here
-- rather than erroring at placement time.
function planner.build_quality(name)
  if name and planner.is_quality(name) then return name end
  return "normal"
end

-- Build materials that carry a quality travel as a { name, quality } pair -- the shape the
-- machine and the recycler already use, and the shape the pickers hand back. A bare string means
-- the thing has no quality dimension at all: belt and pipe, the engine's own exceptions.
function planner.with_quality(name, quality)
  if not name then return nil end
  return { name = name, quality = planner.build_quality(quality) }
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
-- pair consistent, but a remembered choice can outlive a mod update that changes
-- either side, and set_recipe on a ghost of a machine that cannot craft it is a hard error.
local function can_craft(entity, recipe)
  if not entity.crafting_categories then return false end
  for _, category in pairs(recipe.categories) do
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

-- How a machine must be rotated so its fluid input meets the pipe run on the utility column
-- to its west. Same shape as recycler_orientation: per-prototype, computed, nil when nothing
-- works. The rule is pure direction arithmetic, measured on 2.1.14 (api.md §14): a connection
-- authored pointing `dir` points `(dir + rotation) % 16` once the entity is rotated, and the
-- engine merges every input box a recipe needs into one live box exposing ALL their
-- connection points, any one of which feeds the machine -- so one west-pointing input
-- connection is enough. North is tried first, so a machine that already has one (the
-- electromagnetic plant, inputs on opposite flanks) is not rotated needlessly. The vertical
-- run spans the machine's full height, which is why no row test is needed here.
function planner.machine_fluid_orientation(entity)
  local input_directions = {}
  for _, box in pairs(entity.fluidbox_prototypes or {}) do
    if box.production_type == "input" or box.production_type == "input-output" then
      for _, connection in pairs(box.pipe_connections) do
        if connection.connection_type == "normal" then
          input_directions[#input_directions + 1] = connection.direction
        end
      end
    end
  end
  if #input_directions == 0 then return nil end

  for _, rotation in pairs({
    defines.direction.north, defines.direction.east,
    defines.direction.south, defines.direction.west,
  }) do
    local width, height = entity.tile_width, entity.tile_height
    if rotation == defines.direction.east or rotation == defines.direction.west then
      width, height = height, width
    end
    if width >= layout.MIN_MACHINE_WIDTH then
      for _, direction in pairs(input_directions) do
        if (direction + rotation) % 16 == defines.direction.west then
          return { direction = rotation, width = width, height = height }
        end
      end
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

-- Every module item in the game. The engine filters prototypes itself, so this is one call
-- rather than a walk of every item; memoised like the entity candidate scans above.
local function module_items()
  if memo.module_items then return memo.module_items end
  memo.module_items = prototypes.get_item_filtered({ { filter = "type", type = "module" } })
  return memo.module_items
end

-- Items with a positive amount of the effect, name -> effect size. Pure prototype data, so
-- memoised like the entity candidate tables above. Reads the module table rather than every item
-- in the game: only a module carries module_effects.
local function module_candidates(effect)
  memo.modules = memo.modules or {}
  if memo.modules[effect] then return memo.modules[effect] end
  local map = {}
  for name, item in pairs(module_items()) do
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
  return names_of("quality_modules", module_candidates("quality"))
end

function planner.is_quality_module(name)
  return module_candidates("quality")[name] ~= nil
end

-- The ITEM counterpart of planner.buildable: which of these item names the force can make. What
-- the module pickers narrow their lists with, since a module is an item and has no entity to be
-- buildable.
function planner.unlocked(force, names)
  local out = {}
  for _, name in pairs(names) do
    if planner.is_unlocked(force, name) then out[#out + 1] = name end
  end
  return out
end

function planner.unlocked_quality_modules(force)
  return planner.unlocked(force, planner.quality_modules())
end

-- allowed_module_categories is nil when everything is allowed and a name -> true dictionary
-- otherwise. Machines, recyclers and recipes all carry one, and all of them have to agree
-- before a module can go in.
local function accepts_module_category(holder, category)
  local allowed = holder.allowed_module_categories
  return not allowed or allowed[category] == true
end

-- Whether this holder -- a machine prototype or a recipe prototype, which carry the same two
-- fields -- accepts this module at all. The category rule is documented; the effect rule is
-- MEASURED (`analysis/api.md` §16), because the obvious reading is wrong: only the effects a
-- module applies **positively** have to be allowed. A negative side effect on a disallowed effect
-- is fine, which is why a speed module goes in an oil refinery (quality -0.025, quality not
-- allowed there) while a quality module is refused outright.
function planner.accepts_module(holder, item)
  if not accepts_module_category(holder, item.category) then return false end
  for effect, value in pairs(item.module_effects or {}) do
    if value > 0 and not (holder.allowed_effects and holder.allowed_effects[effect]) then
      return false
    end
  end
  return true
end

function planner.modules()
  return names_of("module_names", module_items())
end

function planner.is_module(name)
  return module_items()[name] ~= nil
end

-- One module's refusals, in the order worth reporting: the buildings it goes into, then the
-- recipe. Returns the message, or nil when nothing refuses it.
local function module_refusal(item, holders, recipe)
  for _, holder in pairs(holders) do
    if not planner.accepts_module(holder, item) then
      return { "upl-message.module-not-accepted", item.localised_name, holder.localised_name }
    end
  end
  if not planner.accepts_module(recipe, item) then
    return { "upl-message.module-not-accepted-by-recipe", item.localised_name }
  end
end

-- What the terminal machine's picker offers: the modules this machine and this recipe both
-- accept. Not memoised -- it depends on the pair, and the scan is a dozen items.
function planner.modules_for(machine, recipe)
  local names = {}
  for name, item in pairs(module_items()) do
    if planner.accepts_module(machine, item) and planner.accepts_module(recipe, item) then
      names[#names + 1] = name
    end
  end
  return names
end

function planner.module_fits(name, machine, recipe)
  local item = name and module_items()[name]
  if not item then return false end
  return planner.accepts_module(machine, item) and planner.accepts_module(recipe, item)
end

-- The default for the terminal machine: the strongest researched module that actually raises
-- productivity and that the pair accepts -- or **nothing**, which is the common case, since
-- allow_productivity defaults to false and only a handful of vanilla recipes opt in. Never a
-- quality module: at the target tier there is nothing left to roll into.
function planner.terminal_module(force, machine, recipe)
  return best_by(module_candidates("productivity"), function(name, value)
    if not planner.is_unlocked(force, name) then return nil end
    if not planner.module_fits(name, machine, recipe) then return nil end
    return value
  end)
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

-- Every pipe in vanilla carries fluid the same; volume is the one honest number a modded
-- pipe can be better at, and scoring by it keeps the pick principled rather than iteration
-- order.
function planner.pipe(force)
  return best_by(pipe_candidates(), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    local box = entity.fluidbox_prototypes[1]
    return box and box.get_volume("normal") or 0
  end)
end

-- No prototype links a pipe to its underground counterpart. Wube's own pairs follow the
-- <pipe>-to-ground name convention, so that is tried first -- the plan then stays visually
-- consistent with the player's pick -- and a miss falls back to the longest-reaching
-- researched pipe-to-ground of any family; fluid connectivity does not require a matched
-- pair, only adjacency.
function planner.pipe_to_ground_for(force, pipe_name)
  local guess = pipe_name and prototypes.entity[pipe_name .. "-to-ground"]
  if guess and guess.type == "pipe-to-ground"
    and (guess.max_underground_distance or 0) >= MIN_UNDERGROUND_SPAN
    and entity_is_buildable(force, guess)
  then
    return guess.name
  end
  return best_by(pipe_to_ground_candidates(), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.max_underground_distance
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
-- inserters both need one slot per ingredient. Fuelled ones never reach this pick at all -- the
-- candidate table it reads is the electric one.
function planner.inserter(force, filters_needed)
  return best_by(electric_inserter_candidates(), function(_, entity)
    if (entity.filter_count or 0) < filters_needed then return nil end
    if not entity_is_buildable(force, entity) then return nil end
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

-- The default chest for a role: largest researched inventory, so the pick is deterministic
-- rather than whatever prototype iteration happens to reach first. Scored at normal for the
-- pole's reason -- quality grows every chest's inventory alike, since
-- quality_affects_inventory_size defaults true -- so the ranking is the same at any tier.
function planner.chest(force, role)
  return best_by(chest_candidates(role), function(_, entity)
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

-- The pipe follows the belt's pattern exactly: a picked pipe wins, a stale or wrong-type
-- name falls back to the researched best rather than erroring.
local function chosen_pipe(choices)
  if choices.pipe and planner.is_pipe(choices.pipe) then return choices.pipe end
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

-- The inserter follows the belt's pattern with one addition: a pick can be individually
-- inadequate. Filter slots are needed one per ingredient, so a modded recipe can outgrow an
-- otherwise perfectly good inserter -- and quietly building the loop out of a different one
-- would hide the player's own choice, so the prototype is handed back for validate to name.
local function chosen_inserter(force, choices, filters_needed)
  local slots = planner.inserter_filter_count(choices.inserter)
  if not slots then return planner.inserter(force, filters_needed) end
  if slots >= filters_needed then return choices.inserter end
  return nil, prototypes.entity[choices.inserter]
end

-- The belt's rule once per chest role: a picked chest wins, a stale name falls back.
local function chosen_chest(force, choices, role)
  local name = choices[role]
  if name and planner.is_chest(name, role) then return name end
  return planner.chest(force, role)
end

-- The terminal machine's module is the pole's shape rather than the belt's: nil is a real answer
-- ("leave the top machine empty"), so `no_terminal_module` is what tells an explicit clear from a
-- never-touched picker. A pick that this machine or recipe refuses is NOT corrected here --
-- validate names it, the way it does for the quality module.
local function chosen_terminal_module(force, choices, machine, recipe)
  if choices.no_terminal_module then return nil end
  local name = choices.terminal_module
  if name and planner.is_module(name) then return name end
  return planner.terminal_module(force, machine, recipe)
end

-- Everything the layout needs, gathered in one place. `validate` below checks exactly the same
-- things, so a validated set of choices always produces a plan -- if the two ever drift apart,
-- the player gets a Place button that silently does nothing.
local function resources(force, recipe, machine, choices)
  local quality_module = chosen_quality_module(choices) or planner.quality_module(force)

  -- What the LAST machine gets, and the player's own pick since 0.3.0. It crafts from ingredients
  -- already at the target, so quality modules have nothing left to roll into and it crafts for
  -- yield instead -- but productivity is refused far more often than it looks: allow_productivity
  -- defaults to FALSE, only a handful of vanilla recipes opt in, and a machine can allow quality
  -- without allowing productivity. A refused module would sit in the insert plan forever, so the
  -- default is a productivity module or nothing at all. It is deliberately never a quality module
  -- any more: that old fallback chose for the player, and this is now a choice they can see and
  -- make (repo owner's call, 2026-08-17).
  local terminal_module = chosen_terminal_module(force, choices, machine, recipe)

  -- Gathered even for a fluid-free recipe: the scans are memoised and buildability is cheap,
  -- and validate only ever CHECKS these two when the recipe actually takes a fluid.
  local pipe = chosen_pipe(choices) or planner.pipe(force)

  local inserter, inserter_shortfall =
    chosen_inserter(force, choices, #planner.item_ingredients(recipe))

  local function chest(role)
    return planner.with_quality(chosen_chest(force, choices, role), choices[role .. "_quality"])
  end

  return {
    -- Everything with a quality leaves here as a { name, quality } pair, which is the shape the
    -- layout takes; the belt and the pipe stay bare names because they have no quality at all.
    inserter = planner.with_quality(inserter, choices.inserter_quality),
    -- Set only when the CHOSEN inserter is the thing that fell short, so validate can say so
    -- instead of blaming the recipe.
    inserter_shortfall = inserter_shortfall,
    belt = chosen_belt(choices) or planner.belt(force),
    pipe = pipe,
    pipe_to_ground = planner.pipe_to_ground_for(force, pipe),
    container = chest("container"),
    requester = chest("requester"),
    provider = chest("provider"),
    overflow = chest("overflow"),
    -- Pairs like every other build material with a quality. The two module pickers own their own
    -- qualities: the top machine's module became a separate choice from the quality modules
    -- below it, so one shared quality would have tied two unrelated decisions together.
    quality_module = planner.with_quality(quality_module, choices.quality_module_quality),
    terminal_module = planner.with_quality(terminal_module, choices.terminal_module_quality),
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

-- Poles stand on a FINISHED layout, but where they CAN stand is part of that layout -- so the
-- two are solved together rather than in sequence, narrowest first. Three attempts at most:
--
--   1. compact -- no pole columns at all, poles in whatever the ring already leaves free
--      (the dead ground beside a recycler narrower than its machine, and the last tier's
--      empty lower block). On most shapes this covers, and it is as small as a plan gets.
--   2. all columns -- one sized column before every tier, the 0.2.0 shape.
--   3. shrink -- collapse every column no pole stood in, solve again, repeat. It only ever
--      collapses, so the open set strictly shrinks and this terminates.
--
-- Fewest unpowered consumers wins, and the narrower plan takes any tie -- compact is tried
-- first, so it holds one. Attempt 2 IS the plan the mod used to emit unconditionally, and it
-- is always in the running, which is what makes the outcome impossible to be worse than it.
local function plan_with_poles(layout_params, tier_count, pole_gap, pole)
  local function attempt(gaps)
    layout_params.column_gaps = gaps
    local built = layout.build(layout_params)
    -- Margins are re-derived per attempt rather than carried over: a name missing from the map
    -- reads as "draws no power" and would quietly claim coverage, which is the one lie the
    -- pole pass exists to prevent. Ten prototype lookups is the honest price.
    return {
      gaps = gaps, plan = built,
      poles = poles.plan(built, pole, electric_consumers(built.entities)),
    }
  end

  local function uniform(gap)
    local gaps = {}
    for index = 1, tier_count do gaps[index] = gap end
    return gaps
  end

  local function beats(candidate, incumbent)
    if candidate.poles.unpowered ~= incumbent.poles.unpowered then
      return candidate.poles.unpowered < incumbent.poles.unpowered
    end
    return candidate.plan.width < incumbent.plan.width
  end

  local best = attempt(uniform(0))
  if best.poles.unpowered > 0 then
    local current = attempt(uniform(pole_gap))
    if beats(current, best) then best = current end

    while true do
      -- A column earns its width by holding a pole. Anything else is dead ground, including a
      -- column the free-tile fallback walked away from.
      local held = {}
      for _, column in pairs(current.plan.utility_columns or {}) do
        for _, placed in pairs(current.poles.entities) do
          if placed.dx >= column.x and placed.dx + pole.width <= column.x + column.width then
            held[column.tier] = true
            break
          end
        end
      end

      local gaps, collapsed = {}, false
      for index = 1, tier_count do
        gaps[index] = held[index] and pole_gap or 0
        if gaps[index] ~= current.gaps[index] then collapsed = true end
      end
      if not collapsed then break end

      local shrunk = attempt(gaps)
      -- Coverage is the floor: a narrower plan that leaves one more machine dark is not an
      -- improvement, and stopping here keeps the wider one that did cover.
      if shrunk.poles.unpowered > current.poles.unpowered then break end
      current = shrunk
      if beats(current, best) then best = current end
    end
  end

  local plan = best.plan
  -- poles.plan numbers wire_to within its OWN result, the only ordering it can know. Rebasing
  -- those onto plan indices here -- the one place that sees both numberings -- is what lets
  -- the serialiser wire an entity by index without knowing what a pole is, and it is what a
  -- wire between two unlike entities would need anyway.
  local base = #plan.entities
  for _, entity in ipairs(best.poles.entities) do
    if entity.wire_to then entity.wire_to = base + entity.wire_to end
    plan.entities[#plan.entities + 1] = entity
  end
  if best.poles.unpowered > 0 then plan.unpowered = best.poles.unpowered end
  return plan
end

-- `gathered` is the resources table validate() already collected in the same code path, so
-- gui.refresh does not pay for the scans twice; omitted, plan gathers its own.
function planner.plan(force, choices, gathered)
  if not choices then return nil end

  local recipe = choices.recipe and prototypes.recipe[choices.recipe]
  local machine = choices.machine and prototypes.entity[choices.machine]
  local recycler = choices.recycler and prototypes.entity[choices.recycler]
  if not (recipe and machine and recycler and choices.quality) then return nil end

  -- One fluid at most: a second one would mean a second, separate pipe network, and the one
  -- vanilla two-fluid recipe's product is already covered by a one-fluid recipe.
  local ingredients, fluids = planner.item_ingredients(recipe)
  if #fluids > 1 then return nil end
  -- A fluid recipe rotates the machine so an input connection meets the pipe run, and the
  -- rotated width is what every later width test has to use.
  local fluid_orientation
  if #fluids == 1 then
    fluid_orientation = planner.machine_fluid_orientation(machine)
    if not fluid_orientation then return nil end
  end
  local machine_width = fluid_orientation and fluid_orientation.width or machine.tile_width

  -- Any recycler width fits -- the layout widens its columns -- but the throw itself must
  -- land inside the machine, and both stand left-aligned, so the eject column caps out at
  -- the machine's width.
  local orientation = planner.recycler_orientation(recycler)
  if not orientation or orientation.eject_col >= machine_width then return nil end

  -- The quality the BUILDINGS are placed at, which is nothing to do with choices.quality --
  -- that one is the quality the loop produces.
  local machine_quality = planner.build_quality(choices.machine_quality)
  local recycler_quality = planner.build_quality(choices.recycler_quality)

  local tiers = planner.tiers_up_to(choices.quality)
  if not tiers then return nil end

  local product = single_item_product(recipe)
  if not product then return nil end

  local requests = {}
  for _, ingredient in pairs(ingredients) do
    requests[ingredient.name] = planner.request_count(ingredient, recipe)
  end

  local r = gathered or resources(force, recipe, machine, choices)
  if not (r.inserter and r.belt and r.container and r.requester and r.provider and r.quality_module) then
    return nil
  end
  if #fluids == 1 and not (r.pipe and r.pipe_to_ground) then return nil end

  -- Everything the loop rolls ABOVE the target leaves through the tap in the terminal column.
  -- Both halves need it: a moduled machine rolls the PRODUCT past the target, and a moduled
  -- recycler rolls the INGREDIENTS past it -- and nothing consumes either, because every machine
  -- is pinned to one tier and quality matching is exact. Without the tap they circulate on the
  -- ring until it saturates, which is the defect the reference book this layout descends from
  -- still ships (analysis/blueprints.md).
  --
  -- One nameless "> target" filter covers it, whatever the recipe: an inserter filter may name a
  -- quality and no item at all, measured in analysis/api.md S24. That is why this is a flag here
  -- rather than the list of tiers it replaced -- that list cost one filter slot per tier and was
  -- clamped to the inserter's five, so a long modded quality chain silently lost its top tiers.
  local overflow_tap = planner.needs_overflow_tap(choices.quality)
  if overflow_tap and not r.overflow then return nil end

  -- The machine's footprint is rotated when a fluid input has to face the pipe run --
  -- vanilla crafters are square, so this only moves a modded rectangle -- and its direction
  -- rides into the layout beside it.
  local machine_footprint = footprint_of(machine, machine_quality)
  if fluid_orientation then
    machine_footprint.width = fluid_orientation.width
    machine_footprint.height = fluid_orientation.height
    machine_footprint.direction = fluid_orientation.direction
  end

  -- What a utility column costs where one opens: the pole's own width, plus one for the pipe
  -- run when the recipe takes a fluid. WHICH tiers open one is not decided here --
  -- plan_with_poles measures that against real coverage -- and a poleless plan opens none at
  -- all, leaving layout.build's own fluid clamp as the only thing that can widen a column.
  local pole_name, pole_quality = chosen_pole(force, choices)
  local pole = pole_name and prototypes.entity[pole_name]
  local pole_gap = (#fluids == 1 and 1 or 0) + (pole and pole.tile_width or 0)

  local layout_params = {
    recipe = { name = recipe.name, product = product.name, ingredients = ingredients },
    tiers = tiers,
    overflow_tap = overflow_tap,
    machine = machine_footprint,
    fluid = #fluids == 1 and { pipe = r.pipe, pipe_to_ground = r.pipe_to_ground } or nil,
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
    -- The belt is a bare name; the inserter and the chests are { name, quality } pairs,
    -- because the player picks a quality for each of them and the belt has none to pick.
    belt = r.belt,
    inserter = r.inserter,
    requester = r.requester, container = r.container, provider = r.provider,
    overflow = r.overflow,
    -- One pair per module, or nil for "leave that machine empty" -- which only ever happens to
    -- the terminal one.
    modules = {
      quality_module = r.quality_module,
      terminal_module = r.terminal_module,
    },
    requests = requests,
    -- One stack of the product in front of each recycler: enough to keep it busy through a
    -- gap on the belt, and self-limiting rather than hoarding.
    product_buffer = prototypes.item[product.name].stack_size,
  }
  -- With poles, the layout and the pole pass are solved together -- the columns a plan opens
  -- are the ones poles turned out to need. Without them there is nothing to weigh, so the
  -- geometry is built once.
  local plan
  if pole then
    plan = plan_with_poles(layout_params, #tiers, pole_gap, {
      name = pole_name, quality = pole_quality,
      width = pole.tile_width, height = pole.tile_height,
      -- Quality genuinely grows a pole's reach (+level to the supply radius, +2*level to
      -- the wire reach), so the layout is computed at the quality the poles are placed at.
      supply_distance = pole.get_supply_area_distance(pole_quality),
      wire_distance = pole.get_max_wire_distance(pole_quality),
    })
  else
    plan = layout.build(layout_params)
  end

  -- Carried on the plan rather than through the layout: which chests exist is geometry, whether
  -- their surplus is trashed is the player's call at Confirm. `~= false` keeps a stored choices
  -- table from before the checkbox existed reading as checked.
  plan.trash_unrequested = choices.trash_unrequested ~= false

  -- What the loop MAKES, alongside the counts and the shortfall the plan already carries. A
  -- bare `quality` would be ambiguous here -- the plan holds a machine quality, a recycler
  -- quality, a module quality and a pinned quality per tier -- so this one says which it is.
  plan.product = product.name
  plan.target_quality = choices.quality

  return plan
end

-- Validation

-- Returns ok, message. `ok` false disables Place; a message alongside ok true is a warning the
-- player can legitimately build through.
--
-- Every reason `planner.plan` can return nil must appear here too. A Place button that leaves
-- the cursor empty is the worst failure this GUI can have, because nothing tells the player
-- why.
function planner.validate(force, choices)
  if not choices.recipe then return false, { "upl-gui.pick-a-recipe" } end

  local recipe = prototypes.recipe[choices.recipe]
  if not recipe then return false, { "upl-gui.pick-a-recipe" } end

  local product = single_item_product(recipe)
  if not product then
    return false, { "upl-message.no-recycling-path", recipe.localised_name }
  end

  local ingredients, fluids = planner.item_ingredients(recipe)
  if #fluids > 1 then return false, { "upl-message.too-many-fluids" } end

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

  -- A fluid recipe adds one machine requirement of its own: some rotation must land a fluid
  -- input connection against the pipe run. Computed per prototype like the recycler's eject,
  -- and refused by name when nothing works -- piping a machine wrong is the reference
  -- blueprints' own defect, and the one thing this feature must never reproduce.
  local machine_width = machine.tile_width
  if #fluids == 1 then
    local fluid_orientation = planner.machine_fluid_orientation(machine)
    if not fluid_orientation then
      return false, { "upl-message.machine-no-fluid-face", machine.localised_name }
    end
    machine_width = fluid_orientation.width
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
  -- machine; both stand left-aligned, so that is a minimum machine width -- the ROTATED
  -- width when a fluid recipe stood the machine sideways.
  if orientation.eject_col >= machine_width then
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
    -- Order matters. When nothing available has enough filter slots the RECIPE is the problem
    -- whatever was picked, and naming the pick would advise a fix that does not exist -- which
    -- is every vanilla case, since all six vanilla inserters carry five slots and exactly one
    -- vanilla upcyclable recipe needs six. Only once something better is genuinely available is
    -- the pick worth naming, so that branch needs a modded inserter to reach.
    if not planner.any_inserter(force, #ingredients) then
      return false, { "upl-message.too-many-ingredients" }
    end
    if r.inserter_shortfall then
      return false, {
        "upl-message.inserter-too-few-filters",
        r.inserter_shortfall.localised_name, #ingredients,
      }
    end
    return false, { "upl-message.only-fuelled-inserters" }
  end
  if not r.belt then return false, { "upl-message.no-belt" } end
  if not r.container then return false, { "upl-message.no-chest" } end
  if not (r.requester and r.provider) then return false, { "upl-message.no-logistic-chest" } end
  -- Only asked for when the target has a tier above it: at the top of the chain nothing can roll
  -- past, so the tap is not built and its chest is not needed. Unreachable in vanilla, where the
  -- same technology unlocks the active provider and the requester chest already required above.
  if planner.needs_overflow_tap(choices.quality) and not r.overflow then
    return false, { "upl-message.no-active-provider" }
  end
  if not r.quality_module then return false, { "upl-message.no-quality-module" } end
  if #fluids == 1 then
    if not r.pipe then return false, { "upl-message.no-pipe" } end
    if not r.pipe_to_ground then return false, { "upl-message.no-pipe-to-ground" } end
  end

  -- The modules are the player's picks, so one that some building or the recipe refuses is
  -- reachable in a modded game -- and an insert plan for a refused module never gets filled. The
  -- quality module goes into machines AND recyclers; the terminal one only into the top machine,
  -- and is optional, so nil is not a refusal.
  local refused = module_refusal(prototypes.item[r.quality_module.name], { machine, recycler },
    recipe)
  if not refused and r.terminal_module then
    refused = module_refusal(prototypes.item[r.terminal_module.name], { machine }, recipe)
  end
  if refused then return false, refused end

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
    r.quality_module.quality,
    r.inserter.quality,
    r.requester.quality,
    r.container.quality,
    r.provider.quality,
  }
  if r.terminal_module then
    build_qualities[#build_qualities + 1] = r.terminal_module.quality
  end
  -- Only when it is actually placed, so a legendary plan is not warned about a chest it does
  -- not build.
  if r.overflow and planner.needs_overflow_tap(choices.quality) then
    build_qualities[#build_qualities + 1] = r.overflow.quality
  end
  -- The pole's build quality matters twice over: it gates who can build the ghosts, and it
  -- sets the reach the whole pole layout is computed at.
  if pole_name then build_qualities[#build_qualities + 1] = pole_quality end
  -- Ten entries at most, and in the ordinary game every one of them is "normal" -- so ask the
  -- force once per distinct tier rather than once per material, on a path every refresh runs.
  local asked = {}
  for _, quality in pairs(build_qualities) do
    if not asked[quality] then
      asked[quality] = true
      if not force.is_quality_unlocked(quality) then
        return true, {
          "upl-message.build-quality-not-researched", prototypes.quality[quality].localised_name,
        }, r
      end
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
