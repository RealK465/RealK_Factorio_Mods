-- Choices in, a finished cell out, in one pass: resolve every pick (a default for anything
-- untouched, a fallback for anything stale), refuse what cannot work, size the requests, lay
-- out the cell, power it, and collect the warnings. One function rather than a validator and
-- a planner kept in step by hand.
--
-- plan.build returns the plan, or nil plus a message when it refuses, or nil, nil before an
-- item is picked -- a hint, not an error.

local proto = require("scripts.proto")
local calc = require("scripts.calc")
local cell = require("scripts.cell")
local poles = require("scripts.poles")

local plan = {}

local function number_or(value, default, min, max)
  if type(value) ~= "number" or value ~= value or value < min then return default end
  return math.min(math.floor(value), max)
end

-- The numbers the player edits, one descriptor per mode: which choice key holds it, its
-- default and its ceiling. A number is stored only once edited, so an untouched one keeps
-- following its default.
local SIZE = {
  crafts = { key = "size_crafts", default = 4, max = 1000 },
  minutes = { key = "size_minutes", default = 2, max = 100 },
}
plan.SIZE_MODES = { "crafts", "minutes" }
plan.DEFAULT_CRAFTS, plan.DEFAULT_MINUTES = SIZE.crafts.default, SIZE.minutes.default

plan.CAP_MODES = { "slots", "network", "none" }
plan.DEFAULT_CAP_SLOTS = 2

function plan.size_mode(choices)
  return choices.size_mode == "minutes" and "minutes" or "crafts"
end

-- { mode, key, value, default, min, max } for the request-sizing field.
function plan.size_field(choices)
  local mode = plan.size_mode(choices)
  local spec = SIZE[mode]
  return {
    mode = mode, key = spec.key, default = spec.default, min = 1, max = spec.max,
    value = number_or(choices[spec.key], spec.default, 1, spec.max),
  }
end

function plan.cap_mode(choices)
  if choices.cap_mode == "network" or choices.cap_mode == "none" then return choices.cap_mode end
  return "slots"
end

-- The stock-cap field in the same shape, or { mode = "none" }. The network count defaults to
-- what the slot cap would hold: two stacks of the product.
function plan.cap_field(choices, product)
  local mode = plan.cap_mode(choices)
  if mode == "none" then return { mode = mode } end
  local key, default, max = "cap_slots", plan.DEFAULT_CAP_SLOTS, 65535
  if mode == "network" then
    local item = product and prototypes.item[product]
    key, default, max = "cap_count", 2 * (item and item.stack_size or 50), calc.INT32_MAX
  end
  return {
    mode = mode, key = key, default = default, min = 1, max = max,
    value = number_or(choices[key], default, 1, max),
  }
end

-- nil means never touched, and reads as ticked.
function plan.trash(choices)
  return choices.trash_unrequested ~= false
end

local function valid(name, test)
  return name ~= nil and test(name) and name or nil
end

-- The recipe a cell uses when the player has not picked one among several: a researched one
-- first, then one the chosen machine can craft, then the one named like the item -- so gears
-- in an assembler come from plates, not from Space Age's molten-iron casting, which sorts
-- first (.ai-support/analysis/api.md §6). Ties go to the sorted order.
local function default_recipe(force, choices, item, recipes)
  local machine = choices.machine and proto.is_machine(choices.machine) and prototypes.entity[choices.machine]
  local best, best_score
  for _, name in ipairs(recipes) do
    local researched = force.recipes[name] and force.recipes[name].enabled
    local score = (researched and 4 or 0)
      + ((machine and proto.can_craft(machine, prototypes.recipe[name])) and 2 or 0)
      + (name == item and 1 or 0)
    if not best_score or score > best_score then best, best_score = name, score end
  end
  return best
end

