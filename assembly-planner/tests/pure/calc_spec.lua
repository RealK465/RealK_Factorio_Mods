-- calc.lua as pure arithmetic.

local calc = require("scripts.calc")

describe("calc", function()
  test("speed never drops below a fifth", function()
    assert(calc.speed_multiplier(-2) == calc.MIN_SPEED, "no floor")
    assert(calc.speed_multiplier(0.5) == 1.5, "bonus not added")
  end)

  test("crafts a minute follow speed and recipe time", function()
    assert(calc.crafts_per_minute(1.25, 0, 0.5) == 150, "AM3 gears")
    assert(calc.crafts_per_minute(1, 0, 0) == 0, "a zero-time recipe must not divide by zero")
  end)

  test("crafts mode: the amount times the craft count", function()
    assert(calc.request_amount(2, "crafts", 3, 99) == 6, "K2 battery MK2's steel at 3 crafts")
    assert(calc.request_amount(20, "crafts", 4, 0) == 80, "big mining drill's tungsten carbide at 4 crafts")
  end)

  test("minutes mode: the amount at the real pace, whole items, at least one", function()
    assert(calc.request_amount(2, "minutes", 2, 150) == 600, "two minutes of AM3 gears")
    assert(calc.request_amount(1, "minutes", 1, 0.1) == 1, "the floor is one")
    -- 0.1 * 30 is a hair above 3 in floating point; it must not ceil to 4.
    assert(calc.request_amount(1, "minutes", 30, 0.1) == 3, "a float hair ceiled up a whole item")
  end)

  test("beacon transmission scales by slots, count, effectivity and profile", function()
    assert(calc.beacon_effect(0.5, 2, 1, 1.5, { 1, 0.7071 }) == 1.5, "one vanilla beacon of speed 3s")
    local four = calc.beacon_effect(0.5, 2, 4, 1.5, { 1, 0.7071, 0.5773, 0.5 })
    assert(math.abs(four - 3) < 1e-9, "four beacons: " .. four)
    assert(calc.beacon_effect(0.5, 2, 9, 1.5, { 1, 0.5 }) == 0.5 * 2 * 9 * 1.5 * 0.5,
      "a count past the profile uses its last entry")
    assert(calc.beacon_effect(0.5, 0, 4, 1.5, nil) == 0, "an empty beacon transmits nothing")
  end)

  test("slots needed: one stack per stack size, rounded up", function()
    assert(calc.slots_needed({ { count = 101, stack_size = 100 }, { count = 50, stack_size = 50 } }) == 3,
      "wrong slot count")
  end)
end)

