-- Turns a set of choices into a list of entities to place. PURE: it reads no storage, touches
-- no game state and has no side effects, so the same choices always produce the same plan on
-- every client. That is what makes it desync-safe without any ceremony, and it means the
-- geometry can be reasoned about without a running game.
--
-- The layout is one rectangular belt ring with a column of machinery per quality tier, and an
-- optional utility column before each of them sized to what lives in THAT one -- a pole, the
-- pipe run when the recipe takes a fluid, and the beacon when the player asked for one. The
-- sizes arrive per tier, so a plan pays width only where something stands. NOTHING is ever
-- placed outside the ring: the ring rectangle IS the plan's footprint, and the fluid network
-- reaches the outside world only as underground stubs beneath the ring belts.
--
--     row 0             top ring, flows west
--         1             harvest inserters   | product belt | north pipe stub (fluid plans)
--         2             feed chests         | product belt / output chest on the last tier
--         3             feed inserters      | out inserters
--         4 .. 3+Hm     the crafting machine, pinned to this tier's quality
--     4+Hm .. 3+Hm+Hr   the recycler, tangent under the machine
--       4+Hm+Hr         extract inserter    | recycler-feed inserter
--       5+Hm+Hr         extract chest       | product buffer chest / overflow chest, last tier
--       6+Hm+Hr         unload inserter     | product-fill inserter | south pipe stub
--                                             overflow tap on the last tier: the unload
--                                             inserter's tile, facing the belt instead of away
--       7+Hm+Hr         bottom ring, flows east
--
-- Three things here are load-bearing and easy to break by tidying:
--
-- The recycler MUST stay tangent under its machine. It throws its output out of one face
-- (vector_to_place_result), which is what delivers recycled ingredients into the crafter with
-- no inserter at all -- and which face depends on the prototype, so the planner hands this
-- file a ROTATED footprint and the direction that makes the throw land in the machine above.
-- Put a gap between them and the loop silently stops working.
--
-- The machine is pinned to one quality tier and quality ingredients match EXACTLY, so an
-- ingredient the recycler rolled up a tier would jam the eject. The extract inserter carries a
-- BLACKLIST of this tier's ingredients for that reason: it drains everything the eject cannot
-- deliver, and nothing else. A whitelist there would race the eject for the items it is
-- supposed to be passing through.
--
-- The pipe run must stay on the utility column's EAST edge, touching the machine's west face.
-- The planner rotates each machine so a fluid input connection points west (measured rule,
-- analysis/api.md §14), and the run spans the full interior height so the connection lands on
-- it whatever row the prototype puts it at. Its two ends are pipe-to-ground stubs whose
-- surface openings face INTO the run and whose undergrounds reach out beneath the ring belts:
-- the player supplies fluid by standing a matching underground pipe outside, north or south,
-- and wires the columns together however their base likes. No interior row can carry a
-- horizontal header instead -- every row between the rings is part of an inserter reach-chain.
--
-- The ring is a plain rectangle rather than the underground-threaded loop the shared
-- blueprints use. A dedicated return column costs one tile of width and buys us no underground
-- belts at all -- at this height the span beneath a machine would exceed even a turbo belt.

local layout = {}

-- Derived facts of the column arithmetic below, exported so the planner's gates cannot drift
-- from the geometry: a tier column needs its feed, buffer and product sub-columns distinct
-- (machine width 3), and the recycler-feed inserter drops into the recycler's second column
-- (recycler width 2). Reshuffling the columns means re-deriving both.
layout.MIN_MACHINE_WIDTH = 3
layout.MIN_RECYCLER_WIDTH = 2

local ROW_TOP_RING = 0
local ROW_HARVEST = 1
local ROW_FEED_CHEST = 2
local ROW_INSERTERS = 3
local ROW_MACHINE = 4

local NORTH = defines.direction.north
local EAST = defines.direction.east
local SOUTH = defines.direction.south
local WEST = defines.direction.west

-- An inserter's direction is the side it PICKS UP from; it drops on the opposite side.
-- (Vanilla pickup_position is {0,-1} and insert_position {0,1.2}.) Every inserter below is
-- commented with what it moves rather than which way it faces, because the direction alone
-- reads backwards.

local function rows(machine_height, recycler_height)
  local r = {}
  r.recycler = ROW_MACHINE + machine_height
  r.lower_inserter = r.recycler + recycler_height
  r.lower_chest = r.lower_inserter + 1
  r.unload_inserter = r.lower_chest + 1
  r.bottom_ring = r.unload_inserter + 1
  r.height = r.bottom_ring + 1
  return r
end

