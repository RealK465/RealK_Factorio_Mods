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
