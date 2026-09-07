-- Circuit limits: reserve and cap, decorating a finished plan. Opt-in, off by default.
--
-- Two rules, both the owner's (2026-08-26, correcting the first-shipped cascade). The CAP:
-- every machine and every recycler is enabled only while the output chest holds fewer than
-- the maximum of the product at the TARGET quality -- one shared condition, so the whole
-- loop stops at the cap and wakes on its own as bots draw the chest down. The RESERVES: each
-- tier's reserve inserter -- stock chest to recycler -- is enabled only while that tier's
-- product count is at or above its minimum PLUS the inserter's hand size, and the inserter is
-- pinned to that hand, so a full grab lands exactly on the floor and never below it (the
-- owner's call on a portal report, 2026-09-07: a 12-item bulk hand checked against a bare
-- minimum of 20 left 8 in the chest). The floor is held by the inserter, where the machines
-- run free below the cap. A zero minimum means no reserve, and that tier's inserter is left
-- unwired and unpinned entirely.
--
-- The numbers live on ONE constant combinator (2026-09-07, a portal request): a signal-M row
-- per reserved tier at that tier's quality -- the minimum plus the hand -- and a signal-C
-- row at the target's, and every
-- condition compares the product count against the matching signal rather than a baked
-- constant -- so a stamped loop is retuned in the combinator, and switching the combinator
-- off drops C to 0, which stops every gated machine: the loop's pause switch. With a cap,
-- two lamps and a display panel read the same signal -- blue while the loop runs, green once
-- the chest holds the cap, the panel spelling out running / done / paused (a C of 0 can only
-- mean the combinator is off) with an icon the map shows too.
--
-- What stays combinator-free is the LOGIC: the layout already separates what the conditions
-- need -- the stock chests hold exactly one tier's product each, the output chest alone holds
-- the target's, and a wire signal is distinct per quality -- so every rule is one comparison,
-- no decider anywhere, and the census needs no reading config at all (a wired chest
-- broadcasts by default).
--
-- Pure like layout.lua and poles.lua: plain tables in, plain fields out, nothing from game
-- state -- the planner resolves wire reach from prototypes and hands it in. The fields written
-- are blueprint-shaped already (control_behavior, color, the panel's words pass through the
-- serialiser verbatim; circuit_wire_to is a plan index beside wire_to), so this file needs no
-- defines: blueprint.lua owns the connector id. The combinator's description and the panel's
-- words are blueprint strings, which no locale key can reach -- English, kept short.
--
-- Strictly AFTER the pole pass, never solved with it: every entity this touches was stood by
-- layout.build, so nothing here moves a tile -- which is what lets this be a true decorator
-- where poles could not be.

local circuits = {}

local SIGNAL_MIN = "signal-M"
local SIGNAL_CAP = "signal-C"

local COMBINATOR_DESCRIPTION = "Upcycler limits. M = minimum kept of that quality plus the "
  .. "inserter hand size, C = maximum in the output chest. Switch off to pause the loop."
local COLOR_DONE = { r = 0, g = 1, b = 0, a = 1 }
local COLOR_RUNNING = { r = 0.15, g = 0.45, b = 1, a = 1 }
local ICON_DONE = { type = "virtual", name = "signal-check" }
local ICON_PAUSED = { type = "virtual", name = "signal-deny" }

local function centre(e)
  return e.dx + e.w / 2, e.dy + e.h / 2
end

local function span(a, b)
  local ax, ay = centre(a)
  local bx, by = centre(b)
  return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

local function product_signal(product, quality)
  return { type = "item", name = product, quality = quality }
end

local function threshold_signal(name, quality)
  return { type = "virtual", name = name, quality = quality }
end

-- Blueprint shape, not runtime shape: the field is circuit_enabled here where a live entity
-- calls it circuit_enable_disable -- the same rename trap as the belt's read mode
-- (analysis/api.md S21), so a spec reading a ghost back must use the runtime name.
local function gate(product, quality, comparator, threshold)
  return {
    circuit_enabled = true,
    circuit_condition = {
      comparator = comparator,
      first_signal = product_signal(product, quality),
      second_signal = threshold,
    },
  }
end

