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
local circuits = require("scripts.circuits")
local quality_math = require("scripts.quality_math")

local memo = {}

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

-- The walk itself, taking the head of the chain so a synthetic one can exercise it: a chain
-- longer than the installed game has, and a circular one, are both unreachable from a real
-- prototype table. Stubs need only the three fields read here, the way recycler_orientation is
-- stubbed with a bare footprint.
--
-- Bounded by the names ALREADY SEEN rather than by a tier count. The cycle guard is the same
-- worry -- prototypes.quality.next is a linked list a malformed mod could close into a loop --
-- but a count doubles as a ceiling on how many tiers a WELL-formed mod may add, and silently
-- dropped every tier above it. Marking hidden tiers seen too is what a count was really buying:
-- a cycle of entirely hidden tiers grows no chain, so a #chain bound would spin forever.
function planner.walk_quality_chain(first)
  local chain, seen = {}, {}
  local quality = first
  while quality and not seen[quality.name] do
    seen[quality.name] = true
    if not quality.hidden then chain[#chain + 1] = quality.name end
    quality = quality.next
  end
  return chain
end

-- normal first, then upward, skipping hidden tiers ("quality-unknown" is one of them).
function planner.quality_chain()
  if not memo.qualities then
    memo.qualities = planner.walk_quality_chain(prototypes.quality["normal"])
  end
  return memo.qualities
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

  -- Matched by DISTINCT name, not by entry: a hand-written modded recycling recipe may list
  -- one ingredient across two product rows (a guaranteed row plus a probability row), and
  -- that still returns exactly the crafting ingredients -- counting entries read it as a
  -- mismatch and silently kept the item out of the picker.
  local matched, matched_count = {}, 0
  for _, result in pairs(recycling.products) do
    if result.type ~= "item" then return false end
    if not wanted[result.name] then return false end
    if not matched[result.name] then
      matched[result.name] = true
      matched_count = matched_count + 1
    end
  end

  return matched_count == wanted_count
end

-- THE 2.0 FORK. This file's divergence from main is these helpers plus the roll shim below:
-- 2.0's LuaRecipePrototype has `category`/`additional_categories` where 2.1 has
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

-- Slot-less beacons are excluded up front: a beacon with no module inventory transmits
-- nothing, so planning one would stand a powered statue in every column. Placeability is the
-- machine list's own gate, for the same reason it has it.
local function beacon_candidates()
  return candidates("beacons", function(entity)
    return entity.type == "beacon"
      and (entity.module_inventory_size or 0) > 0
      and entity.items_to_place_this ~= nil
  end)
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

-- The five chest roles the layout builds with, one predicate each. Keyed rather than written out
-- five times, because everything downstream -- the picker's list, the default pick, prune's
-- membership test -- is the same question asked once per role. The order is the one the modal
-- shows them in: what feeds the machines, what holds each tier's items, what relieves the eject,
-- what it hands back to the base, and what it hands away.
--
-- `stock` is the one role whose KIND the player switches (2026-08-26, decisions.md): buffer
-- chests by default, so personal logistics and construction bots can draw on the loop's items,
-- or requester chests to keep them locked in. The flag rides through every accessor as
-- `buffered` rather than living in this table, because the unbuffered kind IS the requester
-- role's list -- resolved_role below collapses the pair, so the scans stay memoised per kind.
--
-- `container` is deliberately a PLAIN chest: the eject's relief must not talk to the
-- player's network, or the loop would compete with the base for its own intermediates. The
-- logistic roles test `type` strictly, because an infinity chest reports a logistic_mode too and
-- a chest that conjures items out of nothing is never a correct buffer in a loop whose whole job
-- is to conserve one population of items.
--
-- `overflow` is the one role that has to be an ACTIVE provider rather than the player's pick of
-- logistic chest. It is the loop's only unbounded sink -- bots take its contents away -- and a
-- passive provider or a plain chest would merely fill, at which point the ring saturates again a
-- few hours later. `logistic-system` unlocks it alongside the requester and the buffer chest
-- (base technology.lua), so neither it nor the stock role's default costs research the mod did
-- not already require.
planner.CHEST_ROLES = { "requester", "stock", "container", "provider", "overflow" }

local CHEST_ACCEPTS = {
  container = function(entity)
    return entity.type == "container" and not entity.logistic_mode
  end,
  requester = function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == "requester"
  end,
  stock = function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == "buffer"
  end,
  provider = function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == "passive-provider"
  end,
  overflow = function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == "active-provider"
  end,
}

-- The stock role's kind switch: unbuffered stock chests ARE requester chests, so the pair
-- shares one candidate scan and one membership test instead of duplicating the list under a
-- second memo key. Every public accessor resolves through here; `buffered` is ignored for the
-- four fixed roles.
local function resolved_role(role, buffered)
  if role == "stock" and not buffered then return "requester" end
  return role
end

-- The one reading of the checkbox: nil -- never touched, or a save from before it existed --
-- means buffered. Every caller derives the accessors' `buffered` argument through here, so a
-- raw nil can never slip into resolved_role and read as the opposite default.
function planner.stock_buffered(choices)
  return choices.buffer_stock ~= false
end

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

-- Beacons as names for the chests' reason: the offered set cannot be a bare type filter, or
-- show-all would put slot-less and unplaceable beacons straight back in the picker.
function planner.beacons()
  return names_of("beacon_names", beacon_candidates())
end

function planner.chests(role, buffered)
  role = resolved_role(role, buffered)
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

function planner.is_beacon(name)
  return beacon_candidates()[name] ~= nil
end

function planner.is_pipe(name)
  return pipe_candidates()[name] ~= nil
end

function planner.is_inserter(name)
  return electric_inserter_candidates()[name] ~= nil
end

function planner.is_chest(name, role, buffered)
  return chest_candidates(resolved_role(role, buffered))[name] ~= nil
end

-- How many filter slots a plan for this recipe needs in all -- the planner's rule, asked by
-- the modal so the inserter picker can be sized before a plan exists, which is why it takes a
-- recipe that may be nil and answers for "nothing picked yet" (needs_pipe below is the same
-- shape for the pipe picker). Written out rather than `and ... or 1`: a recipe with no item
-- ingredients counts 0, and 0 or 1 is 0. What ONE inserter must carry is min_filter_slots of
-- this.
function planner.filters_needed(recipe)
  if not recipe then return 1 end
  return #planner.item_ingredients(recipe)
end

-- The fewest filter slots an inserter can have and still serve a recipe of this many
-- ingredients: the list divides across layout.MAX_FEED_STACKS feed stacks per machine, so an
-- inserter only ever filters the larger share. Every gate on filter slots -- the pick, the
-- modal's re-pick and validate's refusal -- reads this, so the cap has one owner: with the
-- engine's five slots an inserter, ten ingredients is the most a loop can take.
function planner.min_filter_slots(ingredient_count)
  return math.ceil(ingredient_count / layout.MAX_FEED_STACKS)
end

-- The most ingredients a loop can filter with what this force can build: the roomiest
-- inserter's slots, times the stacks a column stands. Only ever said in a refusal, so the fuel
-- rule is ignored like any_inserter's -- a fuelled inserter's slots count for the ceiling.
function planner.max_ingredients(force)
  local roomiest = best_by(inserter_candidates(), function(_, entity)
    return entity_is_buildable(force, entity) and (entity.filter_count or 0) or nil
  end)
  local slots = roomiest and (prototypes.entity[roomiest].filter_count or 0) or 0
  return slots * layout.MAX_FEED_STACKS
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

-- Filter slots on a chosen inserter, nil when nothing valid is chosen. The harvest inserters
-- need one slot per ingredient of their own stack, and the engine caps every inserter at five
-- (prototype docs, both tracks), so only a recipe past two stacks' worth can outrun a pick.
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

-- How many of this beacon a tier's column can stack, asked by the modal so the count
-- dropdown offers exactly what fits and nothing that could fail. Resolves the same rotated
-- heights plan() and validate() use -- a fluid recipe stands the machine sideways, the
-- recycler stands at its eject rotation -- and answers 0 for "nothing to offer yet" when a
-- piece is missing or unworkable.
function planner.max_beacon_count(choices, beacon)
  local recipe = choices.recipe and prototypes.recipe[choices.recipe]
  local machine = choices.machine and prototypes.entity[choices.machine]
  local recycler = choices.recycler and prototypes.entity[choices.recycler]
  if not (recipe and machine and recycler and beacon) then return 0 end
  local orientation = planner.recycler_orientation(recycler)
  if not orientation then return 0 end
  local machine_height = machine.tile_height
  if planner.needs_pipe(recipe) then
    local fluid_orientation = planner.machine_fluid_orientation(machine)
    if not fluid_orientation then return 0 end
    machine_height = fluid_orientation.height
  end
  return layout.max_beacon_count(machine_height, orientation.height, beacon.tile_height)
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

-- The productivity family, the quality family's mirror: the split picker's fallback filter
-- and prune's membership test. Scored by effect like everything else here, so a modded
-- productivity module slots in unnamed.
function planner.productivity_modules()
  return names_of("productivity_modules", module_candidates("productivity"))
end

function planner.is_productivity_module(name)
  return module_candidates("productivity")[name] ~= nil
end

function planner.unlocked_productivity_modules(force)
  return planner.unlocked(force, planner.productivity_modules())
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
-- recipe. Returns the message, or nil when nothing refuses it. The recipe may be nil -- a
-- beacon crafts nothing, so its module answers to the beacon alone.
local function module_refusal(item, holders, recipe)
  for _, holder in pairs(holders) do
    if not planner.accepts_module(holder, item) then
      return { "upl-message.module-not-accepted", item.localised_name, holder.localised_name }
    end
  end
  if recipe and not planner.accepts_module(recipe, item) then
    return { "upl-message.module-not-accepted-by-recipe", item.localised_name }
  end
end

-- What a module picker offers: the modules this holder and this recipe both accept. The
-- recipe may be nil, module_refusal's own rule -- a beacon crafts nothing, so its modules
-- answer to the holder alone. Not memoised -- it depends on the pair, and the scan is a
-- dozen items.
function planner.modules_for(holder, recipe)
  local names = {}
  for name, item in pairs(module_items()) do
    if planner.accepts_module(holder, item)
      and (not recipe or planner.accepts_module(recipe, item))
    then
      names[#names + 1] = name
    end
  end
  return names
end

function planner.module_fits(name, holder, recipe)
  local item = name and module_items()[name]
  if not item then return false end
  return planner.accepts_module(holder, item)
    and (not recipe or planner.accepts_module(recipe, item))
end

-- The strongest researched module that actually raises productivity and that the pair
-- accepts -- or **nothing**, which is the common case, since allow_productivity defaults to
-- false and only a handful of vanilla recipes opt in. One rule, two defaults: the terminal
-- machine's module and the split's productivity half both start here.
function planner.best_productivity_module(force, machine, recipe)
  return best_by(module_candidates("productivity"), function(name, value)
    if not planner.is_unlocked(force, name) then return nil end
    if not planner.module_fits(name, machine, recipe) then return nil end
    return value
  end)
end

-- The terminal default keeps its own name -- the pickers are separate decisions, and a
-- future terminal-only rule must not silently move the split's default with it. Never a
-- quality module: at the target tier there is nothing left to roll into.
function planner.terminal_module(force, machine, recipe)
  return planner.best_productivity_module(force, machine, recipe)
end

-- Whether ANY productivity module can go in this pair -- the structural half alone, research
-- aside, which is what decides whether the mix surface exists at all: an unresearched module
-- is a matter of time, a refusing recipe is a fact about the loop.
function planner.mix_possible(machine, recipe)
  for name in pairs(module_candidates("productivity")) do
    if planner.module_fits(name, machine, recipe) then return true end
  end
  return false
end

-- Efficiency-family candidates for the beacon's default, name -> how much consumption the
-- module saves. Pure prototype data, memoised like module_candidates -- whose positive-only
-- rule this cannot reuse, since efficiency's whole effect is negative. A modded hybrid with a
-- negative quality rider is excluded here: it would transmit exactly the harm the default
-- exists to avoid, so it stays pickable but never the default.
local function efficiency_candidates()
  if memo.efficiency_modules then return memo.efficiency_modules end
  local map = {}
  for name, item in pairs(module_items()) do
    local effects = item.module_effects or {}
    local value = effects["consumption"]
    if value and value < 0 and (effects["quality"] or 0) >= 0 then map[name] = -value end
  end
  memo.efficiency_modules = map
  return map
end

-- The beacon's default module: the strongest researched EFFICIENCY module the beacon accepts,
-- or nothing. Scored by the consumption effect -- the effect, not the category name, the way
-- every other default here reads module_effects -- because a speed module's negative quality
-- side effect transmits to every covered machine and recycler (api.md §25; this loop exists
-- to roll quality), so the honest default is the one family that costs the loop nothing.
-- Speed stays pickable.
function planner.beacon_module(force, beacon)
  return best_by(efficiency_candidates(), function(name, value)
    if not planner.is_unlocked(force, name) then return nil end
    if not planner.accepts_module(beacon, module_items()[name]) then return nil end
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
-- order. 2.0 fork: `volume` is the attribute here -- the quality-parameterised
-- `get_volume()` that main reads only exists from 2.1.7 (analysis/factorio-2.0.md).
function planner.pipe(force)
  return best_by(pipe_candidates(), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    local box = entity.fluidbox_prototypes[1]
    return box and box.volume or 0
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
-- items between adjacent buildings. Filters are not optional: a harvest inserter needs one slot
-- per ingredient of its stack. Fuelled ones never reach this pick at all -- the candidate table
-- it reads is the electric one.
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

-- The default inserter for a recipe of this many ingredients. One that filters the whole list
-- alone wins outright, so a recipe any inserter already serves builds the one stack it always
-- did; only when none can is the split's smaller requirement consulted -- which in vanilla,
-- where every inserter carries five slots, means a recipe past five ingredients and nothing
-- else. A modded game with a faster, narrower inserter would otherwise be handed two stacks
-- for a recipe one inserter could feed.
function planner.inserter_for(force, ingredient_count)
  return planner.inserter(force, ingredient_count)
    or planner.inserter(force, planner.min_filter_slots(ingredient_count))
end

-- The default chest for a role: largest researched inventory, so the pick is deterministic
-- rather than whatever prototype iteration happens to reach first. Scored at normal for the
-- pole's reason -- quality grows every chest's inventory alike, since
-- quality_affects_inventory_size defaults true -- so the ranking is the same at any tier.
function planner.chest(force, role, buffered)
  return best_by(chest_candidates(resolved_role(role, buffered)), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.get_inventory_size(defines.inventory.chest) or 0
  end)
end

-- Throughput

-- How many minutes of crafting every feed chest keeps of each ingredient, the one number the
-- Ingredient amounts panel sizes every row from: the player's own when they typed one
-- (feed_minutes -- only an edit is stored, so nil means the default), else two, the
-- owner's call of 2026-09-09 (it opened at one minute, capped at a stack). Type-guarded like
-- circuit_hand: a hand-edited save can hold anything. NOT a request_<...> key on purpose:
-- that prefix is the per-item override family, which state.prune sweeps by the recipe's
-- ingredients and the item handler clears on a pick -- and this number is a preference
-- that outlives both, not a size fitted to one recipe.
planner.DEFAULT_FEED_MINUTES = 2
planner.MAX_FEED_MINUTES = 100

function planner.feed_minutes(choices)
  local minutes = choices and choices.feed_minutes
  if type(minutes) ~= "number" or minutes ~= minutes or minutes < 1 then
    return planner.DEFAULT_FEED_MINUTES
  end
  return math.min(math.floor(minutes), planner.MAX_FEED_MINUTES)
end

-- Blueprint request counts are int32; the engine clamps past it, this just keeps the
-- number the panel shows the number the chest gets.
local INT32_MAX = 2147483647

-- How many of an ingredient to keep in the feed chest: `minutes` of crafting at the recipe's
-- own pace, whole items, at least one. No stack cap since 1.2.2: the amount is the player's
-- to size, and plan() warns when the chest cannot hold it (request_overflow) rather than
-- clipping it in silence. The reference blueprints express the same thing as a parameter
-- formula because they cannot see the real recipe; we can. Integer numerator, one division:
-- amount / energy * 60 can land a hair under a whole number and ceil it up one.
function planner.request_count(ingredient, recipe, minutes)
  local wanted = math.ceil(ingredient.amount * 60 * minutes / recipe.energy)
  return math.max(1, math.min(wanted, INT32_MAX))
end

-- The player's own amount for one ingredient, or the formula. The Ingredient amounts panel
-- stores an edit as a flat number under request_<item>, and an untouched ingredient has no
-- key at all -- so the formula stays live and a recipe retune, or a new minutes figure,
-- moves the default instead of freezing a number the player never chose. Anything invalid --
-- a zero, a stray non-number from an old save -- falls back the same way.
local function chosen_request(choices, ingredient, recipe, minutes)
  local override = choices["request_" .. ingredient.name]
  if type(override) == "number" and override >= 1 then return math.floor(override) end
  return planner.request_count(ingredient, recipe, minutes)
end

-- Whether the feed chests can hold what they are asked for: the slots each stack's share of
-- the ingredients needs, ceil(count / stack) apiece, against the requester's own slot count
-- at the quality it is placed at (quality grows a chest's inventory; api.md S15). Divided
-- exactly as layout.build divides them, so the halves compared are the halves stood, and
-- the fuller half is what gets reported -- both stacks are the same chest. A warning on the
-- plan, never a refusal: bots fill what fits and the loop runs on a shallower buffer.
local function feed_overflow(requests, ingredients, requester, feed_stacks)
  local slots = prototypes.entity[requester.name]
    .get_inventory_size(defines.inventory.chest, requester.quality) or 0
  local names = {}
  for _, ingredient in pairs(ingredients) do names[#names + 1] = ingredient.name end
  local needed = 0
  for _, share in pairs(layout.split_ingredients(names, feed_stacks)) do
    local used = 0
    for _, name in pairs(share) do
      used = used + math.ceil(requests[name] / prototypes.item[name].stack_size)
    end
    needed = math.max(needed, used)
  end
  if needed > slots then return { needed = needed, slots = slots } end
  return nil
end

-- Building a plan

-- Quality can ADD module slots (quality_affects_module_slots -- off for every vanilla machine,
-- but a modded one may set it), and module_inventory_size is documented as the normal-quality
-- figure only. So the count is read at the quality the building will actually be placed at.
local function module_slots(entity, quality, inventory)
  return entity.get_inventory_size(inventory or defines.inventory.crafter_modules, quality)
    or entity.module_inventory_size
end

local function footprint_of(entity, quality, inventory)
  return {
    name = entity.name,
    quality = quality,
    width = entity.tile_width,
    height = entity.tile_height,
    module_slots = module_slots(entity, quality, inventory),
    -- Which inventory the module insert plan targets; nil means the serialiser's
    -- crafter_modules default. Carried as a plain value because layout.lua runs on the host
    -- interpreter too, where defines.inventory does not exist.
    module_inventory = inventory,
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

-- The beacon is optional like the pole but simpler: it has NO researched-best default, so nil
-- already means exactly one thing -- off -- and no clear-flag is needed to tell an explicit
-- clear from a never-touched picker. A stale name reads as off too, never as a substitute
-- beacon the player did not ask for.
local function chosen_beacon(choices)
  if choices.beacon and planner.is_beacon(choices.beacon) then
    return choices.beacon, planner.build_quality(choices.beacon_quality)
  end
  return nil
end

-- The terminal module's shape: nil is a real answer ("place the beacon empty"), recorded in
-- no_beacon_module. Answers to the beacon prototype alone -- a beacon crafts nothing, so the
-- recipe never enters into it.
local function chosen_beacon_module(force, choices, beacon)
  if choices.no_beacon_module then return nil end
  local name = choices.beacon_module
  if name and planner.is_module(name) then return name end
  return planner.beacon_module(force, beacon)
end

-- The count is clamped, never refused: a remembered pick can outlive the geometry that
-- offered it (a taller machine, a different beacon), and the honest read is "as many as
-- still fit" -- floored at one, since a chosen beacon always stands at least itself.
local function chosen_beacon_count(choices, max)
  return math.max(1, math.min(choices.beacon_count or 1, max))
end

-- The inserter follows the belt's pattern with one addition: a pick can be individually
-- inadequate. A harvest inserter needs a slot per ingredient of its stack, so a recipe past
-- two stacks' worth can outgrow an otherwise perfectly good inserter -- and quietly building
-- the loop out of a different one would hide the player's own choice, so the prototype is
-- handed back for validate to name. A pick that only serves the recipe split is kept as
-- picked: the player chose it, and two stacks is what it costs.
local function chosen_inserter(force, choices, ingredient_count)
  local slots = planner.inserter_filter_count(choices.inserter)
  if not slots then return planner.inserter_for(force, ingredient_count) end
  if slots >= planner.min_filter_slots(ingredient_count) then return choices.inserter end
  return nil, prototypes.entity[choices.inserter]
end

-- The belt's rule once per chest role: a picked chest wins, a stale name falls back. The stock
-- role's kind follows the checkbox, so a pick of the other kind reads as stale and falls back
-- to the active kind's best -- which is also what heals a save whose flag and pick disagree.
local function chosen_chest(force, choices, role)
  local buffered = planner.stock_buffered(choices)
  local name = choices[role]
  if name and planner.is_chest(name, role, buffered) then return name end
  return planner.chest(force, role, buffered)
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

-- Whether the split may mix at all: the stock_buffered idiom, nil meaning ON -- the checkbox
-- starts ticked, and only an explicit untick forces every lower machine back to quality
-- modules only. The stored per-tier overrides stay put while unticked, the circuit numbers'
-- own rule, so re-ticking restores the player's tuning.
function planner.split_enabled(choices)
  return choices.split_enabled ~= false
end

-- The split's productivity module is the belt's shape, not the pole's: there is no "none"
-- to record, because a tier with zero productivity slots already says it -- so an emptied
-- picker snaps back to best_productivity_module's default, nil exactly when the recipe or
-- the machine refuses productivity, which is what forces the split all-quality with no
-- refusal. A pick the pair refuses falls back too, unlike the terminal module's
-- refuse-at-validate: the no-refusal promise has to hold on every path, GUI or not.
-- Exported, unlike its chosen_* siblings: the GUI's resolver delegates here, which is what
-- keeps the widget and the plan structurally unable to drift.
function planner.chosen_productivity_module(force, choices, machine, recipe)
  local name = choices.productivity_module
  if name and planner.is_productivity_module(name)
    and planner.module_fits(name, machine, recipe) then
    return name
  end
  return planner.best_productivity_module(force, machine, recipe)
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

  local ingredient_count = #planner.item_ingredients(recipe)
  local inserter, inserter_shortfall = chosen_inserter(force, choices, ingredient_count)
  -- How many feed stacks each machine gets: one while the inserter filters the whole list,
  -- two once it cannot -- never more, since chosen_inserter refuses anything that would need
  -- a third. Decided here, on the inserter actually chosen, so the layout and the pole memo
  -- key read one answer.
  local slots = inserter and planner.inserter_filter_count(inserter) or 0
  local feed_stacks = math.min(layout.MAX_FEED_STACKS,
    (slots > 0 and ingredient_count > slots) and math.ceil(ingredient_count / slots) or 1)

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
    feed_stacks = feed_stacks,
    belt = chosen_belt(choices) or planner.belt(force),
    pipe = pipe,
    pipe_to_ground = planner.pipe_to_ground_for(force, pipe),
    container = chest("container"),
    requester = chest("requester"),
    stock = chest("stock"),
    provider = chest("provider"),
    overflow = chest("overflow"),
    -- Pairs like every other build material with a quality. The two module pickers own their own
    -- qualities: the top machine's module became a separate choice from the quality modules
    -- below it, so one shared quality would have tied two unrelated decisions together.
    quality_module = planner.with_quality(quality_module, choices.quality_module_quality),
    terminal_module = planner.with_quality(terminal_module, choices.terminal_module_quality),
    productivity_module = planner.with_quality(
      planner.chosen_productivity_module(force, choices, machine, recipe),
      choices.productivity_module_quality),
  }
end

-- The per-tier module split

-- The engine half of quality_math.solve, gathered here so the pure module never sees a
-- prototype. THE 2.0 ROLL SHIM: get_roll_chances is 2.1.13-only (LuaQualityPrototype ships
-- no methods on 2.0.77), so this track computes the distribution itself from the chain's
-- own prototypes. 2.0 semantics (the 2.1 changelog's own wording; factorio-2.0.md): quality
-- effect values are x10 here and the real one-step chance is effect x next_probability
-- (vanilla 0.1), so no scale conversion happens anywhere else -- raw 2.0 effects flow into
-- this function and the x0.1 lands exactly once. Each further transition multiplies by the
-- reached tier's own next_probability and the chain's top absorbs the remainder, which for
-- vanilla's uniform 0.1 reproduces the 2.1 engine's measured distributions digit for digit
-- (planner_spec pins them); reading each tier's own next_probability is the documented
-- model for modded chains, not a measurement. Ceilings match main's deliberate stance:
-- no force truncation, planning ahead of research is legitimate.
local function roll_chances_for(tier, effect)
  local from = prototypes.quality[tier]
  local dist = {}
  if not from.next then
    dist[tier] = 1
    return dist
  end
  local step = effect * (from.next_probability or 0)
  if step < 0 then step = 0 end
  if step > 1 then step = 1 end
  dist[tier] = 1 - step
  local mass = step
  local q = from.next
  while q do
    if not q.next then
      dist[q.name] = (dist[q.name] or 0) + mass
      break
    end
    local continue = q.next_probability or 0
    dist[q.name] = (dist[q.name] or 0) + mass * (1 - continue)
    mass = mass * continue
    q = q.next
  end
  return dist
end
-- Exported on this track alone, so the premise spec pins the shipped shim rather than a
-- re-derivation of it. Main's counterpart premise pins the engine call instead.
planner.roll_chances_for = roll_chances_for

-- THE 2.0 SEAM: main detects down-rolling quality mods off previous_probability (and its
-- chain twin) and prices their down-rolls at zero in the solve. Neither attribute exists on
-- 2.0.77's LuaQualityPrototype -- the read family arrived with 2.1.7, and reading a missing
-- LuaObject attribute is a hard error, not nil -- and 2.0's quality mechanic has no downward
-- roll at all, so on this track the answer is a constant: no downgrade, the solve's sweep
-- never gated on.
local function quality_downgrades()
  return false
end

-- A module pair's per-slot effects at its own quality, engine-scaled -- get_module_effects,
-- never a hand-applied curve (api.md §30). Both roll axes, so a modded hybrid prices its
-- cross terms (the vanilla families read zero on the other axis), plus speed, which the
-- solve ignores and the time estimate pays for.
local function per_slot_effects(spec)
  local item = spec and module_items()[spec.name]
  if not item then return nil end
  local effects = item.get_module_effects(spec.quality) or {}
  return {
    quality = effects.quality or 0,
    productivity = effects.productivity or 0,
    speed = effects.speed or 0,
  }
end

-- The recyclers' one summed quality effect: base receiver effect, every slot of the
-- quality module, and whatever the beacon stack transmits (a speed module's quality malus
-- lands here too, api.md §25), clamped by the recycler's own limits. Their split never
-- varies -- a recycling recipe refuses productivity by engine rule -- so this is a number,
-- not a search.
local function recycler_quality_effect(recycler, quality, module_spec, beacon_quality)
  local receiver = recycler.effect_receiver
  local base = receiver and receiver.base_effect
  local per_slot = per_slot_effects(module_spec)
  local effect = ((base and base.quality) or 0) + (beacon_quality or 0)
    + (module_slots(recycler, quality) or 0) * ((per_slot and per_slot.quality) or 0)
  local limits = receiver and receiver.quality_limits
  if limits then
    if effect < limits.low then effect = limits.low end
    if effect > limits.high then effect = limits.high end
  end
  return math.max(effect, 0)
end

-- What one tier's beacon stack transmits to every machine and recycler beside it, PER
-- AXIS: count x beacon slots x the module's own effects, scaled by the beacon's
-- distribution effectivity at its quality and by its profile entry for the stack size --
-- the engine's transmission arithmetic (api.md §31). All three axes, because a speed
-- module carries a quality malus: crediting the speed while ignoring the malus would make
-- the yield and the pace flatter a loop the beacons may in truth have killed (api.md §25).
local function beacon_transmitted_effects(force, choices)
  local none = { speed = 0, quality = 0, productivity = 0 }
  local beacon_name, beacon_quality = chosen_beacon(choices)
  local beacon = beacon_name and prototypes.entity[beacon_name]
  if not beacon then return none end
  -- A beacon no count of which fits (too tall for the interior) transmits nothing: validate
  -- refuses that plan, and pricing one beacon anyway would hand the ratio wizard optima for
  -- a configuration that cannot be built.
  local max = planner.max_beacon_count(choices, beacon)
  if max < 1 then return none end
  local count = chosen_beacon_count(choices, max)
  local module_name = chosen_beacon_module(force, choices, beacon)
  local item = module_name and prototypes.item[module_name]
  if not item then return none end
  local effects = item.get_module_effects(
    planner.build_quality(choices.beacon_module_quality)) or {}
  local level = prototypes.quality[beacon_quality].level
  local effectivity = (beacon.distribution_effectivity or 0)
    + (beacon.distribution_effectivity_bonus_per_quality_level or 0) * level
  local profile = beacon.profile
  local factor = 1
  if profile and #profile > 0 then factor = profile[math.min(count, #profile)] end
  local scale = count * (module_slots(beacon, beacon_quality,
    defines.inventory.beacon_modules) or 0) * effectivity * factor
  return {
    speed = (effects.speed or 0) * scale,
    quality = (effects.quality or 0) * scale,
    productivity = (effects.productivity or 0) * scale,
  }
end

-- Product items one recycling CRAFT eats, read off the recipe: the generated ones take
-- exactly one, a modded one may not. One owner, because two consumers must agree on it --
-- the solve's per-item S below and the pace's craft count in station_times.
local function recycling_items_per_craft(recycling, product_name)
  for _, ingredient in pairs(recycling.ingredients) do
    if ingredient.type == "item" and ingredient.name == product_name then
      return ingredient.amount or 1
    end
  end
  return 1
end

-- How many ingredient-sets recycling ONE product item returns, read off the generated
-- recycling recipe rather than assumed 25%: the formula moved in 2.1.13 and a modded
-- recycler may differ (api.md §8). The first crafting ingredient present in both recipes
-- anchors the ratio -- divided by the items one craft eats, since the recipe reports output
-- PER CRAFT and the solve prices S per recycled ITEM ("recycling one product returns S
-- ingredient-sets"). A recipe that never matches falls back to the vanilla constant, floored
-- past a zero-amount modded product that would otherwise divide S to infinity and turn the
-- yield into NaN (0 is truthy, so `or 1` alone cannot catch it).
local function sets_per_recycle(recipe, product_name, products_per_set)
  local recycling = planner.recycling_recipe(product_name)
  if recycling then
    local per_craft = recycling_items_per_craft(recycling, product_name)
    local returned = {}
    for _, result in pairs(recycling.products) do
      if result.type == "item" then
        local amount = (result.amount or ((result.amount_min + result.amount_max) / 2))
          * (result.probability or 1) + (result.extra_count_fraction or 0)
        -- Summed, not assigned: the loop gate accepts an ingredient split across two
        -- product rows, so the ratio has to count both.
        returned[result.name] = (returned[result.name] or 0) + amount
      end
    end
    for _, ingredient in pairs(planner.item_ingredients(recipe)) do
      local amount = returned[ingredient.name]
      if amount and ingredient.amount > 0 and per_craft > 0 then
        return amount / ingredient.amount / per_craft
      end
    end
  end
  if not (products_per_set and products_per_set > 0) then products_per_set = 1 end
  return 0.25 / products_per_set
end

-- One solve is O(tiers x slots) get_roll_chances calls and gui.refresh runs on every pick,
-- so the last answer is kept -- one slot PER FLAVOUR (defaults and overrides-folded), keyed
-- by the VALUE of every input, never by a reference. Two slots because a rebuild with the
-- wizard open runs both flavours back to back, and with overrides stored their keys differ:
-- one slot would thrash on exactly the path that repeats most. Research needs no event to
-- invalidate this: a technology changes the resolved module identities or the recipe's
-- productivity_bonus, and both are in the key. Unlike the prototype memos above this key
-- carries force state, which is exactly why it cannot live in memo.* with a permanent key.
-- The cached table is handed out by reference -- plan() and the wizard alias it -- so
-- callers treat it as read-only, or a mutation poisons every later hit.
local split_keys, split_values = {}, {}

local function spec_key(spec)
  return spec and (spec.name .. "@" .. (spec.quality or "normal")) or "-"
end

-- The optimal split and the loop's expected yield for these choices. `gathered` is
-- resources()' table when the caller already paid for it; `ignore_overrides` computes the
-- untouched optimum, which is what the wizard's fields open showing. Returns nil until the
-- choices name a loop; otherwise { prods = {tier_index -> productivity count}, yield =
-- { per_set, per_item, and -- when the loop has any output -- machine_sets/recycled, the
-- expected crafts per target item the pace estimate reads }, slots = machine module slots,
-- transmitted = the beacon stack's per-axis effects, mixable }.
function planner.split(force, choices, gathered, ignore_overrides)
  local recipe = choices.recipe and prototypes.recipe[choices.recipe]
  local machine = choices.machine and prototypes.entity[choices.machine]
  local recycler = choices.recycler and prototypes.entity[choices.recycler]
  if not (recipe and machine and recycler and choices.quality) then return nil end
  local tiers = planner.tiers_up_to(choices.quality)
  if not tiers then return nil end
  -- The vetted product record: exactly one item product with a real amount, the upcyclable
  -- gate's own accessor -- so the amount needs no re-derivation and no defensive fallback.
  local product = single_item_product(recipe)
  if not product then return nil end

  local r = gathered or resources(force, recipe, machine, choices)
  if not r.quality_module then return nil end

  local machine_quality = planner.build_quality(choices.machine_quality)
  local recycler_quality = planner.build_quality(choices.recycler_quality)

  -- Unticked, the mix checkbox forces all-quality: the solve prices no productivity module
  -- at all -- the same path a productivity-refusing recipe takes -- and the stored per-tier
  -- overrides go inert rather than being cleared, so a re-tick restores them.
  local mixing = planner.split_enabled(choices)
  local productivity_module = mixing and r.productivity_module or nil

  local overrides = {}
  local key_overrides = ""
  if mixing and not ignore_overrides then
    for j = 1, #tiers - 1 do
      local value = choices["split_prod_" .. tiers[j]]
      -- Type-guarded like tier_columns and chosen_request: a hand-edited save can hold
      -- anything, and a non-number here would crash the key concat and the solve's clamp.
      if type(value) == "number" then
        overrides[j] = value
        key_overrides = key_overrides .. j .. ":" .. value .. ";"
      end
    end
  end

  -- The beacon stack's transmitted effects reach every machine and recycler, so the solve
  -- must see them: a speed beacon's quality malus can lower every roll, or kill the loop
  -- outright, and pricing only its speed would flatter exactly that configuration.
  local transmitted = beacon_transmitted_effects(force, choices)

  local flavour = ignore_overrides and "defaults" or "folded"
  local bonus = force.recipes[recipe.name].productivity_bonus or 0
  local key = table.concat({
    force.name, choices.quality, recipe.name,
    machine.name .. "@" .. machine_quality, recycler.name .. "@" .. recycler_quality,
    spec_key(r.quality_module), spec_key(productivity_module),
    spec_key(r.terminal_module), tostring(choices.no_terminal_module or false),
    -- The flag itself is in the key: with it off the productivity spec above already reads
    -- "-", but a modset with no productivity module would collide the two states otherwise.
    tostring(mixing), tostring(bonus), key_overrides,
    -- The transmitted VALUES rather than the beacon picks that produce them: count, beacon,
    -- module, both qualities and research all fold into these three numbers.
    transmitted.speed .. ":" .. transmitted.quality .. ":" .. transmitted.productivity,
  }, "|")
  if key == split_keys[flavour] then return split_values[flavour] end

  local slots = module_slots(machine, machine_quality) or 0
  local receiver = machine.effect_receiver
  local base = receiver and receiver.base_effect
  local products_per_set = product.amount * (product.probability or 1)

  local prods, yield = quality_math.solve({
    tiers = tiers,
    slots = slots,
    quality_module = per_slot_effects(r.quality_module),
    productivity_module = per_slot_effects(productivity_module),
    terminal = per_slot_effects(r.terminal_module),
    base = {
      quality = ((base and base.quality) or 0) + transmitted.quality,
      productivity = ((base and base.productivity) or 0) + transmitted.productivity,
    },
    research_productivity = bonus,
    max_productivity = recipe.maximum_productivity,
    limits = receiver and {
      quality = receiver.quality_limits,
      productivity = receiver.productivity_limits,
    } or nil,
    recycler_effect = recycler_quality_effect(recycler, recycler_quality, r.quality_module,
      transmitted.quality),
    products_per_set = products_per_set,
    sets_per_recycle = sets_per_recycle(recipe, product.name, products_per_set),
    roll_chances = roll_chances_for,
    downgrade = quality_downgrades() or nil,
  }, overrides)

  split_keys[flavour] = key
  split_values[flavour] = {
    prods = prods, yield = yield, slots = slots, transmitted = transmitted,
    -- Whether a mix is possible at all: nil means the pair refuses productivity (or the
    -- checkbox is unticked) and the split is forced all-quality -- the wizard says which.
    mixable = productivity_module ~= nil,
  }
  return split_values[flavour]
end

-- Columns per tier

-- The ceiling every column_count_<quality> value honours, wizard field and stored key alike.
-- A PERFORMANCE cap, not a ratio: the first cap (250, sized to clear the wiki's 208.5
-- sustained lower-tier crafters per terminal) let a few maxed tiers ask the engine for a
-- plan it could not survive -- the owner hit crashes on big layouts the day the feature
-- landed, so the ceiling came down to 32 (owner's call, 2026-08-28), then doubled to 64
-- once the pole solve went near-linear and 64-column plans measured comfortably inside a
-- refresh (owner's call, 2026-08-29; the measurements are in .ai-support/analysis/poles.md).
-- The wizard field's tooltip names the cap and the reason to the player.
planner.MAX_COLUMNS_PER_TIER = 64

-- One rule for "a whole number of columns": floored, at least one, at most the ceiling.
local function clamp_columns(value)
  return math.max(1, math.min(math.floor(value), planner.MAX_COLUMNS_PER_TIER))
end

-- The player's column count per LOWER tier, quality-keyed like the column_count_<quality>
-- keys themselves, DENSE: every lower tier gets an entry. Clamped defensively whatever the
-- GUI enforced -- a hand-edited save can hold anything -- and the TARGET tier is never in
-- the result: it keeps exactly one column, the single output chest the tap, the catcher
-- and the circuit cap all stand on, so a stray column_count_<target> key is structurally
-- ignored.
function planner.tier_columns(choices, tiers)
  local counts = {}
  for j = 1, #tiers - 1 do
    local value = choices["column_count_" .. tiers[j]]
    counts[tiers[j]] = type(value) == "number" and value >= 1 and clamp_columns(value) or 1
  end
  return counts
end

-- A per-DISTINCT-tier array expanded into one entry per PHYSICAL column: each lower tier's
-- value repeated by its count, the target's exactly once, last. Called once with the chain
-- itself (layout, circuits and the pole ladder all walk physical columns) and once with
-- the split's per-tier counts, which is what keeps layout.build's positional read
-- untouched. quality_math and planner.split keep the distinct chain, since repeating
-- entries there would corrupt the probability model; all-ones expands to a copy of the
-- input, which is what keeps an untouched plan byte-identical. The write goes through an
-- explicit counter, never #out + 1: values may carry holes (split.prods has no terminal
-- entry), and #out would stall on one.
function planner.expand_columns(values, tiers, counts)
  local out, n = {}, 0
  for j = 1, #tiers do
    for _ = 1, j < #tiers and counts[tiers[j]] or 1 do
      n = n + 1
      out[n] = values[j]
    end
  end
  return out
end

-- The per-tier station time for ONE column of each tier: the larger of the tier's expected
-- machine crafts x craft time and recycler crafts x craft time, seconds per target-quality
-- item, with the expected crafts from the same solve as the yield and the rates folding in
-- build quality (get_crafting_speed), each tier's own module speed penalties, and the
-- beacon stack's transmitted speed -- the same split.transmitted whose quality axis the
-- solve already priced. The engine floors a machine's speed at 20% of base, so the
-- multiplier does too. The SINGLE owner of the formula: loop_seconds divides these by the
-- player's column counts and keeps the worst. nil when the solve reports no flow or a
-- rate is zero.
local function station_times(recipe, machine, machine_quality, recycler, recycler_quality,
    product, split, tiers, r)
  local yield = split and split.yield
  if not (yield and yield.machine_sets) then return nil end
  local beacon_effect = split.transmitted.speed

  local recycling = planner.recycling_recipe(product.name)
  if not recycling then return nil end
  -- The same read sets_per_recycle divides S by, shared so pace and solve cannot disagree.
  local items_per_craft = recycling_items_per_craft(recycling, product.name)

  local machine_speed = machine.get_crafting_speed(machine_quality)
  local recycler_speed = recycler.get_crafting_speed(recycler_quality)
  if not (machine_speed and machine_speed > 0 and recycler_speed and recycler_speed > 0
    and items_per_craft > 0) then
    return nil
  end

  local function base_speed(entity)
    local receiver = entity.effect_receiver
    return (receiver and receiver.base_effect and receiver.base_effect.speed) or 0
  end

  local qm = per_slot_effects(r.quality_module)
  local pm = per_slot_effects(r.productivity_module)
  local tm = per_slot_effects(r.terminal_module)
  local qm_speed = (qm and qm.speed) or 0

  local recycler_mult = math.max(1 + base_speed(recycler)
    + (module_slots(recycler, recycler_quality) or 0) * qm_speed + beacon_effect, 0.2)
  local recycler_time = recycling.energy / (recycler_speed * recycler_mult)

  local machine_base = base_speed(machine)
  local slots = split.slots
  local times = {}
  for j = 1, #tiers do
    local modules_speed
    if j == #tiers then
      modules_speed = slots * ((tm and tm.speed) or 0)
    else
      local p = (split.prods and split.prods[j]) or 0
      modules_speed = (slots - p) * qm_speed + p * ((pm and pm.speed) or 0)
    end
    local mult = math.max(1 + machine_base + modules_speed + beacon_effect, 0.2)
    local time = yield.machine_sets[j] * recipe.energy / (machine_speed * mult)
    local recycled = yield.recycled and yield.recycled[j]
    if recycled then
      time = math.max(time, (recycled / items_per_craft) * recycler_time)
    end
    times[j] = time
  end
  return times
end

-- Steady-state seconds per target-quality item. Every station runs in parallel, so the
-- loop's pace is its single slowest one -- and a tier the player gave N columns shares its
-- load N ways, so its station time divides before the worst is taken. `columns` is
-- tier_columns' quality-keyed counts; a tier absent from it divides by one, which keeps an
-- untouched plan's pace byte-identical. nil when station_times reports no flow or the
-- worst degenerates.
local function loop_seconds(recipe, machine, machine_quality, recycler, recycler_quality,
    product, split, tiers, r, columns)
  local times = station_times(recipe, machine, machine_quality, recycler, recycler_quality,
    product, split, tiers, r)
  if not times then return nil end
  local worst = 0
  for j = 1, #tiers do
    -- The target is absent from counts by design and divides by one.
    worst = math.max(worst, times[j] / (columns[tiers[j]] or 1))
  end
  if worst <= 0 or worst ~= worst or worst == math.huge then return nil end
  return worst
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

-- Whether the beacon stack, standing where layout.build stands it -- layout.beacon_offsets
-- is the one owner of those positions, so this cannot drift from the built plan -- reaches
-- both footprints: SOME beacon reaches the machine and SOME reaches the recycler, not
-- necessarily the same one, which is the point of a stack whose ends sit nearer one receiver
-- each. The measured rule (tests/beacon_spec.lua): the supply area is a beacon's collision
-- box expanded by the supply distance on every side, and a receiver counts on collision-box
-- overlap. Margins shrink both boxes like the pole pass's stand-ins, so the answer can
-- under-promise -- an over-honest warning -- but never claim reach the game would not
-- deliver. Plain values in, so a spec can exercise shapes no installed mod ships; the
-- recycler is nil on the terminal tier, whose band is the machine alone.
function planner.beacon_reach(beacon, machine, recycler, fluid, count)
  local offsets = layout.beacon_offsets(machine.height, recycler and recycler.height,
    beacon, fluid, count or 1)
  local m, s = beacon.margin, beacon.supply
  local mm = machine.margin
  local machine_ok, recycler_ok = false, recycler == nil
  for _, o in pairs(offsets) do
    -- The pole pass's own overlap rule -- strict inequalities, touching covers nothing --
    -- with this beacon's expanded square as the first box.
    local x0, y0 = o.dx + m - s, o.dy + m - s
    local x1, y1 = o.dx + beacon.width - m + s, o.dy + beacon.height - m + s
    local function reaches(tx0, ty0, tx1, ty1)
      return poles.overlap(x0, y0, x1, y1, tx0, ty0, tx1, ty1)
    end
    if not machine_ok and reaches(mm, mm, machine.width - mm, machine.height - mm) then
      machine_ok = true
    end
    if recycler and not recycler_ok then
      local rm = recycler.margin
      if reaches(rm, machine.height + rm,
        recycler.width - rm, machine.height + recycler.height - rm) then
        recycler_ok = true
      end
    end
    if machine_ok and recycler_ok then break end
  end
  return machine_ok and recycler_ok
end

-- The layout+pole ladder is the most expensive thing a refresh runs, and most refreshes do
-- not move it: a module pick, a ratio keystroke or a circuit toggle changes no geometry. So
-- the winning column gaps and pole placements are kept under a key of every geometric input
-- (planner.plan builds it), and a hit replays them through ONE layout.build instead of the
-- ladder's 2..N full solves -- deterministically the same answer, since the ladder itself is
-- deterministic over the same inputs, which is what the plan determinism specs pin. One
-- slot, module-local like the split memo: rebuilt on load, identical on every client. The
-- cached pole entities are never handed out -- append_poles copies them -- so a later wire
-- rebase or circuit pass cannot poison the cache.
local pole_memo = {}

-- Appends the solved poles to the plan as FRESH entity tables, wire_to rebased from the pole
-- solve's own numbering onto plan indices -- the one place that sees both numberings, and
-- what lets the serialiser wire an entity by index without knowing what a pole is. Copies
-- rather than aliases, because the memo replays the same solved poles into many plans.
local function append_poles(plan, placed, unpowered)
  local base = #plan.entities
  for i = 1, #placed do
    local p = placed[i]
    plan.entities[base + i] = {
      name = p.name, quality = p.quality, dx = p.dx, dy = p.dy, w = p.w, h = p.h,
      wire_to = p.wire_to and (base + p.wire_to) or nil,
    }
  end
  if unpowered > 0 then plan.unpowered = unpowered end
end

-- Poles stand on a FINISHED layout, but where they CAN stand is part of that layout -- so the
-- two are solved together rather than in sequence, narrowest first. Three attempts at most:
--
--   1. compact -- no pole columns at all, poles in whatever the ring already leaves free
--      (the dead ground beside a recycler narrower than its machine, and the last tier's
--      empty lower block). On most shapes this covers, and it is as small as a plan gets.
--   2. all columns -- one sized column before every tier, the 0.2.0 shape.
--   3. shrink -- collapse every column no pole stood in, solve again, repeat. Ordinarily it
--      only collapses, so the open set shrinks -- but a column the LAYOUT floors open (the
--      beacon's lane) still stands when its gap is requested away, and a pole landing in it
--      re-grows the gap. The walk is deterministic, so a revisited pattern would repeat
--      forever: the visited patterns are remembered, and a revisit ends the walk.
--
-- Fewest unpowered consumers wins, and the narrower plan takes any tie -- compact is tried
-- first, so it holds one. Attempt 2 IS the plan the mod used to emit unconditionally, and it
-- is always in the running, which is what makes the outcome impossible to be worse than it.
local function plan_with_poles(layout_params, tier_count, pole_gap, pole, memo_key)
  if pole_memo.key == memo_key then
    layout_params.column_gaps = pole_memo.gaps
    local plan = layout.build(layout_params)
    append_poles(plan, pole_memo.placed, pole_memo.unpowered)
    return plan
  end

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

    -- The walk's visited gap patterns. A closed column cannot ordinarily regain a pole, but
    -- a column the layout floors open regardless (the beacon's lane) can -- and the walk is
    -- deterministic, so revisiting any pattern would repeat the same orbit forever.
    local seen = { [table.concat(current.gaps, ",")] = true }
    while true do
      -- A column earns its width by holding a pole. Anything else is dead ground, including a
      -- column the free-tile fallback walked away from. poles.column_at is the one owner of
      -- the containment rule, shared with the solve's own column filter so the two passes
      -- cannot drift -- and it is the binary search that kept this from going quadratic with
      -- the physical column count once tiers repeat.
      local held = {}
      local columns = current.plan.utility_columns
      if columns then
        for _, placed in pairs(current.poles.entities) do
          local found = poles.column_at(columns, placed.dx, pole.width)
          if found then held[found.tier] = true end
        end
      end

      local gaps, collapsed = {}, false
      for index = 1, tier_count do
        gaps[index] = held[index] and pole_gap or 0
        if gaps[index] ~= current.gaps[index] then collapsed = true end
      end
      if not collapsed then break end
      local pattern = table.concat(gaps, ",")
      if seen[pattern] then break end
      seen[pattern] = true

      local shrunk = attempt(gaps)
      -- Coverage is the floor: a narrower plan that leaves one more machine dark is not an
      -- improvement, and stopping here keeps the wider one that did cover.
      if shrunk.poles.unpowered > current.poles.unpowered then break end
      current = shrunk
      if beats(current, best) then best = current end
    end
  end

  local plan = best.plan
  append_poles(plan, best.poles.entities, best.poles.unpowered)
  pole_memo = {
    key = memo_key, gaps = best.gaps,
    placed = best.poles.entities, unpowered = best.poles.unpowered,
  }
  return plan
end

-- One owner for the cap's default -- one stack of the product, the stock chest's own sizing
-- rule -- shared by the wizard's backfill and plan()'s fallback, so the number the player is
-- shown and the number the plan uses cannot drift. Nil until a recipe names a product.
function planner.default_circuit_max(recipe)
  local product = recipe and planner.product_of(recipe)
  local item = product and prototypes.item[product]
  return item and item.stack_size or nil
end

-- The hand size an inserter has TODAY: one, plus the prototype's own built-in bonus, plus
-- the force's researched bonus -- the bulk capacity family for a bulk inserter, the plain
-- stack-size family for the rest -- unless the prototype opts out of research. Quality never
-- enters it, and this is exactly the number the engine's inserter_target_pickup_count reports
-- for an entity with neither override nor circuit (measured, api.md S33) -- read here off the
-- prototype and the force so no entity has to stand.
function planner.inserter_hand(force, name)
  -- No inserter at all -- a recipe no researched inserter can filter leaves the pick empty
  -- while validate refuses the plan -- reads as the engine's floor of one, so the wizard can
  -- still stand and show something rather than index nil.
  local entity = name and prototypes.entity[name]
  if not entity then return 1 end
  local hand = 1 + (entity.inserter_stack_size_bonus or 0)
  if entity.uses_inserter_stack_size_bonus then
    hand = hand + (entity.bulk and force.bulk_inserter_capacity_bonus
      or math.floor(force.inserter_stack_size_bonus))
  end
  return hand
end

-- The blueprint's override_stack_size is a uint8, so the hand a plan can pin tops out here.
planner.MAX_HAND = 255

-- The hand every reserve inserter is pinned to and every minimum is raised by: the wizard's
-- own number when the player typed one (circuit_hand -- only an edit is stored, the
-- ingredient amounts' rule, so an untouched field keeps following the pick and the
-- research), else the chosen inserter's researched hand. Type-guarded like the thresholds:
-- a hand-edited save can hold anything.
function planner.circuit_hand(force, choices, inserter_name)
  local hand = choices.circuit_hand
  -- A NaN is a number that fails `< 1`, and it must fall back rather than reach the
  -- decorator's assert; `hand ~= hand` is the one test that catches it.
  if type(hand) ~= "number" or hand ~= hand or hand < 1 then
    hand = planner.inserter_hand(force, inserter_name)
  end
  return math.min(math.floor(hand), planner.MAX_HAND)
end

-- The shortest circuit-wire distance among everything the circuit pass wires. A wire is
-- refused past the SHORTER end's reach, so one conservative number serves every hop; each
-- prototype is asked at the quality it is placed at, since quality genuinely grows a pole's
-- wire reach and may grow these the same way. The belt carries no quality by the engine's own
-- rule. get_max_CIRCUIT_wire_distance, not the copper getter beside it -- the two answer
-- different questions and only this one is documented for circuit wires (api.md S26). A
-- modded entity with no circuit wire support answers 0, which the decorator turns into
-- unlinked counts -- a warning, never a refusal. The inserter joins the min only when some
-- reserve is set: it is wired only then, and a wireless modded inserter must not zero the
-- reach of a plan that never wires one.
-- The circuit stack's prototypes: fixed vanilla ones, no picker and no research gate (the
-- owner's call, 2026-09-07 -- both techs are trivial and early), so plain names here rather
-- than a resources() field, handed to layout.build which names no prototype of its own.
local CIRCUIT_COMBINATOR = "constant-combinator"
local CIRCUIT_LAMP = "small-lamp"
local CIRCUIT_PANEL = "display-panel"

-- The circuit thresholds, normalised ONCE: minimums sparse (a tier present only when its
-- floor is above zero), maximum nil when off -- "zero means off" resolved here and nowhere
-- else, so plan() (which stands the combinator on it), validate() (which warns about an
-- unreachable floor) and gui.refresh (which greys Start paused) cannot disagree. An unset cap
-- falls back to default_circuit_max, so plan() stays callable without the GUI's defaults
-- having run; the cap lives under its own circuit_max_<quality> key, never a re-read
-- minimum, so a remembered floor cannot become a ceiling when the target moves onto its
-- tier. Type-guarded like tier_columns: a hand-edited save can hold anything.
function planner.circuit_limits(choices, recipe, tiers)
  local minimums = {}
  for i = 1, #tiers - 1 do
    local floor = choices["circuit_min_" .. tiers[i]]
    if type(floor) == "number" and floor > 0 then minimums[tiers[i]] = floor end
  end
  local maximum = choices["circuit_max_" .. choices.quality]
  if type(maximum) ~= "number" then maximum = planner.default_circuit_max(recipe) end
  if not (maximum and maximum > 0) then maximum = nil end
  return minimums, maximum
end

local function circuit_reach(machine, machine_quality, recycler, recycler_quality, r, circuit)
  local reach = math.min(
    machine.get_max_circuit_wire_distance(machine_quality),
    recycler.get_max_circuit_wire_distance(recycler_quality),
    prototypes.entity[r.stock.name].get_max_circuit_wire_distance(r.stock.quality),
    prototypes.entity[r.provider.name].get_max_circuit_wire_distance(r.provider.quality),
    prototypes.entity[r.belt].get_max_circuit_wire_distance(),
    prototypes.entity[CIRCUIT_COMBINATOR].get_max_circuit_wire_distance())
  if next(circuit.minimums) ~= nil then
    reach = math.min(reach,
      prototypes.entity[r.inserter.name].get_max_circuit_wire_distance(r.inserter.quality))
  end
  if circuit.capped then
    reach = math.min(reach,
      prototypes.entity[CIRCUIT_LAMP].get_max_circuit_wire_distance(),
      prototypes.entity[CIRCUIT_PANEL].get_max_circuit_wire_distance())
  end
  return reach
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

  local minutes = planner.feed_minutes(choices)
  local requests = {}
  for _, ingredient in pairs(ingredients) do
    requests[ingredient.name] = chosen_request(choices, ingredient, recipe, minutes)
  end

  local r = gathered or resources(force, recipe, machine, choices)
  if not (r.inserter and r.belt and r.container and r.requester and r.stock and r.provider
    and r.quality_module) then
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
  -- all, leaving layout.build's own floor clamp as the only thing that can widen a column.
  local pole_name, pole_quality = chosen_pole(force, choices)
  local pole = pole_name and prototypes.entity[pole_name]
  local beacon_name, beacon_quality = chosen_beacon(choices)
  local beacon = beacon_name and prototypes.entity[beacon_name]
  -- The player's count, floored at one and capped to what the pair leaves standing room for.
  -- validate() computes the same clamp from its own locals; plan() re-derives it because it
  -- is also called directly, without validate() having run first -- which is why a max of
  -- zero (a beacon taller than the interior, validate's beacon-too-tall refusal) returns nil
  -- here instead of flooring to one and building the stack across the ring belts.
  local beacon_count
  if beacon then
    local beacon_max = layout.max_beacon_count(machine_footprint.height, orientation.height,
      beacon.tile_height)
    if beacon_max == 0 then return nil end
    beacon_count = chosen_beacon_count(choices, beacon_max)
  end
  -- The pole's lane is added BESIDE the beacon's width rather than sharing it: a full-height
  -- stack can leave the beacon's column without a single free row, and the sum reserves the
  -- pole ground the stack cannot take. Only ever paid where it buys coverage --
  -- plan_with_poles reads this width on no attempt before the compact one has left a
  -- consumer dark, and every covering plan stays exactly as wide as before.
  local pole_gap = (#fluids == 1 and 1 or 0) + (pole and pole.tile_width or 0)
    + (beacon and beacon.tile_width or 0)

  local product_stack = prototypes.item[product.name].stack_size

  -- The per-tier split, solved on the same gathered resources: which mix of quality and
  -- productivity modules each lower tier's machine carries, defaulting to the computed
  -- optimum with the player's split_prod_<tier> overrides folded in. nil when no
  -- productivity module fits, which is the old flat all-quality rule.
  local split = planner.split(force, choices, r)

  -- Per-tier column repeats, expanded ONCE here into the physical-column lists everything
  -- geometric walks -- layout, the pole ladder, the circuit decoration. The distinct
  -- `tiers` keeps feeding the solve, the circuit floors and the pace: their model is the
  -- quality chain, not the machinery count. All-ones keeps every hand-off byte-identical.
  local columns = planner.tier_columns(choices, tiers)
  local expanded_tiers = planner.expand_columns(tiers, tiers, columns)
  local expanded_split = split and split.prods
    and planner.expand_columns(split.prods, tiers, columns) or nil

  -- Circuit limits, resolved BEFORE the layout runs: the combinator is a real entity in the
  -- terminal column since 2026-09-07, so whether one stands -- and whether the lamps and
  -- panel join it -- is geometry now, not decoration. nil unless something is actually
  -- non-zero, which keeps a circuits-off plan byte-identical. layout_params.circuit below
  -- and the decoration after the poles both read this one table, so the two can never
  -- disagree about which entities exist.
  local circuit
  if choices.circuit_enabled then
    local minimums, maximum = planner.circuit_limits(choices, recipe, tiers)
    if maximum or next(minimums) ~= nil then
      circuit = {
        minimums = minimums, maximum = maximum, capped = maximum ~= nil,
        paused = maximum ~= nil and choices.circuit_paused == true,
        -- The cap counted across the logistic network (circuits.lua, network mode): only
        -- ever with a cap, and pure decoration -- the stack stands the same either way.
        network = maximum ~= nil and choices.circuit_network == true,
        hand = planner.circuit_hand(force, choices, r.inserter.name),
      }
    end
  end

  local layout_params = {
    recipe = { name = recipe.name, product = product.name, ingredients = ingredients },
    tiers = expanded_tiers,
    overflow_tap = overflow_tap,
    -- One feed stack per machine, or two when the recipe outgrew the inserter's filter
    -- slots -- resources() decided, on the inserter it chose.
    feed_stacks = r.feed_stacks,
    circuit = circuit and {
      capped = circuit.capped,
      combinator = CIRCUIT_COMBINATOR, lamp = CIRCUIT_LAMP, panel = CIRCUIT_PANEL,
    } or nil,
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
    requester = r.requester, stock = r.stock, container = r.container,
    provider = r.provider, overflow = r.overflow,
    -- Off unless the player picked one: the beacon has no researched-best default, because it
    -- costs a column of width per tier and its transmittable modules trade against the quality
    -- rolls the loop exists for. Footprint and slots resolved per prototype like the machine's;
    -- the count stacks that footprint vertically, so it costs rows, never width.
    beacon = beacon
      and footprint_of(beacon, beacon_quality, defines.inventory.beacon_modules) or nil,
    beacon_count = beacon_count,
    -- One pair per module, or nil for "leave that machine empty" -- which only ever happens to
    -- the terminal one, and for "place the beacon empty". `split` carries each lower tier's
    -- productivity-slot count; absent, every lower tier is all-quality, the pre-split rule.
    modules = {
      quality_module = r.quality_module,
      terminal_module = r.terminal_module,
      productivity_module = r.productivity_module,
      split = expanded_split,
      beacon_module = beacon and planner.with_quality(
        chosen_beacon_module(force, choices, beacon), choices.beacon_module_quality) or nil,
    },
    requests = requests,
    -- One stack of the product in front of each recycler: enough to keep it busy through a
    -- gap on the belt, and self-limiting rather than hoarding.
    product_buffer = product_stack,
  }
  -- With poles, the layout and the pole pass are solved together -- the columns a plan opens
  -- are the ones poles turned out to need. Without them there is nothing to weigh, so the
  -- geometry is built once.
  local plan
  if pole then
    -- The pole memo's key: every input the ladder's answer depends on -- the occupied
    -- geometry (footprints, tier count, pipes, the tap), the consumer set (entity NAMES
    -- decide electric-or-not and the margins, and a modded chest or belt can carry an
    -- electric energy source), and the pole itself, whose quality sets both reaches.
    -- Modules, requests and circuit NUMBERS are absent on purpose: they never move a tile.
    -- Circuit presence is in -- off, reserved, capped -- because the stack it stands is
    -- occupied ground and the lamps are consumers; typing a threshold still re-solves
    -- nothing, only crossing zero does. The feed-stack count is in for the same reason:
    -- a second stack is three occupied tiles and two consumers per column, on the very
    -- ground a compact plan's poles stood in -- the recipe itself stays out, since which
    -- ingredients they are moves nothing.
    local memo_key = table.concat({
      #expanded_tiers, tostring(overflow_tap), #fluids, r.feed_stacks,
      circuit and (circuit.capped and "capped" or "reserved") or "off",
      machine_footprint.name, machine_footprint.width, machine_footprint.height,
      tostring(machine_footprint.direction),
      recycler.name, orientation.width, orientation.height, orientation.direction,
      r.belt, r.inserter.name,
      r.requester.name, r.stock.name, r.container.name, r.provider.name,
      r.overflow and r.overflow.name or "-",
      #fluids == 1 and r.pipe or "-", #fluids == 1 and r.pipe_to_ground or "-",
      beacon_name or "-", beacon and beacon.tile_width or 0,
      beacon and beacon.tile_height or 0, beacon_count or 0,
      pole_name, pole_quality, pole_gap,
    }, "|")
    plan = plan_with_poles(layout_params, #expanded_tiers, pole_gap, {
      name = pole_name, quality = pole_quality,
      width = pole.tile_width, height = pole.tile_height,
      -- Quality genuinely grows a pole's reach (+level to the supply radius, +2*level to
      -- the wire reach), so the layout is computed at the quality the poles are placed at.
      supply_distance = pole.get_supply_area_distance(pole_quality),
      wire_distance = pole.get_max_wire_distance(pole_quality),
    }, memo_key)
  else
    plan = layout.build(layout_params)
  end

  -- Circuit limits, decorated onto the finished plan -- strictly after the pole pass, since
  -- only the conditions and the wiring are left to do: WHICH entities exist was settled
  -- above, from the same normalised tables the decorator reads now, so the reach and the
  -- wiring cannot disagree about what is actually wired.
  if circuit then
    local unlinked = circuits.decorate(plan.entities, {
      tiers = expanded_tiers,
      minimums = circuit.minimums,
      maximum = circuit.maximum,
      paused = circuit.paused,
      network = circuit.network,
      hand = circuit.hand,
      product = product.name,
      reach = circuit_reach(machine, machine_quality, recycler, recycler_quality, r, circuit),
    })
    -- Reported like the pole pass's unpowered: only the built geometry knows it, and the loop
    -- still runs -- an unwired entity just runs without its limit.
    if unlinked > 0 then plan.circuit_unlinked = unlinked end
  end

  -- Carried on the plan rather than through the layout: which chests exist is geometry, whether
  -- their surplus is trashed is the player's call at Confirm. `~= false` keeps a stored choices
  -- table from before the checkbox existed reading as checked.
  plan.trash_unrequested = choices.trash_unrequested ~= false

  -- A feed request past what the chest holds, reported like unpowered and circuit_unlinked
  -- rather than as validate's warning -- validate shows ONE warning, first come, so a
  -- spoiling recipe would never surface this one -- and a line of its own on the status
  -- area. Nothing geometric: it follows the amounts and the chest pick alone.
  plan.request_overflow = feed_overflow(requests, ingredients, r.requester, r.feed_stacks)

  -- What the loop MAKES, alongside the counts and the shortfall the plan already carries. A
  -- bare `quality` would be ambiguous here -- the plan holds a machine quality, a recycler
  -- quality, a module quality and a pinned quality per tier -- so this one says which it is.
  plan.product = product.name
  plan.target_quality = choices.quality

  -- The loop's expected yield under exactly the modules this plan carries, for the status
  -- line: per_item is target-or-above product per tier-one item recycled in, the wiki's own
  -- "items per legendary" as 1/per_item.
  plan.yield = split and split.yield or nil

  -- And its pace: steady-state seconds per target item, nil when the loop cannot make one.
  plan.seconds = loop_seconds(recipe, machine, machine_quality, recycler, recycler_quality,
    product, split, tiers, r, columns)

  return plan
end

-- Validation

-- Whether an item rots. `get_spoil_ticks` is a METHOD taking the quality, not the data stage's
-- `spoil_ticks` field -- LuaItemPrototype carries no such attribute, so reading one gives nil
-- and every item reads as safe. It returns 0 for anything that does not spoil, and the answer
-- genuinely grows with the tier (measured 2.1.16: a captive biter spawner lasts 108000 ticks at
-- normal and 270000 at legendary), so this asks at normal -- the tier every loop holds, and the
-- one that rots first.
local function spoils(item_name)
  local item = prototypes.item[item_name]
  return item ~= nil and item.get_spoil_ticks("normal") > 0
end

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
  local machine_width, machine_height = machine.tile_width, machine.tile_height
  if #fluids == 1 then
    local fluid_orientation = planner.machine_fluid_orientation(machine)
    if not fluid_orientation then
      return false, { "upl-message.machine-no-fluid-face", machine.localised_name }
    end
    machine_width = fluid_orientation.width
    machine_height = fluid_orientation.height
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

  -- One gate for the target: tiers_up_to answers nil for a nil quality, an unknown name and
  -- a hidden tier alike, so a separate prototype-existence check would only restate this
  -- refusal.
  if not planner.tiers_up_to(choices.quality) then
    return false, { "upl-gui.pick-a-recipe" }
  end

  -- The building materials the layout is made of. Each is a real research gate, so each gets
  -- its own message rather than one vague "something is missing". The gathered table rides on
  -- every ok return so plan() can reuse it instead of re-running the same scans.
  local r = resources(force, recipe, machine, choices)
  if not r.inserter then
    -- Order matters. When nothing available has enough filter slots for even the larger
    -- share of a split the RECIPE is the problem whatever was picked, and naming the pick
    -- would advise a fix that does not exist -- which is every vanilla case, since the engine
    -- caps every inserter at five slots and two stacks make that ten ingredients; no vanilla
    -- recipe reaches it. Only once something better is genuinely available is the pick worth
    -- naming, so that branch needs a modded inserter with fewer slots to reach.
    local per_inserter = planner.min_filter_slots(#ingredients)
    if not planner.any_inserter(force, per_inserter) then
      return false, { "upl-message.too-many-ingredients", planner.max_ingredients(force) }
    end
    if r.inserter_shortfall then
      return false, {
        "upl-message.inserter-too-few-filters",
        r.inserter_shortfall.localised_name, per_inserter,
      }
    end
    return false, { "upl-message.only-fuelled-inserters" }
  end
  if not r.belt then return false, { "upl-message.no-belt" } end
  if not r.container then return false, { "upl-message.no-chest" } end
  if not (r.requester and r.provider) then return false, { "upl-message.no-logistic-chest" } end
  -- Only reachable with buffer chests on: unbuffered, the stock role shares the requester's
  -- list, so a missing stock is the missing requester already refused above. Unreachable in
  -- vanilla either way -- logistic-system unlocks all three logistic kinds together.
  if not r.stock then return false, { "upl-message.no-buffer-chest" } end
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

  -- The beacon is optional and defaults to off, so everything about it only runs on a pick.
  -- Its module answers to the beacon alone -- no recipe, a beacon crafts nothing -- and a
  -- beacon taller than the interior rows would poke through the ring belts, which layout.build
  -- clamps against and this refuses honestly instead: max_beacon_count of zero is exactly
  -- that case, and the count the player asked for clamps to the same max plan() uses.
  local beacon_name, beacon_quality = chosen_beacon(choices)
  local beacon = beacon_name and prototypes.entity[beacon_name]
  local beacon_module, beacon_count
  if beacon then
    local beacon_max = layout.max_beacon_count(machine_height, orientation.height,
      beacon.tile_height)
    if beacon_max == 0 then
      return false, { "upl-message.beacon-too-tall", beacon.localised_name }
    end
    beacon_count = chosen_beacon_count(choices, beacon_max)
    beacon_module = chosen_beacon_module(force, choices, beacon)
    if beacon_module then
      local beacon_refusal = module_refusal(prototypes.item[beacon_module], { beacon }, nil)
      if beacon_refusal then return false, beacon_refusal end
    end
  end

  -- Warnings from here: the plan is sound, so Place stays enabled.

  -- Spoilage, first among the warnings because it is the only one that never resolves itself:
  -- the research ones below come good when the technology lands, this one is a property of the
  -- item. The loop holds items for minutes at a time -- in the ingredient chests, in each
  -- tier's stock chest and on the ring -- so anything that rots does so before it can climb.
  --
  -- A warning rather than a refusal (owner's call): whether spoilage outruns the dwell time
  -- depends on throughput, and productivity module 3 -- biter eggs, 30 minutes -- is one of the
  -- game's headline upcycling targets, so refusing it outright would cost more than it saves.
  -- Measured 2026-08-27 on 2.1.16: 10 of the 210 upcyclable items carry a spoiling product or
  -- ingredient, `nutrients` being the only one that spoils as the product itself.
  local spoiling = spoils(product.name) and product
  if not spoiling then
    for _, ingredient in pairs(ingredients) do
      if spoils(ingredient.name) then
        spoiling = ingredient
        break
      end
    end
  end
  if spoiling then
    return true, { "upl-message.item-spoils", prototypes.item[spoiling.name].localised_name }, r
  end

  -- Planning ahead of research is legitimate, since the result is ghosts that bots will build
  -- once the technology lands.
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
    r.stock.quality,
    r.container.quality,
    r.provider.quality,
  }
  if r.terminal_module then
    build_qualities[#build_qualities + 1] = r.terminal_module.quality
  end
  -- The split's productivity module ships in the lower tiers' insert plans whenever it
  -- resolved at all and the mix is on; a refused pick already fell back inside
  -- chosen_productivity_module, so what arrives here is always something the pair accepts.
  if r.productivity_module and planner.split_enabled(choices) then
    build_qualities[#build_qualities + 1] = r.productivity_module.quality
  end
  -- Only when it is actually placed, so a legendary plan is not warned about a chest it does
  -- not build.
  if r.overflow and planner.needs_overflow_tap(choices.quality) then
    build_qualities[#build_qualities + 1] = r.overflow.quality
  end
  -- The pole's build quality matters twice over: it gates who can build the ghosts, and it
  -- sets the reach the whole pole layout is computed at.
  if pole_name then build_qualities[#build_qualities + 1] = pole_quality end
  if beacon then
    build_qualities[#build_qualities + 1] = beacon_quality
    if beacon_module then
      build_qualities[#build_qualities + 1] = planner.build_quality(choices.beacon_module_quality)
    end
  end
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

  -- A stack whose supply cannot span its tier's machine+recycler pair from the column is a
  -- warning, not a refusal: the loop runs fine, the beacons just reach less than the player
  -- expects. Some beacon must reach each receiver, not every beacon both. Only the pair band
  -- needs checking -- the terminal stack centres on the machine alone, a strictly easier
  -- reach from the same column. Unreachable in vanilla, whose beacon covers the tallest
  -- eligible pair with room to spare; a modded short-reach beacon is who this is for.
  if beacon and not planner.beacon_reach(
    { width = beacon.tile_width, height = beacon.tile_height,
      margin = consumer_margin(beacon),
      supply = beacon.get_supply_area_distance(beacon_quality) },
    { width = machine_width, height = machine_height, margin = consumer_margin(machine) },
    { width = orientation.width, height = orientation.height, margin = consumer_margin(recycler) },
    #fluids == 1, beacon_count)
  then
    return true, { "upl-message.beacon-out-of-reach", beacon.localised_name }, r
  end

  -- A circuit threshold the stock chest cannot physically hold could never be reached -- the
  -- count tops out at capacity and the reserve inserter only draws from the floor PLUS its
  -- hand upward -- so that tier's recycling would stop silently, the exact failure the
  -- request-raising rule in circuits.decorate closes for the trash-unrequested case.
  -- Capacity is asked at the chest's build quality, since quality grows a chest's inventory.
  if choices.circuit_enabled then
    local slots = prototypes.entity[r.stock.name]
      .get_inventory_size(defines.inventory.chest, r.stock.quality) or 0
    local capacity = slots * prototypes.item[product.name].stack_size
    local tiers = planner.tiers_up_to(choices.quality)
    -- Every column's census chest shares the one green network, so a repeated tier's floor
    -- reads the SUMMED count and can fill up to N chests -- and its threshold carries one
    -- hand per column (circuits.lua). The warning follows the same resolution plan()
    -- applies, or a multi-column tier warned falsely.
    local minimums = planner.circuit_limits(choices, recipe, tiers)
    if next(minimums) ~= nil then
      local columns = planner.tier_columns(choices, tiers)
      local hand = planner.circuit_hand(force, choices, r.inserter.name)
      for i = 1, #tiers - 1 do
        local floor, n = minimums[tiers[i]], columns[tiers[i]] or 1
        if floor and floor + hand * n > capacity * n then
          return true, {
            "upl-message.circuit-min-too-big", prototypes.quality[tiers[i]].localised_name,
          }, r
        end
      end
    end
  end

  return true, nil, r
end

return planner