-- The rows a utility-column occupant may stand in: harvest row through unload row, everything
-- between the ring belts. Exported so the planner's beacon-height gate cannot drift from the
-- row arithmetic above.
function layout.interior_height(machine_height, recycler_height)
  local r = rows(machine_height, recycler_height)
  return r.unload_inserter - ROW_HARVEST + 1
end

-- How many beacons of this height a tier's column can stack between the ring belts. Zero is
-- a real answer -- a lone beacon already overruns the interior -- and is exactly the
-- beacon-too-tall refusal, so validate reads it from here rather than keeping its own
-- comparison. Every caller caps the planned count at this, which is what lets build below
-- clamp the stack as one block without ever having to truncate it.
function layout.max_beacon_count(machine_height, recycler_height, beacon_height)
  return math.floor(layout.interior_height(machine_height, recycler_height) / beacon_height)
end

-- Where a tier's beacons stand, relative to the tier column's start and the machine's top
-- row: flush against the column (west of the pipe run when there is one), the stack of
-- `count` centred as one block on the machine+recycler band -- recycler_height is nil on the
-- terminal tier, whose band is the machine alone. Centring is what makes the supply squares
-- -- each collision box grown by the supply distance on every side (measured,
-- tests/beacon_spec.lua) -- overlap both footprints. Exported for planner.beacon_reach,
-- interior_height's own reason: the out-of-reach warning must not drift from the built
-- positions. The interior-row clamp for an over-band stack stays in build below, which owns
-- the row plan; reasoning from the unclamped centring is safe, since a stack tall enough to
-- clamp overlaps strictly more than its centred stand-in.
function layout.beacon_offsets(machine_height, recycler_height, beacon, fluid, count)
  count = count or 1
  local band = machine_height + (recycler_height or 0)
  local dx = -(fluid and 1 or 0) - beacon.width
  local top = math.floor((band - count * beacon.height) / 2)
  local offsets = {}
  for i = 1, count do
    offsets[i] = { dx = dx, dy = top + (i - 1) * beacon.height }
  end
  return offsets
end