describe("calc throughput", function()
  local function near(a, b) return math.abs(a - b) < 1e-9 end

  test("swing time matches the wiki's 2.0 chest-to-chest table", function()
    -- Ticks per round trip, normal to legendary, measured there on 2.0.26. The multipliers are
    -- the default 1 + 0.3 * level, legendary at level 5.
    local multipliers = { 1, 1.3, 1.6, 1.9, 2.5 }
    local rows = {
      { name = "burner", rotation = 0.013, extension = 0.035, ticks = { 76, 58, 48, 40, 30 } },
      { name = "inserter", rotation = 0.014, extension = 0.035, ticks = { 70, 54, 44, 36, 28 } },
      { name = "long-handed", rotation = 0.02, extension = 0.05, ticks = { 48, 38, 30, 26, 18 } },
      { name = "fast", rotation = 0.04, extension = 0.1, ticks = { 24, 18, 14, 12, 8 } },
    }
    for _, row in ipairs(rows) do
      for i, m in ipairs(multipliers) do
        local got = calc.swing_ticks(row.rotation * m, row.extension * m, 0.2)
        assert(got == row.ticks[i], row.name .. " x" .. m .. ": " .. tostring(got) .. ", wanted " .. row.ticks[i])
      end
    end
  end)

  test("a slow extension sets the swing", function()
    assert(calc.swing_ticks(0.04, 0.005, 0.2) == 2 * (40 - 1), "the extension leg was ignored")
  end)

  test("no rotation, no swing", function()
    assert(calc.swing_ticks(0, 0.1, 0.2) == nil, "a still arm swings")
    assert(calc.swing_ticks(nil, 0.1, 0.2) == nil, "a missing rotation swings")
  end)

  test("a chest's share: even when large, a copy when small, a load between", function()
    assert(calc.chest_share(8, 1, 12) == 8, "one chest takes the whole request")
    assert(calc.chest_share(8, 2, 12) == 8, "a request below a load is copied into each chest")
    assert(calc.chest_share(3813, 2, 12) == 1907, "a large request is shared evenly")
    assert(calc.chest_share(20, 2, 12) == 12, "between one load and two, each chest holds a load")
    assert(calc.chest_share(25, 2, 12) == 13, "past two loads the share rounds up")
    assert(calc.chest_share(1, 3, 12) == 1, "a single item is copied")
  end)

  test("the slot cap is shared, at least one slot each", function()
    assert(calc.cap_share(2, 1) == 2 and calc.cap_share(2, 2) == 1, "the cap is not shared")
    assert(calc.cap_share(1, 2) == 1, "a chest was left with no slot")
    assert(calc.cap_share(5, 2) == 3, "the share does not round up")
  end)

  test("expected products count productivity and probabilities", function()
    assert(calc.expected_count({ amount = 2 }, 0) == 2, "plain amount")
    assert(near(calc.expected_count({ amount = 2 }, 0.5), 3), "productivity")
    assert(calc.expected_count({ amount_min = 1, amount_max = 3 }, 0) == 2, "a range counts its middle")
    assert(near(calc.expected_count({ amount = 1, independent_probability = 0.5 }, 0), 0.5), "probability")
    assert(near(calc.expected_count({ amount = 2, ignored_by_productivity = 1 }, 1), 3),
      "productivity applied to the ignored part")
    assert(near(calc.expected_count({ amount = 1, extra_count_fraction = 0.5 }, 0), 1.5), "extra count")
    assert(near(calc.expected_count({ amount = 4, shared_probability = { min = 0, max = 0.25 } }, 0), 1),
      "shared probability")
  end)

  test("the allocator adds what the pace needs and stops", function()
    local result = calc.allocate({ { spc = 2 / 12, count = 1 }, { spc = 1 / 12, count = 1 } }, 15.89, 2.5, 1)
    assert(result.counts[1] == 2 and result.counts[2] == 1,
      "gears want two inputs and one output, got " .. result.counts[1] .. "/" .. result.counts[2])
    assert(near(result.rate, 15.89), "the rate should reach the pace: " .. result.rate)
  end)

  test("the allocator spends room on the bottleneck first", function()
    local result = calc.allocate({ { spc = 2 / 3, count = 1 }, { spc = 0.918 / 3, count = 1 },
      { spc = 0.082 / 3, count = 1 } }, 10.4, 2.5, 6)
    assert(result.counts[1] == 3 and result.counts[2] == 2 and result.counts[3] == 1,
      "wanted 3/2/1, got " .. result.counts[1] .. "/" .. result.counts[2] .. "/" .. result.counts[3])
    assert(near(result.rate, 10.4), "the rate should reach the pace: " .. result.rate)
  end)

  test("an extra that buys nothing is pruned", function()
    local tied = function() return { { spc = 0.5, count = 1 }, { spc = 0.5, count = 1 } } end
    local one = calc.allocate(tied(), 8, 2.5, 1)
    assert(one.counts[1] == 1 and one.counts[2] == 1, "room for one of two tied roles kept a useless extra")
    assert(near(one.rate, 5), "rate " .. one.rate)
    local two = calc.allocate(tied(), 8, 2.5, 2)
    assert(two.counts[1] == 2 and two.counts[2] == 2 and near(two.rate, 8), "two tied roles did not grow together")
  end)

  test("no room: the rate is what the inserters move", function()
    local result = calc.allocate({ { spc = 2, count = 1 } }, 10.4, 2.5, 0)
    assert(result.counts[1] == 1 and near(result.rate, 1.25), "rate " .. result.rate)
  end)

  test("crafts a minute read with one decimal while small", function()
    assert(calc.format_rate(9.94) == "9.9" and calc.format_rate(0.5) == "0.5", "small rates lost their decimal")
    assert(calc.format_rate(953.4) == "953" and calc.format_rate(375) == "375", "large rates kept a decimal")
  end)

  test("a role that is absent never grows", function()
    local result = calc.allocate({ { spc = 0, count = 0 }, { spc = 1, count = 1 } }, 10, 2.5, 3)
    assert(result.counts[1] == 0 and result.counts[2] == 4, "counts " .. result.counts[1] .. "/" .. result.counts[2])
    assert(near(result.rate, 10), "rate " .. result.rate)
  end)
end)
