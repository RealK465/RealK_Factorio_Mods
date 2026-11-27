-- The bot loop through the planner, validate and the blueprint, against real prototypes: the
-- layout accessors, what a bot plan stands and refuses, that the belt plans beside it never
-- move, and what the engine makes of the stamped ghosts. The live behaviour -- bots actually
-- carrying items tier to tier -- is bot_loop_spec's.

local planner = require("scripts.planner")
local research = require("tests.support.research")
local stamping = require("tests.support.stamp")
local deep_equal = require("tests.support.deep_equal")
local component = require("tests.support.component")
local footprint = require("tests.support.footprint")

local function force()
  return game.forces.player
end

local function nauvis()
  return game.surfaces["nauvis"]
end

local function choices_with(overrides)
  local choices = {
    recipe = "iron-gear-wheel", quality = "rare",
    machine = "assembling-machine-3", recycler = "recycler", layout = "bot",
  }
  for key, value in pairs(overrides or {}) do choices[key] = value end
  return choices
end

-- The belt twin of choices_with: the same picks with the layout key removed.
local function belt_choices(overrides)
  local choices = choices_with(overrides)
  choices.layout = nil
  return choices
end

local function count_by_name(plan, name)
  return #footprint.by_name(plan, name)
end

-- Spares the character: blueprint_spec runs next and stamps through the player's cursor.
local function wipe()
  stamping.wipe(nauvis(), true)
end

describe("the layout accessors", function()
  test("bots only when picked: nil and anything a hand-edited save holds read as belts", function()
    assert(planner.layout_kind({}) == "belt", "nil must read as belts")
    assert(planner.layout_kind({ layout = "bot" }) == "bot", "bot must read as bots")
    assert(planner.layout_kind({ layout = "hexagon" }) == "belt", "junk must read as belts")
    assert(planner.layout_kind({ layout = 7 }) == "belt", "a number must read as belts")
  end)

  test("bots force both requests and the network count, and leave the stored ticks alone", function()
    local c = { layout = "bot", stock_requests = false, terminal_requests = false, circuit_network = false }
    assert(planner.requests_forced(c), "bots must force the requests")
    assert(planner.stock_requests(c) == false and planner.terminal_requests(c) == false,
      "the raw accessors must keep the player's own ticks for the belt layout")
    assert(planner.circuit_network(c), "bots must count the network")
    assert(not planner.requests_forced({}), "belts force nothing")
    assert(planner.circuit_network({ circuit_network = true }), "a belt plan's tick still counts")
    assert(not planner.circuit_network({}), "an unticked belt plan counts the output chest")
  end)

  test("which chests each layout stands", function()
    for _, quality in pairs({ "rare", "legendary" }) do
      local bot = { layout = "bot", quality = quality }
      assert(not planner.uses_chest(bot, "container"), "bots stand no relay chest")
      assert(planner.uses_chest(bot, "overflow"), "bots always stand active providers")
      for _, role in pairs({ "requester", "stock", "provider" }) do
        assert(planner.uses_chest(bot, role), "bots stand the " .. role .. " role")
      end
    end
    assert(planner.uses_chest({ quality = "rare" }, "container"), "belts stand the relay chest")
    assert(planner.uses_chest({ quality = "rare" }, "overflow"), "a rare belt plan stands the tap")
    assert(not planner.uses_chest({ quality = "legendary" }, "overflow"),
      "a legendary belt plan stands no tap")
  end)

  test("one filter slot serves any recipe with bots", function()
    local recipe = prototypes.recipe["fusion-reactor-equipment"]
    assert(planner.filters_needed(recipe, { layout = "bot" }) == 1, "bots need one slot")
    assert(planner.filters_needed(recipe, {}) == #planner.item_ingredients(recipe),
      "belts need one slot per ingredient")
    assert(planner.filters_needed(recipe) == #planner.item_ingredients(recipe),
      "no choices at all still reads as belts")
  end)

  test("the beacon count follows the layout's rows: three vanilla beacons for bots, four for belts", function()
    local choices = { recipe = "iron-gear-wheel", machine = "assembling-machine-2", recycler = "recycler" }
    assert(planner.max_beacon_count(choices, prototypes.entity["beacon"]) == 4, "belt max")
    choices.layout = "bot"
    assert(planner.max_beacon_count(choices, prototypes.entity["beacon"]) == 3,
      "bot max, expected floor(11 / 3)")
  end)
end)