local function quality_filters(names, quality)
  local filters = {}
  for _, name in pairs(names) do
    filters[#filters + 1] = { name = name, quality = quality }
  end
  return filters
end

function layout.build(params)
  local machine, recycler = params.machine, params.recycler
  local tiers = params.tiers
  local r = rows(machine.height, recycler.height)

  -- Column pitch fits whichever of the pair is wider: a recycler wider than its machine (Age
  -- of Production's 4-wide salvager under a 3-wide assembler) just gets dead columns beside
  -- the machine. The last column carries no recycler, so it only needs the machine.
  local pitch = math.max(machine.width, recycler.width)
  -- The utility columns: `column_gaps[i]` empty columns standing before tier column i, sized by
  -- the planner to what lives in THAT one -- the pole's width where a pole goes, plus one for
  -- the pipe run when the recipe takes a fluid. Per tier rather than one uniform width, so a
  -- plan pays only where something stands; all zero collapses them and leaves the plan
  -- byte-identical to the pre-utility-column layout.
  local gaps, offsets = {}, {}
  -- The floor no caller may collapse a column below: the pipe run needs its tile on a fluid
  -- plan, and a beacon plan stands one beacon in every column, so the column is at least the
  -- beacon wide -- plus the pipe's tile, since the run keeps the east edge and the beacon
  -- stands west of it. Clamped here rather than in the planner so no caller can take away the
  -- ground either is standing on. Zero when neither applies, and the plan stays byte-identical
  -- to the beaconless one.
  local gap_floor = (params.fluid and 1 or 0) + (params.beacon and params.beacon.width or 0)
  local next_col = 1
  for index = 1, #tiers do
    local gap = params.column_gaps and params.column_gaps[index] or 0
    if gap < gap_floor then gap = gap_floor end
    gaps[index] = gap
    offsets[index] = next_col + gap
    next_col = next_col + gap + pitch
  end
  -- The last tier carries no recycler, so the plan ends one machine past its column, plus the
  -- right ring belt.
  local width = offsets[#tiers] + machine.width + 1
  local height = r.height

  local entities = {}
  -- Returns the entity so a call site can tag what it just placed -- the circuit pass finds
  -- its entities by those tags, and an assignment at the site beats an open-ended merge
  -- parameter on every helper.
  local function add(entity)
    entities[#entities + 1] = entity
    return entity
  end

  local function belt(dx, dy, direction)
    return add({ name = params.belt, dx = dx, dy = dy, w = 1, h = 1, direction = direction })
  end

  -- The inserter and the chests arrive as { name, quality } pairs -- the machine and the recycler
  -- already do, and the player picks a quality for each. The belt and the pipe stay bare names:
  -- they are the engine's own quality exceptions, so there is nothing to carry.
  local function inserter(dx, dy, direction, filters, filter_mode)
    return add({
      name = params.inserter.name, quality = params.inserter.quality,
      dx = dx, dy = dy, w = 1, h = 1, direction = direction,
      filters = filters, filter_mode = filter_mode,
    })
  end

  -- A module arrives as a { name, quality } pair too, or nil for "leave this machine empty" --
  -- which the terminal machine gets whenever nothing useful can go in it. The entity keeps the
  -- flat shape the serialiser reads, so a nil pair becomes a nil name rather than a missing table.
  local function module_slot(spec, count)
    return { name = spec and spec.name, quality = spec and spec.quality, count = count }
  end

  -- A lower tier's machine under the split: `prod_count` productivity modules, quality in the
  -- rest. The flat single-spec shape survives whenever the tier is homogeneous -- so every
  -- plan without a genuine mix, the recyclers and the beacons included, reads exactly as it
  -- always did, and only a mixed tier carries the array the serialiser fans out into two
  -- insert plans (quality first, so its stacks come first).
  local function split_modules(mods, prod_count, slots)
    local p = math.min(prod_count or 0, slots or 0)
    if p <= 0 or not mods.productivity_module then
      return module_slot(mods.quality_module, slots)
    end
    if p >= (slots or 0) then
      return module_slot(mods.productivity_module, slots)
    end
    return {
      module_slot(mods.quality_module, slots - p),
      module_slot(mods.productivity_module, p),
    }
  end

  local function chest(spec, dx, dy, requests)
    return add({
      name = spec.name, quality = spec.quality, dx = dx, dy = dy, w = 1, h = 1,
      requests = requests,
    })
  end

  local function pipe(dx, dy)
    add({ name = params.fluid.pipe, dx = dx, dy = dy, w = 1, h = 1 })
  end

  local function pipe_to_ground(dx, dy, direction)
    add({
      name = params.fluid.pipe_to_ground, dx = dx, dy = dy, w = 1, h = 1,
      direction = direction,
    })
  end

  -- The ring. Corners carry the turn: the belt at a corner faces where the items go next.
  belt(0, ROW_TOP_RING, SOUTH)
  belt(width - 1, ROW_TOP_RING, WEST)
  belt(0, r.bottom_ring, EAST)
  belt(width - 1, r.bottom_ring, NORTH)
  for x = 1, width - 2 do
    belt(x, ROW_TOP_RING, WEST)
    belt(x, r.bottom_ring, EAST)
  end
  for y = ROW_TOP_RING + 1, r.bottom_ring - 1 do
    belt(0, y, SOUTH)
    belt(width - 1, y, NORTH)
  end
  -- Everything built so far is the perimeter ring -- the per-tier product belts below stay
  -- untagged. The circuit pass rides the top row as its wire relay on a plan too wide for
  -- direct hops; a structural fact recorded like utility_columns, not circuit knowledge.
  for _, e in pairs(entities) do e.circuit_role = "ring" end

  local ingredient_names = {}
  for _, ingredient in pairs(params.recipe.ingredients) do
    ingredient_names[#ingredient_names + 1] = ingredient.name
  end

  -- The utility columns that actually opened, reported so the pole pass can prefer them
  -- without re-deriving the column arithmetic. A tier whose gap is zero contributes nothing,
  -- which is why each entry names its own tier.
  local utility_columns = {}

  -- Tier-invariant, hoisted: every tier's beacon carries the same insert plan, and a long
  -- modded chain would otherwise build this table hundreds of times across the pole ladder's
  -- attempts. Nothing downstream mutates a modules table, so sharing one is safe.
  local beacon_modules = params.beacon
    and module_slot(params.modules.beacon_module, params.beacon.module_slots)

  for index, quality in pairs(tiers) do
    local is_terminal = index == #tiers
    local col = offsets[index]
    local gap = gaps[index]
    local col_feed = col
    local col_buffer = col + 1
    local col_product = col + machine.width - 1
    -- Shared by the harvest inserter (whitelist) and the extract inserter (blacklist).
    local ingredient_filters = quality_filters(ingredient_names, quality)

    if gap > 0 then
      -- `tier` is what lets the planner collapse the one column a pole did not stand in
      -- without counting entries against tiers that opened no column at all.
      utility_columns[#utility_columns + 1] = { x = col - gap, width = gap, tier = index }
    end

    -- The pipe run: full interior height on the utility column's east edge, an underground
    -- stub at each end. The stubs' surface openings face INTO the run (south at the top,
    -- north at the bottom), so their undergrounds extend OUTWARD beneath the ring belts --
    -- the player's own matching pipe-to-ground, stood outside within reach, is the tap.
    -- Nothing of the plan crosses the ring.
    if params.fluid then
      local col_pipe = col - 1
      pipe_to_ground(col_pipe, ROW_HARVEST, SOUTH)
      for y = ROW_FEED_CHEST, r.unload_inserter - 1 do
        pipe(col_pipe, y)
      end
      pipe_to_ground(col_pipe, r.unload_inserter, NORTH)
    end

    -- The tier's beacon stack, at beacon_offsets' shared positions, clamped to the interior
    -- rows as one rigid block -- shifting the whole stack keeps it contiguous, where clamping
    -- each beacon alone would pile them onto one row. A stack taller than the band cannot
    -- poke into the ring belts; one taller than the whole interior never arrives, because
    -- every caller caps the count at max_beacon_count and validate refuses the count-of-one
    -- remainder of that case.
    if params.beacon then
      local count = params.beacon_count or 1
      local stack = layout.beacon_offsets(machine.height,
        not is_terminal and recycler.height or nil, params.beacon, params.fluid ~= nil, count)
      local top = ROW_MACHINE + stack[1].dy
      local stack_height = count * params.beacon.height
      local shift = math.max(ROW_HARVEST,
        math.min(top, r.unload_inserter + 1 - stack_height)) - top
      for i = 1, count do
        add({
          name = params.beacon.name, quality = params.beacon.quality,
          dx = col + stack[i].dx, dy = ROW_MACHINE + stack[i].dy + shift,
          w = params.beacon.width, h = params.beacon.height,
          -- Which inventory the module insert plan targets. Resolved by the planner -- this
          -- file runs on the host interpreter too, where defines.inventory does not exist.
          module_inventory = params.beacon.module_inventory,
          modules = beacon_modules,
        })
      end
    end

    -- Quality modules have nothing left to roll into once the ingredients already are the
    -- target quality, so the last machine crafts for yield instead -- and gets nothing at all
    -- when the recipe refuses productivity, which the planner signals with a nil. Written as an
    -- if rather than `is_terminal and terminal or quality`, because that idiom silently falls
    -- through to the quality module on exactly the nil this has to respect. A lower tier's
    -- machine follows the split -- its computed-or-overridden productivity count -- through
    -- split_modules above.
    local machine_modules
    if is_terminal then
      machine_modules = module_slot(params.modules.terminal_module, machine.module_slots)
    else
      machine_modules = split_modules(params.modules,
        params.modules.split and params.modules.split[index], machine.module_slots)
    end

    add({
      name = machine.name, dx = col, dy = ROW_MACHINE,
      w = machine.width, h = machine.height,
      -- North unless the planner rotated the machine so its fluid input faces the pipe run.
      direction = machine.direction or NORTH,
      -- Two unrelated qualities on one entity: `quality` is the machine's own, the thing the
      -- player picked; `recipe_quality` is the tier this column is pinned to craft at.
      quality = machine.quality,
      recipe = params.recipe.name, recipe_quality = quality,
      modules = machine_modules,
      -- circuit_role/circuit_tier: structural tags the circuit pass finds entities by
      -- (scripts/circuits.lua). Written unconditionally -- they cost nothing when circuits
      -- are off, and the serialiser reads only the fields it names.
      circuit_role = "machine", circuit_tier = index,
    })

    -- Ingredients at this tier come off the ring into the feed chest, then into the machine.
    -- The chest also carries a logistic request, which is what seeds the loop from the
    -- player's own base; on the upper tiers it is a top-up that will usually go unfilled.
    inserter(col_feed, ROW_HARVEST, NORTH, ingredient_filters, "whitelist")

    local requests = {}
    for _, ingredient in pairs(params.recipe.ingredients) do
      requests[#requests + 1] = {
        name = ingredient.name, quality = quality, count = params.requests[ingredient.name],
      }
    end
    chest(params.requester, col_feed, ROW_FEED_CHEST, requests)

    inserter(col_feed, ROW_INSERTERS, NORTH)

    -- Everything the machine makes leaves unfiltered: this tier's product and any lucky roll
    -- above it.
    inserter(col_product, ROW_INSERTERS, SOUTH)

    if is_terminal then
      -- The last tier is the way out. Its machine crafts from ingredients already at the
      -- target quality, so its whole output is target quality; the catcher above collects
      -- product that lower tiers rolled by luck and put on the ring -- at the target quality
      -- AND above it, which is the whole of what ">=" says. It used to be one filter per tier
      -- above the target, clamped to the inserter's five slots, so a long modded quality chain
      -- silently lost its top tiers; one comparator is exact and cannot be outrun.
      -- The census chest of the target tier: the circuit pass counts the finished product
      -- here, so the target's threshold is the loop's off switch.
      local output = chest(params.provider, col_product, ROW_FEED_CHEST)
      output.circuit_role, output.circuit_tier = "census", index
      inserter(col_product, ROW_HARVEST, NORTH,
        { { name = params.recipe.product, quality = quality, comparator = ">=" } }, "whitelist")

      -- The overflow tap: everything the loop rolled ABOVE the target leaves the ring here.
      -- Both the machines and the recyclers can overshoot, and nothing consumes an above-target
      -- roll -- so without this it laps the ring forever and eventually saturates it.
      --
      -- ONE filter does it, naming a quality and no item at all, so the cost does not grow with
      -- the ingredient count and anything unexpected is caught too. The chest is an ACTIVE
      -- provider on purpose: bots empty it, where a plain chest would fill and put the ring back
      -- where it started a few hours later.
      --
      -- It stands in the two tiles the terminal column has spare -- no recycler here, so no
      -- extract stack -- and is exactly the unload inserter every other column carries, reversed:
      -- same tile, facing the belt instead of away from it. So the footprint does not change.
      if params.overflow_tap then
        inserter(col_feed, r.unload_inserter, SOUTH,
          { { quality = quality, comparator = ">" } }, "whitelist")
        chest(params.overflow, col_feed, r.lower_chest)
      end
    else
      -- Product rides up to the top ring, round, and down to this tier's own recycler.
      belt(col_product, ROW_FEED_CHEST, NORTH)
      belt(col_product, ROW_HARVEST, NORTH)

      add({
        name = recycler.name, dx = col_feed, dy = r.recycler,
        -- Width, height and direction arrive pre-rotated from the planner so the eject face
        -- points at the machine -- vanilla's recycler throws north as authored, Age of
        -- Production's salvager has to stand facing west to do the same.
        w = recycler.width, h = recycler.height, direction = recycler.direction,
        quality = recycler.quality,
        -- A recycler cannot take productivity modules at all; quality is the whole point here.
        modules = module_slot(params.modules.quality_module, recycler.module_slots),
        circuit_role = "recycler", circuit_tier = index,
      })

      -- Product: off the ring into the stock chest, then into the recycler. The chest is what
      -- lets the recycler keep working while the ring is busy with other tiers.
      --
      -- It requests the product as well as catching it off the belt, so bots can top it up
      -- when the ring is slow. On the first tier that also means the player's own production
      -- of the item feeds the loop, which is how an upcycler is normally fed; the higher tiers
      -- cannot pull from the base at all, because the engine forces every request to name an
      -- exact quality. Which KIND the planner hands over is the player's checkbox: a buffer
      -- chest shares the tier's items with the base, a requester chest keeps them in.
      inserter(col_buffer, r.unload_inserter, SOUTH,
        { { name = params.recipe.product, quality = quality } }, "whitelist")
      -- Also this tier's census chest: it is where the tier's product settles, so its count
      -- is what the reserve below and the cap on the machines read.
      local buffer = chest(params.stock, col_buffer, r.lower_chest, {
        { name = params.recipe.product, quality = quality, count = params.product_buffer },
      })
      buffer.circuit_role, buffer.circuit_tier = "census", index
      -- The reserve point: gating THIS inserter is what keeps a tier's floor in the chest --
      -- the recycler only ever eats what the inserter hands it.
      local reserve = inserter(col_buffer, r.lower_inserter, SOUTH)
      reserve.circuit_role, reserve.circuit_tier = "reserve", index

      -- Ingredients the recycler rolled ABOVE this tier: the machine above would reject them
      -- and stall the eject, so they are pulled out and put back on the ring for a higher
      -- tier to harvest. Blacklisting this tier's ingredients is what leaves the eject alone.
      inserter(col_feed, r.lower_inserter, NORTH, ingredient_filters, "blacklist")
      chest(params.container, col_feed, r.lower_chest)
      inserter(col_feed, r.unload_inserter, NORTH)
    end
  end

  -- One machine per tier; every tier but the last also gets a recycler.
  return {
    entities = entities,
    width = width,
    height = height,
    machines = #tiers,
    recyclers = #tiers - 1,
    utility_columns = #utility_columns > 0 and utility_columns or nil,
  }
end

return layout
