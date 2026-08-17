-- builder.place on real ground: ghosts created and read back, the all-or-nothing check, the
-- deconstruction-mark rollback, and surface routing. This is the H4/H5/H9 "placed and read
-- back" harness work made permanent. Everything runs at full research on the lab world.

local planner = require("scripts.planner")
local builder = require("scripts.builder")
local research = require("tests.support.research")

local ANCHOR = { x = 0, y = 0 }

local function force()
  return game.forces.player
end

local function nauvis()
  return game.surfaces["nauvis"]
end

local function gear_plan(overrides)
  local choices = {
    recipe = "iron-gear-wheel", quality = "rare",
    machine = "assembling-machine-3", recycler = "recycler",
    pole = "medium-electric-pole",
  }
  for key, value in pairs(overrides or {}) do choices[key] = value end
  local plan = planner.plan(force(), choices)
  assert(plan, "plan failed in test setup")
  return plan
end

local function place(plan, surface)
  return builder.place(plan, ANCHOR, { surface = surface or nauvis(), force = force() })
end

local function ghosts_on(surface)
  return surface.find_entities_filtered({ name = "entity-ghost" })
end

local function ghosts_of(surface, inner_name)
  local out = {}
  for _, ghost in pairs(ghosts_on(surface)) do
    if ghost.ghost_name == inner_name then out[#out + 1] = ghost end
  end
  return out
end

local function wipe(surface)
  for _, entity in pairs(surface.find_entities_filtered({})) do
    entity.destroy()
  end
end

describe("builder.place", function()
  before_all(function() research.full(force()) end)
  after_each(function() wipe(nauvis()) end)

  test("a full plan lands: one ghost per planned entity", function()
    local plan = gear_plan()
    local placed = place(plan)
    assert(placed == #plan.entities,
      "placed " .. tostring(placed) .. " of " .. #plan.entities)
    assert(#ghosts_on(nauvis()) == placed, "ghost count differs from placed count")
  end)

  test("machine ghosts carry recipe, pinned quality, build quality and an insert plan", function()
    place(gear_plan({ machine_quality = "uncommon" }))
    local machines = ghosts_of(nauvis(), "assembling-machine-3")
    assert(#machines == 3, "machine ghost count " .. #machines)
    local pinned = {}
    for _, ghost in pairs(machines) do
      -- The ghost itself is built at the player's chosen build quality; the recipe quality is
      -- the tier the column is pinned to. Two unrelated qualities on one entity (fact 2).
      assert(ghost.quality.name == "uncommon", "ghost built at " .. ghost.quality.name)
      local recipe, quality = ghost.get_recipe()
      assert(recipe and recipe.name == "iron-gear-wheel", "ghost recipe missing")
      if quality then pinned[quality.name] = true end
      local plan_entries = ghost.insert_plan
      assert(#plan_entries == 1, "insert plan entries " .. #plan_entries)
      assert(plan_entries[1].id.name == "productivity-module-3"
        or plan_entries[1].id.name == "quality-module-3",
        "unexpected module " .. tostring(plan_entries[1].id.name))
    end
    for _, tier in pairs({ "normal", "uncommon", "rare" }) do
      assert(pinned[tier], "no machine pinned to " .. tier)
    end
  end)

  test("the blacklist inserter and the requester survive the ghost round-trip", function()
    local plan = gear_plan()
    place(plan)

    local inserter_name
    for _, e in pairs(plan.entities) do
      if e.filter_mode == "blacklist" then inserter_name = e.name end
    end
    assert(inserter_name, "plan lost its blacklist inserter")
    local blacklists = 0
    for _, ghost in pairs(ghosts_of(nauvis(), inserter_name)) do
      if ghost.inserter_filter_mode == "blacklist" then
        blacklists = blacklists + 1
        local filter = ghost.get_filter(1)
        -- get_filter hands the name back as a plain string.
        assert(filter and filter.name == "iron-plate",
          "blacklist filter reads back as " .. tostring(filter and filter.name))
      end
    end
    assert(blacklists == 2, "blacklist inserters " .. blacklists .. ", expected one per lower tier")

    -- Requests go through the logistic point; a non-zero min is quality-exact by engine rule.
    local requested = false
    for _, ghost in pairs(ghosts_of(nauvis(), "requester-chest")) do
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      assert(point, "requester ghost has no logistic point")
      assert(point.trash_not_requested == true, "trash default did not reach the ghost")
      local slot = point.sections[1] and point.sections[1].get_slot(1)
      if slot and slot.value and slot.value.name == "iron-plate" then
        assert(slot.min == 100, "iron-plate request min " .. tostring(slot.min))
        requested = true
      end
    end
    assert(requested, "no requester ghost carries the iron-plate request")
  end)

  test("unticking the trash checkbox reaches every requester ghost", function()
    place(gear_plan({ trash_unrequested = false }))
    for _, ghost in pairs(ghosts_of(nauvis(), "requester-chest")) do
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      assert(point.trash_not_requested == false, "unticked trash flag lost on the way down")
    end
  end)

  test("pole ghosts come wired into one connected network", function()
    -- The exact edge count is the engine's business, not ours: since 2.0 wires are
    -- first-class content and ghost poles preview their own auto-connections on top of the
    -- spanning tree the builder draws. The contract worth pinning is that every pole ends up
    -- in ONE network -- an unwired island is the failure poles.lua's honesty rule exists for.
    place(gear_plan())
    local poles = ghosts_of(nauvis(), "medium-electric-pole")
    assert(#poles == 3, "pole ghost count " .. #poles)

    local index_of = {}
    for i, ghost in pairs(poles) do index_of[ghost.unit_number] = i end
    local visited, stack = { [1] = true }, { 1 }
    while #stack > 0 do
      local ghost = poles[stack[#stack]]
      stack[#stack] = nil
      local connector = ghost.get_wire_connector(defines.wire_connector_id.pole_copper, false)
      for _, connection in pairs(connector and connector.connections or {}) do
        local other = index_of[connection.target.owner.unit_number]
        if other and not visited[other] then
          visited[other] = true
          stack[#stack + 1] = other
        end
      end
    end
    local reached = 0
    for _ in pairs(visited) do reached = reached + 1 end
    assert(reached == #poles, "only " .. reached .. " of " .. #poles .. " poles share the network")
  end)

  test("a fluid plan's pipes land as ordinary ghosts with their directions", function()
    -- Pipes carry no recipe, modules, filters or requests, so the builder needs no new code
    -- for them -- this pins that a fluid plan places completely and the crossing pair reads
    -- back with the facings the underground hop depends on.
    local choices = {
      recipe = "battery", quality = "rare",
      machine = "chemical-plant", recycler = "recycler",
      pole = "medium-electric-pole",
    }
    local plan = planner.plan(force(), choices)
    assert(plan, "battery plan failed in test setup")
    local placed = place(plan)
    assert(placed == #plan.entities, "placed " .. tostring(placed) .. " of " .. #plan.entities)

    assert(#ghosts_of(nauvis(), "pipe") == 33, "pipe ghost count")
    local stubs = ghosts_of(nauvis(), "pipe-to-ground")
    assert(#stubs == 6, "pipe-to-ground ghost count " .. #stubs)
    for _, ghost in pairs(stubs) do
      assert(ghost.direction == defines.direction.north or ghost.direction == defines.direction.south,
        "stub ghost faces " .. tostring(ghost.direction))
    end
    for _, ghost in pairs(ghosts_of(nauvis(), "chemical-plant")) do
      assert(ghost.direction == defines.direction.west, "plant ghost lost its rotation")
      assert(ghost.get_recipe() and ghost.get_recipe().name == "battery", "plant ghost recipe")
    end
  end)

  test("all or nothing: one blocker means zero ghosts and the blocking position", function()
    local blocker = nauvis().create_entity({
      name = "steel-chest", position = { 0.5, 0.5 }, force = force(),
    })
    assert(blocker, "test setup failed to place the blocker")
    local placed, blocked_at = place(gear_plan())
    assert(placed == nil, "placement went ahead over a blocker")
    assert(blocked_at and blocked_at.x and blocked_at.y, "no blocking position returned")
    assert(#ghosts_on(nauvis()) == 0, "ghosts left behind by a refused placement")
  end)

  test("a refused placement cancels only its own deconstruction marks", function()
    local surface = nauvis()
    local tree_ours = surface.create_entity({ name = "tree-01", position = { 3.5, 0.5 } })
    local tree_player = surface.create_entity({ name = "tree-01", position = { 6.5, 0.5 } })
    tree_player.order_deconstruction(force())
    local blocker = surface.create_entity({
      name = "steel-chest", position = { 0.5, 1.5 }, force = force(),
    })
    assert(tree_ours and tree_player and blocker, "test setup failed")

    local placed = place(gear_plan())
    assert(placed == nil, "blocker did not block")
    assert(not tree_ours.to_be_deconstructed(),
      "the refused placement left its own deconstruction order behind")
    assert(tree_player.to_be_deconstructed(),
      "the refused placement cancelled an order the player had placed")
  end)

  test("a successful placement marks the trees in its way", function()
    local tree = nauvis().create_entity({ name = "tree-01", position = { 3.5, 0.5 } })
    assert(tree, "test setup failed")
    local placed = place(gear_plan())
    assert(placed, "trees must not block a placement")
    assert(tree.to_be_deconstructed(), "tree in the footprint was not marked")
  end)

  test("ghosts land on the context surface, not some default", function()
    -- The H4 rule: on_player_selected_area names the surface the selection happened on, and
    -- that is what the context carries -- never player.surface.
    local alt = game.get_surface("upl-test-alt")
    if not alt then
      alt = game.create_surface("upl-test-alt")
      alt.generate_with_lab_tiles = true
      alt.request_to_generate_chunks({ x = 0, y = 0 }, 2)
      alt.force_generate_chunk_requests()
    end
    -- The surface persists across runs in one save, and a trailing wipe never runs when an
    -- assert throws -- so the cleanup that keeps THIS run honest happens before placing,
    -- clearing whatever a previous failure left behind.
    wipe(alt)
    local plan = gear_plan()
    local placed = place(plan, alt)
    assert(placed == #plan.entities, "placement on the alt surface failed")
    assert(#ghosts_on(alt) == placed, "ghosts missing from the alt surface")
    assert(#ghosts_on(nauvis()) == 0, "ghosts leaked onto nauvis")
    wipe(alt)
  end)
end)
