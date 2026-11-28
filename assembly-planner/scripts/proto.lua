-- Everything the planner asks of the prototypes: which items a cell can make, which machines
-- craft them, what the force has researched, and what each module, beacon, inserter and chest
-- accepts. Derived from prototypes.* only -- never from storage -- so every client computes the
-- same answers, and the memo below is rebuilt on load simply because this file is required
-- fresh each time. Several rules here were measured for Upcycler Planner first; each says
-- where.

local calc = require("scripts.calc")

local proto = {}

local memo = {}

-- The key of the highest-scoring entry; `score_of(key, value)` returns nil to reject one.
-- Callers pass a table keyed by prototype name, so the answer is a name.
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

-- Positions arrive from the API in array form; the x/y arm covers hand-written tables.
local function xy(v)
  return v[1] or v.x, v[2] or v.y
end

local function contains(list, wanted)
  for _, value in pairs(list) do
    if value == wanted then return true end
  end
  return false
end
proto.contains = contains

-- Quality tiers

-- normal first, then upward, skipping hidden tiers ("quality-unknown" is one). Bounded by the
-- names already seen, so a mod that closes prototypes.quality.next into a loop cannot spin it.
function proto.quality_chain()
  if memo.qualities then return memo.qualities end
  local chain, seen = {}, {}
  local quality = prototypes.quality["normal"]
  while quality and not seen[quality.name] do
    seen[quality.name] = true
    if not quality.hidden then chain[#chain + 1] = quality.name end
    quality = quality.next
  end
  memo.qualities = chain
  return chain
end

function proto.is_quality(name)
  if not memo.quality_set then
    memo.quality_set = {}
    for _, quality in pairs(proto.quality_chain()) do memo.quality_set[quality] = true end
  end
  return memo.quality_set[name] == true
end

-- The quality a pick is placed at. A tier some mod has since removed reads as normal.
function proto.build_quality(name)
  if name and proto.is_quality(name) then return name end
  return "normal"
end

function proto.with_quality(name, quality)
  if not name then return nil end
  return { name = name, quality = proto.build_quality(quality) }
end

-- The tier above this one, or nil at the top of the chain.
function proto.next_quality(name)
  local chain = proto.quality_chain()
  for i, quality in ipairs(chain) do
    if quality == name then return chain[i + 1] end
  end
  return nil
end

-- What the force has researched

-- A recipe that really makes something: not recycling, not Factoriopedia-hidden, not a
-- blueprint parameter. Researching recycling unlocks every *-recycling recipe at once, and
-- cheat tools ship enabled hidden recipes, so either would read unresearched items as unlocked
-- (Upcycler Planner's research-gating finding, its api.md §8).
local function is_real_recipe(recipe)
  for _, category in pairs(recipe.categories) do
    if category == "recycling" then return false end
  end
  return not recipe.hidden_in_factoriopedia and not recipe.parameter
end

-- item -> the real recipes that produce it.
local function producers()
  if memo.producers then return memo.producers end
  local map = {}
  for name, recipe in pairs(prototypes.recipe) do
    if is_real_recipe(recipe) then
      for _, product in pairs(recipe.products) do
        if product.type == "item" then
          map[product.name] = map[product.name] or {}
          table.insert(map[product.name], name)
        end
      end
    end
  end
  memo.producers = map
  return map
end

function proto.is_unlocked(force, item_name)
  for _, recipe_name in pairs(producers()[item_name] or {}) do
    local recipe = force.recipes[recipe_name]
    if recipe and recipe.enabled then return true end
  end
  return false
end

-- An entity is buildable when any item that places it is unlocked.
local function entity_is_buildable(force, entity)
  for _, item in pairs(entity.items_to_place_this or {}) do
    if proto.is_unlocked(force, item.name) then return true end
  end
  return false
end

function proto.buildable(force, names)
  local out = {}
  for _, name in pairs(names) do
    local entity = prototypes.entity[name]
    if entity and entity_is_buildable(force, entity) then out[#out + 1] = name end
  end
  return out
end

-- The item counterpart, for modules.
function proto.unlocked(force, names)
  local out = {}
  for _, name in pairs(names) do
    if proto.is_unlocked(force, name) then out[#out + 1] = name end
  end
  return out
end

-- Memoised scans: pure prototype predicates, keyed name -> prototype so best_by returns names.
-- Force questions stay with the callers, because research moves between calls.
local function candidates(kind, accept)
  if memo[kind] then return memo[kind] end
  local map = {}
  for name, entity in pairs(prototypes.entity) do
    if accept(entity) then map[name] = entity end
  end
  memo[kind] = map
  return map
end

local function names_of(kind, map)
  local key = kind .. "-names"
  if memo[key] then return memo[key] end
  local names = {}
  for name in pairs(map) do names[#names + 1] = name end
  table.sort(names)
  memo[key] = names
  return names
end

-- Machines

-- An assembling machine the cell can run: one that takes a recipe (a furnace picks its own
-- from what is inserted, and its blueprint group carries no recipe at all -- Upcycler Planner
-- api.md §21), runs on electricity or nothing (the cell delivers no fuel), and that a player
-- can place. Module slots are not required: an assembling machine 1 is a fine mall machine.
local function is_cell_machine(entity)
  return entity.type == "assembling-machine"
    and entity.crafting_categories ~= nil
    and entity.items_to_place_this ~= nil
    and not entity.fixed_recipe
    and (entity.electric_energy_source_prototype ~= nil
      or entity.void_energy_source_prototype ~= nil)
end

local function machine_map()
  return candidates("machines", is_cell_machine)
end

function proto.machine_candidates()
  return names_of("machines", machine_map())
end

function proto.is_machine(name)
  return machine_map()[name] ~= nil
end

function proto.can_craft(entity, recipe)
  if not entity.crafting_categories then return false end
  for _, category in pairs(recipe.categories) do
    if entity.crafting_categories[category] then return true end
  end
  return false
end

function proto.machines_for(recipe)
  local names = {}
  for _, name in pairs(proto.machine_candidates()) do
    if proto.can_craft(prototypes.entity[name], recipe) then names[#names + 1] = name end
  end
  return names
end

-- Fastest machine the force can build; the first candidate when none is researched, so the
-- modal can still explain itself.
function proto.best_machine(force, recipe)
  local names = proto.machines_for(recipe)
  local map = {}
  for _, name in pairs(names) do map[name] = prototypes.entity[name] end
  local best = best_by(map, function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.get_crafting_speed("normal")
  end)
  return best or names[1]
end

-- Recipes and the items a cell makes

function proto.item_ingredients(recipe)
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

-- Why a recipe cannot be a cell, as a message key, or nil when it can. A fluid product would
-- fill its output box and stall the machine with nowhere to go; a second fluid would need a
-- second pipe row. Both are left for later (deferred.md).
local function cell_refusal(recipe)
  for _, product in pairs(recipe.products) do
    if product.type == "fluid" then return "makes-fluid" end
  end
  local _, fluids = proto.item_ingredients(recipe)
  if #fluids > 1 then return "too-many-fluids" end
  if #proto.machines_for(recipe) == 0 then return "no-machine" end
  return nil
end

-- Every item a cell can make, and the cell-able recipes for each: real recipes producing an
-- item that pass cell_refusal. Names sorted, so a drop-down lists recipes in a stable order.
local function catalogue()
  if memo.catalogue then return memo.catalogue end
  local items, recipes_for = {}, {}
  for name, recipe in pairs(prototypes.recipe) do
    if is_real_recipe(recipe) and not cell_refusal(recipe) then
      for _, product in pairs(recipe.products) do
        if product.type == "item" then
          if not recipes_for[product.name] then
            recipes_for[product.name] = {}
            items[#items + 1] = product.name
          end
          if not contains(recipes_for[product.name], name) then
            table.insert(recipes_for[product.name], name)
          end
        end
      end
    end
  end
  for _, list in pairs(recipes_for) do table.sort(list) end
  table.sort(items)
  memo.catalogue = { items = items, recipes_for = recipes_for }
  return memo.catalogue
end

function proto.items()
  return catalogue().items
end

function proto.recipes_for_item(item_name)
  return catalogue().recipes_for[item_name] or {}
end

-- Whether a cell can make this item at all: the item picker's catalogue, and what a chain offers.
function proto.has_cell_recipe(item_name)
  return catalogue().recipes_for[item_name] ~= nil
end

-- Whether the force has researched a recipe a cell can make this item with.
function proto.is_cell_unlocked(force, item_name)
  for _, recipe_name in pairs(proto.recipes_for_item(item_name)) do
    local recipe = force.recipes[recipe_name]
    if recipe and recipe.enabled then return true end
  end
  return false
end

function proto.unlocked_items(force)
  local out = {}
  for _, item in pairs(proto.items()) do
    if proto.is_cell_unlocked(force, item) then out[#out + 1] = item end
  end
  return out
end

-- Why no recipe for this item makes a cell: the reason of the first real recipe producing it.
function proto.item_refusal(item_name)
  for _, recipe_name in pairs(producers()[item_name] or {}) do
    local recipe = prototypes.recipe[recipe_name]
    local reason = cell_refusal(recipe)
    if reason then return { "apl-message." .. reason } end
  end
  return { "apl-message.no-recipe", prototypes.item[item_name].localised_name }
end

-- Inserters

-- Every inserter in the cell stands between two adjacent tiles, so its hands must reach exactly
-- one tile straight ahead. Without this gate the long-handed inserter would reach past both.
local function reaches_adjacent_tiles(entity)
  local pickup, drop = entity.inserter_pickup_position, entity.inserter_drop_position
  if not (pickup and drop) then return false end
  local px, py = xy(pickup)
  local dx, dy = xy(drop)
  return math.abs(px) < 0.5 and py > -1.5 and py < -0.5
    and math.abs(dx) < 0.5 and dy > 0.5 and dy < 1.5
end

-- Electric only: nothing in the cell delivers fuel.
local function is_cell_inserter(entity)
  return entity.type == "inserter" and reaches_adjacent_tiles(entity)
    and entity.items_to_place_this ~= nil
    and not (entity.burner_prototype or entity.fluid_energy_source_prototype)
end

local function inserter_map()
  return candidates("inserters", is_cell_inserter)
end

function proto.inserters()
  return names_of("inserters", inserter_map())
end

function proto.is_inserter(name)
  return inserter_map()[name] ~= nil
end

-- Bulk inserters move a stack per swing; among equals, the faster arm wins.
function proto.best_inserter(force)
  return best_by(inserter_map(), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    -- A method, not the rotation_speed attribute, which is for cars and turrets.
    return (entity.bulk and 1000 or 0) + entity.get_inserter_rotation_speed("normal")
  end)
end

-- Items one swing carries: the prototype's own bonus plus the force's capacity research for its
-- kind -- the bulk bonus for a bulk inserter, the plain one for the rest -- unless the prototype
-- opts out of research. Quality speeds the arm, not the hand. The plain bonus is a double a mod
-- can make fractional; the engine floors the hand (measured, 4.5 -> 4), and so must a request
-- count built from it.
function proto.inserter_hand(entity, force)
  local hand = 1 + (entity.inserter_stack_size_bonus or 0)
  if entity.uses_inserter_stack_size_bonus ~= false then
    hand = hand + (entity.bulk and force.bulk_inserter_capacity_bonus or force.inserter_stack_size_bonus)
  end
  return math.floor(hand)
end

-- Ticks per round trip at this quality, from the arm's own speeds; nil when it cannot turn.
-- The reach term is the hand's change of distance between pickup and drop (0.2 for vanilla).
function proto.inserter_swing(entity, quality)
  local reach = 0
  local pickup, drop = entity.inserter_pickup_position, entity.inserter_drop_position
  if pickup and drop then
    local px, py = xy(pickup)
    local dx, dy = xy(drop)
    reach = math.abs(math.sqrt(dx * dx + dy * dy) - math.sqrt(px * px + py * py))
  end
  return calc.swing_ticks(entity.get_inserter_rotation_speed(quality),
    entity.get_inserter_extension_speed(quality), reach)
end

-- Chests

-- Two roles, each a one-tile logistic container in one mode. A strict type test, because an
-- infinity chest reports a logistic_mode too; placeability, because base ships unplaceable 1x1
-- scenery containers (Upcycler Planner api.md §15).
local CHEST_MODES = { requester = "requester", output = "passive-provider" }

local function chest_map(role)
  return candidates("chests-" .. role, function(entity)
    return entity.type == "logistic-container" and entity.logistic_mode == CHEST_MODES[role]
      and entity.tile_width == 1 and entity.tile_height == 1
      and entity.items_to_place_this ~= nil
  end)
end

function proto.chests(role)
  return names_of("chests-" .. role, chest_map(role))
end

function proto.is_chest(name, role)
  return chest_map(role)[name] ~= nil
end

function proto.is_requester(name) return proto.is_chest(name, "requester") end
function proto.is_output_chest(name) return proto.is_chest(name, "output") end

-- Largest researched inventory. Quality grows every chest alike, so normal ranks them.
function proto.best_chest(force, role)
  return best_by(chest_map(role), function(_, entity)
    if not entity_is_buildable(force, entity) then return nil end
    return entity.get_inventory_size(defines.inventory.chest) or 0
  end)
end

function proto.chest_slots(name, quality)
  return prototypes.entity[name].get_inventory_size(defines.inventory.chest, quality) or 0
end

-- Beacons, poles, pipes

-- A beacon with no module slots transmits nothing.
local function beacon_map()
  return candidates("beacons", function(entity)
    return entity.type == "beacon" and (entity.module_inventory_size or 0) > 0
      and entity.items_to_place_this ~= nil
  end)
end

function proto.beacons() return names_of("beacons", beacon_map()) end
function proto.is_beacon(name) return beacon_map()[name] ~= nil end

local function pole_map()
  return candidates("poles", function(entity)
    return entity.type == "electric-pole" and entity.items_to_place_this ~= nil
  end)
end

function proto.poles() return names_of("poles", pole_map()) end
function proto.is_pole(name) return pole_map()[name] ~= nil end

local function pipe_map()
  return candidates("pipes", function(entity)
    return entity.type == "pipe" and entity.items_to_place_this ~= nil
  end)
end

function proto.pipes() return names_of("pipes", pipe_map()) end
function proto.is_pipe(name) return pipe_map()[name] ~= nil end

-- Vanilla's pipe when it is researched, else whichever researched pipe sorts first.
function proto.best_pipe(force)
  local buildable = proto.buildable(force, proto.pipes())
  if contains(buildable, "pipe") then return "pipe" end
  return buildable[1]
end

-- Modules

local function module_items()
  if memo.module_items then return memo.module_items end
  memo.module_items = prototypes.get_item_filtered({ { filter = "type", type = "module" } })
  return memo.module_items
end

function proto.is_module(name)
  return module_items()[name] ~= nil
end

-- Whether this holder -- a machine, a beacon or a recipe, which carry the same two fields --
-- accepts this module. Only the effects a module applies POSITIVELY must be allowed: a speed
-- module goes in a machine that refuses quality, because its quality malus is not checked
-- (measured, Upcycler Planner api.md §16). allowed_module_categories is nil when every
-- category is allowed.
function proto.accepts_module(holder, item)
  local categories = holder.allowed_module_categories
  if categories and not categories[item.category] then return false end
  for effect, value in pairs(item.module_effects or {}) do
    if value > 0 and not (holder.allowed_effects and holder.allowed_effects[effect]) then
      return false
    end
  end
  return true
end

-- What a module picker offers: the modules this holder and, for a machine, its recipe accept.
function proto.modules_for(holder, recipe)
  local names = {}
  for name, item in pairs(module_items()) do
    if proto.accepts_module(holder, item) and not (recipe and not proto.accepts_module(recipe, item)) then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function proto.module_fits(name, holder, recipe)
  local item = name and module_items()[name]
  if not item then return false end
  return proto.accepts_module(holder, item) and not (recipe and not proto.accepts_module(recipe, item))
end

-- The strongest researched module raising `effect` that the holder accepts, by the size of
-- that effect -- so a modded module slots in without being named here.
function proto.best_module(force, effect, holder)
  local map = {}
  for name, item in pairs(module_items()) do
    local value = item.module_effects and item.module_effects[effect]
    if value and value > 0 then map[name] = item end
  end
  return best_by(map, function(name, item)
    if not proto.is_unlocked(force, name) then return nil end
    if holder and not proto.accepts_module(holder, item) then return nil end
    return item.module_effects[effect]
  end)
end

-- Quality can add module slots (quality_affects_module_slots), so the count is read at the
-- quality the building is placed at; module_inventory_size is the normal-quality figure only.
function proto.module_slots(entity, quality, inventory)
  return entity.get_inventory_size(inventory or defines.inventory.crafter_modules, quality)
    or entity.module_inventory_size or 0
end

-- Fluids

-- The connection categories a pipe can join: an array at runtime, {"default"} when its author
-- wrote none. Two connections join only when they share one (measured, Upcycler Planner
-- api.md §14.7) -- a port in another category is no fluid face, however it is authored.
local function pipe_categories(pipe_name)
  local categories = {}
  local pipe = pipe_name and pipe_map()[pipe_name]
  for _, box in pairs(pipe and pipe.fluidbox_prototypes or {}) do
    for _, connection in pairs(box.pipe_connections) do
      for _, category in pairs(connection.connection_category) do categories[category] = true end
    end
  end
  if not next(categories) then categories.default = true end
  return categories
end

local function joins(connection, categories)
  for _, category in pairs(connection.connection_category) do
    if categories[category] then return true end
  end
  return false
end

-- The rotation that turns one of the machine's fluid inputs to face NORTH, onto the pipe row
-- behind the cell, or nil when none does. A connection authored pointing `dir` points
-- `(dir + rotation) % 16` once the entity is rotated, and the engine merges every input box a
-- recipe needs into one live box that any of their connections feeds -- so one north-facing
-- input is enough (measured, Upcycler Planner api.md §14; the north row itself re-measured on
-- 2.1.23: AM3 and chemical plant unrotated, EM plant east, foundry south). North is tried
-- first, so a machine that already faces the row is never turned.
function proto.fluid_rotation(entity, pipe_name)
  local categories = pipe_categories(pipe_name)
  local directions = {}
  for _, box in pairs(entity.fluidbox_prototypes or {}) do
    if box.production_type == "input" or box.production_type == "input-output" then
      for _, connection in pairs(box.pipe_connections) do
        if connection.connection_type == "normal" and joins(connection, categories) then
          directions[#directions + 1] = connection.direction
        end
      end
    end
  end
  for _, rotation in pairs({
    defines.direction.north, defines.direction.east,
    defines.direction.south, defines.direction.west,
  }) do
    for _, direction in pairs(directions) do
      if (direction + rotation) % 16 == defines.direction.north then return rotation end
    end
  end
  return nil
end

-- Power and reach

-- How far a collision box sits inside its tile rect, on the larger axis so the shrunken
-- stand-in stays a subset of the real box at any rotation; clamped short of half a tile so a
-- degenerate box cannot yield an empty one. Vanilla: machines 0.3, inserters 0.35.
function proto.margin(entity)
  local box = entity.collision_box
  local ltx, lty = xy(box.left_top)
  local rbx, rby = xy(box.right_bottom)
  local inset_x = (entity.tile_width - (rbx - ltx)) / 2
  local inset_y = (entity.tile_height - (rby - lty)) / 2
  return math.min(math.max(inset_x, inset_y, 0), 0.45)
end

function proto.is_electric(entity)
  return entity.electric_energy_source_prototype ~= nil
end

-- Surfaces and spoilage

-- The first surface property this surface puts outside the conditions, or nil when it meets
-- them all. Recipes and entities carry the same SurfaceCondition list.
function proto.failed_condition(conditions, surface)
  for _, condition in pairs(conditions or {}) do
    local value = surface.get_property(condition.property)
    if (condition.min and value < condition.min) or (condition.max and value > condition.max) then
      return condition.property
    end
  end
  return nil
end

-- A METHOD; there is no spoil_ticks attribute, and the wrong spelling reads nil, which would
-- make every item look safe (Upcycler Planner api.md §29).
function proto.spoils(item_name, quality)
  local item = prototypes.item[item_name]
  return item ~= nil and (item.get_spoil_ticks(quality) or 0) > 0
end

return proto
