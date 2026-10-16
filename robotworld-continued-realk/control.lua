local quick_start_items = {
  ["inserter"] = 200,
  ["small-electric-pole"] = 200,
  ["electric-mining-drill"] = 24,
  ["stone-furnace"] = 28,
  ["assembling-machine-1"] = 20,
  ["pipe"] = 5,
  ["steam-engine"] = 8,
  ["boiler"] = 4,
  ["offshore-pump"] = 1,
  ["pipe-to-ground"] = 2,
  ["lab"] = 10,
  ["coal"] = 50,
  ["passive-provider-chest"] = 50,
  ["requester-chest"] = 50,
  ["logistic-robot"] = 200,
  ["construction-robot"] = 50,
  ["roboport"] = 10,
}

-- Krastorio 2 boilers make 1.5 MW instead of 1.8 while its labs and drills draw more, which
-- leaves the base kit's steam plant short. Two boilers keep the 1:2 engine ratio.
local krastorio_items = {
  ["boiler"] = 2,
  ["steam-engine"] = 4,
}

local function add_items(items, extra)
  for name, count in pairs(extra) do
    if prototypes.item[name] then
      items[name] = (items[name] or 0) + count
    end
  end
end

-- Freeplay gives its created items to every new player, multiplayer joins included, and
-- handles the crash-site cutscene itself, so adding to that list is all quick start needs.
local function add_quick_start()
  if not settings.startup["rwcr-enable-quick-start"].value then return end
  local freeplay = remote.interfaces["freeplay"]
  if not (freeplay and freeplay.get_created_items and freeplay.set_created_items) then return end

  local items = remote.call("freeplay", "get_created_items") or {}
  add_items(items, quick_start_items)

  if script.active_mods["Krastorio2"] then
    add_items(items, krastorio_items)
    -- K2's labs research with basic tech cards, 5 wood + 5 copper cable for 5. Krastorio 2
    -- Spaced Out hides the card, so ask the recipe rather than naming that mod.
    local cards = prototypes.recipe["kr-basic-tech-card"]
    if cards and not cards.hidden then
      add_items(items, {["wood"] = 100})
    end
  end

  remote.call("freeplay", "set_created_items", items)
end

-- The robotics technologies also make destroyed buildings leave ghosts and enable the
-- "connect to logistic network" button, and early robots skip that research, so the force
-- gets both directly. The game recomputes them from research whenever technology effects are
-- reset, so they are set again after every reset.
local early_robots = settings.startup["rwcr-early-robots"].value ~= "off"

local function enable_robotics(force)
  if force.name ~= "enemy" and force.name ~= "neutral" then
    force.create_ghost_on_entity_death = true
    force.unlock_logistic_network = true
  end
end

local function enable_robotics_everywhere()
  for _, force in pairs(game.forces) do
    enable_robotics(force)
  end
end

script.on_init(function()
  add_quick_start()
  if early_robots then enable_robotics_everywhere() end
end)

if early_robots then
  -- Mod and startup setting changes reset technology effects before this runs.
  script.on_configuration_changed(enable_robotics_everywhere)
  script.on_event({
    defines.events.on_force_created,
    defines.events.on_force_reset,
    defines.events.on_technology_effects_reset,
  }, function(event) enable_robotics(event.force) end)
end

-- Largest pieces first: grid.put packs first-fit, and Krastorio 2 shrinks this armor's grid
-- from 10x10 to 8x8.
local armor_equipment = {
  {"fission-reactor-equipment", 1},
  {"exoskeleton-equipment", 1},
  {"personal-roboport-equipment", 2},
  {"night-vision-equipment", 1},
  {"battery-equipment", 4},
}

-- Equipment that burns fuel gets the plainest fuel it accepts. Krastorio 2's reactor burns
-- uranium fuel cells; five run it for about four and a half hours at full load.
local fuel_count = 5

local function plainest_fuel(burner)
  local plainest
  for category in pairs(burner.fuel_categories) do
    local fuels = prototypes.get_item_filtered({{filter = "fuel-category", ["fuel-category"] = category}})
    for _, fuel in pairs(fuels) do
      if not fuel.hidden and (not plainest or fuel.fuel_value < plainest.fuel_value) then
        plainest = fuel
      end
    end
  end
  return plainest
end

-- Freeplay starts the crash-site cutscene from its own on_player_created, so the character
-- may already be parked in cutscene_character when this runs.
local function give_power_armor(event)
  if not prototypes.item["power-armor-mk2"] then return end
  local player = game.get_player(event.player_index)
  local character = player.character or player.cutscene_character
  if not character then return end

  local inventory = character.get_inventory(defines.inventory.character_armor)
  if not inventory.is_empty() then
    inventory = character.get_main_inventory()
  end
  local stack = inventory.find_empty_stack()
  if not (stack and stack.set_stack({name = "power-armor-mk2"})) then return end

  local grid = stack.grid or stack.create_grid()
  for _, entry in ipairs(armor_equipment) do
    local name, count = entry[1], entry[2]
    if prototypes.equipment[name] then
      for _ = 1, count do
        local equipment = grid.put({name = name})
        local burner = equipment and equipment.burner
        local fuel = burner and plainest_fuel(burner)
        if fuel then
          burner.inventory.insert({name = fuel.name, count = fuel_count})
        end
      end
    end
  end
end

if settings.startup["rwcr-start-with-power-armor"].value then
  script.on_event(defines.events.on_player_created, give_power_armor)
end
