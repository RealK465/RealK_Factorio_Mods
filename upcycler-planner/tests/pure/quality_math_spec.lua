-- quality_math.solve as pure arithmetic: hand-built params, a stubbed roll function, no
-- prototypes and no force -- the engine's own get_roll_chances semantics are pinned separately
-- in planner_spec (api.md §30), and this file proves the recursion built on top of them.
--
-- The ground truth is a two-tier fixture small enough to solve by hand, then the wiki's own
-- published yields as looser cross-checks -- the one number set in this repo that was fetched
-- twice and matched (analysis/quality-math.md §2-3).

local quality_math = require("scripts.quality_math")
local deep_equal = require("tests.support.deep_equal")

local function close(a, b, tolerance)
  return math.abs(a - b) <= (tolerance or 1e-6)
end

-- The measured 2.1 roll maths as a stub: one-step chance = the summed effect, each further
-- step x 0.1, x 0.9 except into the chain's top, which absorbs the remainder.
local function vanilla_roll(chain)
  local index = {}
  for i, name in ipairs(chain) do index[name] = i end
  return function(tier, effect)
    local i = index[tier]
    local top = #chain
    if i == top then return { [tier] = 1 } end
    local dist = { [tier] = 1 - effect }
    local mass = effect
    for k = i + 1, top do
      if k == top then
        dist[chain[k]] = mass
      else
        dist[chain[k]] = mass * 0.9
        mass = mass * 0.1
      end
    end
    return dist
  end
end

-- The hand fixture: two tiers, machine rolls 20% at all-quality, recyclers 50%, quarter
-- returns, terminal at +100% productivity. Worked by hand:
--   w2 = (1 + 4 x 0.25) x 1 = 2,   r_above = 0.5 x 2 = 1
--   w1 = (0.2 + 0.8 x 0.25 x 1) / (1 - 0.25 x 0.8 x 0.5) = 0.4 / 0.9
--   u1 = 0.25 x (0.5 x w1 + 1)
local function hand_params(roll)
  return {
    tiers = { "n", "u" },
    slots = 4,
    quality_module = { quality = 0.05 },
    productivity_module = { productivity = 0.25 },
    terminal = { productivity = 0.25 },
    recycler_effect = 0.5,
    products_per_set = 1,
    sets_per_recycle = 0.25,
    max_productivity = 3,
    roll_chances = roll or vanilla_roll({ "n", "u" }),
  }
end

