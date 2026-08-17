-- state.lua: the storage shape, Confirm's snapshot, and prune-by-membership.
-- All of this is player-free by design -- storage.players is a plain table keyed by index, so
-- the specs seed it directly. Prune tests membership in the planner's candidate lists, which
-- are prototype-level and force-independent (the memoised half of the H5 split), so no
-- research state is needed here.

local state = require("scripts.state")

-- A player index no real player will ever hold; forget() in after_each keeps runs independent.
local IDX = 9999

describe("state.of and forget", function()
  after_each(function() state.forget(IDX) end)

  test("of() creates an entry with empty choices on first touch", function()
    assert(storage.players[IDX] == nil, "test index unexpectedly in use")
    local entry = state.of(IDX)
    assert(entry.choices, "entry has no choices table")
    assert(next(entry.choices) == nil, "choices not empty")
    assert(storage.players[IDX] == entry, "entry not stored")
  end)

  test("forget() drops the entry entirely", function()
    state.of(IDX)
    state.forget(IDX)
    assert(storage.players[IDX] == nil, "entry survived forget()")
  end)
end)

describe("state.arm -- the Confirm snapshot", function()
  after_each(function() state.forget(IDX) end)

  test("pending is a copy: later edits to choices do not reach it", function()
    local entry = state.of(IDX)
    entry.choices.recipe = "iron-gear-wheel"
    entry.choices.quality = "rare"
    state.arm(IDX)
    entry.choices.recipe = "iron-stick"
    assert(entry.pending.recipe == "iron-gear-wheel", "snapshot followed the live choices")
    assert(entry.pending.quality == "rare", "snapshot lost a field")
  end)

  test("the copy is a whole-table loop: a novel key is not left behind", function()
    -- The H5 regression: arm() used to copy a named field list, so a newly added choice
    -- could be silently missing from the snapshot. The loop shape is the fix.
    local entry = state.of(IDX)
    entry.choices.some_future_choice = "value"
    state.arm(IDX)
    assert(entry.pending.some_future_choice == "value", "novel key missing from snapshot")
  end)
end)

describe("state.prune -- drop what no longer qualifies", function()
  after_each(function() state.forget(IDX) end)

  local function seeded(choices)
    local entry = state.of(IDX)
    entry.choices = choices
    entry.pending = { recipe = "iron-gear-wheel" }
    return entry
  end

  test("valid choices survive", function()
    local entry = seeded({
      recipe = "iron-gear-wheel",
      machine = "assembling-machine-2",
      recycler = "recycler",
      belt = "transport-belt",
      pipe = "pipe",
      quality = "rare",
      quality_module = "quality-module",
      pole = "small-electric-pole",
      machine_quality = "uncommon",
      trash_unrequested = false,
    })
    state.prune()
    local c = entry.choices
    assert(c.recipe == "iron-gear-wheel", "recipe pruned wrongly")
    assert(c.machine == "assembling-machine-2", "machine pruned wrongly")
    assert(c.recycler == "recycler", "recycler pruned wrongly")
    assert(c.belt == "transport-belt", "belt pruned wrongly")
    assert(c.pipe == "pipe", "pipe pruned wrongly")
    assert(c.quality == "rare", "quality pruned wrongly")
    assert(c.quality_module == "quality-module", "module pruned wrongly")
    assert(c.pole == "small-electric-pole", "pole pruned wrongly")
    assert(c.machine_quality == "uncommon", "machine_quality pruned wrongly")
    assert(c.trash_unrequested == false, "boolean choice touched by prune")
  end)

  test("names that exist but do not qualify are dropped", function()
    -- Every one of these is a real prototype of the wrong kind -- the prune contract is
    -- membership, not existence (a steel furnace exists; it is still not a machine here).
    local entry = seeded({
      recipe = "steel-plate",             -- self-recycling: not upcyclable
      machine = "steel-furnace",          -- no module slots
      recycler = "assembling-machine-1",  -- does not recycle
      belt = "iron-chest",
      pipe = "transport-belt",
      quality = "not-a-quality",
      quality_module = "speed-module",
      pole = "stone-wall",
      pole_quality = "not-a-quality",
    })
    state.prune()
    local c = entry.choices
    assert(c.recipe == nil, "non-upcyclable recipe survived")
    assert(c.machine == nil, "moduleless furnace survived as machine")
    assert(c.recycler == nil, "non-recycler survived")
    assert(c.belt == nil, "chest survived as belt")
    assert(c.pipe == nil, "belt survived as pipe")
    assert(c.quality == nil, "bogus quality survived")
    assert(c.quality_module == nil, "speed module survived as quality module")
    assert(c.pole == nil, "wall survived as pole")
    assert(c.pole_quality == nil, "bogus build quality survived")
  end)

  test("prune always clears pending", function()
    local entry = seeded({ recipe = "iron-gear-wheel" })
    state.prune()
    assert(entry.pending == nil, "pending survived a configuration change")
  end)
end)
