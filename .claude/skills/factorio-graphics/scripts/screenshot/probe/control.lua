-- Places the requested entities on a real surface and photographs them with
-- the game's own renderer.
--
-- Everything offline compositing cannot answer happens here: render_layer
-- ordering between an entity and its own shadow, apply_module_tint against a
-- real module, draw_as_light against real darkness, and what the sprite looks
-- like on terrain the map generator actually produced. shoot.ps1 stages this
-- mod and writes spec.lua next to it.
--
-- The work is spread over several ticks on purpose. Chunk generation, entity
-- placement and screenshotting each need the previous one to have completed,
-- and a screenshot requested in the same tick as the entity that is meant to
-- be in it photographs empty ground.

-- spec.lua holds JSON, not a Lua table, and it is parsed lazily rather than at
-- chunk load: `helpers` is not guaranteed to exist while control.lua is still
-- being loaded. Going through the engine's own parser also sidesteps
-- PowerShell's habit of unrolling a single-element array, which turned a
-- one-group spec into the group itself the first time this ran.
local spec_json = require("spec")
local spec

local function as_list(v)
  -- a JSON object where a list was meant -- normalise rather than crash
  if v == nil then return {} end
  if v.name or v.label then return { v } end
  return v
end

local function get_spec()
  if not spec then
    spec = helpers.json_to_table(spec_json)
    spec.groups = as_list(spec.groups)
    for _, g in pairs(spec.groups) do
      g.entities = as_list(g.entities)
      if type(g.zooms) == "number" then g.zooms = { g.zooms } end
    end
  end
  return spec
end

local STEP_GENERATE = 2
local STEP_BUILD = 10
local STEP_SHOOT = 20
local STEP_DONE = 40

local log_lines = {}

local function note(fmt, ...)
  local line = string.format(fmt, ...)
  log_lines[#log_lines + 1] = line
  log(line)
end

local function surface()
  return game.surfaces[get_spec().surface or "nauvis"] or game.surfaces[1]
end

local function area_for(group)
  local r = group.radius or 20
  local cx, cy = group.center and group.center[1] or 0, group.center and group.center[2] or 0
  return { { cx - r, cy - r }, { cx + r, cy + r } }
end

local function generate()
  local surf = surface()
  surf.always_day = true
  -- Freeplay's own pollution and enemies would wander into shot.
  game.forces.enemy.kill_all_units()
  surf.peaceful_mode = true
  for _, group in pairs(get_spec().groups) do
    surf.request_to_generate_chunks(group.center or { 0, 0 }, math.ceil((group.radius or 20) / 32) + 1)
  end
  surf.force_generate_chunk_requests()
  note("generated chunks for %d group(s)", #get_spec().groups)
end

local function clear(group)
  local surf = surface()
  local area = area_for(group)
  for _, e in pairs(surf.find_entities_filtered { area = area }) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  if group.tile then
    local tiles = {}
    local r = group.radius or 20
    local cx, cy = group.center and group.center[1] or 0, group.center and group.center[2] or 0
    for x = cx - r, cx + r do
      for y = cy - r, cy + r do
        tiles[#tiles + 1] = { name = group.tile, position = { x, y } }
      end
    end
    surf.set_tiles(tiles)
  end
end

local function build(group)
  local surf = surface()
  clear(group)
  for _, spawn in pairs(group.entities or {}) do
    local ok, entity = pcall(function()
      return surf.create_entity {
        name = spawn.name,
        position = { spawn.x or 0, spawn.y or 0 },
        direction = spawn.direction and defines.direction[spawn.direction] or nil,
        force = "player",
        raise_built = false,
      }
    end)
    if not ok or not entity then
      note("FAILED to place %s at %s,%s: %s", spawn.name, spawn.x or 0, spawn.y or 0,
           tostring(entity))
    else
      -- Module tint, working lights and animation states only exist on a
      -- powered, loaded machine -- which is the entire reason for shooting in
      -- the engine rather than compositing the sprites offline.
      if spawn.module then
        local inv = entity.get_module_inventory()
        if inv then
          for _ = 1, (spawn.module_count or #inv) do inv.insert(spawn.module) end
        end
      end
      if spawn.recipe and entity.type == "assembling-machine" then
        pcall(function() entity.set_recipe(spawn.recipe) end)
      end
      -- LuaEntity.minable is read-only in 2.1; nothing here needs it anyway,
      -- the run lasts a couple of hundred ticks with no player in it.
      entity.destructible = false
      note("placed %s at %s,%s", spawn.name, spawn.x or 0, spawn.y or 0)
    end
  end
  -- Electric machines need real power or they render their idle state. An
  -- electric-energy-interface is the cheapest infinite source that does not
  -- itself appear in shot when placed outside the framing.
  if group.power ~= false then
    local px = (group.center and group.center[1] or 0)
    local py = (group.center and group.center[2] or 0) - (group.radius or 20) + 2
    local src = surf.create_entity {
      name = "electric-energy-interface", position = { px, py }, force = "player",
    }
    if src then
      src.power_production = 5000000000
      src.electric_buffer_size = 5000000000
      src.energy = 5000000000
      local pole = surf.create_entity {
        name = "big-electric-pole", position = { px + 2, py }, force = "player",
      }
      if pole then pole.destructible = false end
      src.destructible = false
    end
  end
end

local function shoot(group)
  local surf = surface()
  for _, zoom in pairs(group.zooms or { 1 }) do
    for _, alt in pairs(group.alt_mode and { false, true } or { false }) do
      local name = string.format("%s-z%s%s.png", group.label, tostring(zoom),
                                 alt and "-alt" or "")
      game.take_screenshot {
        surface = surf,
        position = group.center or { 0, 0 },
        resolution = group.resolution or { 1200, 900 },
        zoom = zoom,
        path = name,
        show_gui = false,
        show_entity_info = alt,
        anti_alias = true,       -- renders at double resolution and downscales
        daytime = 0,             -- noon: no night tint confusing a colour check
        hide_clouds = true,
        hide_fog = true,
        water_tick = 0,
        allow_in_replay = true,
      }
      note("shot %s", name)
    end
  end
end

script.on_event(defines.events.on_tick, function(event)
  local t = event.tick
  if t == STEP_GENERATE then
    generate()
  elseif t == STEP_BUILD then
    for _, group in pairs(get_spec().groups) do build(group) end
  elseif t == STEP_SHOOT then
    for _, group in pairs(get_spec().groups) do shoot(group) end
    game.set_wait_for_screenshots_to_finish()
  elseif t == STEP_DONE then
    helpers.write_file("gfx-probe.log", table.concat(log_lines, "\n") .. "\n", false)
  end
end)
