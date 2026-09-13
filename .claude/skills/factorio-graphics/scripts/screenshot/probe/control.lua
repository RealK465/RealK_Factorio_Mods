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
local STEP_SHOOT = 60
-- the log is written 20 ticks after the last shot; see on_tick

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
  -- A crafting machine only WORKS if its recipe is unlocked, and a fresh map
  -- has researched nothing: a recycler fed processing units sat idle with the
  -- output arrow drawn and the working-only layers absent, photographed 2026-09-11
  -- as "working" until a tick sequence showed the rotor never moved. Research
  -- everything before placing anything.
  game.forces.player.research_all_technologies()
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
      -- A crafting machine only shows its WORKING state -- animation frame,
      -- working_visualisations, additive glow -- with something to craft, and
      -- a furnace picks its recipe from whatever is inserted. Recycling runs at
      -- a sixteenth of the original craft time, so use a slow item and plenty
      -- of it or the machine is idle again before the screenshot tick.
      if spawn.insert then
        local ok2, err = pcall(function()
          return entity.insert { name = spawn.insert, count = spawn.insert_count or 50 }
        end)
        if not ok2 then
          note("insert %s into %s FAILED: %s", spawn.insert, spawn.name, tostring(err))
        else
          note("inserted %s x%d into %s", spawn.insert, spawn.insert_count or 50, spawn.name)
        end
      end
      -- A recipe with several ingredients, or a fluid one, needs more than
      -- one `insert`: `inserts` is a list of {name, count} and `fluids` a
      -- list of {name, amount} put straight into the machine's fluid box, so
      -- a slow fluid recipe (processing units: 10 s) keeps a machine working
      -- for the whole run without a pump and a tank beside it.
      for _, item in pairs(spawn.inserts or {}) do
        local ok2, err = pcall(function()
          return entity.insert { name = item.name, count = item.count or 50 }
        end)
        if not ok2 then
          note("insert %s into %s FAILED: %s", item.name, spawn.name, tostring(err))
        else
          note("inserted %s x%d into %s", item.name, item.count or 50, spawn.name)
        end
      end
      for _, fluid in pairs(spawn.fluids or {}) do
        local ok2, got = pcall(function()
          return entity.insert_fluid { name = fluid.name, amount = fluid.amount or 1000 }
        end)
        if not ok2 then
          note("insert fluid %s into %s FAILED: %s", fluid.name, spawn.name, tostring(got))
        else
          note("inserted fluid %s x%s into %s", fluid.name, tostring(got), spawn.name)
        end
      end
      -- A belt in a composed scene should carry something: `belt_items` is a
      -- list of {name, count} put on every lane of this belt at the build
      -- tick, so inserters downstream have work and the line reads as live.
      if spawn.belt_items and entity.type == "transport-belt" then
        for li = 1, entity.get_max_transport_line_index() do
          local line = entity.get_transport_line(li)
          for _, item in pairs(spawn.belt_items) do
            for _ = 1, (item.count or 1) do
              pcall(function() line.insert_at_back({ name = item.name, count = 1 }) end)
            end
          end
        end
      end
      -- `use_mirroring` entities have a second set of art the player reaches
      -- with the flip key; a spec entity with `mirror = true` photographs it.
      if spawn.mirror then
        local ok3, err3 = pcall(function() entity.mirroring = true end)
        if not ok3 then note("mirror %s FAILED: %s", spawn.name, tostring(err3)) end
      end
      -- LuaEntity.minable is read-only in 2.1; nothing here needs it anyway,
      -- the run lasts a couple of hundred ticks with no player in it.
      entity.destructible = false
      -- Say where the engine actually put it and on what grid: create_entity
      -- snaps a building to its tile grid, so a spec position off that grid
      -- lands somewhere else, and a 4x4 asked for at x.5 reports x.0 here.
      local proto = entity.prototype
      note("placed %s at %s,%s -> engine position %s,%s (grid %dx%d)", spawn.name,
           spawn.x or 0, spawn.y or 0, entity.position.x, entity.position.y,
           proto.tile_width, proto.tile_height)
    end
  end
  -- Electric machines need real power or they render their idle state. An
  -- electric-energy-interface is the cheapest infinite source that does not
  -- itself appear in shot when placed outside the framing.
  --
  -- The source alone is not enough: a big pole SUPPLIES only a 4x4 area, so
  -- one pole beside the source 24 tiles away powered nothing, and every
  -- machine this probe photographed before 2026-09-11 reported `no_power`
  -- while looking plausibly idle. A substation at the group's centre supplies
  -- 18x18 -- the whole rig -- and a relay big pole halfway out carries the
  -- wire from the source, whose distance exceeds the substation's own reach.
  if group.power ~= false then
    local cx = (group.center and group.center[1] or 0)
    local cy = (group.center and group.center[2] or 0)
    local py = cy - (group.radius or 20) + 2
    local src = surf.create_entity {
      name = "electric-energy-interface", position = { cx, py }, force = "player",
    }
    if src then
      src.power_production = 5000000000
      src.electric_buffer_size = 5000000000
      src.energy = 5000000000
      src.destructible = false
    end
    for _, spec_e in pairs({
        { name = "big-electric-pole", position = { cx + 2, py } },
        { name = "big-electric-pole", position = { cx, cy - 10 } },
        { name = "substation", position = { cx, cy } } }) do
      local pole = surf.create_entity {
        name = spec_e.name, position = spec_e.position, force = "player",
      }
      if pole then pole.destructible = false
      else note("FAILED to place %s", spec_e.name) end
    end
  end