-- Every pick resolved to what would actually be placed. Never writes storage: the window
-- writes the entity defaults back itself, so its pickers show them.
function plan.picks(force, choices)
  local r = {}
  if choices.item and prototypes.item[choices.item] then r.item = choices.item end
  r.recipes = r.item and proto.recipes_for_item(r.item) or {}
  if choices.recipe and proto.contains(r.recipes, choices.recipe) then
    r.recipe = choices.recipe
  elseif r.item then
    r.recipe = default_recipe(force, choices, r.item, r.recipes)
  end
  r.recipe_quality = proto.build_quality(choices.recipe_quality)

  local recipe = r.recipe and prototypes.recipe[r.recipe]
  if recipe then
    if choices.machine and proto.contains(proto.machines_for(recipe), choices.machine) then
      r.machine = choices.machine
    else
      r.machine = proto.best_machine(force, recipe)
    end
  else
    r.machine = valid(choices.machine, proto.is_machine)
  end
  r.machine_quality = proto.build_quality(choices.machine_quality)

  -- Only membership here; whether the machine and recipe accept it is build's to explain.
  r.module = valid(choices.module, proto.is_module)
  r.module_quality = proto.build_quality(choices.module_quality)

  r.inserter = valid(choices.inserter, proto.is_inserter) or proto.best_inserter(force)
  r.inserter_quality = proto.build_quality(choices.inserter_quality)
  r.requester = valid(choices.requester, proto.is_requester) or proto.best_chest(force, "requester")
  r.requester_quality = proto.build_quality(choices.requester_quality)
  r.output = valid(choices.output, proto.is_output_chest) or proto.best_chest(force, "output")
  r.output_quality = proto.build_quality(choices.output_quality)
  r.pipe = valid(choices.pipe, proto.is_pipe) or proto.best_pipe(force)

  -- Off until picked: no default beacon and no default pole.
  r.beacon = valid(choices.beacon, proto.is_beacon)
  r.beacon_quality = proto.build_quality(choices.beacon_quality)
  if r.beacon and not choices.no_beacon_module then
    r.beacon_module = valid(choices.beacon_module, proto.is_module)
      or proto.best_module(force, "speed", prototypes.entity[r.beacon])
  end
  r.beacon_module_quality = proto.build_quality(choices.beacon_module_quality)
  r.pole = valid(choices.pole, proto.is_pole)
  r.pole_quality = proto.build_quality(choices.pole_quality)
  return r
end

