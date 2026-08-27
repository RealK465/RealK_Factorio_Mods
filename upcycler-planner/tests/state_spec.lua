-- state.lua: the storage shape and prune-by-membership.
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

describe("state.prune -- drop what no longer qualifies", function()
  after_each(function() state.forget(IDX) end)

  local function seeded(choices)
    local entry = state.of(IDX)
    entry.choices = choices
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
      inserter = "fast-inserter",
      requester = "requester-chest",
      stock = "buffer-chest",
      container = "steel-chest",
      provider = "passive-provider-chest",
      machine_quality = "uncommon",
      inserter_quality = "rare",
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
    assert(c.inserter == "fast-inserter", "inserter pruned wrongly")
    assert(c.requester == "requester-chest", "requester pruned wrongly")
    assert(c.stock == "buffer-chest", "stock chest pruned wrongly")
    assert(c.container == "steel-chest", "plain chest pruned wrongly")
    assert(c.provider == "passive-provider-chest", "provider pruned wrongly")
    assert(c.inserter_quality == "rare", "inserter_quality pruned wrongly")
    assert(c.trash_unrequested == false, "boolean choice touched by prune")
  end)

  test("the snapshot 0.3.1 left behind is cleared", function()
    -- Not a field this version writes: prune is where a save made before the blueprint flow
    -- loses it, so the "choices and nothing else" promise holds for an upgraded save.
    local entry = seeded({ recipe = "iron-gear-wheel" })
    entry.pending = { recipe = "iron-gear-wheel" }
    state.prune()
    assert(entry.pending == nil, "the legacy snapshot survived a configuration change")
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
      inserter = "stack-inserter",       -- builds belt stacks
      requester = "steel-chest",         -- plain chest in a logistic role
      stock = "requester-chest",         -- the wrong KIND while buffer_stock reads true
      container = "requester-chest",     -- logistic chest in the plain role
      provider = "requester-chest",      -- the wrong logistic mode
      inserter_quality = "not-a-quality",
      container_quality = "not-a-quality",
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
    assert(c.inserter == nil, "belt-stacking inserter survived")
    assert(c.requester == nil, "plain chest survived in a logistic role")
    assert(c.stock == nil, "a requester survived in the buffered stock role")
    assert(c.container == nil, "logistic chest survived in the plain role")
    assert(c.provider == nil, "requester chest survived as the provider")
    -- Matched by key, not listed by name: every *_quality choice is pruned, including ones
    -- added after prune was written.
    assert(c.inserter_quality == nil, "bogus inserter quality survived")
    assert(c.container_quality == nil, "bogus chest quality survived")
  end)

  test("the stock role prunes by the kind the checkbox picks", function()
    -- The same name is valid under one flag and stale under the other; the flag rides in the
    -- same choices table, so prune reads each player's own answer, never a global.
    local unbuffered = seeded({ buffer_stock = false, stock = "requester-chest" })
    local buffered = state.of(IDX + 1)
    buffered.choices = { buffer_stock = true, stock = "requester-chest" }
    state.prune()
    state.forget(IDX + 1)
    assert(unbuffered.choices.stock == "requester-chest",
      "the unbuffered requester pick was pruned")
    assert(unbuffered.choices.buffer_stock == false, "the checkbox choice was touched by prune")
    assert(buffered.choices.stock == nil, "a requester survived the buffered flag")
  end)

  test("the terminal module prunes by module membership; the explicit clears survive", function()
    -- Membership is ALL modules, not the quality role: whether the machine and recipe accept
    -- the pick is validate's business, so a speed module must survive here. The two booleans
    -- are plain choices, never prototype references -- prune must not touch them.
    local entry = seeded({
      terminal_module = "iron-plate",
      no_terminal_module = true,
      no_poles = true,
    })
    state.prune()
    assert(entry.choices.terminal_module == nil, "a plain item survived as the terminal module")
    assert(entry.choices.no_terminal_module == true, "the explicit module clear was lost")
    assert(entry.choices.no_poles == true, "the explicit pole clear was lost")

    entry = seeded({ terminal_module = "speed-module" })
    state.prune()
    assert(entry.choices.terminal_module == "speed-module",
      "a real module was pruned -- membership must be all modules, not one role")
  end)

  test("circuit reserves and caps prune by the quality in their KEY; the enable flag survives", function()
    -- circuit_min_/circuit_max_<quality> hold numbers, so the value-based _quality$ sweep
    -- cannot cover them -- the tier a mod removed has to be read out of the key itself.
    local entry = seeded({
      circuit_enabled = true,
      circuit_min_rare = 200,
      circuit_min_gone = 25,
      circuit_max_epic = 50,
      circuit_max_gone = 9,
    })
    state.prune()
    local c = entry.choices
    assert(c.circuit_enabled == true, "the enable flag was lost -- booleans are not pruned")
    assert(c.circuit_min_rare == 200, "a live tier's reserve was pruned")
    assert(c.circuit_min_gone == nil, "a removed tier's reserve survived")
    assert(c.circuit_max_epic == 50, "a live tier's cap was pruned")
    assert(c.circuit_max_gone == nil, "a removed tier's cap survived")
  end)

  test("ingredient-amount overrides prune by the chosen recipe's own ingredients", function()
    -- request_<item> holds the player's number for one of the CHOSEN recipe's ingredients,
    -- claimed structurally in the key loop like the circuit families. Gears eat iron plates
    -- and nothing else, so a copper override is a leftover and goes; with no recipe at all,
    -- every override goes -- the formula default needs no key to fall back to.
    local entry = seeded({
      recipe = "iron-gear-wheel",
      ["request_iron-plate"] = 42,
      ["request_copper-plate"] = 9,
    })
    state.prune()
    local c = entry.choices
    assert(c.recipe == "iron-gear-wheel", "premise: the recipe survived")
    assert(c["request_iron-plate"] == 42, "a live ingredient's override was pruned")
    assert(c["request_copper-plate"] == nil, "an override survived leaving the recipe")

    entry = seeded({ ["request_iron-plate"] = 42 })
    state.prune()
    assert(entry.choices["request_iron-plate"] == nil,
      "an override survived with no recipe to belong to")
  end)

  test("the beacon prunes by membership; a pruned one reads as off; the clear flag survives", function()
    local entry = seeded({
      beacon = "beacon",
      beacon_module = "speed-module",
      beacon_quality = "not-a-quality",
      no_beacon_module = true,
    })
    state.prune()
    local c = entry.choices
    assert(c.beacon == "beacon", "a real beacon was pruned")
    -- Module membership is all modules, the terminal module's rule -- whether the beacon
    -- accepts it is validate's business.
    assert(c.beacon_module == "speed-module", "a real module was pruned from the beacon")
    -- The generic _quality$ sweep must cover the new keys without a hand-added line.
    assert(c.beacon_quality == nil, "a bogus beacon quality survived")
    assert(c.no_beacon_module == true, "the explicit module clear was lost")

    entry = seeded({ beacon = "stone-wall", beacon_module = "iron-plate" })
    state.prune()
    assert(entry.choices.beacon == nil, "a wall survived as the beacon")
    assert(entry.choices.beacon_module == nil, "a plain item survived as the beacon module")
  end)
end)
