-- The blueprint the player is handed: the table blueprint.entities writes, and what the engine
-- makes of it when the thing is stamped. This is the builder_spec work carried over -- the
-- assertions are the same ghosts read back the same way, only the placement call changed.
--
-- Stamping through build_blueprint rather than a cursor keeps the specs headless and free of
-- reach, but it is the same code path a player's click takes: the engine reads our table and
-- makes the ghosts. Anything it silently drops shows up here as a missing property, which is
-- the whole reason these assertions read the world back instead of trusting the table.

local planner = require("scripts.planner")
local blueprint = require("scripts.blueprint")
local research = require("tests.support.research")
local stamping = require("tests.support.stamp")

local function force()
  return game.forces.player
end

local function nauvis()
  return game.surfaces["nauvis"]
end

local function player()
  return game.connected_players[1]
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

local function stamp(plan, overrides)
  return (stamping.place(plan, nauvis(), force(), overrides))
end

local function ghosts_on(surface)
  return surface.find_entities_filtered({ name = "entity-ghost" })
end

local function ghosts_of(surface, inner_name)
  return surface.find_entities_filtered({ ghost_name = inner_name })
end

local function wipe(surface)
  for _, entity in pairs(surface.find_entities_filtered({})) do
    entity.destroy()
  end
end