end

local function shoot(group, tick_tag)
  local surf = surface()
  -- Say what state each machine is actually in when it is photographed, so a
  -- shot of an idle machine is never mistaken for a shot of a working one.
  for _, e in pairs(surf.find_entities_filtered {
      area = area_for(group), type = { "furnace", "assembling-machine" } }) do
    local name = "?"
    for k, v in pairs(defines.entity_status) do
      if v == e.status then name = k end
    end
    note("%s at %s,%s: status %s", e.name, e.position.x, e.position.y, name)
  end
  -- What every belt in the group carries, per lane: the item count and the
  -- largest stack on it. A picture cannot tell a stack of four from a single
  -- item, and whether a crafting machine's direct output stacks on a belt is
  -- not something the prototype API says -- so a group with `belt_report`
  -- measures it.
  if group.belt_report then
    for _, b in pairs(surf.find_entities_filtered {
        area = area_for(group), type = { "transport-belt" } }) do
      for li = 1, b.get_max_transport_line_index() do
        local line = b.get_transport_line(li)
        local biggest, total = 0, 0
        for _, d in pairs(line.get_detailed_contents()) do
          total = total + d.stack.count
          if d.stack.count > biggest then biggest = d.stack.count end
        end
        if total > 0 then
          note("belt at %s,%s lane %d: %d items, largest stack %d",
               b.position.x, b.position.y, li, total, biggest)
        end
      end
    end
  end
  -- A group with `report = true` says what the engine actually makes of each
  -- crafting machine in it -- the numbers a prototype only promises: crafting
  -- speed with modules, the quality / productivity / speed / consumption
  -- effects in force, what the module inventory holds, the energy buffer --
  -- plus, for every spec entity carrying `fast_replace_over = "<name>"`,
  -- whether the engine would fast-replace that name at its position; and
  -- for `report_tech` / `report_recipe` lists, what the force sees of them.
  if group.report then
    for _, e in pairs(surf.find_entities_filtered {
        area = area_for(group), type = { "furnace", "assembling-machine" } }) do
      local fx = e.effects or {}
      local inv = e.get_module_inventory()
      local mods = {}
      if inv then
        for _, item in pairs(inv.get_contents()) do mods[#mods + 1] = string.format("%s x%d", item.name, item.count) end
      end
      note("REPORT %s at %s,%s: recipe %s | crafting_speed %.3f | effects quality %.4f productivity %.4f speed %.4f consumption %.4f pollution %.4f | productivity_bonus %.4f speed_bonus %.4f | modules [%s] slots %d | buffer %s J",
           e.name, e.position.x, e.position.y,
           e.get_recipe() and e.get_recipe().name or "-", e.crafting_speed,
           fx.quality or 0, fx.productivity or 0, fx.speed or 0, fx.consumption or 0, fx.pollution or 0,
           e.productivity_bonus or 0, e.speed_bonus or 0, table.concat(mods, ", "), inv and #inv or 0,
           tostring(e.electric_buffer_size))
    end
    for _, spawn in pairs(group.entities or {}) do
      if spawn.fast_replace_over then
        local ok = surf.can_fast_replace {
          name = spawn.fast_replace_over, position = { spawn.x or 0, spawn.y or 0 },
          direction = defines.direction.north, force = "player" }
        note("REPORT fast_replace %s over %s at %s,%s: %s", spawn.fast_replace_over, spawn.name,
             spawn.x or 0, spawn.y or 0, tostring(ok))
      end
    end
    local force = game.forces.player
    for _, tname in pairs(group.report_tech or {}) do
      local t = force.technologies[tname]
      if not t then note("REPORT tech %s: MISSING", tname)
      else
        local pre = {}
        for pname in pairs(t.prerequisites) do pre[#pre + 1] = pname end
        local ing = {}
        for _, i in pairs(t.research_unit_ingredients) do ing[#ing + 1] = i.name end
        note("REPORT tech %s: researched %s | units %d x %ss | packs [%s] | prerequisites [%s] | unlocks %d effects",
             tname, tostring(t.researched), t.research_unit_count, tostring(t.research_unit_energy / 60),
             table.concat(ing, ", "), table.concat(pre, ", "), #t.prototype.effects)
      end
    end
    for _, rname in pairs(group.report_recipe or {}) do
      local r = force.recipes[rname]
      if not r then note("REPORT recipe %s: MISSING", rname)
      else
        local ing = {}
        for _, i in pairs(r.ingredients) do ing[#ing + 1] = string.format("%s x%s", i.name, tostring(i.amount)) end
        -- `categories`, plural: 2.1 gave a recipe several, and `category` is gone
        note("REPORT recipe %s: enabled %s | energy %ss | categories %s | ingredients [%s]",
             rname, tostring(r.enabled), tostring(r.energy), table.concat(r.categories, "/"), table.concat(ing, ", "))
      end
    end
  end
  -- A group with `factoriopedia = "<prototype name>"` opens that entity's
  -- Factoriopedia page for the first player and shoots the screen WITH the
  -- GUI: the stats card a mod portal gallery wants, straight from the game.
  -- Needs a player in the run; a benchmark without one says so and skips.
  if group.factoriopedia then
    local p = game.connected_players[1] or game.players[1]
    local proto = prototypes.entity[group.factoriopedia] or prototypes.item[group.factoriopedia]
    if not p then
      note("factoriopedia %s: no player in this run, no GUI to shoot", group.factoriopedia)
    elseif not proto then
      note("factoriopedia %s: no such entity or item", group.factoriopedia)
    else
      local ok, err = pcall(function() p.open_factoriopedia_gui(proto) end)
      if not ok then note("factoriopedia open FAILED: %s", tostring(err)) end
      local name = string.format("%s-factoriopedia%s.png", group.label, tick_tag or "")
      game.take_screenshot {
        player = p, show_gui = true, path = name, anti_alias = true,
        resolution = group.resolution and { group.resolution[1], group.resolution[2] } or nil,
      }
      note("shot %s (gui)", name)
    end
  end
  -- Night is not cosmetic here: draw_as_light and blend_mode "additive" only
  -- resolve in the light pass, so a layer that glows after dark is invisible
  -- at noon and cannot be checked offline at all. A group asking for several
  -- daytimes shoots each one.
  local times = group.daytimes or { group.daytime or 0 }
  for _, zoom in pairs(group.zooms or { 1 }) do
    for _, dt in pairs(times) do
    for _, alt in pairs(group.alt_mode and { false, true } or { false }) do
      local suffix = (dt ~= 0) and string.format("-d%s", tostring(dt)) or ""
      local name = string.format("%s-z%s%s%s%s.png", group.label, tostring(zoom),
                                 suffix, alt and "-alt" or "", tick_tag or "")
      game.take_screenshot {
        surface = surf,
        position = group.center or { 0, 0 },
        resolution = group.resolution or { 1200, 900 },
        zoom = zoom,
        path = name,
        show_gui = false,
        show_entity_info = alt,
        anti_alias = true,       -- renders at double resolution and downscales
        daytime = dt,            -- 0 = noon; 0.5 = midnight, for light layers
        hide_clouds = true,
        hide_fog = true,
        water_tick = 0,
        allow_in_replay = true,
      }
      note("shot %s", name)
    end
    end
  end
end

-- A working loop cannot be judged from one frame. A group may carry
-- `shoot_ticks`, a list of tick offsets AFTER the build tick; each is shot
-- separately with a `-t<offset>` tag. At animation_speed 2 a 64-frame loop is
-- 32 ticks, so offsets 4 apart sample it 8 frames apart.
local function shoot_offsets(group)
  local list = group.shoot_ticks
  if list == nil then return { STEP_SHOOT - STEP_BUILD } end
  if type(list) == "number" then return { list } end
  return list
end

script.on_event(defines.events.on_tick, function(event)
  local t = event.tick
  if t == STEP_GENERATE then
    generate()
  elseif t == STEP_BUILD then
    for _, group in pairs(get_spec().groups) do build(group) end
  elseif t > STEP_BUILD then
    local last = STEP_SHOOT
    for _, group in pairs(get_spec().groups) do
      for _, off in pairs(shoot_offsets(group)) do
        local at = STEP_BUILD + off
        if at > last then last = at end
        if t == at then
          shoot(group, group.shoot_ticks and string.format("-t%d", off) or nil)
          game.set_wait_for_screenshots_to_finish()
        end
      end
    end
    if t == last + 20 then
      helpers.write_file("gfx-probe.log", table.concat(log_lines, "\n") .. "\n", false)
    end
  end
end)
