-- Expected-value maths for the per-tier module split: which mix of quality and productivity
-- modules each tier's machine should carry, and what the loop yields per input. PURE like
-- layout.lua -- plain values in, no prototypes.*, no defines -- so it runs on the host
-- interpreter and the recursion is pinned by sub-second specs. The engine enters through ONE
-- injected function, params.roll_chances(tier_name, effect), which planner.lua wraps around
-- LuaQualityPrototype.get_roll_chances (its measured semantics: analysis/api.md §30).
--
-- The model (analysis/quality-math.md; the wiki's transition matrices, solved exactly):
-- crafting one ingredient-set at tier j yields (1+p_j) * R products rolled upward by the
-- machine's quality effect; recycling one product returns S ingredient-sets rolled upward by
-- the recyclers' effect. Product at or above the target exits with value 1 -- the target via
-- the output chest, overshoot via the tap, both successes. Ingredients rolled ABOVE the
-- target are lost to the loop (the tap takes them; no machine crafts them), value 0;
-- ingredients rolled TO the target feed the terminal machine deterministically.
--
-- Quality never goes down (no negative quality_limits.low, no previous_probability in this
-- modset), so tiers resolve top-down: at tier j the pair (w_j, u_j) -- value per
-- ingredient-set and per product item -- is two linear equations in two unknowns given the
-- tiers above, closed form. And the split chosen at tier j moves nothing above j, while every
-- value below j is monotone in (w_j, u_j) -- so maximising w_j greedily per tier IS the
-- global optimum: O(tiers x slots) roll calls, the mid-tier value sweep quadratic in the
-- chain length, measured ~106 ms at the 254-tier modded ceiling -- comfortably out of hang
-- territory (the pole-solve lesson), where a search over every combination would not be.

local quality_math = {}

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

-- The engine's own defaults for EffectReceiver limits; nothing in the SA modset sets them,
-- but a modded machine may (api.md §30), so the caller can pass params.limits.
local function limit_pair(limits, key, default_low)
  local pair = limits and limits[key] or nil
  return (pair and pair.low) or default_low, (pair and pair.high) or 1000
end

-- One owner for the productivity cap sequence: receiver limits, then the recipe cap --
-- built-in bonus and research both count TOWARD it, never on top -- then the zero floor.
-- Shared by the per-tier candidates and the terminal machine, so the rule cannot drift
-- between them.
local function cap_productivity(params, raw)
  local p_low, p_high = limit_pair(params.limits, "productivity", -0.8)
  local productivity = clamp(raw, p_low, p_high)
  productivity = math.min(productivity, params.max_productivity or 1000)
  if productivity < 0 then productivity = 0 end
  return productivity
end

-- One machine configuration's summed effects: q quality modules and p productivity modules,
-- each contributing BOTH effect axes -- a modded hybrid module carries the cross terms, and
-- for the vanilla families they are simply zero.
local function machine_effects(params, q, p)
  local base = params.base or {}
  local qm, pm = params.quality_module, params.productivity_module
  local q_low, q_high = limit_pair(params.limits, "quality", 0)

  local quality = (base.quality or 0)
    + q * ((qm and qm.quality) or 0) + p * ((pm and pm.quality) or 0)
  quality = clamp(quality, q_low, q_high)
  if quality < 0 then quality = 0 end

  local productivity = cap_productivity(params,
    (base.productivity or 0) + (params.research_productivity or 0)
    + q * ((qm and qm.productivity) or 0) + p * ((pm and pm.productivity) or 0))

  return quality, productivity
end

-- The solve. params, all plain data:
--   tiers                array of quality names, normal first, target last
--   slots                machine module slots (at build quality)
--   quality_module       { quality, productivity } per-slot effects, engine-scaled
--   productivity_module  same, or nil -- nil means the split is forced all-quality
--   terminal             { productivity } per-slot for the terminal machine's module, or nil
--   base                 machine effect_receiver.base_effect as { quality, productivity }
--   research_productivity  force.recipes[...].productivity_bonus
--   max_productivity     the recipe's cap
--   limits               { quality = {low, high}, productivity = {low, high} } or nil
--   recycler_effect      summed quality effect on the recyclers
--   products_per_set     R: products one craft yields
--   sets_per_recycle     S: ingredient-sets one recycled product returns (vanilla: 1 / (4R))
--   roll_chances         function(tier_name, effect) -> { tier_name -> probability }
--
-- overrides is a sparse array over tier INDEX (1..#tiers-1): a present entry pins that
-- tier's productivity count instead of searching, which is how the GUI's per-tier edits and
-- the display's what-if evaluation both ride the same solve.
--
-- Returns the effective productivity counts (dense, 1..#tiers-1) and the yield:
-- per_set = expected target-or-above products per tier-1 ingredient-set, per_item = the same
-- per tier-1 product item recycled in -- the wiki's own "items per legendary" is 1/per_item.
-- When the loop has any output, the yield also carries the expected work per target item:
-- machine_sets[j] = ingredient-sets the tier-j machine crafts, recycled[j] = items the
-- tier-j recycler eats, both per one target-or-above product out -- the flow pass below.
function quality_math.solve(params, overrides)
  local tiers = params.tiers
  local T = #tiers
  local R = params.products_per_set or 1
  local S = params.sets_per_recycle or 0
  local slots = params.slots or 0
  local roll = params.roll_chances
  overrides = overrides or {}

  -- The terminal machine crafts from target-quality ingredients, so its whole output is
  -- target quality: pure yield, no roll. Its module is the terminal picker's, not the split's.
  local base = params.base or {}
  local terminal_p = cap_productivity(params,
    (base.productivity or 0) + (params.research_productivity or 0)
    + slots * ((params.terminal and params.terminal.productivity) or 0))

  local w, u, prods = {}, {}, {}
  w[T], u[T] = (1 + terminal_p) * R, 1
  if T < 2 then
    local yield = { per_set = w[T], per_item = 1 }
    if w[T] > 1e-9 then
      yield.machine_sets, yield.recycled = { 1 / w[T] }, {}
    end
    return prods, yield
  end

  local recycler_effect = math.max(params.recycler_effect or 0, 0)

  -- The chosen split's distributions, kept for the flow pass: re-rolling them there would
  -- repeat the engine calls the memo exists to avoid.
  local chosen, r_dists = {}, {}

  for j = T - 1, 1, -1 do
    -- The recyclers' roll from this tier is split-independent, so it is priced once per tier.
    -- Always indexed by tier NAME, never iterated: the dictionary's order is not a contract.
    local r_dist = roll(tiers[j], recycler_effect)
    r_dists[j] = r_dist
    local r_stay = r_dist[tiers[j]] or 0
    local r_above = (r_dist[tiers[T]] or 0) * w[T]
    for k = j + 1, T - 1 do
      r_above = r_above + (r_dist[tiers[k]] or 0) * w[k]
    end

    local best_w, best_u, best_p
    local first, last = 0, slots
    local forced = overrides[j]
    -- No productivity module beats a forced override: a stale split_prod_<tier> can outlive
    -- a switch to a recipe that refuses productivity (tier names are shared across recipes),
    -- and honouring it would price slots as wasted that the built plan gives to quality --
    -- an understated yield for a blueprint that is actually fine. layout.split_modules
    -- enforces the same invariant on the build side.
    if not params.productivity_module then
      last = 0
    elseif forced ~= nil then
      first = clamp(forced, 0, slots)
      last = first
    end

    -- Ascending, keeping the first maximum: an exact tie goes to the quality-heavy split,
    -- which is what keeps the vanilla early game byte-identical to the old flat rule.
    for p = first, last do
      local qe, pe = machine_effects(params, slots - p, p)
      local c_dist = roll(tiers[j], qe)
      local c_stay = c_dist[tiers[j]] or 0
      local c_mid_sum, c_mid_value = 0, 0
      for k = j + 1, T - 1 do
        local chance = c_dist[tiers[k]] or 0
        c_mid_sum = c_mid_sum + chance
        c_mid_value = c_mid_value + chance * u[k]
      end
      -- Target-and-above as the complement, not a key sweep: the dictionary lists only
      -- positive entries, and the measured distribution sums to 1.
      local c_top = 1 - c_stay - c_mid_sum
      if c_top < 0 then c_top = 0 end

      -- w_j = (1+p)R [c_mid_value + c_top + c_stay * u_j], u_j = S [r_stay * w_j + r_above]:
      -- two linear equations, closed form. D <= 0 means a modded loop that GAINS mass every
      -- lap -- value unbounded -- so it is floored to keep the comparison finite and ordered
      -- rather than dividing into NaN.
      local gain = (1 + pe) * R
      local D = 1 - gain * S * c_stay * r_stay
      if D < 1e-9 then D = 1e-9 end
      local wj = gain * (c_mid_value + c_top + c_stay * S * r_above) / D
      local uj = S * (r_stay * wj + r_above)

      if not best_w or wj > best_w then
        best_w, best_u, best_p = wj, uj, p
        chosen[j] = { c_dist = c_dist, c_stay = c_stay, gain = gain }
      end
    end

    w[j], u[j], prods[j] = best_w, best_u, best_p
  end

  local yield = { per_set = w[1], per_item = u[1] }

  -- The flow pass: expected crafts, forward through the very distributions the chosen splits
  -- were priced with. Per one tier-1 ingredient-set fed, sets[j] is what the tier-j machine
  -- crafts and recycled[j] what the tier-j recycler eats; each tier's own craft-recycle
  -- self-loop is the same linear equation as the value pass -- same denominator, same floor.
  -- Products rolled to target-or-above exit uncounted, recycler rolls past the target are
  -- lost: the asymmetry the value pass prices, mirrored as flow.
  if w[1] > 1e-9 then
    local sets_in, products_in = {}, {}
    for j = 1, T do
      sets_in[j], products_in[j] = 0, 0
    end
    sets_in[1] = 1
    local sets, recycled = {}, {}
    for j = 1, T - 1 do
      local pick = chosen[j]
      local r_dist = r_dists[j]
      local r_stay = r_dist[tiers[j]] or 0
      local D = 1 - pick.gain * S * pick.c_stay * r_stay
      if D < 1e-9 then D = 1e-9 end
      sets[j] = (sets_in[j] + products_in[j] * S * r_stay) / D
      recycled[j] = products_in[j] + sets[j] * pick.gain * pick.c_stay
      for k = j + 1, T - 1 do
        products_in[k] = products_in[k] + sets[j] * pick.gain * (pick.c_dist[tiers[k]] or 0)
      end
      for k = j + 1, T do
        sets_in[k] = sets_in[k] + recycled[j] * S * (r_dist[tiers[k]] or 0)
      end
    end
    sets[T] = sets_in[T]

    -- Normalised to one target item out, which is what a rate display divides by.
    local machine_sets, per_item_recycled = {}, {}
    for j = 1, T do machine_sets[j] = sets[j] / w[1] end
    for j = 1, T - 1 do per_item_recycled[j] = recycled[j] / w[1] end
    yield.machine_sets, yield.recycled = machine_sets, per_item_recycled
  end

  return prods, yield
end

return quality_math