-- The combinator's rows, chain order so two identical plans decorate identically: signal-M
-- at each reserved quality -- the minimum plus the hand, the number the reserve inserter
-- really runs at -- then signal-C at the target's. tiers is the expanded per-column
-- array, so a repeated quality is written once. Absence IS "zero means off" -- the planner
-- stripped every zero before this ran, so a tier without a row keeps no reserve, and the
-- player adds one later by adding the row.
local function rows_of(tiers, minimums, maximum, hand)
  local rows, seen = {}, {}
  for k = 1, #tiers - 1 do
    local quality = tiers[k]
    if minimums[quality] and not seen[quality] then
      seen[quality] = true
      rows[#rows + 1] = {
        index = #rows + 1, type = "virtual", name = SIGNAL_MIN, quality = quality,
        comparator = "=", count = minimums[quality] + hand,
      }
    end
  end
  if maximum then
    rows[#rows + 1] = {
      index = #rows + 1, type = "virtual", name = SIGNAL_CAP, quality = tiers[#tiers],
      comparator = "=", count = maximum,
    }
  end
  return rows
end

-- entities: plan.entities, mutated in place. Only entries layout.build tagged (circuit_role,
-- plus circuit_tier on the per-column ones) are touched; everything else is left alone,
-- which a pure spec pins.
--
-- opts: tiers -- the plan's quality names, normal first, one entry per PHYSICAL column with
-- repeats allowed (the planner's expanded array, parallel to the circuit_tier tags; the
-- GUI's wizard stays keyed by the distinct chain, and the two agree on the values resolved
-- per quality name, not on array shape); minimums -- quality name -> reserve floor, SPARSE:
-- the planner normalises "zero means off" before calling, so an absent tier simply has no
-- reserve and its inserter stays out of the network; maximum -- the cap counted in the
-- output chest at the TARGET quality, gating every machine and recycler, or nil for no cap
-- at all (they then stay ungated, and the layout stood no lamps or panel); paused -- ship
-- the combinator switched off; product -- the item the conditions count; hand -- items per
-- swing of the reserve inserters: every M row is the minimum plus it and every reserved
-- inserter is pinned to it, required whenever a minimum is set (api.md S33); reach -- tiles,
-- the shortest circuit wire distance among the wired prototypes, since a wire is refused
-- past its shorter end.
--
-- Returns how many tagged entities no wire could reach: 0 normally, more on extreme modded
-- footprints. An unwired entity simply runs without its limit -- an enable condition with no
-- connected network gates nothing -- so the planner reports the count as a warning, never a
-- refusal.
function circuits.decorate(entities, opts)
  local tiers, minimums = opts.tiers, opts.minimums
  local target = tiers[#tiers]

  local machines, recyclers, censuses, reserves, ring = {}, {}, {}, {}, {}
  local limits, lamp_done, lamp_running, panel
  for index, e in ipairs(entities) do
    local role = e.circuit_role
    if role == "machine" then machines[e.circuit_tier] = index end
    if role == "recycler" then recyclers[e.circuit_tier] = index end
    if role == "census" then censuses[e.circuit_tier] = index end
    if role == "reserve" then reserves[e.circuit_tier] = index end
    if role == "ring" then ring[#ring + 1] = index end
    if role == "limits" then limits = index end
    if role == "lamp_done" then lamp_done = index end
    if role == "lamp_running" then lamp_running = index end
    if role == "panel" then panel = index end
  end

  -- Off is ABSENCE, on both sides: a tier missing from minimums keeps no reserve, a nil
  -- maximum caps nothing. The planner owns the zero-means-off normalisation, so this file
  -- never re-interprets a player value -- and cannot disagree with the reach the planner
  -- resolved from the same tables.
  local capped = opts.maximum ~= nil
  local function reserve_at(k)
    return minimums[tiers[k]] and reserves[k] or nil
  end

  -- A reserve without its hand would gate on a bare minimum again -- the dip this file
  -- exists to close -- so the planner has to hand one over whenever a minimum is set.
  local hand = opts.hand
  assert(next(minimums) == nil or (type(hand) == "number" and hand >= 1),
    "circuits.decorate: a reserve needs the inserter hand size")

  -- The layout stands the stack from the same tables the planner built these opts from. A
  -- decoration whose combinator is missing would ship conditions against a signal nothing
  -- emits -- every machine stopped for good -- so the mismatch is a bug, never a degraded
  -- plan, and it fails here rather than in a stamped loop.
  assert(limits and (not capped or (lamp_done and lamp_running and panel)),
    "circuits.decorate: the layout stood no circuit stack for these limits")

  -- Conditions first, independent of the wiring: harmless on an entity a wire never reaches,
  -- since an unconnected enable condition leaves the entity running normally. Machines and
  -- recyclers all stop at the one cap; each reserve inserter holds its own tier's floor.
  local cap = capped and threshold_signal(SIGNAL_CAP, target) or nil
  if capped then
    for _, set in pairs({ machines, recyclers }) do
      for _, index in pairs(set) do
        entities[index].control_behavior = gate(opts.product, target, "<", cap)
      end
    end
  end
  for k = 1, #tiers do
    local reserve = reserve_at(k)
    if reserve then
      -- ">=" against minimum + hand: the inserter checks its condition at pickup and then
      -- takes a whole hand, so the threshold is where a full grab lands exactly on the
      -- floor. Pinning the hand is what makes that arithmetic hold -- the engine caps a
      -- hand at what research allows, so a pin past it merely over-keeps until the research
      -- lands, and a pin below it is what makes a hand typed smaller than research real.
      entities[reserve].control_behavior =
        gate(opts.product, tiers[k], ">=", threshold_signal(SIGNAL_MIN, tiers[k]))
      entities[reserve].override_stack_size = hand
      -- The threshold must sit INSIDE the chest's logistic request: with trash-unrequested
      -- on, bots skim anything above the requested amount, so a threshold past the request
      -- could never be reached and the tier would silently stop recycling. Raising the
      -- request by it keeps the working-stock band on top of what the player keeps -- and
      -- on the first tier it makes the bots actively deliver toward the floor, which is what
      -- "keep this many in the chest" asks for.
      local census = censuses[k] and entities[censuses[k]]
      if census and census.requests and census.requests[1] then
        census.requests[1].count = census.requests[1].count + minimums[tiers[k]] + hand
      end
    end
  end

  -- The combinator carries the numbers every condition above compares against. Written as
  -- an explicit branch: `paused and false or nil` would read nil either way, false being
  -- falsy -- the same idiom trap layout.lua's terminal module already notes.
  local combinator = entities[limits]
  combinator.control_behavior = {
    sections = { sections = { { index = 1, filters = rows_of(tiers, minimums, opts.maximum, hand) } } },
  }
  if opts.paused then combinator.control_behavior.is_on = false end
  combinator.player_description = COMBINATOR_DESCRIPTION

  -- The indicators, capped plans only: the lamps split on the one comparison the machines
  -- make, and the panel asks "paused" first because a C of 0 would read as done for any
  -- chest -- the panel shows the first row whose condition holds, its own icon and words
  -- otherwise. always_on lifts the lamps' night-only rule; the condition still gates them
  -- (measured, tests/loop_spec.lua).
  if capped then
    local done, running, board = entities[lamp_done], entities[lamp_running], entities[panel]
    done.color = COLOR_DONE
    done.always_on = true
    done.control_behavior = gate(opts.product, target, ">=", cap)
    running.color = COLOR_RUNNING
    running.always_on = true
    running.control_behavior = gate(opts.product, target, "<", cap)
    board.icon = product_signal(opts.product, target)
    board.text = "Running"
    board.always_show = true
    board.show_in_chart = true
    board.control_behavior = { parameters = {
      { condition = { comparator = "=", first_signal = cap, constant = 0 },
        icon = ICON_PAUSED, text = "Paused" },
      { condition = { comparator = ">=", first_signal = product_signal(opts.product, target),
          second_signal = cap },
        icon = ICON_DONE, text = "Done" },
    } }
  end

  -- One outgoing link per entity, wire_to's own shape: the network is a tree, so a parent
  -- index each is enough, and blueprint.lua writes both ends exactly as it does for copper.
  --
  -- Half a tile of margin against the reach, because WHERE the engine measures a wire is
  -- unrecorded: the reach itself is measured (api.md S26), but whether it spans entity
  -- centres or the off-centre connector points is not, and the widest vanilla pitch (a
  -- substation, beacon and pipe column) puts a spine hop at exactly 9.0 centre-to-centre.
  -- The margin turns an exact-boundary hop into a relay or an honest unlinked count, where
  -- guessing wrong would drop the wire silently at build and split the network unwarned.
  local usable = opts.reach - 0.5
  local unlinked = 0
  local function link(from, to)
    if not (from and to) then return end
    if span(entities[from], entities[to]) <= usable then
      entities[from].circuit_wire_to = to
    else
      unlinked = unlinked + 1
    end
  end

  -- Each tier's own stack, wired child-to-parent up the column: reserve inserter -> census
  -- chest -> recycler -> machine, the terminal census landing straight on its machine --
  -- link() ignoring a nil endpoint IS the terminal case, where no recycler stands. Bounded
  -- by the machine+recycler band alone, never by pitch. The whole loop joins one network
  -- whenever anything is gated: a reserve-only plan still has to hear the combinator, so
  -- its machines carry the wire ungated, as the relay belts do.
  local active = capped or next(minimums) ~= nil
  for k = 1, #tiers do
    link(reserve_at(k), censuses[k])
    if active then
      link(censuses[k], recyclers[k] or machines[k])
      link(recyclers[k], machines[k])
    end
  end

  -- The cross-tier spine rides the machine row: every machine shares its rows, so these hops
  -- are purely horizontal and stay inside vanilla wire reach whatever the band height -- the
  -- chest row cannot say the same, its hop to the output chest spanning the whole band. When
  -- a hop would exceed reach (a wide modded pitch, a fat utility column), the spine falls
  -- back to relaying along the top ring belts instead: hops of one tile whatever the width,
  -- each machine tapping the belt above it. A wired belt with no control_behavior neither
  -- reads nor gates -- it just carries the network.
  if active then
    local worst = 0
    for k = 1, #tiers - 1 do
      if machines[k] and machines[k + 1] then
        worst = math.max(worst, span(entities[machines[k]], entities[machines[k + 1]]))
      end
    end

    if worst <= usable then
      for k = 1, #tiers - 1 do
        link(machines[k], machines[k + 1])
      end
    else
      -- The top row of the ring, found by geometry rather than a row constant this file has
      -- no business knowing, chained left to right.
      local top_y = math.huge
      for _, i in ipairs(ring) do top_y = math.min(top_y, entities[i].dy) end
      local top = {}
      for _, i in ipairs(ring) do
        if entities[i].dy == top_y then top[#top + 1] = i end
      end
      table.sort(top, function(a, b) return entities[a].dx < entities[b].dx end)
      for j = 1, #top - 1 do
        entities[top[j]].circuit_wire_to = top[j + 1]
      end

      -- The tap is the machine's one outgoing link -- in relay mode it never links to the
      -- next machine, so the slot is free for the belt above its own centre. Machines and
      -- the sorted top row both run left to right, so one advancing pointer finds every
      -- nearest belt in a single pass -- a rescan per machine went quadratic at exactly the
      -- long-chain scale this branch exists for. Advancing only while STRICTLY closer keeps
      -- the leftmost of an equidistant pair, the rescan's own tie-break.
      local j = 1
      for k = 1, #tiers do
        local m = machines[k]
        if m then
          local mx = centre(entities[m])
          while j < #top
            and math.abs(entities[top[j + 1]].dx + 0.5 - mx)
              < math.abs(entities[top[j]].dx + 0.5 - mx) do
            j = j + 1
          end
          link(m, top[j])
        end
      end
    end
  end

  -- The stack hangs off the terminal machine a tile a hop -- lamps, panel, combinator in
  -- the order the layout stood them -- so no pitch or machine size can put the combinator
  -- out of reach. Its own link, never the spine's: the terminal machine still owns its
  -- outgoing slot up there.
  local chain = capped and { lamp_done, lamp_running, panel, limits } or { limits }
  local from = machines[#tiers]
  for _, index in ipairs(chain) do
    link(index, from)
    from = index
  end

  return unlinked
end

return circuits
