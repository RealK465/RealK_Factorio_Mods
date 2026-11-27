-- The bot loop: the belt ring's per-tier columns with every belt taken out. The player's
-- logistic network is the transport between tiers -- each machine hands its output to the
-- network, each recycler is fed by a chest that requests its tier's item, and the rolled-up
-- ingredients go back to the network for the tier they rolled into. PURE like layout.lua, and
-- the same contract: params in, { entities, width, height, machines, recyclers,
-- utility_columns } out, so the planner, the pole pass, the circuit pass and the serialiser
-- take either layout without knowing which.
--
--     row 0             feed chest           | output chest
--         1             feed inserter        | out inserter
--         2 .. 1+Hm     the crafting machine, pinned to this tier's quality
--     2+Hm .. 1+Hm+Hr   the recycler, tangent under the machine
--       2+Hm+Hr         extract inserter     | return inserter
--       3+Hm+Hr         extract chest        | return chest
--
-- What carries over from the belt ring unchanged, and must stay: the recycler tangent under its
-- machine, throwing recycled ingredients straight in (layout.lua's header has why), and the
-- extract inserter's one nameless "above this tier" filter, without which a rolled-up
-- ingredient wedges the recycler.
--
-- What the network changes. Every lower tier's output chest and every extract chest is an
-- ACTIVE provider -- the player's overflow pick -- because no belt sorts by quality here: bots
-- take each item to whichever chest requests it, and store what nobody requests, which is
-- where a lower tier's lucky finished item and anything above the target go (measured
-- 2026-11-27, analysis/api.md S37: an active provider fills an open request before storage
-- and keeps its items when there is no storage). A passive one would hold those forever and
-- fill. The final machine's output stays the player's passive output chest. The return
-- chest's request is how a tier's own item reaches its recycler at all, so it always
-- requests, and the feed inserters, out inserters and return inserter carry no filter: each
-- chest only ever holds what it requested.
--
-- No ring belt stands, so x starts at 0 and the plan ends one machine past the last column.

local layout = require("scripts.layout")

local layout_bot = {}

local ROW_TOP_CHEST = 0
local ROW_TOP_INSERTER = 1
local ROW_MACHINE = 2

local NORTH = defines.direction.north
local SOUTH = defines.direction.south

local function rows(machine_height, recycler_height)
  local r = {}
  r.recycler = ROW_MACHINE + machine_height
  r.lower_inserter = r.recycler + recycler_height
  r.lower_chest = r.lower_inserter + 1
  r.height = r.lower_chest + 1
  return r
end

-- The planner's beacon-height gate. Every row is free ground for a utility-column occupant
-- here, there being no ring belts to keep clear, so a stack may span the plan's full height.
function layout_bot.max_beacon_count(machine_height, recycler_height, beacon_height)
  return math.floor(rows(machine_height, recycler_height).height / beacon_height)
end