-- How many ghosts one wire network holds: walk get_wire_connector(...).connections outward
-- from a start ghost. Shared by the pole-copper and circuit-green network tests -- the two
-- used to carry the walk independently, in different bookkeeping.
local function reachable(start, connector_id)
  local visited, stack, count = { [start.unit_number] = true }, { start }, 0
  while #stack > 0 do
    local ghost = stack[#stack]
    stack[#stack] = nil
    count = count + 1
    local connector = ghost.get_wire_connector(connector_id, false)
    for _, connection in pairs(connector and connector.connections or {}) do
      local other = connection.target.owner
      if not visited[other.unit_number] then
        visited[other.unit_number] = true
        stack[#stack + 1] = other
      end
    end
  end
  return count, visited
end

-- Stamps through the player's cursor -- the route a real click takes, and the only one that
-- accepts flip arguments, which build_blueprint has none of. Forced build mode, so reach never
-- enters into it.
local function stamp_from_cursor(plan, overrides)
  local p = player()
  local cursor = p.cursor_stack
  p.clear_cursor()
  cursor.set_stack({ name = "blueprint", count = 1 })
  cursor.set_blueprint_entities(blueprint.entities(plan))

  local options = {
    position = { x = plan.width / 2, y = plan.height / 2 },
    build_mode = defines.build_mode.forced,
  }
  for key, value in pairs(overrides or {}) do options[key] = value end
  -- As production hands it over, so clearing the cursor destroys the stack instead of filing
  -- a real blueprint into the test player's inventory on every call.
  p.cursor_stack_temporary = true
  p.build_from_cursor(options)
  p.clear_cursor()
end

describe("blueprint.entities", function()
  before_all(function() research.full(force()) end)

  test("one blueprint entity per planned entity, numbered 1..n", function()
    local plan = gear_plan()
    local entities = blueprint.entities(plan)
    assert(#entities == #plan.entities,
      "wrote " .. #entities .. " of " .. #plan.entities .. " planned entities")
    for index, entity in ipairs(entities) do
      assert(entity.entity_number == index, "entity_number " .. tostring(entity.entity_number)
        .. " at index " .. index)
      assert(entity.name, "entity " .. index .. " has no name")
      assert(entity.position and entity.position.x and entity.position.y,
        "entity " .. index .. " has no position")
    end
  end)

  test("pole copper is written on both ends of every link", function()
    -- create_blueprint writes a pole's links reciprocally, so this does too. A one-sided wire
    -- reads back asymmetric and there is no reason to hand the engine a shape it would not
    -- have produced itself.
    local entities = blueprint.entities(gear_plan())
    local links = 0
    for _, entity in ipairs(entities) do
      for _, wire in pairs(entity.wires or {}) do
        links = links + 1
        assert(wire[1] == entity.entity_number, "wire does not start at its own entity")
        local other = entities[wire[3]]
        assert(other, "wire points at entity " .. tostring(wire[3]) .. ", which does not exist")
        local mirrored = false
        for _, back in pairs(other.wires or {}) do
          if back[3] == entity.entity_number then mirrored = true end
        end
        assert(mirrored, "wire from " .. entity.entity_number .. " to " .. wire[3]
          .. " has no matching entry on the other end")
      end
    end
    assert(links > 0, "a three-pole plan wrote no wires at all")
  end)
end)

describe("stamping the blueprint", function()
  before_all(function() research.full(force()) end)
  after_each(function() wipe(nauvis()) end)

  test("a full plan lands: one ghost per planned entity", function()
    local plan = gear_plan()
    local ghosts = stamp(plan)
    assert(#ghosts == #plan.entities,
      "built " .. #ghosts .. " of " .. #plan.entities)
    assert(#ghosts_on(nauvis()) == #ghosts, "ghost count differs from what the stamp reported")
  end)

  test("machine ghosts carry recipe, pinned quality, build quality and an insert plan", function()
    stamp(gear_plan({ machine_quality = "uncommon" }))
    local machines = ghosts_of(nauvis(), "assembling-machine-3")
    assert(#machines == 3, "machine ghost count " .. #machines)
    local pinned = {}
    for _, ghost in pairs(machines) do
      -- The ghost itself is built at the player's chosen build quality; the recipe quality is
      -- the tier the column is pinned to. Two unrelated qualities on one entity.
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

  test("the relief inserter and the requester survive the blueprint round-trip", function()
    local plan = gear_plan()
    stamp(plan)

    -- The relief inserter under each recycler: a nameless "> this tier" whitelist, facing
    -- north off the recycler -- the overflow tap carries the same filter shape facing south.
    local inserter_name
    for _, e in pairs(plan.entities) do
      if e.filters and e.filters[1] and not e.filters[1].name
        and e.direction == defines.direction.north then
        inserter_name = e.name
      end
    end
    assert(inserter_name, "plan lost its relief inserter")
    local reliefs = {}
    for _, ghost in pairs(ghosts_of(nauvis(), inserter_name)) do
      local filter = ghost.get_filter(1)
      if ghost.direction == defines.direction.north and type(filter) == "table"
        and not filter.name then
        assert(ghost.inserter_filter_mode == "whitelist",
          "relief filter mode reads back as " .. tostring(ghost.inserter_filter_mode))
        assert(filter.comparator == ">", "relief comparator reads back as " .. tostring(filter.comparator))
        reliefs[filter.quality] = (reliefs[filter.quality] or 0) + 1
      end
    end
    assert(reliefs["normal"] == 1 and reliefs["uncommon"] == 1 and reliefs["rare"] == nil,
      "relief inserters by tier: " .. serpent.line(reliefs) .. ", expected one per lower tier")

    -- The blueprint's logistic filter is the flat shape -- a count on the filter itself -- and
    -- the engine turns it back into a section slot with a min. Getting that translation wrong
    -- yields an empty section rather than an error, which is what this pins.
    local requested = false
    for _, ghost in pairs(ghosts_of(nauvis(), "requester-chest")) do
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      assert(point, "requester ghost has no logistic point")
      assert(point.trash_not_requested == true, "trash default did not reach the ghost")
      assert(ghost.request_from_buffers == true, "request-from-buffers did not reach the ghost")
      local slot = point.sections[1] and point.sections[1].get_slot(1)
      if slot and slot.value and slot.value.name == "iron-plate" then
        -- Two minutes of gear crafting: 480 plates, past the stack the old formula capped at.
        assert(slot.min == 480, "iron-plate request min " .. tostring(slot.min))
        requested = true
      end
    end
    assert(requested, "no requester ghost carries the iron-plate request")

    -- The stock chests ride the same translation as buffer chests: same flat filter shape,
    -- same trash flag, read back off the ghost rather than trusted from the table.
    local stocked = 0
    for _, ghost in pairs(ghosts_of(nauvis(), "buffer-chest")) do
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      assert(point, "stock ghost has no logistic point")
      assert(point.trash_not_requested == true, "trash default did not reach the stock ghost")
      local slot = point.sections[1] and point.sections[1].get_slot(1)
      assert(slot and slot.value and slot.value.name == "iron-gear-wheel",
        "stock ghost requests " .. tostring(slot and slot.value and slot.value.name))
      assert(slot.min == 100, "gear request min " .. tostring(slot.min))
      stocked = stocked + 1
    end
    assert(stocked == 2, "stock ghosts " .. stocked .. ", expected one per lower tier")
  end)

  test("unticking the trash checkbox reaches every requesting ghost", function()
    stamp(gear_plan({ trash_unrequested = false }))
    for _, name in pairs({ "requester-chest", "buffer-chest" }) do
      for _, ghost in pairs(ghosts_of(nauvis(), name)) do
        local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
        assert(point.trash_not_requested == false, "unticked trash flag lost on " .. name)
      end
    end
  end)

  test("a recipe past one inserter's slots stamps two feed stacks per column, filters and requests intact", function()
    -- Fusion reactor equipment: six ingredients, three per stack, the only vanilla recipe
    -- past one inserter's five slots. Read back off real ghosts: two feed chests per column
    -- requesting disjoint halves, and two harvest inserters per column whose filters name
    -- exactly those halves at the column's tier.
    local recipe = prototypes.recipe["fusion-reactor-equipment"]
    local names = {}
    for _, ingredient in pairs(planner.item_ingredients(recipe)) do names[ingredient.name] = true end
    local plan = gear_plan({ recipe = "fusion-reactor-equipment", quality = "uncommon" })
    stamp(plan)

    local inserter_name
    for _, e in pairs(plan.entities) do
      if e.filters and e.filters[1] and names[e.filters[1].name] then inserter_name = e.name end
    end
    assert(inserter_name, "plan carries no harvest inserter naming an ingredient")

    -- Harvest inserters: those whose first filter names an ingredient (the catcher and the
    -- product-fill inserters name the product). Keyed by tier, each carrying three names.
    local harvested = { normal = {}, uncommon = {} }
    local harvests = 0
    for _, ghost in pairs(ghosts_of(nauvis(), inserter_name)) do
      local first = ghost.get_filter(1)
      if type(first) == "string" then first = { name = first } end
      if first and names[first.name] then
        harvests = harvests + 1
        local tier = first.quality or "normal"
        local carried = 0
        for slot = 1, 5 do
          local filter = ghost.get_filter(slot)
          if type(filter) == "string" then filter = { name = filter } end
          if filter and filter.name then
            carried = carried + 1
            assert((filter.quality or "normal") == tier, "one harvest inserter mixes tiers")
            assert(not harvested[tier][filter.name], filter.name .. " harvested twice at " .. tier)
            harvested[tier][filter.name] = true
          end
        end
        assert(carried == 3, "a harvest inserter carries " .. carried .. " filters, expected 3")
      end
    end
    assert(harvests == 4, "harvest inserters " .. harvests .. ", expected two per column")
    for tier, seen in pairs(harvested) do
      for name in pairs(names) do
        assert(seen[name], name .. " is harvested by no stack at " .. tier)
      end
    end

    -- Feed chests: two per column, three requests apiece, disjoint per column.
    local requested = { normal = {}, uncommon = {} }
    local chests = 0
    for _, ghost in pairs(ghosts_of(nauvis(), "requester-chest")) do
      chests = chests + 1
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      local section = point and point.sections[1]
      assert(section, "a feed chest ghost has no logistic section")
      local slots = 0
      for slot = 1, 5 do
        local request = section.get_slot(slot)
        if request and request.value and request.value.name then
          slots = slots + 1
          local tier = request.value.quality or "normal"
          assert(not requested[tier][request.value.name], request.value.name .. " requested twice at " .. tier)
          requested[tier][request.value.name] = true
        end
      end
      assert(slots == 3, "a feed chest requests " .. slots .. " items, expected 3")
    end
    assert(chests == 4, "feed chests " .. chests .. ", expected two per column")
    for tier, seen in pairs(requested) do
      for name in pairs(names) do
        assert(seen[name], name .. " is requested by no chest at " .. tier)
      end
    end
  end)

  test("the tap and the catcher keep their quality comparators through the blueprint", function()
    -- The only two filters in the plan that name a quality RANGE instead of one tier, read back
    -- off real ghosts rather than trusted from the table. A comparator the engine dropped would
    -- leave a tap that catches nothing and a catcher that misses every lucky roll, and neither
    -- failure raises anything -- which is the whole reason this reads the world back.
    --
    -- The engine normalises ">=" to its single glyph on the way in (analysis/api.md S24), so the
    -- catcher is compared against what comes out, not against what blueprint.lua wrote.
    local GTE = "\226\137\165"
    stamp(gear_plan())

    local tap, catcher
    for _, ghost in pairs(ghosts_on(nauvis())) do
      if ghost.ghost_prototype.type == "inserter" then
        local filter = ghost.get_filter(1)
        -- get_filter hands back a bare string when there is nothing but a name to report.
        if type(filter) == "string" then filter = { name = filter } end
        -- Nameless AND facing the bottom ring: the relief inserters under the recyclers carry
        -- the same nameless shape at their own tiers, facing north.
        if filter and not filter.name and ghost.direction == defines.direction.south then
          tap = filter
        elseif filter and filter.comparator == GTE then
          catcher = filter
        end
      end
    end

    assert(tap, "no nameless filter survived -- the overflow tap catches nothing")
    assert(tap.quality == "rare" and tap.comparator == ">",
      "tap filter came back as " .. serpent.line(tap))
    assert(catcher, "no >= filter survived -- the catcher misses above-target product")
    assert(catcher.name == "iron-gear-wheel" and catcher.quality == "rare",
      "catcher filter came back as " .. serpent.line(catcher))

    assert(#ghosts_of(nauvis(), "active-provider-chest") == 1,
      "the tap has no active provider to drop into")
  end)

  test("pole ghosts come wired into one connected network", function()
    -- The exact edge count is the engine's business, not ours: wires are first-class blueprint
    -- content and ghost poles preview their own auto-connections on top of the spanning tree
    -- the plan draws. The contract worth pinning is that every pole ends up in ONE network --
    -- an unwired island is the failure poles.lua's honesty rule exists for.
    stamp(gear_plan())
    local poles = ghosts_of(nauvis(), "medium-electric-pole")
    -- Six, not the three a per-tier pole column used to line up: the compact plan wins on
    -- width and the poles spread into the ring's own free ground instead. The sixth is the
    -- overflow tap's -- see plan_spec's medium-pole scenario for why it costs one.
    assert(#poles == 6, "pole ghost count " .. #poles)

    local reached = reachable(poles[1], defines.wire_connector_id.pole_copper)
    assert(reached == #poles, "only " .. reached .. " of " .. #poles .. " poles share the network")
  end)

  test("a fluid plan's pipes land as ordinary ghosts with their directions", function()
    -- Pipes carry no recipe, modules, filters or requests, so the serialiser needs no new code
    -- for them -- this pins that a fluid plan stamps completely and the crossing pair reads
    -- back with the facings the underground hop depends on.
    local plan = planner.plan(force(), {
      recipe = "battery", quality = "rare",
      machine = "chemical-plant", recycler = "recycler",
      pole = "medium-electric-pole",
    })
    assert(plan, "battery plan failed in test setup")
    local ghosts = stamp(plan)
    assert(#ghosts == #plan.entities, "built " .. #ghosts .. " of " .. #plan.entities)

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

  test("circuit limits survive the stamp: gates on all three kinds, one green network, neutral belts", function()
    -- The naming trap, read back off real ghosts on purpose: the BLUEPRINT field is
    -- circuit_enabled, but a live control behaviour spells the same flag
    -- circuit_enable_disable -- a read of .circuit_enabled here would come back nil and
    -- prove nothing (the belt's read_contents_mode / circuit_contents_read_mode split
    -- again, api.md S21).
    stamp(gear_plan({
      circuit_enabled = true, circuit_max_rare = 77,
      circuit_min_normal = 5, circuit_min_uncommon = 9,
    }))

    -- Every machine carries the one cap: the target's count against the combinator's
    -- signal-C at the target quality, no constant anywhere.
    local machines = ghosts_of(nauvis(), "assembling-machine-3")
    assert(#machines == 3, "machine ghost count " .. #machines)
    for _, ghost in pairs(machines) do
      local cb = ghost.get_control_behavior()
      assert(cb and cb.circuit_enable_disable == true, "a machine ghost lost its gate")
      local condition = cb.circuit_condition
      assert(condition.first_signal and condition.first_signal.name == "iron-gear-wheel"
        and condition.first_signal.quality == "rare"
        and condition.second_signal and condition.second_signal.name == "signal-C"
        and condition.second_signal.quality == "rare",
        "machine condition came back as " .. serpent.line(condition))
    end

    -- The recycler is a furnace, whose blueprint group carries control_behavior and nothing
    -- else -- the half of the design that had no precedent in the mod before this test. It
    -- stops at the same cap as the machines.
    for _, ghost in pairs(ghosts_of(nauvis(), "recycler")) do
      local cb = ghost.get_control_behavior()
      assert(cb and cb.circuit_enable_disable == true, "a recycler ghost lost its gate")
      assert(cb.circuit_condition.first_signal.quality == "rare"
        and cb.circuit_condition.second_signal.name == "signal-C",
        "recycler condition " .. serpent.line(cb.circuit_condition))
    end

    -- The reserve inserters hold their floors, at or above, at their own tiers, each
    -- against signal-M at its own quality, and each pinned to the hand the floor was raised
    -- by -- 12, the bulk inserter's at full research, read back off the ghost as
    -- inserter_stack_size_override (api.md S33). A signal's quality reads back OMITTED when
    -- it is normal -- the same default omission as a north direction or a whitelist
    -- filter_mode -- so nil means normal here, on both sides of the comparison.
    local reserves, pinned = 0, 0
    for _, ghost in pairs(ghosts_on(nauvis())) do
      if ghost.ghost_prototype.type == "inserter" then
        local cb = ghost.get_control_behavior()
        if cb and cb.circuit_enable_disable then
          local c = cb.circuit_condition
          -- The blueprint wrote ">=" and the ghost reads back the canonical U+2265 "greater
          -- than or equal" sign: ComparatorString accepts both spellings on write and hands
          -- back the one-character form (documented, api.md S33) -- the family's fourth
          -- read-back trap. Spelled as bytes, since Factorio's Lua 5.2 has no \u escape.
          assert(c.comparator == "\226\137\165", "reserve comparator " .. tostring(c.comparator))
          local tier = c.first_signal.quality or "normal"
          assert(c.second_signal.name == "signal-M"
            and (c.second_signal.quality or "normal") == tier,
            "reserve condition " .. serpent.line(c))
          assert(ghost.inserter_stack_size_override == 12,
            "reserve pinned to " .. tostring(ghost.inserter_stack_size_override))
          reserves = reserves + 1
        elseif ghost.inserter_stack_size_override ~= 0 then
          pinned = pinned + 1
        end
      end
    end
    assert(reserves == 2, reserves .. " gated inserters, expected one reserve per lower tier")
    assert(pinned == 0, pinned .. " ungated inserters carry a pin -- only the reserves may")

    -- The numbers themselves, on the combinator ghost: two floors, each plus the hand of
    -- 12, then the cap. Runtime names again -- a section's filter is { value = {...}, min =
    -- count } here, where the blueprint wrote a flat row (api.md S32).
    local combinators = ghosts_of(nauvis(), "constant-combinator")
    assert(#combinators == 1, "combinator ghost count " .. #combinators)
    local filters = combinators[1].get_control_behavior().get_section(1).filters
    assert(#filters == 3, "combinator rows " .. #filters)
    assert(filters[1].value.name == "signal-M" and filters[1].value.quality == "normal"
      and filters[1].min == 17, "row 1 reads " .. serpent.line(filters[1]))
    assert(filters[2].value.name == "signal-M" and filters[2].value.quality == "uncommon"
      and filters[2].min == 21, "row 2 reads " .. serpent.line(filters[2]))
    assert(filters[3].value.name == "signal-C" and filters[3].value.quality == "rare"
      and filters[3].min == 77, "row 3 reads " .. serpent.line(filters[3]))
    assert(combinators[1].get_control_behavior().enabled == true,
      "an unpaused combinator stamped switched off")

    -- One green component spanning every gated entity, every census chest and the stack:
    -- 3 machines, 2 recyclers, 2 reserve inserters, 2 buffer chests, the output chest, the
    -- combinator, the two lamps and the panel.
    local start
    for _, ghost in pairs(ghosts_of(nauvis(), "passive-provider-chest")) do start = ghost end
    assert(start, "no output chest ghost to walk from")
    local reached = reachable(start, defines.wire_connector_id.circuit_green)
    assert(reached == 14, "the green network spans " .. reached .. " ghosts, expected 14")

    -- Direct mode on a vanilla plan: the ring must carry no wires and no behaviour -- a belt
    -- that grew either would gate or read the very path the limits leave alone.
    for _, ghost in pairs(ghosts_of(nauvis(), "transport-belt")) do
      assert(ghost.get_control_behavior() == nil, "a belt ghost grew a control behaviour")
      local connector = ghost.get_wire_connector(defines.wire_connector_id.circuit_green, false)
      assert(not connector or #connector.connections == 0, "a belt ghost was wired in direct mode")
    end
  end)

  test("the circuit stack survives the stamp: colours, words, the switch and the description", function()
    -- Read back off REVIVED entities rather than ghosts: a lamp's colour and a combinator's
    -- description are entity fields the ghost route was never measured for (api.md S32),
    -- and a script revive needs no items. Runtime names: is_on is `enabled`,
    -- player_description is `combinator_description`.
    stamp(gear_plan({ circuit_enabled = true, circuit_max_rare = 77, circuit_paused = true }))
    local revived = {}
    for _, name in pairs({ "constant-combinator", "small-lamp", "display-panel" }) do
      for _, ghost in pairs(ghosts_of(nauvis(), name)) do
        local _, entity = ghost.revive()
        assert(entity, "reviving a " .. name .. " ghost gave nothing back")
        revived[name] = revived[name] or {}
        revived[name][#revived[name] + 1] = entity
      end
    end
    assert(#revived["constant-combinator"] == 1 and #revived["small-lamp"] == 2
      and #revived["display-panel"] == 1, "the stack did not stamp whole")

    local combinator = revived["constant-combinator"][1]
    assert(combinator.get_control_behavior().enabled == false,
      "Start paused did not survive the stamp")
    assert(combinator.combinator_description:find("pause", 1, true),
      "the description came back as " .. tostring(combinator.combinator_description))

    local green, blue = 0, 0
    for _, lamp in pairs(revived["small-lamp"]) do
      local color = lamp.color
      assert(color, "a status lamp lost its colour")
      assert(lamp.always_on == true, "a status lamp would only show at night")
      local c = lamp.get_control_behavior().circuit_condition
      assert(c.second_signal and c.second_signal.name == "signal-C",
        "a lamp condition came back as " .. serpent.line(c))
      if color.g == 1 and color.r == 0 then
        green = green + 1
        assert(c.comparator == "\226\137\165", "the green lamp compares with " .. c.comparator)
      elseif color.b == 1 then
        blue = blue + 1
        assert(c.comparator == "<", "the blue lamp compares with " .. c.comparator)
      end
    end
    assert(green == 1 and blue == 1, green .. " green and " .. blue .. " blue lamps")

    -- The panel's rows come back through the engine's own encoder rather than its control
    -- behaviour: 2.0.77 spells that class's list `messages` and 2.1 `records`, each a hard
    -- error on the other track (analysis/factorio-2.0.md), where the blueprint shape is one
    -- and the same. A one-tile area, so the lamp above and the combinator below stay out.
    local panel = revived["display-panel"][1]
    local inventory = game.create_inventory(1)
    inventory.insert({ name = "blueprint", count = 1 })
    inventory[1].create_blueprint({
      surface = nauvis(), force = force(),
      area = { { panel.position.x - 0.4, panel.position.y - 0.4 },
        { panel.position.x + 0.4, panel.position.y + 0.4 } },
    })
    local encoded
    for _, e in pairs(inventory[1].get_blueprint_entities() or {}) do
      if e.name == "display-panel" then encoded = e end
    end
    inventory.destroy()
    assert(encoded, "the revived panel did not encode into a blueprint")
    assert(encoded.show_in_chart == true and encoded.always_show == true,
      "the panel lost its map or always-show flag: " .. serpent.line(encoded))
    local records = encoded.control_behavior.parameters
    assert(#records == 2, "panel records " .. #records)
    assert(records[1].icon.name == "signal-deny" and records[1].text == "Paused"
      and (records[1].condition.constant or 0) == 0 and records[1].condition.second_signal == nil
      and records[1].condition.first_signal.name == "signal-C",
      "panel row 1 is " .. serpent.line(records[1]))
    assert(records[2].icon.name == "signal-check" and records[2].text == "Done"
      and records[2].condition.second_signal.name == "signal-C",
      "panel row 2 is " .. serpent.line(records[2]))
  end)

  test("the widest vanilla pitch stays one green network, through the ring relay", function()
    -- The substation+beacon+pipe column stretches a machine-row hop to 9.0 centre-to-centre
    -- -- exactly the wire reach, where nothing records whether the engine measures centres
    -- or connector points. The decorator's half-tile margin sends this plan through the
    -- ring relay instead of gambling on the boundary; this stamps it and proves every gated
    -- ghost still shares one network on the engine's own arithmetic.
    local plan = planner.plan(force(), {
      recipe = "battery", quality = "rare",
      machine = "chemical-plant", recycler = "recycler",
      pole = "substation", beacon = "beacon", beacon_count = 4,
      circuit_enabled = true, circuit_max_rare = 50,
      circuit_min_normal = 5, circuit_min_uncommon = 5,
    })
    assert(plan, "widest-pitch plan failed in test setup")
    assert(plan.circuit_unlinked == nil,
      "unlinked " .. tostring(plan.circuit_unlinked) .. " on the widest vanilla pitch")
    local relayed = false
    for _, e in pairs(plan.entities) do
      if e.circuit_role == "ring" and e.circuit_wire_to then relayed = true end
    end
    assert(relayed, "test premise: this geometry must push the spine onto the ring relay")

    stamp(plan)
    local start
    for _, ghost in pairs(ghosts_of(nauvis(), "passive-provider-chest")) do start = ghost end
    assert(start, "no output chest ghost to walk from")
    local _, visited = reachable(start, defines.wire_connector_id.circuit_green)
    local function all_reached(name, expected)
      local ghosts = ghosts_of(nauvis(), name)
      local hit = 0
      for _, ghost in pairs(ghosts) do
        if visited[ghost.unit_number] then hit = hit + 1 end
      end
      assert(hit == expected, name .. ": " .. hit .. " of " .. #ghosts
        .. " on the network, expected " .. expected)
    end
    all_reached("chemical-plant", 3)
    all_reached("recycler", 2)
    -- The two census stock chests belong on the network; the three feed requesters do not.
    all_reached("buffer-chest", 2)
    all_reached("requester-chest", 0)
  end)
end)

-- The engine premise the per-tier module split rests on: one machine's inventory holding TWO
-- module identities at once. items_of has only ever written one BlueprintInsertPlan per entity
-- and api.md §21's capture never exercised a mix, so both directions are measured here before
-- any production code assumes the shape -- what the engine's own encoder emits for a hand-mixed
-- machine, and what its decoder makes of a hand-written two-plan entity. Per-identity COUNTS
-- are the contract; which physical stack holds which module is the engine's business, so no
-- assertion here pins stack positions beyond disjointness.
describe("mixed-module premises for the per-tier split", function()
  before_all(function() research.full(force()) end)
  after_each(function() wipe(nauvis()) end)

  -- Reads an items array into { [item-name] = stack_count } plus a disjointness verdict, so
  -- both directions below judge the same way whatever entry order the engine picks.
  local function stacks_by_id(items)
    local counts, seen, disjoint = {}, {}, true
    for _, plan in pairs(items or {}) do
      local name = plan.id.name
      for _, slot in pairs(plan.items.in_inventory or {}) do
        counts[name] = (counts[name] or 0) + 1
        local key = tostring(slot.inventory) .. ":" .. tostring(slot.stack)
        if seen[key] then disjoint = false end
        seen[key] = true
      end
    end
    return counts, disjoint
  end

  test("encoder: blueprinting a hand-mixed machine yields one insert plan per identity", function()
    local machine = nauvis().create_entity({
      name = "assembling-machine-3", position = { 4.5, 4.5 }, force = force(),
    })
    assert(machine, "test setup failed to place the machine")
    local modules = machine.get_module_inventory()
    assert(modules.insert({ name = "quality-module-3", count = 3 }) == 3
      and modules.insert({ name = "productivity-module-3", count = 1 }) == 1,
      "test setup failed to insert the mix")

    local inventory = game.create_inventory(1)
    inventory.insert({ name = "blueprint", count = 1 })
    local stack = inventory[1]
    stack.create_blueprint({
      surface = nauvis(), force = force(),
      area = { { 2, 2 }, { 7, 7 } },
    })
    local entities = stack.get_blueprint_entities()
    inventory.destroy()

    assert(entities and #entities == 1, "captured " .. tostring(entities and #entities)
      .. " entities, expected the one machine")
    local items = entities[1].items
    assert(items and #items == 2, "the engine encoded the mix as "
      .. tostring(items and #items) .. " insert plans: " .. serpent.line(items))
    local counts, disjoint = stacks_by_id(items)
    assert(counts["quality-module-3"] == 3 and counts["productivity-module-3"] == 1,
      "per-identity counts came back as " .. serpent.line(counts))
    assert(disjoint, "the encoder reused a stack index across identities")
  end)

  test("decoder: a hand-written two-plan entity stamps, reads back, and delivers the mix", function()
    local inventory = defines.inventory.crafter_modules
    local ghosts = stamping.place_entities({ {
      entity_number = 1, name = "assembling-machine-3", position = { x = 1.5, y = 1.5 },
      recipe = "iron-gear-wheel",
      items = {
        { id = { name = "quality-module-3" }, items = { in_inventory = {
          { inventory = inventory, stack = 0 }, { inventory = inventory, stack = 1 },
          { inventory = inventory, stack = 2 },
        } } },
        { id = { name = "productivity-module-3" }, items = { in_inventory = {
          { inventory = inventory, stack = 3 },
        } } },
      },
    } }, {
      surface = nauvis(), force = force(),
      position = { x = 8, y = 8 }, build_mode = defines.build_mode.forced,
    })
    assert(#ghosts == 1, "the two-plan entity stamped " .. #ghosts .. " ghosts")

    local counts, disjoint = stacks_by_id(ghosts[1].insert_plan)
    assert(counts["quality-module-3"] == 3 and counts["productivity-module-3"] == 1,
      "the ghost's insert plan reads back as " .. serpent.line(counts))
    assert(disjoint, "the decoder collapsed two identities onto one stack")

    -- The delivery half: reviving hands the requests to an item-request proxy, the same
    -- vehicle a bot-built ghost uses, and the mix must survive into it per identity.
    local _, machine, proxy = ghosts[1].revive({ return_item_request_proxy = true })
    assert(machine, "the mixed ghost refused to revive")
    assert(proxy, "no item-request proxy carried the module requests")
    local requested = stacks_by_id(proxy.insert_plan)
    assert(requested["quality-module-3"] == 3 and requested["productivity-module-3"] == 1,
      "the proxy carries " .. serpent.line(requested))
  end)

  test("a split plan stamps: two insert plans per mixed machine, one on the terminal", function()
    -- End to end through planner.plan and blueprint.entities: the per-tier overrides force a
    -- 3q+1p mix on both lower tiers, and the serialiser's fan-out must land on real ghosts.
    stamp(gear_plan({ split_prod_normal = 1, split_prod_uncommon = 1 }))
    local mixed = 0
    for _, ghost in pairs(ghosts_of(nauvis(), "assembling-machine-3")) do
      local _, quality = ghost.get_recipe()
      local entries = ghost.insert_plan
      if quality and quality.name ~= "rare" then
        assert(#entries == 2, "a mixed machine carries " .. #entries .. " insert plans")
        local counts, disjoint = stacks_by_id(entries)
        assert(counts["quality-module-3"] == 3 and counts["productivity-module-3"] == 1,
          "mixed counts " .. serpent.line(counts))
        assert(disjoint, "the fan-out reused a stack index")
        mixed = mixed + 1
      else
        assert(#entries == 1, "the terminal machine grew a second insert plan")
      end
    end
    assert(mixed == 2, "expected two mixed machines, found " .. mixed)
  end)
end)

-- Rotation and flipping come free with a blueprint, and one of them could break the loop
-- silently. The recycler throws its output on a vector with a non-zero x offset
-- (vector_to_place_result = {-0.35, -2.3}), so a mirror that failed to mirror the throw would
-- land it two thirds of a tile off and no craft would ever start -- the exact failure the
-- eject mechanism is built to avoid, and one no amount of counting ghosts would notice.
--
-- Asserted through the engine's own arithmetic rather than by reproducing the vector maths
-- here, which is the only way the test could stay honest about a composition -- mirroring on
-- top of rotation -- that nothing documents.
describe("rotation and flipping keep the eject pointed at its machine", function()
  before_all(function() research.full(force()) end)
  after_each(function() wipe(nauvis()) end)

  -- drop_position, not drop_target: a furnace-type recycler reports no drop_target at all
  -- (measured -- it comes back nil even for the plain unrotated loop that loop_spec proves
  -- works), but the position it throws to is the engine's own arithmetic, mirroring included.
  local function assert_ejects_into_machines(label)
    local surface = nauvis()
    local recyclers = surface.find_entities_filtered({ name = "recycler" })
    assert(#recyclers == 2, label .. ": recycler count " .. #recyclers)
    for _, recycler in pairs(recyclers) do
      local drop = recycler.drop_position
      assert(drop, label .. ": recycler reports no drop position")
      -- A degenerate AREA, not `position`: the position filter matches an entity whose own
      -- centre is that point, where what is being asked is which entity COVERS it.
      local caught = surface.find_entities_filtered({
        area = {
          left_top = { x = drop.x - 0.01, y = drop.y - 0.01 },
          right_bottom = { x = drop.x + 0.01, y = drop.y + 0.01 },
        },
        type = "assembling-machine",
      })
      assert(#caught == 1, label .. ": the throw at " .. serpent.line(drop) .. " lands in "
        .. #caught .. " machines, not one")
    end
  end

  -- One registrar rather than four near-identical bodies: the label named the orientation
  -- twice before, in the test name and in the assertion, and the two had already drifted.
  local function ejects_after(label, options)
    test(label .. ": every recycler throws into its own machine", function()
      stamp_from_cursor(gear_plan(), options)
      stamping.revive_all(nauvis())
      assert_ejects_into_machines(label)
    end)
  end

  ejects_after("unflipped")
  ejects_after("flipped horizontally", { flip_horizontal = true })
  ejects_after("flipped vertically", { flip_vertical = true })
  ejects_after("rotated a quarter turn east", { direction = defines.direction.east })
end)

-- Undo was an open question while the mod placed ghosts itself: create_entity takes a player
-- and an undo_index, but whether several dozen calls collapse into ONE undoable step was never
-- checked. Handing over a blueprint answers it -- the engine files a stamp as a single item --
-- and this is where that answer is pinned, because the player-facing promise is "Ctrl+Z takes
-- the whole loop back", not "Ctrl+Z takes one belt back ninety times".
describe("undo", function()
  before_all(function() research.full(force()) end)
  after_each(function() wipe(nauvis()) end)

  test("a stamped loop is one undo item covering every entity", function()
    local p = player()
    local stack = p.undo_redo_stack
    local before = stack.get_undo_item_count()

    local plan = gear_plan()
    stamp_from_cursor(plan)

    assert(stack.get_undo_item_count() == before + 1,
      "a stamp filed " .. (stack.get_undo_item_count() - before) .. " undo items, not one")
    -- Index 1 is the newest item. It carries one action per ghost and a couple more besides --
    -- measured at 94 for a 92-entity loop, the extras being the poles' copper -- so the
    -- contract is coverage, not an exact count the engine never promised.
    local actions = stack.get_undo_item(1)
    assert(#actions >= #plan.entities,
      "the undo item covers " .. #actions .. " actions of " .. #plan.entities .. " entities")
  end)
end)

-- The engine's own build modes, which this mod now delegates every obstacle decision to. These
-- are premise tests: nothing here exercises mod code, and that is the point -- the moment the
-- engine stops refusing on a normal click or stops clearing trees on a forced one, the player
-- experience this design promises has changed and something must say so.
describe("build modes -- the behaviour the mod delegates to", function()
  before_all(function() research.full(force()) end)
  after_each(function() wipe(nauvis()) end)

  -- Stamps once to learn where the layout actually lands rather than assuming, clears up, and
  -- puts `spec` on the first tile it used. Hardcoding a coordinate instead would go stale the
  -- first time the layout changed shape, and silently: the obstacle would simply miss.
  local function obstruct(plan, spec)
    local ghosts = stamp(plan)
    assert(#ghosts > 0, "the clear-ground stamp built nothing")
    spec.position = ghosts[1].position
    wipe(nauvis())
    local obstacle = nauvis().create_entity(spec)
    assert(obstacle, "test setup failed to place the " .. spec.name)
    return obstacle
  end

  test("a normal stamp refuses outright when something is in the way", function()
    local plan = gear_plan()
    obstruct(plan, { name = "steel-chest", force = force() })

    local blocked = stamp(plan)
    assert(#blocked == 0, "a normal stamp built " .. #blocked .. " ghosts over a blocker")
    assert(#ghosts_on(nauvis()) == 0, "ghosts left behind by a refused stamp")
  end)

  -- A tree is the case the player-facing text turns on, and it is NOT the same as the chest
  -- above: vanilla marks trees for deconstruction under a plainly-placed blueprint in plenty of
  -- situations, so "normal refuses over a tree" had to be measured rather than inferred from the
  -- chest. Measured 2026-08-18: it refuses, builds nothing, and leaves the tree alone -- which is
  -- what makes "shift-click to build through trees" the honest instruction in the changelog,
  -- the README and the shortcut's own description.
  test("a normal stamp over a tree refuses and leaves the tree alone", function()
    local plan = gear_plan()
    local tree = obstruct(plan, { name = "tree-01" })

    local ghosts = stamp(plan)
    assert(#ghosts == 0, "a normal stamp built " .. #ghosts .. " ghosts over a tree")
    assert(not tree.to_be_deconstructed(),
      "a refused stamp marked the tree anyway -- shift-click is no longer the instruction")
  end)

  test("a forced stamp builds anyway and marks the trees it stands on", function()
    local plan = gear_plan()
    local tree = obstruct(plan, { name = "tree-01" })

    local ghosts = stamp(plan, { build_mode = defines.build_mode.forced })
    assert(#ghosts > 0, "a forced stamp built nothing")
    assert(tree.to_be_deconstructed(),
      "a forced stamp left a tree in the footprint unmarked -- shift-click no longer clears")
  end)
end)
