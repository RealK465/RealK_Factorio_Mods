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

-- Crafts a minute as the window shows them: one decimal while small.
function calc.format_rate(value)
  if value < 10 then return string.format("%.1f", value) end
  return string.format("%d", math.floor(value + 0.5))
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

-- Ticks for one round trip of an inserter between two adjacent tiles: half a turn each way, or
-- the hand's change of reach when that is slower. Each leg ends a tick short of the turn's own
-- count: 2 * (ceil(0.5 / rotation) - 1) fits every row of the wiki's 2.0.26 chest-to-chest
-- table, a fast inserter's 24 ticks among them. The epsilon keeps an exact count (long-handed:
-- 25) from ceiling up through float noise. nil when the arm cannot turn.
function calc.swing_ticks(rotation, extension, reach)
  if not (rotation and rotation > 0) then return nil end
  local leg = 0.5 / rotation
  if extension and extension > 0 and reach and reach > 0 then
    leg = math.max(leg, reach / extension)
  end
  return 2 * math.max(1, math.ceil(leg - 1e-6) - 1)
end

-- What each of `n` chests requests of an ingredient the cell wants `total` of: an even share,
-- but never less than one load, or the whole request when that is smaller -- so adding a chest
-- never shrinks what a swing carries (.ai-support/throughput-design.md, Requests).
function calc.chest_share(total, n, load)
  return math.max(math.ceil(total / n), math.min(total, load))
end

-- Each of `n` capped output chests' part of the slot cap. At least one slot: a chest with none
-- would stop its inserter for good.
function calc.cap_share(value, n)
  return math.max(1, math.ceil(value / n))
end

-- The items of one product a craft yields on average: productivity on the part it applies to,
-- the extra-count chance, and both probabilities. `product` is a plain ItemProduct table.
function calc.expected_count(product, productivity)
  local base = product.amount or ((product.amount_min or 0) + (product.amount_max or 0)) / 2
  local ignored = math.min(product.ignored_by_productivity or 0, base)
  local bonus = 1 + (productivity or 0)
  local count = ignored + (base - ignored) * bonus + (product.extra_count_fraction or 0) * bonus
  local shared = product.shared_probability
  local chance = (product.independent_probability or 1) * (shared and (shared.max - shared.min) or 1)
  return count * chance
end

-- How many inserters each role gets and the crafts a second they allow. `roles` holds
-- { spc, count } per role -- swings a craft needs, and the inserters the cell starts with, 0
-- for a role it lacks. Room goes one inserter at a time to the role allowing the fewest
-- crafts until every role keeps up with `pace` or the room runs out. Then each role is cut back
-- to what the final rate needs, so an inserter that bought nothing -- one of two tied roles
-- grown alone -- is never placed.
function calc.allocate(roles, pace, per_second, room)
  local counts = {}
  for i, role in ipairs(roles) do counts[i] = role.count end
  local function capacity(i)
    local spc = roles[i].spc
    if counts[i] == 0 or spc <= 0 then return math.huge end
    return counts[i] * per_second / spc
  end
  while room > 0 do
    local worst, lowest
    for i in ipairs(roles) do
      local c = capacity(i)
      if not lowest or c < lowest then worst, lowest = i, c end
    end
    if not worst or lowest >= pace - 1e-9 then break end
    counts[worst] = counts[worst] + 1
    room = room - 1
  end
  local rate = pace
  for i in ipairs(roles) do rate = math.min(rate, capacity(i)) end
  for i, role in ipairs(roles) do
    if role.count > 0 and role.spc > 0 then
      counts[i] = math.max(role.count, math.ceil(rate * role.spc / per_second - 1e-9))
    end
  end
  return { counts = counts, rate = rate }
end

return calc
