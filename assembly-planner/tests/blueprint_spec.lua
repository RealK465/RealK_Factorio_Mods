-- The plan through the blueprint and back: stamped as ghosts, revived, and every field read off
-- the real entities -- recipe, modules, filters, requests, the chest cap, the network condition
-- -- then the hand-over into the cursor.

local plan = require("scripts.plan")
local blueprint = require("scripts.blueprint")
local research = require("tests.support.research")
local stamp = require("tests.support.stamp")

local function force() return game.forces.player end

-- A lab-tile surface: a fresh graphics-tier map can put a tree or water anywhere on nauvis, and
-- a ghost then refuses to revive. Named nauvis() so the body reads like the other specs; it
-- is not nauvis. A corner of its own, clear of cell_live_spec's.
local lab
local function nauvis()
  if not (lab and lab.valid) then lab = stamp.lab() end
  return lab
end

local ORIGIN = { x = -70, y = -70 }
local AREA = { { -80, -80 }, { -30, -30 } }

local function find(name)
  return nauvis().find_entities_filtered({ name = name, area = AREA })
end

local function by_x(list)
  table.sort(list, function(a, b) return a.position.x < b.position.x end)
  return list
end

describe("blueprint round trip", function()
  before_all(function() research.full(force()) end)
  after_each(function() stamp.wipe(nauvis(), AREA) end)

  test("the quality cell revives with every field", function()
    local p = assert(plan.build(force(), nauvis(), {
      item = "personal-roboport-mk2-equipment", machine = "assembling-machine-3",
      module = "quality-module-3", inserter = "fast-inserter", cap_slots = 3,
    }))
    local ghosts = stamp.place(p, nauvis(), force(), ORIGIN)
    assert(#ghosts == #p.entities, "stamped " .. #ghosts .. " of " .. #p.entities)
    -- Modules ride the ghost's insert plan; a revive turns them into a delivery request.
    local modules = 0
    for _, ghost in pairs(ghosts) do
      if ghost.ghost_name == "assembling-machine-3" then
        for _, entry in pairs(ghost.insert_plan) do modules = modules + #entry.items.in_inventory end
      end
    end
    assert(modules == 4, "the machine's ghost plans " .. modules .. " modules")
    stamp.revive_all(nauvis(), AREA)

    local machine = find("assembling-machine-3")[1]
    local recipe, quality = machine.get_recipe()
    assert(recipe.name == "personal-roboport-mk2-equipment" and quality.name == "normal", "recipe lost")

    local inserters = by_x(find("fast-inserter"))
    local normal, better = inserters[2].get_filter(1), inserters[3].get_filter(1)
    assert(normal.quality == "normal" and normal.comparator == "=", "normal filter: " .. serpent.line(normal))
    assert(better.quality == "normal" and better.comparator == ">", "quality filter: " .. serpent.line(better))

    local outputs = by_x(find("passive-provider-chest"))
    local capped = outputs[1].get_inventory(defines.inventory.chest)
    -- bar = 3 in the blueprint is three open slots, read back as the index where red starts.
    assert(capped.get_bar() == 4, "capped chest bar " .. capped.get_bar())
    local open = outputs[2].get_inventory(defines.inventory.chest)
    assert(open.get_bar() == #open + 1, "the quality chest was capped")

    local requester = find("requester-chest")[1]
    local section = requester.get_logistic_sections().get_section(1)
    assert(section.filters_count == #prototypes.recipe["personal-roboport-mk2-equipment"].ingredients,
      "requests lost: " .. section.filters_count)
    local slot = section.get_slot(1)
    assert(slot.min and slot.min > 0, "a request came back without a count")
  end)

  test("network mode survives the stamp", function()
    local p = assert(plan.build(force(), nauvis(), {
      item = "iron-gear-wheel", machine = "assembling-machine-3", inserter = "fast-inserter",
      cap_mode = "network", cap_count = 250,
    }))
    stamp.place(p, nauvis(), force(), ORIGIN)
    stamp.revive_all(nauvis(), AREA)
    local output = by_x(find("fast-inserter"))[2]
    local behavior = output.get_control_behavior()
    assert(behavior and behavior.connect_to_logistic_network, "the output lost its logistic connection")
    local condition = behavior.logistic_condition
    assert(condition.first_signal.name == "iron-gear-wheel" and condition.constant == 250
      and condition.comparator == "<", "condition " .. serpent.line(condition))
  end)

  test("a fluid cell keeps its turn and its pipe row", function()
    local p = assert(plan.build(force(), nauvis(), { item = "supercapacitor", machine = "electromagnetic-plant" }))
    stamp.place(p, nauvis(), force(), ORIGIN)
    stamp.revive_all(nauvis(), AREA)
    local machine = find("electromagnetic-plant")[1]
    assert(machine.direction == defines.direction.east, "the EM plant lost its turn")
    assert(#find("pipe") == p.width, "the pipe row lost tiles")
  end)
end)

describe("blueprint.give", function()
  before_all(function() research.full(force()) end)

  test("hands the cell over as a temporary blueprint wearing the product", function()
    local player = game.connected_players[1]
    local p = assert(plan.build(force(), nauvis(), {
      item = "iron-gear-wheel", recipe_quality = "uncommon", machine = "assembling-machine-3",
    }))
    assert(blueprint.give(player, p), "the hand-over was refused")
    local cursor = player.cursor_stack
    assert(cursor.valid_for_read and cursor.name == "blueprint", "no blueprint in the cursor")
    local icon = cursor.preview_icons[1].signal
    assert(icon.name == "iron-gear-wheel" and icon.quality == "uncommon", "preview icon " .. serpent.line(icon))
    assert(#cursor.get_blueprint_entities() == #p.entities, "entities lost on the way in")
    assert(player.cursor_stack_temporary, "the blueprint is not temporary")
    player.clear_cursor()
  end)
end)