describe("planner.plan with bots", function()
  before_all(function() research.full(force()) end)

  test("vanilla gears to rare: 9 by 11, no belt, no relay chest, every consumer powered", function()
    local plan = planner.plan(force(), choices_with())
    assert(plan, "plan failed")
    assert(plan.width == 9 and plan.height == 11, "footprint " .. plan.width .. "x" .. plan.height)
    assert(plan.machines == 3 and plan.recyclers == 2, "column counts")
    assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    local expected = {
      ["assembling-machine-3"] = 3, ["recycler"] = 2, ["requester-chest"] = 3,
      ["buffer-chest"] = 2, ["passive-provider-chest"] = 1, ["active-provider-chest"] = 4,
      ["transport-belt"] = 0, ["turbo-transport-belt"] = 0, ["steel-chest"] = 0,
      ["wooden-chest"] = 0, ["iron-chest"] = 0,
    }
    for name, count in pairs(expected) do
      assert(count_by_name(plan, name) == count, name .. " count " .. count_by_name(plan, name)
        .. ", expected " .. count)
    end
    footprint.assert_no_overlap_and_in_bounds(plan)
  end)

  test("the two request opt-outs change nothing: bots have no other transport", function()
    local plain = planner.plan(force(), choices_with())
    local unticked = planner.plan(force(), choices_with({ stock_requests = false, terminal_requests = false }))
    assert(deep_equal(plain, unticked), "an unticked request moved the bot plan")
  end)

  test("a capped bot plan counts the whole network, whatever its own box says", function()
    local plan = planner.plan(force(), choices_with({
      circuit_enabled = true, circuit_max_rare = 100, circuit_network = false,
    }))
    assert(plan, "plan failed")
    for _, e in pairs(plan.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler" then
        assert(e.control_behavior and e.control_behavior.connect_to_logistic_network == true
          and e.control_behavior.logistic_condition.constant == 100,
          e.circuit_role .. " tier " .. e.circuit_tier .. " is not capped on the network")
      end
    end
    assert(plan.circuit_unlinked == nil, "unlinked " .. tostring(plan.circuit_unlinked))
  end)

  test("a fluid recipe with beacons plans, its pipe runs and stacks in every column", function()
    local plan = planner.plan(force(), choices_with({
      recipe = "battery", machine = "chemical-plant", quality = "uncommon",
      pole = "substation", beacon = "beacon", beacon_count = 2,
    }))
    assert(plan, "plan failed")
    assert(count_by_name(plan, "beacon") == 4, "beacons " .. count_by_name(plan, "beacon"))
    assert(count_by_name(plan, "pipe-to-ground") == 4, "stubs " .. count_by_name(plan, "pipe-to-ground"))
    assert(plan.height == 11, "height " .. plan.height)
    assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    footprint.assert_no_overlap_and_in_bounds(plan)
  end)

  test("the pole memo tells the layouts apart, in both directions", function()
    -- The memo keeps one plan's pole solution, so a key shared by the two layouts would hand
    -- the plan solved second the first one's poles. Each is checked against its twin solved
    -- after something unrelated.
    local poles = { pole = "medium-electric-pole" }
    local unrelated = belt_choices({ pole = "medium-electric-pole", recipe = "battery",
      machine = "chemical-plant", quality = "uncommon" })
    local belt = planner.plan(force(), belt_choices(poles))
    local bot = planner.plan(force(), choices_with(poles))
    local belt_again = planner.plan(force(), belt_choices(poles))
    assert(planner.plan(force(), unrelated), "the unrelated plan failed")
    local bot_alone = planner.plan(force(), choices_with(poles))
    assert(deep_equal(belt, belt_again), "a bot plan in between moved the belt plan")
    assert(deep_equal(bot, bot_alone), "a belt plan before it moved the bot plan")
    assert(bot.unpowered == nil and belt.unpowered == nil, "a plan was left unpowered")
    footprint.assert_no_overlap_and_in_bounds(bot)
    footprint.assert_no_overlap_and_in_bounds(belt)
  end)

  test("columns per tier repeat a bot tier's whole column", function()
    local one = planner.plan(force(), choices_with())
    local two = planner.plan(force(), choices_with({ column_count_normal = 2 }))
    assert(one and two, "plan failed")
    assert(two.machines == one.machines + 1 and two.recyclers == one.recyclers + 1,
      "machines " .. two.machines .. ", recyclers " .. two.recyclers .. " with two normal columns")
    assert(two.width > one.width, "the second column took no room")
    assert(count_by_name(two, "requester-chest") == count_by_name(one, "requester-chest") + 1,
      "the repeated column brought no feed chest of its own")
    footprint.assert_no_overlap_and_in_bounds(two)
  end)

  test("the yield and the pace are the belt plan's own", function()
    local belt = planner.plan(force(), belt_choices())
    local bot = planner.plan(force(), choices_with())
    assert(deep_equal(belt.yield, bot.yield), "the bot plan's yield differs")
    assert(belt.seconds == bot.seconds, "the bot plan's pace differs")
  end)

  test("a recipe past one inserter's filters still takes one feed chest a tier with bots", function()
    -- fusion-reactor-equipment carries six ingredients: two feed stacks on belts, one
    -- unfiltered chest with bots.
    local belt = planner.plan(force(), belt_choices({ recipe = "fusion-reactor-equipment" }))
    local bot = planner.plan(force(), choices_with({ recipe = "fusion-reactor-equipment" }))
    assert(belt and bot, "plan failed")
    assert(count_by_name(belt, "requester-chest") == 6, "belt feed chests "
      .. count_by_name(belt, "requester-chest"))
    assert(count_by_name(bot, "requester-chest") == 3, "bot feed chests "
      .. count_by_name(bot, "requester-chest"))
  end)
end)

describe("validate and plan agree for both layouts", function()
  after_all(function() research.full(force()) end)

  test("full research passes and plans every case, a fresh force refuses every one", function()
    for _, state in pairs({ "fresh", "full" }) do
      research[state](force())
      for _, recipe in pairs({ "iron-gear-wheel", "battery", "fusion-reactor-equipment" }) do
        local machine = recipe == "battery" and "chemical-plant" or "assembling-machine-3"
        for _, layout in pairs({ "bot", "belt" }) do
          local choices = choices_with({ recipe = recipe, machine = machine })
          if layout == "belt" then choices.layout = nil end
          local ok, message = planner.validate(force(), choices)
          local case = state .. " " .. recipe .. " " .. layout .. " " .. serpent.line(message)
          if state == "full" then
            assert(ok, "validate refused: " .. case)
            assert(planner.plan(force(), choices), "validate passed but plan failed: " .. case)
          else
            assert(not ok, "validate passed with nothing researched: " .. case)
          end
        end
      end
    end
  end)
end)

describe("the stamped bot blueprint", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  test("a bot plan lands whole, its filters and requests intact", function()
    local plan = planner.plan(force(), choices_with({ pole = "medium-electric-pole" }))
    local ghosts = stamping.place(plan, nauvis(), force())
    assert(#ghosts == #plan.entities, "built " .. #ghosts .. " of " .. #plan.entities)

    local extracts = {}
    for _, ghost in pairs(nauvis().find_entities_filtered({ name = "entity-ghost", ghost_type = "inserter" })) do
      local filter = ghost.get_filter(1)
      if type(filter) == "table" then
        assert(ghost.inserter_filter_mode == "whitelist" and filter.comparator == ">"
          and filter.name == nil, "an inserter filter lost its shape")
        extracts[filter.quality] = (extracts[filter.quality] or 0) + 1
      end
    end
    assert(extracts.normal == 1 and extracts.uncommon == 1 and extracts.rare == nil,
      "extract inserters by tier: " .. serpent.line(extracts))

    local feeds = 0
    for _, ghost in pairs(nauvis().find_entities_filtered({ ghost_name = "requester-chest" })) do
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      local slot = point.sections[1].get_slot(1)
      assert(slot.value.name == "iron-plate" and slot.min == 480, "feed request "
        .. tostring(slot.value.name) .. " x " .. tostring(slot.min))
      assert(point.trash_not_requested == true, "the trash flag did not reach a feed chest")
      feeds = feeds + 1
    end
    assert(feeds == 3, "feed chests " .. feeds)

    local returns = 0
    for _, ghost in pairs(nauvis().find_entities_filtered({ ghost_name = "buffer-chest" })) do
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      local slot = point.sections[1].get_slot(1)
      assert(slot.value.name == "iron-gear-wheel" and slot.min == 100, "return request "
        .. tostring(slot.value.name) .. " x " .. tostring(slot.min))
      returns = returns + 1
    end
    assert(returns == 2, "return chests " .. returns)

    for _, ghost in pairs(nauvis().find_entities_filtered({ ghost_name = "active-provider-chest" })) do
      local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
      assert(not point or #point.sections == 0 or point.sections[1].filters_count == 0,
        "an active provider carries a request")
    end
  end)

  test("a capped bot plan's gated ghosts share the combinator's one green network", function()
    local plan = planner.plan(force(), choices_with({
      pole = "medium-electric-pole", circuit_enabled = true, circuit_max_rare = 100,
      circuit_min_normal = 20,
    }))
    stamping.place(plan, nauvis(), force())
    local limits_index
    for index, e in pairs(plan.entities) do
      if e.circuit_role == "limits" then limits_index = index end
    end
    local planned = 0
    for _ in pairs(component(plan.entities, limits_index, "circuit_wire_to")) do planned = planned + 1 end

    local combinator = nauvis().find_entities_filtered({ ghost_name = "constant-combinator" })[1]
    local reached = stamping.reachable(combinator, defines.wire_connector_id.circuit_green)
    assert(reached == planned, "the stamped green network holds " .. reached .. " of the plan's " .. planned)
  end)
end)
