-- Belt plans end to end, frozen: planner.plan at full research for a spread of choices, each
-- digested whole -- entities, poles, wires, conditions, the stats. Captured from the tree
-- before the bot layout threaded a layout kind through the planner (2026-11-27), so the
-- builder threading, the layout-aware gates and the reach and memo changes are proven to
-- leave every belt plan exactly as it was. The pure belt_golden_spec does the same for the
-- builder alone; this one covers what only the planner adds.

local planner = require("scripts.planner")
local research = require("tests.support.research")
local fingerprint = require("tests.support.fingerprint")

local function force()
  return game.forces.player
end

local function choices_with(overrides)
  local choices = {
    recipe = "iron-gear-wheel", quality = "rare",
    machine = "assembling-machine-3", recycler = "recycler",
  }
  for key, value in pairs(overrides or {}) do choices[key] = value end
  return choices
end

local CASES = {
  gears_rare = {},
  gears_legendary_no_tap = { quality = "legendary" },
  battery_fluid_beacons = {
    recipe = "battery", machine = "chemical-plant", pole = "substation",
    beacon = "beacon", beacon_count = 2,
  },
  circuits_capped = {
    circuit_enabled = true, circuit_min_normal = 20, circuit_min_uncommon = 10,
    circuit_max_rare = 200,
  },
  circuits_network_paused = {
    circuit_enabled = true, circuit_max_rare = 200, circuit_network = true,
    circuit_paused = true,
  },
  columns_and_opt_outs = {
    column_count_normal = 3, column_count_uncommon = 2,
    stock_requests = false, terminal_requests = false, buffer_stock = false,
  },
  electronic_circuit_split = {
    recipe = "electronic-circuit", machine = "electromagnetic-plant", quality = "epic",
    quality_module = "quality-module-3", quality_module_quality = "legendary",
  },
  six_ingredients = { recipe = "fusion-reactor-equipment", inserter = "fast-inserter" },
}

-- Captured from the pristine tree on 2026-11-27 (Factorio 2.1.23; unchanged on 2.1.25). Empty
-- means "not captured yet": the test then fails naming the digest to paste here. Game data
-- reaches these digests too -- pace, yield, request amounts -- so a game update that moves
-- them is re-captured in a commit of its own, and a mismatch logs the whole serialisation for
-- a diff against the old one.
local PINNED = {
  battery_fluid_beacons = "16321:717547332:313810497",
  circuits_capped = "16286:564959162:96370762",
  circuits_network_paused = "15581:825285333:326203614",
  columns_and_opt_outs = "18503:1503730355:998225203",
  electronic_circuit_split = "14972:1960812400:615564338",
  gears_legendary_no_tap = "15971:1188262433:672533448",
  gears_rare = "10886:877082684:480630172",
  six_ingredients = "13983:1575750207:959429355",
}

describe("belt plans are frozen", function()
  before_all(function() research.full(force()) end)

  local names = {}
  for name in pairs(CASES) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    test(name, function()
      local plan = planner.plan(force(), choices_with(CASES[name]))
      assert(plan, "plan failed for golden '" .. name .. "'")
      local digest = fingerprint.of(plan)
      if PINNED[name] ~= digest then
        log("UPL-GOLDEN " .. name .. " " .. fingerprint.text(plan))
      end
      assert(PINNED[name] == digest,
        "plan golden '" .. name .. "' is " .. digest .. ", pinned " .. tostring(PINNED[name]))
    end)
  end
end)
