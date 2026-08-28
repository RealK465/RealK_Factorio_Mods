-- Circuit limits: reserve and cap, decorating a finished plan. Opt-in, off by default.
--
-- Two rules, both the owner's (2026-08-26, correcting the first-shipped cascade). The CAP:
-- every machine and every recycler is enabled only while the output chest holds fewer than
-- the maximum of the product at the TARGET quality -- one shared condition, so the whole
-- loop stops at the cap and wakes on its own as bots draw the chest down. The RESERVES: each
-- tier's reserve inserter -- stock chest to recycler -- is enabled only while that tier's
-- product count is ABOVE its minimum, so the loop never grinds a tier's stock below what the
-- player asked to keep -- a floor held by the inserter, where the machines run free below the
-- cap. A zero minimum means no reserve, and that tier's inserter is left unwired entirely.
--
-- Combinator-free because the layout already separates what the conditions need: the stock
-- chests hold exactly one tier's product each, the output chest alone holds the target's,
-- and a wire signal is distinct per quality -- so every rule above is a single comparison,
-- and the census needs no reading config at all (a wired chest broadcasts by default).
--
-- Pure like layout.lua and poles.lua: plain tables in, plain fields out, nothing from game
-- state -- the planner resolves wire reach from prototypes and hands it in. The fields written
-- are blueprint-shaped already (control_behavior passes through the serialiser verbatim;
-- circuit_wire_to is a plan index beside wire_to), so this file needs no defines:
-- blueprint.lua owns the connector id.
--
-- Strictly AFTER the pole pass, never solved with it: circuits change no geometry -- no width,
-- no height, no entity -- which is what lets this be a true decorator where poles could not be.

local circuits = {}

local function centre(e)
  return e.dx + e.w / 2, e.dy + e.h / 2
end

local function span(a, b)
  local ax, ay = centre(a)
  local bx, by = centre(b)
  return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Blueprint shape, not runtime shape: the field is circuit_enabled here where a live entity
-- calls it circuit_enable_disable -- the same rename trap as the belt's read mode
-- (analysis/api.md S21), so a spec reading a ghost back must use the runtime name.
local function gate(product, quality, comparator, count)
  return {
    circuit_enabled = true,
    circuit_condition = {
      comparator = comparator,
      constant = count,
      first_signal = { type = "item", name = product, quality = quality },
    },
  }
end

-- entities: plan.entities, mutated in place. Only entries layout.build tagged (circuit_role +
-- circuit_tier) are touched; everything else is left alone, which a pure spec pins.
--
-- opts: tiers -- the plan's quality names, normal first, one entry per PHYSICAL column with
-- repeats allowed (the planner's expanded array, parallel to the circuit_tier tags; the
-- GUI's wizard stays keyed by the distinct chain, and the two agree on the values resolved
-- per quality name, not on array shape); minimums -- quality name -> reserve floor, SPARSE:
-- the planner normalises "zero
-- means off" before calling, so an absent tier simply has no reserve and its inserter stays
-- out of the network; maximum -- the cap counted in the output chest at the TARGET quality,
-- gating every machine and recycler, or nil for no cap at all (they then stay ungated and
-- unwired, and each reserve is its own two-entity island reading only its own chest);
-- product -- the item the conditions count; reach -- tiles, the shortest circuit wire
-- distance among the wired prototypes, since a wire is refused past its shorter end.
--
-- Returns how many tagged entities no wire could reach: 0 normally, more on extreme modded
-- footprints. An unwired entity simply runs without its limit -- an enable condition with no
-- connected network gates nothing -- so the planner reports the count as a warning, never a
-- refusal.
function circuits.decorate(entities, opts)
  local tiers, minimums = opts.tiers, opts.minimums
  local target = tiers[#tiers]

  local machines, recyclers, censuses, reserves, ring = {}, {}, {}, {}, {}
  for index, e in ipairs(entities) do
    if e.circuit_role == "machine" then machines[e.circuit_tier] = index end
    if e.circuit_role == "recycler" then recyclers[e.circuit_tier] = index end
    if e.circuit_role == "census" then censuses[e.circuit_tier] = index end
    if e.circuit_role == "reserve" then reserves[e.circuit_tier] = index end
    if e.circuit_role == "ring" then ring[#ring + 1] = index end
  end

  -- Off is ABSENCE, on both sides: a tier missing from minimums keeps no reserve, a nil
  -- maximum caps nothing. The planner owns the zero-means-off normalisation, so this file
  -- never re-interprets a player value -- and cannot disagree with the reach the planner
  -- resolved from the same tables.
  local capped = opts.maximum ~= nil
  local function reserve_at(k)
    return minimums[tiers[k]] and reserves[k] or nil
  end

  -- Conditions first, independent of the wiring: harmless on an entity a wire never reaches,
  -- since an unconnected enable condition leaves the entity running normally. Machines and
  -- recyclers all stop at the one cap; each reserve inserter holds its own tier's floor.
  if capped then
    for _, set in pairs({ machines, recyclers }) do
      for _, index in pairs(set) do
        entities[index].control_behavior = gate(opts.product, target, "<", opts.maximum)
      end
    end
  end
  for k = 1, #tiers do
    local reserve = reserve_at(k)
    if reserve then
      entities[reserve].control_behavior =
        gate(opts.product, tiers[k], ">", minimums[tiers[k]])
      -- The floor must sit INSIDE the chest's logistic request: with trash-unrequested on,
      -- bots skim anything above the requested amount, so a floor past the request could
      -- never fill and the tier would silently stop recycling. Raising the request by the
      -- floor keeps the working-stock band on top of what the player keeps -- and on the
      -- first tier it makes the bots actively deliver toward the floor, which is what
      -- "keep this many in the chest" asks for.
      local census = censuses[k] and entities[censuses[k]]
      if census and census.requests and census.requests[1] then
        census.requests[1].count = census.requests[1].count + minimums[tiers[k]]
      end
    end
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
  -- by the machine+recycler band alone, never by pitch. With no cap only the reserves need
  -- wires at all.
  for k = 1, #tiers do
    link(reserve_at(k), censuses[k])
    if capped then
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
  if capped then
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

  return unlinked
end

return circuits