-- The machine's footprint and rotation: turned so a fluid input faces the pipe row when the
-- recipe takes a fluid; otherwise unrotated, unless it is too narrow for the inserter row and
-- taller than wide (Space Age's 2x3 crusher), when it lies on its side. nil when no rotation
-- puts a fluid input on the row.
local MAX_SLOTS = 3

local function orientation(machine, fluid, pipe)
  local direction = defines.direction.north
  if fluid then
    direction = proto.fluid_rotation(machine, pipe)
    if not direction then return nil end
  elseif machine.tile_width < MAX_SLOTS and machine.tile_height > machine.tile_width
    and machine.supports_direction then
    direction = defines.direction.east
  end
  local w, h = machine.tile_width, machine.tile_height
  if direction == defines.direction.east or direction == defines.direction.west then
    w, h = h, w
  end
  return { direction = direction, w = w, h = h }
end

-- The plain numbers cell.lua's reach rule needs, for the machine at its rotation and a beacon
-- at its quality.
local function machine_geometry(machine, shape)
  return { w = shape.w, h = shape.h, margin = proto.margin(machine) }
end

local function beacon_geometry(beacon, quality)
  return {
    w = beacon.tile_width, h = beacon.tile_height, margin = proto.margin(beacon),
    supply = beacon.get_supply_area_distance(quality),
  }
end

-- How many beacons the chosen machine and beacon can hold, for the window's count drop-downs:
-- { side, above_sided, above_alone }, or nil when there is no beacon or nothing to place it by.
function plan.capacity(force, choices, r)
  r = r or plan.picks(force, choices)
  local recipe = r.recipe and prototypes.recipe[r.recipe]
  local machine = r.machine and prototypes.entity[r.machine]
  local beacon = r.beacon and prototypes.entity[r.beacon]
  if not (recipe and machine and beacon) then return nil end
  local _, fluids = proto.item_ingredients(recipe)
  local shape = orientation(machine, #fluids > 0, r.pipe)
  if not shape then return nil end
  return cell.capacity(machine_geometry(machine, shape), beacon_geometry(beacon, r.beacon_quality), #fluids > 0)
end

-- The counts a capacity allows: the player's own when picked, else as many as fit. The side
-- count decides how wide the row above may be. Returns side, above and above's ceiling.
function plan.beacon_counts(choices, capacity)
  local side = number_or(choices.beacons_side, capacity.side, 0, capacity.side)
  local above_max = side > 0 and capacity.above_sided or capacity.above_alone
  return side, number_or(choices.beacons_above, above_max, 0, above_max), above_max
end

-- Whether an effect reaches the machine at all: the receiver's own allowed_effects gate what
-- modules and beacons hand it (Upcycler Planner api.md §25), and the recipe's gate what it
-- crafts with. A recipe with no table allows everything.
local function applies(machine, recipe, effect)
  local mine, theirs = machine.allowed_effects, recipe.allowed_effects
  return mine ~= nil and mine[effect] == true and (theirs == nil or theirs[effect] == true)
end

local AXES = { "speed", "quality", "productivity" }

-- The cell's summed effects per axis: the machine's own base effect, its modules, and what the
-- beacons transmit. An estimate for the status line and the quality split -- the engine's
-- own clamps are not reproduced.
local function cell_effects(machine, recipe, module_spec, beacon)
  local total = { speed = 0, quality = 0, productivity = 0 }
  local receiver = machine.effect_receiver or {}
  local function add(axis, value)
    if value and value ~= 0 and applies(machine, recipe, axis) then
      total[axis] = total[axis] + value
    end
  end
  for _, axis in ipairs(AXES) do add(axis, receiver.base_effect and receiver.base_effect[axis]) end
  if module_spec and receiver.uses_module_effects ~= false then
    local effects = prototypes.item[module_spec.name].get_module_effects(module_spec.quality) or {}
    for _, axis in ipairs(AXES) do add(axis, (effects[axis] or 0) * module_spec.count) end
  end
  if beacon and beacon.count > 0 and beacon.modules and receiver.uses_beacon_effects ~= false then
    local entity = prototypes.entity[beacon.name]
    local level = prototypes.quality[beacon.quality].level
    local effectivity = (entity.distribution_effectivity or 0)
      + (entity.distribution_effectivity_bonus_per_quality_level or 0) * level
    local effects = prototypes.item[beacon.modules.name].get_module_effects(beacon.modules.quality) or {}
    for _, axis in ipairs(AXES) do
      add(axis, calc.beacon_effect(effects[axis] or 0, beacon.modules.count, beacon.count,
        effectivity, entity.profile))
    end
  end
  total.quality = math.max(total.quality, 0)
  return total
end

-- The amount each item ingredient is requested at, before the player's own overrides: the
-- Ingredient amounts panel shows these as its defaults, and build starts from them. Works
-- from the picks alone, so the panel can open on a plan refused for another reason; without a
-- pace it prices minutes at the machine's bare speed.
function plan.sizing(force, choices, r, crafts_per_minute)
  r = r or plan.picks(force, choices)
  local recipe = r.recipe and prototypes.recipe[r.recipe]
  if not recipe then return {} end
  if not crafts_per_minute then
    local machine = r.machine and prototypes.entity[r.machine]
    local speed = machine and machine.get_crafting_speed(r.machine_quality) or 1
    crafts_per_minute = calc.crafts_per_minute(speed, 0, recipe.energy)
  end
  local field = plan.size_field(choices)
  local rows = {}
  for _, ingredient in ipairs((proto.item_ingredients(recipe))) do
    rows[#rows + 1] = {
      name = ingredient.name,
      default = calc.request_amount(ingredient.amount, field.mode, field.value, crafts_per_minute),
    }
  end
  return rows
end

-- One swing's worth of an item: the hand, capped by the item's stack.
local function load_of(hand, name)
  return math.min(hand, prototypes.item[name].stack_size)
end

-- Swings a craft needs per role (.ai-support/throughput-design.md): every item ingredient in,
-- each swing carrying a load or what its chest holds, whichever is less; every item product
-- out, the better qualities through the quality outputs when the cell splits.
local function swings_per_craft(recipe, items, requests, hand, productivity, quality_share)
  local inputs = 0
  for i, ingredient in ipairs(items) do
    inputs = inputs + ingredient.amount / math.min(load_of(hand, ingredient.name), requests[i].count)
  end
  local products = 0
  for _, product in pairs(recipe.products) do
    if product.type == "item" then
      products = products + calc.expected_count(product, productivity) / load_of(hand, product.name)
    end
  end
  return inputs, products * (1 - quality_share), products * quality_share
end

-- Every power-drawing entity in the cell and its collision margin, for the pole pass.
local function electric_margins(entities)
  local out, seen = {}, {}
  for _, e in pairs(entities) do
    if not seen[e.name] then
      seen[e.name] = true
      local entity = prototypes.entity[e.name]
      if entity and proto.is_electric(entity) then out[e.name] = proto.margin(entity) end
    end
  end
  return out
end

-- Poles over the cell: free tiles first, and only when they leave something dark, more ground
-- -- a column on the right, a row along the top, then both -- each kept only if it powers
-- strictly more, so a tie stays with the smaller cell. The row is what a short-reach pole needs
-- for a full row of beacons above the machine, which no free tile below can reach. Appends the
-- poles to the cell's entities, rebasing each wire onto plan indices. Returns the cell and the
-- unpowered count.
local EXTRA_GROUND = { { column = true }, { row = true }, { column = true, row = true } }

local function power(params, built, pole)
  local margins = electric_margins(built.entities)
  local result = poles.plan(built, pole, margins)
  for _, extra in ipairs(EXTRA_GROUND) do
    if result.unpowered == 0 then break end
    params.pole_column = extra.column and pole.width or nil
    params.pole_row = extra.row and pole.height or nil
    local larger = cell.build(params)
    local attempt = poles.plan(larger, pole, margins)
    if attempt.unpowered < result.unpowered then built, result = larger, attempt end
  end
  local base = #built.entities
  for _, e in ipairs(result.entities) do
    if e.wire_to then e.wire_to = base + e.wire_to end
    built.entities[#built.entities + 1] = e
  end
  return built, result.unpowered
end

local function message(key, ...)
  return { "apl-message." .. key, ... }
end

function plan.build(force, surface, choices)
  local r = plan.picks(force, choices)
  if not r.item then return nil, nil end
  if not r.recipe then return nil, proto.item_refusal(r.item) end

  local recipe = prototypes.recipe[r.recipe]
  local quality = r.recipe_quality
  if quality ~= "normal" and not recipe.can_set_quality then
    return nil, message("no-recipe-quality", prototypes.quality[quality].localised_name)
  end
  if not r.machine then return nil, message("no-machine") end
  local machine = prototypes.entity[r.machine]
  if not proto.can_craft(machine, recipe) then
    return nil, message("machine-cannot-craft", machine.localised_name)
  end

  local items, fluids = proto.item_ingredients(recipe)
  local fluid = #fluids > 0
  if fluid and not r.pipe then return nil, message("no-pipe") end
  local shape = orientation(machine, fluid, r.pipe)
  if not shape then return nil, message("machine-no-fluid-face", machine.localised_name) end

  local module_spec
  local slots = proto.module_slots(machine, r.machine_quality)
  if r.module and slots > 0 then
    if not proto.module_fits(r.module, machine) then
      return nil, message("module-not-accepted", prototypes.item[r.module].localised_name,
        machine.localised_name)
    end
    if not proto.module_fits(r.module, machine, recipe) then
      return nil, message("module-not-accepted-by-recipe", prototypes.item[r.module].localised_name)
    end
    module_spec = { name = r.module, quality = r.module_quality, count = slots }
  end

  local geometry = machine_geometry(machine, shape)
  local beacon_params, beacon_count
  if r.beacon then
    local entity = prototypes.entity[r.beacon]
    local modules
    if r.beacon_module then
      if not proto.module_fits(r.beacon_module, entity) then
        return nil, message("module-not-accepted", prototypes.item[r.beacon_module].localised_name,
          entity.localised_name)
      end
      modules = {
        name = r.beacon_module, quality = r.beacon_module_quality,
        count = proto.module_slots(entity, r.beacon_quality, defines.inventory.beacon_modules),
      }
    end
    beacon_params = beacon_geometry(entity, r.beacon_quality)
    beacon_params.name, beacon_params.quality = r.beacon, r.beacon_quality
    beacon_params.modules, beacon_params.module_inventory = modules, defines.inventory.beacon_modules
    local capacity = cell.capacity(geometry, beacon_params, fluid)
    if capacity.side + capacity.above_alone + capacity.above_sided == 0 then
      return nil, message("beacon-out-of-reach", entity.localised_name)
    end
    beacon_params.side, beacon_params.above = plan.beacon_counts(choices, capacity)
    beacon_count = 2 * beacon_params.side + beacon_params.above
  end

  local effects = cell_effects(machine, recipe, module_spec, beacon_params and {
    name = r.beacon, quality = r.beacon_quality, modules = beacon_params.modules,
    count = beacon_count,
  })

  -- Outputs split by quality automatically whenever anything can roll above the recipe's
  -- quality; the checkbox stores an override only while it disagrees. Nothing to split into
  -- at the top of the chain.
  local higher = proto.next_quality(quality)
  local auto = effects.quality > 0 and higher ~= nil
  local split = higher ~= nil and (choices.split == nil and auto or choices.split == true)

  local roles = {}
  if #items > 0 then roles[#roles + 1] = "input" end
  roles[#roles + 1] = "output"
  if split then roles[#roles + 1] = "quality" end
  if shape.w < #roles then
    return nil, message("machine-too-narrow", machine.localised_name, #roles)
  end

  if not r.inserter then return nil, message("no-inserter") end
  local inserter = prototypes.entity[r.inserter]
  if split and (inserter.filter_count or 0) < 1 then
    return nil, message("inserter-no-filters", inserter.localised_name)
  end
  if #items > 0 and not r.requester then return nil, message("no-requester") end
  if not r.output then return nil, message("no-output-chest") end

  local cap = plan.cap_field(choices, r.item)
  if cap.mode == "network" and inserter.has_flag("no-logistic-connection") then
    return nil, message("no-logistic-connection", inserter.localised_name)
  end

  local crafts_per_minute = calc.crafts_per_minute(machine.get_crafting_speed(r.machine_quality),
    effects.speed, recipe.energy)
  local rows = plan.sizing(force, choices, r, crafts_per_minute)
  local requests = {}
  for i, row in ipairs(rows) do
    requests[i] = {
      name = row.name, quality = quality,
      count = number_or(choices["request_" .. row.name], row.default, 1, calc.INT32_MAX),
    }
  end

  -- As many inserter-and-chest pairs per role as keep up with the machine, the bottom edge's free
  -- tiles and then the sides allowing (.ai-support/throughput-design.md). An arm that cannot
  -- turn has no rate to model, so it keeps one of each.
  local pace = crafts_per_minute / 60
  local hand = proto.inserter_hand(inserter, force)
  local swing = proto.inserter_swing(inserter, r.inserter_quality)
  local researched = force.recipes[r.recipe] and force.recipes[r.recipe].productivity_bonus or 0
  local productivity = math.max(0, math.min(effects.productivity + researched, recipe.maximum_productivity))
  local in_spc, out_spc, quality_spc = swings_per_craft(recipe, items, requests, hand, productivity,
    split and math.min(1, effects.quality) or 0)
  local counts = { #items > 0 and 1 or 0, 1, split and 1 or 0 }
  local rate = pace
  local per_second = swing and 60 / swing
  if per_second then
    local room = shape.w - #roles + 2 * cell.side_room(geometry, beacon_params)
    local result = calc.allocate({
      { spc = in_spc, count = counts[1] }, { spc = out_spc, count = counts[2] },
      { spc = quality_spc, count = counts[3] },
    }, pace, per_second, room)
    counts, rate = result.counts, result.rate
  end

  local slots_list = {}
  local function add_slot(role, extra, slot)
    slot.role, slot.extra = role, extra or nil
    slot.inserter = { name = r.inserter, quality = r.inserter_quality }
    slots_list[#slots_list + 1] = slot
  end
  -- Every input chest carries every ingredient: its share, never less than a load.
  local shares = {}
  for i, request in ipairs(requests) do
    shares[i] = {
      name = request.name, quality = request.quality,
      count = calc.chest_share(request.count, counts[1], load_of(hand, request.name)),
    }
  end
  for k = 1, counts[1] do
    add_slot("input", k > 1, { chest = { name = r.requester, quality = r.requester_quality }, requests = shares })
  end
  -- Every recipe-quality output is capped, or the uncapped one would keep filling: the slot cap
  -- is shared out, the network count held by each inserter.
  local bar = cap.mode == "slots" and calc.cap_share(cap.value, counts[2]) or nil
  local condition
  if cap.mode == "network" then
    condition = {
      connect_to_logistic_network = true,
      logistic_condition = {
        first_signal = { type = "item", name = r.item, quality = quality },
        comparator = "<",
        constant = cap.value,
      },
    }
  end
  -- Nameless quality filters: one slot covers whatever the recipe makes (measured on 2.1.23,
  -- both at normal -- .ai-support/analysis/api.md §2).
  for k = 1, counts[2] do
    add_slot("output", k > 1, {
      chest = { name = r.output, quality = r.output_quality },
      filters = split and { { quality = quality, comparator = "=" } } or nil,
      bar = bar, control_behavior = condition,
    })
  end
  for k = 1, counts[3] do
    add_slot("quality", k > 1, {
      chest = { name = r.output, quality = r.output_quality },
      filters = { { quality = quality, comparator = ">" } },
    })
  end

  local params = {
    machine = {
      name = r.machine, quality = r.machine_quality, w = shape.w, h = shape.h,
      margin = geometry.margin, direction = shape.direction,
      recipe = r.recipe, recipe_quality = quality, modules = module_spec,
    },
    slots = slots_list,
    pipe = fluid and r.pipe or nil,
    beacon = beacon_params,
  }
  local built = cell.build(params)

  local unpowered = 0
  if r.pole then
    local entity = prototypes.entity[r.pole]
    built, unpowered = power(params, built, {
      name = r.pole, quality = r.pole_quality, width = entity.tile_width, height = entity.tile_height,
      supply_distance = entity.get_supply_area_distance(r.pole_quality),
      wire_distance = entity.get_max_wire_distance(r.pole_quality),
    })
  end

  -- Warnings: the plan still places, but the player should know. Spoilage first.
  local warnings = {}
  local function warn(...) warnings[#warnings + 1] = message(...) end
  for _, request in ipairs(requests) do
    if proto.spoils(request.name, quality) then
      warn("item-spoils", prototypes.item[request.name].localised_name)
      break
    end
  end
  if proto.spoils(r.item, quality) then warn("product-spoils", prototypes.item[r.item].localised_name) end
  if surface then
    local property = proto.failed_condition(recipe.surface_conditions, surface)
    if property then warn("recipe-wrong-surface", prototypes.surface_property[property].localised_name) end
    property = proto.failed_condition(machine.surface_conditions, surface)
    if property then
      warn("machine-wrong-surface", machine.localised_name, prototypes.surface_property[property].localised_name)
    end
  end
  if not (force.recipes[r.recipe] and force.recipes[r.recipe].enabled) then warn("recipe-not-researched") end
  if not force.is_quality_unlocked(quality) then
    warn("quality-not-researched", prototypes.quality[quality].localised_name)
  end
  -- One line for every build material placed at a quality not researched yet. Appended one by
  -- one: a list written with `and` would hold nils, and ipairs stops at the first.
  local placed = { r.machine_quality, r.inserter_quality, r.output_quality }
  if #items > 0 then placed[#placed + 1] = r.requester_quality end
  if module_spec then placed[#placed + 1] = r.module_quality end
  if beacon_params then placed[#placed + 1] = r.beacon_quality end
  if beacon_params and beacon_params.modules then placed[#placed + 1] = r.beacon_module_quality end
  if r.pole then placed[#placed + 1] = r.pole_quality end
  for _, q in ipairs(placed) do
    if not force.is_quality_unlocked(q) then
      warn("build-quality-not-researched", prototypes.quality[q].localised_name)
      break
    end
  end
  -- One chest's share against one chest's slots.
  if #items > 0 then
    local stacks = {}
    for i, share in ipairs(shares) do
      stacks[i] = { count = share.count, stack_size = prototypes.item[share.name].stack_size }
    end
    local needed = calc.slots_needed(stacks)
    local have = proto.chest_slots(r.requester, r.requester_quality)
    if needed > have then warn("request-too-big", needed, have) end
  end
  if bar and bar >= proto.chest_slots(r.output, r.output_quality) then
    warn("cap-no-effect")
  end
  -- What still caps the cell once the room is spent. When the inputs bind and a request is
  -- below a load, bigger requests would raise every swing.
  if rate < pace - 1e-9 then
    warn("inserters-limit", calc.format_rate(rate * 60), calc.format_rate(crafts_per_minute))
    local inputs_bind = per_second and counts[1] > 0 and in_spc > 0
      and counts[1] * per_second / in_spc <= rate + 1e-9
    if inputs_bind then
      for _, request in ipairs(requests) do
        if request.count < load_of(hand, request.name) then
          warn("requests-below-load")
          break
        end
      end
    end
  end
  if cap.mode == "network" then warn("network-cap") end
  if split and effects.quality <= 0 then warn("split-nothing-above", prototypes.quality[quality].localised_name) end
  if unpowered > 0 then warn("consumers-unpowered", unpowered) end

  return {
    entities = built.entities, width = built.width, height = built.height,
    product = r.item, product_quality = quality,
    trash_unrequested = plan.trash(choices),
    split = split, split_auto = auto,
    -- The amounts before the player's overrides, priced at this cell's real pace: what the
    -- Ingredient amounts panel shows as each field's default.
    request_rows = rows,
    warnings = warnings,
    -- crafts_per_minute is what the inserters let the machine make; pace_per_minute what the
    -- machine alone could.
    stats = {
      crafts_per_minute = rate * 60, pace_per_minute = crafts_per_minute, quality = effects.quality,
      productivity = effects.productivity, beacons = beacon_count or 0,
    },
  }
end

return plan