describe("quality_math.solve -- the recursion", function()
  test("the hand-computed two-tier fixture, at the all-quality override", function()
    local prods, yield = quality_math.solve(hand_params(), { 0 })
    assert(prods[1] == 0, "the override was not echoed: " .. tostring(prods[1]))
    assert(close(yield.per_set, 0.4 / 0.9), "per_set " .. yield.per_set)
    assert(close(yield.per_item, 0.25 * (0.5 * (0.4 / 0.9) + 1)), "per_item " .. yield.per_item)
  end)

  test("machine rolls past the walked chain count as success -- the tap's side", function()
    -- The machine's 20% lands on a tier name the chain does not carry; the complement rule
    -- must price it exactly like a roll to the target, so the yield matches the hand fixture.
    local params = hand_params(function(_, effect)
      if effect == 0.5 then return { n = 0.5, u = 0.5 } end
      return { n = 1 - effect, x = effect }
    end)
    local _, yield = quality_math.solve(params, { 0 })
    assert(close(yield.per_set, 0.4 / 0.9), "beyond-chain product priced wrong: " .. yield.per_set)
  end)

  test("recycler rolls past the target are lost -- the other side of the asymmetry", function()
    -- Half the recyclers' output lands beyond the target: no machine crafts it, so it must
    -- contribute NOTHING -- pricing it like the machine side would chase an undeliverable
    -- optimum.
    local params = hand_params(function(_, effect)
      if effect == 0.5 then return { n = 0.5, x = 0.5 } end
      return { n = 1 - effect, u = effect }
    end)
    local _, yield = quality_math.solve(params, { 0 })
    assert(close(yield.per_set, 0.2 / 0.9), "lost ingredients still valued: " .. yield.per_set)
    assert(close(yield.per_item, 0.25 * 0.5 * (0.2 / 0.9)), "per_item " .. yield.per_item)
  end)

  test("no productivity module forces every tier to all-quality", function()
    local params = hand_params()
    params.tiers = { "n", "u", "r" }
    params.roll_chances = vanilla_roll(params.tiers)
    params.productivity_module = nil
    local prods, yield = quality_math.solve(params)
    assert(#prods == 2 and prods[1] == 0 and prods[2] == 0,
      "forced all-quality came back as " .. tostring(prods[1]) .. "," .. tostring(prods[2]))
    assert(yield.per_set > 0, "the forced solve still yields")
  end)

  test("a stale override cannot outrank a missing productivity module", function()
    -- split_prod_<tier> keys outlive an item switch (tier names are shared), so a leftover
    -- override can meet a recipe that refuses productivity. The build already gives every
    -- slot to quality; the solve must price it the same way, or the yield line understates a
    -- perfectly good plan (~18% on this fixture, the review's own numbers).
    local params = hand_params()
    params.productivity_module = nil
    local prods, yield = quality_math.solve(params, { 2 })
    assert(prods[1] == 0, "the stale override was honoured: " .. tostring(prods[1]))
    assert(close(yield.per_set, 0.4 / 0.9),
      "the yield priced phantom productivity slots: " .. yield.per_set)
  end)

  test("the search flips to productivity when it genuinely wins, and an override beats it", function()
    -- A near-worthless quality module against a strong productivity module: every tier's
    -- optimum is all-productivity. Pinning quality back in by override must be respected and
    -- must cost yield.
    local params = hand_params()
    params.quality_module = { quality = 0.001 }
    local prods, best = quality_math.solve(params)
    assert(prods[1] == 4, "the search kept " .. prods[1] .. " productivity slots")

    local forced, worse = quality_math.solve(params, { 1 })
    assert(forced[1] == 1, "the override was not echoed")
    assert(worse.per_set <= best.per_set + 1e-12,
      "an override outperformed the optimum: " .. worse.per_set .. " > " .. best.per_set)
  end)

  test("an exact tie keeps the quality-heavy split", function()
    -- A REAL tie: both modules zero-effect, the machine's base carrying the only quality --
    -- every candidate then computes the identical w, and the first maximum (ascending p)
    -- must win, which is what keeps degenerate configs byte-identical to the old flat rule.
    local params = hand_params()
    params.quality_module = { quality = 0 }
    params.productivity_module = { productivity = 0 }
    params.base = { quality = 0.05 }
    local prods = quality_math.solve(params)
    assert(prods[1] == 0, "an exact tie still took " .. prods[1] .. " productivity slots")
  end)

  test("productivity clamps to the recipe cap; a negative base quality clamps to zero", function()
    -- Terminal at 4 x 2.5 = +1000% against a cap of 3: the yield must read (1 + 3) x R.
    local capped = hand_params()
    capped.tiers = { "u" }
    capped.terminal = { productivity = 2.5 }
    local _, yield = quality_math.solve(capped)
    assert(close(yield.per_set, 4), "the cap did not hold: " .. yield.per_set)

    -- A modded machine with a negative base quality effect: the summed effect floors at zero,
    -- so nothing ever rolls and the loop lives on the recyclers alone.
    local floored = hand_params()
    floored.base = { quality = -1 }
    floored.quality_module = { quality = 0 }
    floored.productivity_module = nil
    local _, y = quality_math.solve(floored, { 0 })
    assert(close(y.per_set, 0.25 / 0.875), "floored quality effect: " .. y.per_set)
  end)

  test("a better-than-break-even modded loop stays finite and ordered", function()
    -- Lossless recycler (S = 1) with capped +300% productivity: the loop gains mass every
    -- lap and the true value diverges. The denominator floor turns that into a huge finite
    -- number rather than a NaN, so the search still orders candidates.
    local params = {
      tiers = { "n", "u" },
      slots = 4,
      base = { quality = 0.05 },
      quality_module = { quality = 0 },
      productivity_module = { productivity = 0.75 },
      terminal = {},
      recycler_effect = 0.05,
      products_per_set = 1,
      sets_per_recycle = 1,
      max_productivity = 3,
      roll_chances = vanilla_roll({ "n", "u" }),
    }
    local prods, yield = quality_math.solve(params)
    assert(yield.per_set == yield.per_set and yield.per_item == yield.per_item,
      "the degenerate loop produced NaN")
    assert(yield.per_set > 1e6, "a diverging loop read as ordinary: " .. yield.per_set)
    assert(prods[1] == 4, "the diverging candidate did not win: " .. tostring(prods[1]))
  end)

  test("solving the same params twice is byte-identical", function()
    local params = hand_params()
    local prods_a, yield_a = quality_math.solve(params)
    local prods_b, yield_b = quality_math.solve(params)
    assert(deep_equal(prods_a, prods_b) and deep_equal(yield_a, yield_b),
      "two solves of one input disagreed")
  end)
end)

describe("quality_math.solve -- the flow pass", function()
  test("the hand fixture's expected crafts, conserving exactly one item out", function()
    -- Same fixture, worked forward by hand. Per one n-set fed: sets_1 = 1/0.9 = 10/9,
    -- recycled_1 = 10/9 x 0.8 = 8/9, sets_2 = 8/9 x 0.25 x 0.5 = 1/9. Output
    -- 10/9 x 0.2 + 1/9 x 2 = 4/9 = per_set, so per one item out: 2.5 sets at tier 1,
    -- 0.25 terminal sets, 2 items recycled -- and the overshoot (2.5 x 0.2 = 0.5) plus the
    -- terminal's own output (0.25 x 2 = 0.5) is the whole item, conservation by hand.
    local _, yield = quality_math.solve(hand_params(), { 0 })
    assert(close(yield.machine_sets[1], 2.5), "tier-1 sets " .. tostring(yield.machine_sets[1]))
    assert(close(yield.machine_sets[2], 0.25), "terminal sets " .. tostring(yield.machine_sets[2]))
    assert(close(yield.recycled[1], 2.0), "recycled items " .. tostring(yield.recycled[1]))
    assert(yield.recycled[2] == nil, "the target tier grew a recycler")
  end)

  test("a target-tier-only chain is terminal work alone", function()
    local params = hand_params()
    params.tiers = { "u" }
    local _, yield = quality_math.solve(params)
    -- per_set = (1 + 4 x 0.25) x 1 = 2, so half a set per item and nothing recycled.
    assert(close(yield.machine_sets[1], 0.5), "terminal sets " .. tostring(yield.machine_sets[1]))
    assert(next(yield.recycled) == nil, "a one-tier chain recycled something")
  end)

  test("a loop that can never roll up reports no flow at all", function()
    -- Zero effect on both sides: nothing ever reaches the target, per_set is zero, and the
    -- crafts-per-item arrays would be a division by it -- so they are absent, which is what
    -- the time display keys on.
    local params = hand_params()
    params.quality_module = { quality = 0 }
    params.productivity_module = nil
    params.recycler_effect = 0
    local _, yield = quality_math.solve(params, { 0 })
    assert(close(yield.per_set, 0), "a dead loop still yields " .. yield.per_set)
    assert(yield.machine_sets == nil and yield.recycled == nil,
      "a dead loop still reports expected crafts")
  end)
end)

describe("quality_math.solve -- the wiki cross-checks", function()
  local chain = { "normal", "uncommon", "rare", "epic", "legendary" }

  test("AM3 with normal q3/p3 modules, all-quality: about 2161 items per legendary", function()
    -- The wiki's own configuration and its own published yield (0.046275% per input item,
    -- quality-math.md §3). Its tables run ONE module quality throughout -- machines 4 x 0.025
    -- and recyclers 4 x 0.025 alike; the first run of this spec priced the recyclers at the
    -- legendary 0.248 and read 643 items per legendary, 3.4x too optimistic, which is what
    -- settled the assumption. Tolerance is loose because the wiki rounds where the engine
    -- does not.
    local _, yield = quality_math.solve({
      tiers = chain,
      slots = 4,
      quality_module = { quality = 0.025 },
      productivity_module = { productivity = 0.10 },
      terminal = { productivity = 0.10 },
      recycler_effect = 0.1,
      products_per_set = 1,
      sets_per_recycle = 0.25,
      max_productivity = 3,
      roll_chances = vanilla_roll(chain),
    }, { 0, 0, 0, 0 })
    local per_legendary = 1 / yield.per_item
    assert(math.abs(per_legendary - 2161) <= 110,
      "AM3 all-quality reads " .. per_legendary .. " items per legendary, wiki says ~2161")
  end)

  test("EM plant with legendary modules at the wiki's 1q+4p: about 37 items per legendary", function()
    local params = {
      tiers = chain,
      slots = 5,
      base = { productivity = 0.5 },
      quality_module = { quality = 0.062 },
      productivity_module = { productivity = 0.25 },
      terminal = { productivity = 0.25 },
      recycler_effect = 0.248,
      products_per_set = 1,
      sets_per_recycle = 0.25,
      max_productivity = 3,
      roll_chances = vanilla_roll(chain),
    }
    local _, wiki_config = quality_math.solve(params, { 4, 4, 4, 4 })
    local per_legendary = 1 / wiki_config.per_item
    assert(math.abs(per_legendary - 36.7) <= 2,
      "EM 1q+4p reads " .. per_legendary .. " items per legendary, wiki says ~36.7")

    -- The search may do better than the wiki's own table, never worse.
    local _, best = quality_math.solve(params)
    assert(best.per_item >= wiki_config.per_item - 1e-12,
      "the search lost to the wiki's fixed configuration")
  end)

  test("stronger modules shift the optimum productivity-ward", function()
    local function total_prod(quality_per_slot)
      local params = {
        tiers = chain,
        slots = 8,
        quality_module = { quality = quality_per_slot },
        productivity_module = { productivity = 0.25 },
        terminal = { productivity = 0.25 },
        recycler_effect = 8 * quality_per_slot,
        products_per_set = 1,
        sets_per_recycle = 0.25,
        max_productivity = 3,
        roll_chances = vanilla_roll(chain),
      }
      local prods = quality_math.solve(params)
      local sum = 0
      for _, p in pairs(prods) do sum = sum + p end
      return sum
    end
    assert(total_prod(0.0625) >= total_prod(0.01),
      "stronger quality modules moved the split quality-ward, against the measured direction")
  end)
end)

describe("quality_math.solve -- the modded ceiling", function()
  test("a 254-tier chain solves, stays finite, and is deterministic", function()
    local chain = {}
    for i = 1, 254 do chain[i] = "q-" .. i end
    local params = {
      tiers = chain,
      slots = 4,
      quality_module = { quality = 0.025 },
      productivity_module = { productivity = 0.10 },
      terminal = { productivity = 0.10 },
      recycler_effect = 0.1,
      products_per_set = 1,
      sets_per_recycle = 0.25,
      max_productivity = 3,
      roll_chances = vanilla_roll(chain),
    }
    local prods, yield = quality_math.solve(params)
    assert(#prods == 253, "prod counts for " .. #prods .. " of 253 tiers")
    for j, p in pairs(prods) do
      assert(p >= 0 and p <= 4 and p == math.floor(p),
        "tier " .. j .. " holds a nonsense count " .. tostring(p))
    end
    assert(yield.per_set == yield.per_set and yield.per_set >= 0, "long-chain yield went bad")

    local prods_b, yield_b = quality_math.solve(params)
    assert(deep_equal(prods, prods_b) and deep_equal(yield, yield_b),
      "the long chain solved differently twice")
  end)
end)