function layout_bot.build(params)
  local machine, recycler = params.machine, params.recycler
  local tiers = params.tiers
  local r = rows(machine.height, recycler.height)
  local gaps, offsets = layout.column_plan(params, 0)
  local width = offsets[#tiers] + machine.width

  local entities = {}
  local function add(entity)
    entities[#entities + 1] = entity
    return entity
  end

  local function inserter(dx, dy, direction, filters)
    return add({
      name = params.inserter.name, quality = params.inserter.quality,
      dx = dx, dy = dy, w = 1, h = 1, direction = direction,
      filters = filters, filter_mode = filters and "whitelist" or nil,
    })
  end

  local function chest(spec, dx, dy, requests)
    return add({
      name = spec.name, quality = spec.quality, dx = dx, dy = dy, w = 1, h = 1,
      requests = requests,
    })
  end

  local utility_columns = {}
  local beacon_modules = params.beacon
    and layout.module_slot(params.modules.beacon_module, params.beacon.module_slots)
  -- One extract filter per quality, shared by that tier's repeated columns -- the belt
  -- builder's cache, safe for its reason: nothing downstream mutates a filters table.
  local extract_filters = {}

  for index, quality in pairs(tiers) do
    local is_terminal = index == #tiers
    local col = offsets[index]
    local col_out = col + machine.width - 1

    if gaps[index] > 0 then
      utility_columns[#utility_columns + 1] = { x = col - gaps[index], width = gaps[index], tier = index }
    end

    -- The pipe run spans every row: there is no ring for its stubs to dive under, so their
    -- undergrounds reach straight out of the plan's top and bottom edges.
    if params.fluid then
      layout.stand_pipe_run(add, params, col - 1, ROW_TOP_CHEST, r.height - 1)
    end

    if params.beacon then
      layout.stand_beacons(add, params, col, not is_terminal and recycler.height or nil,
        ROW_MACHINE, ROW_TOP_CHEST, r.height, beacon_modules)
    end

    add({
      name = machine.name, dx = col, dy = ROW_MACHINE,
      w = machine.width, h = machine.height,
      direction = machine.direction or NORTH,
      quality = machine.quality,
      recipe = params.recipe.name, recipe_quality = quality,
      modules = layout.machine_modules(params, index, is_terminal),
      circuit_role = "machine", circuit_tier = index,
    })

    -- One feed chest for every ingredient: the feed inserter is unfiltered -- the machine
    -- takes only its own recipe at its own quality -- so no filter slot caps the recipe and a
    -- second stack is never needed.
    local requests = {}
    for _, ingredient in pairs(params.recipe.ingredients) do
      requests[#requests + 1] = {
        name = ingredient.name, quality = quality, count = params.requests[ingredient.name],
      }
    end
    local feed = chest(params.requester, col, ROW_TOP_CHEST, requests)
    feed.circuit_role, feed.circuit_tier = "feed", index

    -- Tagged as the circuit spine's relay: when a hop between two machines outruns the wire,
    -- the circuit pass chains them through these instead of the ring a belt plan has. An
    -- unconfigured wired inserter keeps working and reads nothing (analysis/api.md S37).
    local feed_in = inserter(col, ROW_TOP_INSERTER, NORTH)
    feed_in.circuit_role, feed_in.circuit_tier = "relay_in", index
    local out = inserter(col_out, ROW_TOP_INSERTER, SOUTH)
    out.circuit_role, out.circuit_tier = "relay_out", index

    if is_terminal then
      -- The way out: the target tier's whole output lands in the player's passive provider,
      -- which is also the census the circuit pass counts the finished product in.
      local output = chest(params.provider, col_out, ROW_TOP_CHEST)
      output.circuit_role, output.circuit_tier = "census", index

      -- The circuit stack under the terminal machine, combinator first. The band below it is
      -- Hr + 2 rows -- one short of the belt ring's -- so a short recycler wraps the stack
      -- into the column's next tile to the west rather than out of the plan.
      if params.circuit then
        local band = r.height - r.recycler
        for offset, e in ipairs(layout.circuit_stack(params)) do
          local column = math.floor((offset - 1) / band)
          e.dx, e.dy, e.w, e.h = col_out - column, r.recycler + (offset - 1) % band, 1, 1
          add(e)
        end
      end
    else
      -- Everything the machine makes leaves through the network: this tier's product for the
      -- return chest below, a lucky roll for its own tier's return chest, a finished item or
      -- anything above the target for storage.
      chest(params.overflow, col_out, ROW_TOP_CHEST)

      add({
        name = recycler.name, dx = col, dy = r.recycler,
        w = recycler.width, h = recycler.height, direction = recycler.direction,
        quality = recycler.quality,
        modules = layout.module_slot(params.modules.quality_module, recycler.module_slots),
        circuit_role = "recycler", circuit_tier = index,
      })

      -- The return chest asks the network for this tier's product, which is the only way it
      -- reaches the recycler -- and so also how the network's own stock of the item at this
      -- quality is drawn in and upcycled. Also this tier's census, as in the belt ring.
      local stock = chest(params.stock, col + 1, r.lower_chest, params.product_buffer and {
        { name = params.recipe.product, quality = quality, count = params.product_buffer },
      } or nil)
      stock.circuit_role, stock.circuit_tier = "census", index
      local reserve = inserter(col + 1, r.lower_inserter, SOUTH)
      reserve.circuit_role, reserve.circuit_tier = "reserve", index

      extract_filters[quality] = extract_filters[quality] or layout.above_tier_filter(quality)
      inserter(col, r.lower_inserter, NORTH, extract_filters[quality])
      chest(params.overflow, col, r.lower_chest)
    end
  end

  return {
    entities = entities,
    width = width,
    height = r.height,
    machines = #tiers,
    recyclers = #tiers - 1,
    utility_columns = #utility_columns > 0 and utility_columns or nil,
  }
end

return layout_bot
