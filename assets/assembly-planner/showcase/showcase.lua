-- Showcase scene for Assembly Planner's portal images. showcase.ps1 stages it into a scratch copy
-- of the mod; it is never shipped. Builds rows of real cells from the planner's own plans on
-- refined concrete, powers and feeds them, lets them run, takes alt-mode screenshots, then opens
-- the planner window for one more, and writes a marker the driver waits for.
--
-- Rows are spaced so no close-up catches a neighbouring row: a medium pole's sprite stands 3.34
-- tiles above its position, so a row whose poles sit on its top tile reaches 2.84 above it.
-- Power comes in from the east, along a pole trunk at x = 18.5 that every close-up leaves out.

local plan = require("scripts.plan")
local blueprint = require("scripts.blueprint")
local gui = require("scripts.gui")
local state = require("scripts.state")

local OUT = "apl-shots/"
-- Everything the scene touches: cleared of trees and rocks, searched for poles and chests.
local AREA = { { -40, 0 }, { 40, 52 } }
-- The refined-concrete pad the cells stand on.
local PAD = { { -26, 4 }, { 26, 49 } }

local function say(text)
  helpers.write_file(OUT .. "log.txt", text .. "\n", true)
end

local function prepare(surface, force)
  surface.always_day = true
  force.research_all_technologies()
  surface.request_to_generate_chunks({ 0, 26 }, 3)
  surface.force_generate_chunk_requests()
  for _, e in pairs(surface.find_entities_filtered({ area = AREA })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  surface.destroy_decoratives({ area = PAD })
  local tiles = {}
  for x = PAD[1][1], PAD[2][1] - 1 do
    for y = PAD[1][2], PAD[2][2] - 1 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
end

-- Stamps one cell with its top-left at x, y, revives it, and delivers its modules the way bots
-- would.
local function stamp(surface, force, choices, x, y)
  local p, message = plan.build(force, surface, choices)
  if not p then
    say("REFUSED " .. choices.item .. ": " .. serpent.line(message))
    return nil
  end
  local inventory = game.create_inventory(1)
  inventory.insert({ name = "blueprint", count = 1 })
  local stack = inventory[1]
  stack.set_blueprint_entities(blueprint.entities(p))
  local ghosts = stack.build_blueprint({
    surface = surface, force = force, position = { x + p.width / 2, y + p.height / 2 },
    build_mode = defines.build_mode.superforced,
  })
  inventory.destroy()
  local revived = 0
  local cell_poles = {}
  for _, ghost in pairs(ghosts) do
    if ghost.valid then
      local _, entity, proxy = ghost.revive({ return_item_request_proxy = true })
      if entity then revived = revived + 1 end
      if entity and entity.type == "electric-pole" then cell_poles[#cell_poles + 1] = entity end
      if proxy and proxy.valid then
        local target = proxy.proxy_target
        local modules = target and target.get_module_inventory()
        for _, entry in pairs(proxy.insert_plan or {}) do
          if modules then
            modules.insert({ name = entry.id.name, quality = entry.id.quality or "normal",
              count = #entry.items.in_inventory })
          end
        end
        proxy.destroy()
      end
    end
  end
  say(string.format("cell %s at %d,%d: %dx%d, %d of %d revived, %d poles", choices.item, x, y,
    p.width, p.height, revived, #p.entities, #cell_poles))
  for _, warning in ipairs(p.warnings) do say("  warning " .. serpent.line(warning)) end
  return p, cell_poles
end

local COPPER = defines.wire_connector_id.pole_copper

local function distance(a, b)
  local dx, dy = a.position.x - b.position.x, a.position.y - b.position.y
  return math.sqrt(dx * dx + dy * dy)
end

local function join(a, b)
  a.get_wire_connector(COPPER, true).connect_to(b.get_wire_connector(COPPER, true))
end

-- Joins two poles, standing bridge poles halfway along while they are out of reach. A bridge
-- goes only on a free tile next to the halfway point; when there is none, whatever this call
-- placed is removed and it returns false, so the caller can try another pair.
local function link(surface, force, a, b)
  local reach = a.prototype.get_max_wire_distance("normal")
  local placed = {}
  while distance(a, b) > reach and #placed < 6 do
    local mid = { (a.position.x + b.position.x) / 2, (a.position.y + b.position.y) / 2 }
    local spot = surface.find_non_colliding_position("medium-electric-pole", mid, 1, 0.5, true)
    -- auto_connect defaults to true: a created pole would wire itself to every pole in reach.
    local bridge = spot and surface.create_entity({ name = "medium-electric-pole", position = spot,
      force = force, auto_connect = false })
    if not bridge then
      for _, pole in ipairs(placed) do pole.destroy() end
      return false
    end
    placed[#placed + 1] = bridge
    join(a, bridge)
    a = bridge
  end
  join(a, b)
  for _, pole in ipairs(placed) do
    say(string.format("bridge pole at %.1f,%.1f", pole.position.x, pole.position.y))
  end
  return true
end

-- Links two pole groups through their shortest pair that can be bridged on free ground; ties go
-- to the higher pair, which on a beaconed cell is the free pole row along its top.
local function link_groups(surface, force, list_a, list_b)
  local candidates = {}
  for _, a in ipairs(list_a) do
    for _, b in ipairs(list_b) do
      candidates[#candidates + 1] = { a = a, b = b, d = distance(a, b), y = a.position.y + b.position.y }
    end
  end
  table.sort(candidates, function(p, q)
    if math.abs(p.d - q.d) > 1e-6 then return p.d < q.d end
    return p.y < q.y
  end)
  for _, c in ipairs(candidates) do
    if link(surface, force, c.a, c.b) then return end
  end
  say("could not link two pole groups")
end

-- Prim's tree over one cell's poles: each joins its nearest already-joined one. The plan placed
-- them connected within reach, so no edge here is longer than one the plan itself relied on.
local function tree(list)
  local joined, left = { list[1] }, {}
  for i = 2, #list do left[#left + 1] = list[i] end
  while #left > 0 do
    local best_i, best_from, best_d
    for i, pole in ipairs(left) do
      for _, from in ipairs(joined) do
        local d = distance(pole, from)
        if not best_d or d < best_d then best_i, best_from, best_d = i, from, d end
      end
    end
    local pole = table.remove(left, best_i)
    join(pole, best_from)
    joined[#joined + 1] = pole
  end
end

-- Tidy copper, the way a careful player would string it: every wire the revived cells made on
-- their own is cut, then a tree inside each cell, one wire between neighbouring cells, one from
-- each row out to the trunk, and the runs out to the west roboport and to the power source.
local function wire(surface, force, rows, around)
  for _, pole in pairs(surface.find_entities_filtered({ area = AREA, type = "electric-pole" })) do
    pole.get_wire_connector(COPPER, true).disconnect_all()
  end
  for i = 2, #around.trunk do link(surface, force, around.trunk[i - 1], around.trunk[i]) end
  for _, row in ipairs(rows) do
    local previous
    local all = {}
    for _, cell_poles in ipairs(row) do
      if #cell_poles > 0 then
        tree(cell_poles)
        if previous then link_groups(surface, force, previous, cell_poles) end
        previous = cell_poles
        for _, pole in ipairs(cell_poles) do all[#all + 1] = pole end
      end
    end
    if #all > 0 then link_groups(surface, force, all, around.trunk) end
  end
  local first = {}
  for _, cell_poles in ipairs(rows[1]) do
    for _, pole in ipairs(cell_poles) do first[#first + 1] = pole end
  end
  for _, run in ipairs({ { from = first, poles = around.west }, { from = around.trunk, poles = around.east } }) do
    link_groups(surface, force, run.from, { run.poles[1] })
    for i = 2, #run.poles do link(surface, force, run.poles[i - 1], run.poles[i]) end
  end
end

-- Every requester gets what it asks for, so the machines run without bots.
local function feed(surface)
  for _, chest in pairs(surface.find_entities_filtered({ area = AREA, type = "logistic-container" })) do
    if chest.prototype.logistic_mode == "requester" then
      local sections = chest.get_logistic_sections()
      local section = sections and sections.get_section(1)
      for i = 1, section and section.filters_count or 0 do
        local slot = section.get_slot(i)
        local value = slot.value
        if value and value.name then
          local quality = type(value.quality) == "string" and value.quality
            or (value.quality and value.quality.name) or "normal"
          chest.insert({ name = value.name, quality = quality, count = math.max(1, math.min(slot.min or 1, 200)) })
        end
      end
    end
  end
end

-- What a base around the cells would have: a roboport on each side for the logistic network,
-- the trunk bringing power down the east side, a short run out to the west roboport, and the
-- power source east of every frame, overview included.
local function surroundings(surface, force)
  local function create(spec)
    spec.force = force
    local entity = surface.create_entity(spec)
    if not entity then say("could not place " .. spec.name .. " at " .. serpent.line(spec.position)) end
    return entity
  end
  local function poles(spots)
    local out = {}
    for _, at in ipairs(spots) do
      out[#out + 1] = create({ name = "medium-electric-pole", position = at, auto_connect = false })
    end
    return out
  end
  create({ name = "roboport", position = { -23, 27 } })
  create({ name = "roboport", position = { 23, 27 } })
  create({ name = "electric-energy-interface", position = { 36, 34 } })
  return {
    trunk = poles({ { 18.5, 11.5 }, { 18.5, 17.5 }, { 18.5, 25.5 }, { 18.5, 33.5 }, { 18.5, 41.5 } }),
    west = poles({ { -14.5, 12.5 }, { -21.5, 16.5 }, { -22.5, 24.5 } }),
    east = poles({ { 26.5, 33.5 }, { 34.5, 33.5 } }),
  }
end

local function build(surface, force)
  prepare(surface, force)
  local base = { machine = "assembling-machine-3", inserter = "bulk-inserter", pole = "medium-electric-pole" }
  local function with(extra)
    local c = {}
    for k, v in pairs(base) do c[k] = v end
    for k, v in pairs(extra) do c[k] = v end
    return c
  end
  local rows = {}

  -- One row of cells side by side from x, each cell's poles kept for the wiring.
  local function row(x, y, list)
    local cells = {}
    for _, choices in ipairs(list) do
      local p, cell_poles = stamp(surface, force, choices, x, y)
      if p then
        x = x + p.width
        cells[#cells + 1] = cell_poles
      end
    end
    rows[#rows + 1] = cells
  end

  -- A plain mall row: speed modules, one capped output chest each.
  local plain = {}
  for _, item in ipairs({ "transport-belt", "fast-inserter", "electric-mining-drill",
    "assembling-machine-2", "medium-electric-pole", "solar-panel" }) do
    plain[#plain + 1] = with({ item = item, module = "speed-module-3" })
  end
  row(-9, 8, plain)

  -- Quality cells: quality modules, so the outputs split into two chests.
  local quality = {}
  for _, item in ipairs({ "fast-inserter", "bulk-inserter", "assembling-machine-3", "substation" }) do
    quality[#quality + 1] = with({ item = item, module = "quality-module-3", module_quality = "legendary" })
  end
  row(-8, 17, quality)

  -- Electromagnetic plants with beacons beside and above, as many as fit.
  local beaconed = {}
  for _, item in ipairs({ "accumulator", "electronic-circuit", "advanced-circuit" }) do
    beaconed[#beaconed + 1] = with({ item = item, machine = "electromagnetic-plant",
      module = "speed-module-3", beacon = "beacon" })
  end
  row(-15, 26, beaconed)

  -- Fluid cells side by side, one pipe line fed from a lubricant tank at the west end.
  local fluid = {}
  for _ = 1, 3 do fluid[#fluid + 1] = with({ item = "electric-engine-unit" }) end
  row(-4, 39, fluid)
  local tank = surface.create_entity({ name = "storage-tank", position = { -5.5, 38.5 }, force = force })
  if tank then tank.insert_fluid({ name = "lubricant", amount = 20000 }) end

  wire(surface, force, rows, surroundings(surface, force))
  feed(surface)
end

-- Each frame is the row's own extent plus half a tile, measured from the sprites: an AM3 draws
-- 0.37 above its top, a requester chest 0.05 below its tile, a storage tank 2.06 above the row.
local SHOTS = {
  { name = "02-mall-row", position = { 0, 10.3 }, zoom = 2, resolution = { 1920, 480 } },
  { name = "03-quality-cells", position = { 0, 18.1 }, zoom = 2.5, resolution = { 1920, 704 } },
  { name = "04-beacon-cells", position = { 0, 29.6 }, zoom = 1.75, resolution = { 1920, 768 } },
  { name = "05-fluid-cells", position = { -1, 41 }, zoom = 2.5, resolution = { 1600, 720 } },
  { name = "06-mall-overview", position = { 0, 26.3 }, zoom = 1, resolution = { 1920, 1280 } },
}

local start
script.on_event(defines.events.on_tick, function(event)
  local player = game.connected_players[1]
  if not player then return end
  local surface = game.surfaces["nauvis"]
  if not start then
    start = event.tick
    build(surface, player.force)
    say("built at tick " .. event.tick)
    return
  end
  local t = event.tick - start
  if t == 900 then
    for _, shot in ipairs(SHOTS) do
      game.take_screenshot({
        surface = surface, position = shot.position, zoom = shot.zoom,
        resolution = shot.resolution, show_entity_info = true, daytime = 0,
        path = OUT .. shot.name .. ".jpg", quality = 92,
      })
    end
    say("world shots at tick " .. event.tick)
  elseif t == 920 then
    player.teleport({ 0, 2 })
    player.game_view_settings.show_research_info = false
    local choices = state.of(player.index).choices
    for k in pairs(choices) do choices[k] = nil end
    for k, v in pairs({
      item = "fast-inserter", machine = "assembling-machine-3", machine_quality = "rare",
      module = "quality-module-3", module_quality = "legendary", inserter = "bulk-inserter",
      beacon = "beacon", beacon_module = "speed-module-3", beacons_side = 1, beacons_above = 3,
      pole = "medium-electric-pole",
    }) do choices[k] = v end
    -- A production chain, balanced: the circuits made beside the inserters, and the cable beside
    -- those, each at the count the planner works out for them (green in the window).
    state.of(player.index).cells = {
      ["electronic-circuit"] = { on = true, machine = "assembling-machine-3", module = "productivity-module-3",
        count = 3 },
      ["copper-cable"] = { on = true, machine = "assembling-machine-3", module = "productivity-module-3",
        count = 4 },
    }
    gui.open(player)
  elseif t == 960 then
    -- Low enough that the window hides the electronic circuit cell's one dark inserter, whose
    -- no-power icon blinks (the plan warns about it).
    game.take_screenshot({
      player = player, position = { 0, 28.5 }, zoom = 1, resolution = { 1920, 1080 },
      show_gui = true, show_entity_info = true, daytime = 0,
      path = OUT .. "01-planner-window.jpg", quality = 92,
    })
    say("gui shot at tick " .. event.tick)
  elseif t == 990 then
    game.set_wait_for_screenshots_to_finish()
  elseif t == 1020 then
    helpers.write_file(OUT .. "done.txt", "done")
  end
end)
