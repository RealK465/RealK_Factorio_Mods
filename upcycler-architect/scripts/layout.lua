-- Turns a set of choices into a list of entities to place. PURE: it reads no storage, touches
-- no game state and has no side effects, so the same choices always produce the same plan on
-- every client. That is what makes it desync-safe without any ceremony, and it means the
-- geometry can be reasoned about without a running game.
--
-- The layout is one rectangular belt ring with a column of machinery per quality tier:
--
--     row 0             top ring, flows west
--         1             harvest inserters   | product belt rising to the ring
--         2             feed chests         | product belt / output chest on the last tier
--         3             feed inserters      | out inserters
--         4 .. 3+Hm     the crafting machine, pinned to this tier's quality
--     4+Hm .. 3+Hm+Hr   the recycler, tangent under the machine
--       4+Hm+Hr         extract inserter    | recycler-feed inserter
--       5+Hm+Hr         extract chest       | product buffer chest
--       6+Hm+Hr         unload inserter     | product-fill inserter
--       7+Hm+Hr         bottom ring, flows east
--
-- Two things here are load-bearing and easy to break by tidying:
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
  local width = 2 + (#tiers - 1) * pitch + machine.width
  local height = r.height

  local entities = {}
  local function add(entity)
    entities[#entities + 1] = entity
  end

  local function belt(dx, dy, direction)
    add({ name = params.belt, dx = dx, dy = dy, w = 1, h = 1, direction = direction })
  end

  local function inserter(dx, dy, direction, filters, filter_mode)
    add({
      name = params.inserter, dx = dx, dy = dy, w = 1, h = 1, direction = direction,
      filters = filters, filter_mode = filter_mode,
    })
  end

  local function chest(name, dx, dy, requests)
    add({ name = name, dx = dx, dy = dy, w = 1, h = 1, requests = requests })
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
  for y = 1, r.bottom_ring - 1 do
    belt(0, y, SOUTH)
    belt(width - 1, y, NORTH)
  end

  local ingredient_names = {}
  for _, ingredient in pairs(params.recipe.ingredients) do
    ingredient_names[#ingredient_names + 1] = ingredient.name
  end

  for index, quality in pairs(tiers) do
    local is_terminal = index == #tiers
    local col = 1 + (index - 1) * pitch
    local col_feed = col
    local col_buffer = col + 1
    local col_product = col + machine.width - 1
    -- Shared by the harvest inserter (whitelist) and the extract inserter (blacklist).
    local ingredient_filters = quality_filters(ingredient_names, quality)

    -- Quality modules have nothing left to roll into once the ingredients already are the
    -- target quality, so the last machine crafts for yield instead -- and gets nothing at all
    -- when the recipe refuses productivity, which the planner signals with a nil. Written as an
    -- if rather than `is_terminal and terminal or quality`, because that idiom silently falls
    -- through to the quality module on exactly the nil this has to respect.
    local machine_module = params.modules.quality_module
    if is_terminal then machine_module = params.modules.terminal_module end

    add({
      name = machine.name, dx = col, dy = ROW_MACHINE,
      w = machine.width, h = machine.height, direction = NORTH,
      -- Two unrelated qualities on one entity: `quality` is the machine's own, the thing the
      -- player picked; `recipe_quality` is the tier this column is pinned to craft at.
      quality = machine.quality,
      recipe = params.recipe.name, recipe_quality = quality,
      modules = {
        name = machine_module,
        quality = params.modules.quality,
        count = machine.module_slots,
      },
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
      -- AND above it. Nothing else consumes an above-target roll (every machine is pinned and
      -- matches exactly), so without those filters it would circulate on the ring forever.
      chest(params.provider, col_product, ROW_FEED_CHEST)
      local catcher_filters = { { name = params.recipe.product, quality = quality } }
      for _, above in pairs(params.above_target or {}) do
        catcher_filters[#catcher_filters + 1] = { name = params.recipe.product, quality = above }
      end
      inserter(col_product, ROW_HARVEST, NORTH, catcher_filters, "whitelist")
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
        modules = {
          name = params.modules.quality_module,
          quality = params.modules.quality,
          count = recycler.module_slots,
        },
      })

      -- Product: off the ring into a buffer, then into the recycler. The buffer is what lets
      -- the recycler keep working while the ring is busy with other tiers.
      --
      -- It requests the product as well as catching it off the belt, so bots can top it up
      -- when the ring is slow. On the first tier that also means the player's own production
      -- of the item feeds the loop, which is how an upcycler is normally fed; the higher tiers
      -- cannot pull from the base at all, because the engine forces every request to name an
      -- exact quality.
      inserter(col_buffer, r.unload_inserter, SOUTH,
        { { name = params.recipe.product, quality = quality } }, "whitelist")
      chest(params.requester, col_buffer, r.lower_chest, {
        { name = params.recipe.product, quality = quality, count = params.product_buffer },
      })
      inserter(col_buffer, r.lower_inserter, SOUTH)

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
  }
end

return layout
