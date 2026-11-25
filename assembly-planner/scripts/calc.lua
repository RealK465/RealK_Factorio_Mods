-- The planner's arithmetic, with nothing of the game in it: crafting pace, ingredient amounts
-- and beacon transmission from plain numbers. PURE, so tests/pure runs it on host Lua.

local calc = {}

-- No speed penalty takes a machine below a fifth of its own speed (documented engine floor;
-- not measured here).
calc.MIN_SPEED = 0.2

-- Blueprint request counts are int32; the engine clamps past it, this keeps the number the
-- planner shows the number the chest gets.
calc.INT32_MAX = 2147483647

function calc.speed_multiplier(speed_bonus)
  return math.max(calc.MIN_SPEED, 1 + speed_bonus)
end

function calc.crafts_per_minute(crafting_speed, speed_bonus, energy)
  if not (energy and energy > 0) then return 0 end
  return 60 * crafting_speed * calc.speed_multiplier(speed_bonus) / energy
end

-- How many of one ingredient the requester keeps: `value` crafts' worth, or `value` minutes of
-- crafting at the machine's real pace. Whole items, at least one. The epsilon keeps a product
-- that lands a hair above a whole number (non-integer speeds) from ceiling up a whole item.
function calc.request_amount(amount, mode, value, crafts_per_minute)
  local wanted
  if mode == "minutes" then
    wanted = amount * value * crafts_per_minute
  else
    wanted = amount * value
  end
  wanted = math.ceil(wanted - 1e-9)
  return math.max(1, math.min(wanted, calc.INT32_MAX))
end

-- What `count` beacons of one kind hand every machine they reach, on one effect axis: each
-- beacon's slots times the module's per-slot effect, scaled by the beacon's distribution
-- effectivity and by its profile entry for that many beacons (the engine's own transmission
-- arithmetic -- documented, not measured).
function calc.beacon_effect(per_module, slots, count, effectivity, profile)
  if count < 1 or slots < 1 then return 0 end
  local factor = 1
  if profile and #profile > 0 then factor = profile[math.min(count, #profile)] end
  return per_module * slots * count * effectivity * factor
end

-- Slots a list of requests fills: { count, stack_size } each, one stack per stack size.
function calc.slots_needed(requests)
  local slots = 0
  for _, request in pairs(requests) do
    slots = slots + math.ceil(request.count / request.stack_size)
  end
  return slots
end

return calc
