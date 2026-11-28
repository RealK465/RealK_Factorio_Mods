-- Single-cell plans end to end, frozen: plan.build at full research on nauvis for a spread of
-- choices, each digested whole -- entities, poles, wires, requests, warnings, stats. Captured
-- from the tree before production chains split plan.build into a cell and its power
-- (2026-11-28), so the split is proven to leave every single cell exactly as it was.

local plan = require("scripts.plan")
local research = require("tests.support.research")
local fingerprint = require("tests.support.fingerprint")

local CASES = {
  gears_plain = { item = "iron-gear-wheel", machine = "assembling-machine-3" },
  roboport_quality_split = {
    item = "personal-roboport-mk2-equipment", machine = "assembling-machine-3",
    module = "quality-module-3", inserter = "fast-inserter",
  },
  -- The deferred dark inserter: the pole ladder runs every rung.
  circuits_em_beacons_medium_poles = {
    item = "electronic-circuit", machine = "electromagnetic-plant", beacon = "beacon",
    pole = "medium-electric-pole",
  },
  engine_fluid_small_poles = {
    item = "electric-engine-unit", machine = "assembling-machine-3", pole = "small-electric-pole",
  },
  foundry_turned_south = { item = "big-mining-drill", machine = "foundry" },
  gears_side_pairs = {
    item = "iron-gear-wheel", machine = "assembling-machine-3", module = "speed-module-3",
    beacon = "beacon", inserter = "fast-inserter",
  },
  gears_network_minutes = {
    item = "iron-gear-wheel", machine = "assembling-machine-2", inserter = "inserter",
    cap_mode = "network", size_mode = "minutes",
  },
  accumulator_above_only_substation = {
    item = "accumulator", machine = "electromagnetic-plant", beacon = "beacon", beacons_side = 0,
    pole = "substation",
  },
}

-- Captured from the tree before the split on 2026-11-28 (Factorio 2.1.25), and kept as a
-- standing pin: a digest that moves means a single cell moved. A mismatch logs the whole
-- serialisation (APL-GOLDEN in the data dir's log) for a diff against the old one. Game data
-- reaches these too -- pace, request amounts, warnings -- so after a game update that moves
-- them, check the diff is the game's and re-capture in a change of its own; a case added
-- unpinned fails naming the digest to paste here.
local PINNED = {
  accumulator_above_only_substation = "1172:1289382486:10419316",
  circuits_em_beacons_medium_poles = "3161:679255960:906446547",
  engine_fluid_small_poles = "1214:495106960:102533957",
  foundry_turned_south = "1509:1110139125:123539554",
  gears_network_minutes = "1077:45981275:400257922",
  gears_plain = "871:257974499:580824801",
  gears_side_pairs = "2595:1573011892:514797836",
  roboport_quality_split = "1492:681234190:415118166",
}

describe("single-cell plans are frozen", function()
  before_all(function() research.full(game.forces.player) end)

  local names = {}
  for name in pairs(CASES) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    test(name, function()
      local p, message = plan.build(game.forces.player, game.surfaces["nauvis"], CASES[name])
      assert(p, "golden '" .. name .. "' refused: " .. serpent.line(message))
      local digest = fingerprint.of(p)
      if PINNED[name] ~= digest then
        log("APL-GOLDEN " .. name .. " " .. fingerprint.text(p))
      end
      assert(PINNED[name] == digest,
        "plan golden '" .. name .. "' is " .. digest .. ", pinned " .. tostring(PINNED[name]))
    end)
  end
end)
