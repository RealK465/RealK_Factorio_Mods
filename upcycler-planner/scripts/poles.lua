-- Places electric poles over a finished plan: enough of them, wired into one network, that
-- every machine, recycler and inserter has power -- belts, chests and pipes need none. PURE,
-- the same contract as layout.lua: no storage, no game state, so the same plan grows the same
-- poles on every client.
--
-- Deliberately blind to layout.lua's row plan: it asks "is this tile free?", discovered from
-- the plan's own entities, never "where is the buffer sub-column?". The one thing it accepts
-- from the layout is the utility-column list -- the dedicated columns the plan already sized
-- to the pole -- so poles prefer a tidy vertical line there and fall back to any free tile
-- only when the columns alone cannot cover.
--
-- Cover, then connect, then be honest. A greedy set cover picks positions (within ln(n)+1 of
-- the true minimum, which is NP-hard and nothing this small needs), a bridge pass joins stray
-- islands, and the reported shortfall counts a consumer as powered only when a pole of the
-- LARGEST connected network reaches it -- a covered consumer on an unwired island would be a
-- lie that only surfaces in game as a mystery.
--
-- Everything below is sized for the worst legal input, not the vanilla one: a modded quality
-- chain expanded by per-tier column counts is thousands of physical columns, and every term
-- that multiplies candidates by rounds, poles or columns has hung the game at that scale
-- (analysis/poles.md). The structures that keep each pass near-linear -- the per-column
-- indexes, the gain heap, the incremental reach lists -- are all exact: same picks, same
-- tie-breaks, same wires as the plain scans they replace, proven by parity sweep.

local poles = {}

-- The engine powers a consumer when its collision box OVERLAPS the supply square (measured,
-- api.md S10). Each consumer therefore carries a stand-in for its collision box -- its tile
-- rect shrunk by the margin the planner computed from the real prototype, always a SUBSET of
-- the real box -- so the test can under-promise (an extra pole, an over-honest warning) but
-- never credit a pole with a machine the game would leave dark.

-- Strict inequalities: an area that merely touches at the border covers nothing. Exported,
-- because the beacon-reach check in planner.lua is the same rule with a different origin
-- (api.md §25) and a second hand-maintained copy is how the two would drift.
local function overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1
end
poles.overlap = overlap

-- Candidates carry their centre precomputed (cx, cy): half a footprint in, the plan's own
-- rule, so odd sizes sit mid-tile and even ones on a tile boundary. Placed poles ARE
-- candidate references, so one field pair serves the reach tests, the spanning tree and the
-- supply square alike -- recomputing it per distance call was ~14% of a long-chain solve.
local function distance_sq(a, b)
  local dx, dy = a.cx - b.cx, a.cy - b.cy
  return dx * dx + dy * dy
end

local function covers(pole, p, consumer)
  local d = pole.supply_distance
  local m = consumer.margin
  return overlap(p.cx - d, p.cy - d, p.cx + d, p.cy + d,
    consumer.dx + m, consumer.dy + m,
    consumer.dx + consumer.w - m, consumer.dy + consumer.h - m)
end

local function occupied(entities)
  local occ = {}
  for _, e in pairs(entities) do
    for x = e.dx, e.dx + e.w - 1 do
      local column = occ[x]
      if not column then
        column = {}
        occ[x] = column
      end
      for y = e.dy, e.dy + e.h - 1 do column[y] = true end
    end
  end
  return occ
end

local function consumers_of(entities, consumer_margins)
  local out = {}
  for _, e in pairs(entities) do
    local margin = consumer_margins[e.name]
    if margin then
      out[#out + 1] = { dx = e.dx, dy = e.dy, w = e.w, h = e.h, margin = margin }
    end
  end
  return out
end

local function fits(occ, width, height, px, py, pole)
  if px < 0 or py < 0 or px + pole.width > width or py + pole.height > height then
    return false
  end
  for x = px, px + pole.width - 1 do
    local column = occ[x]
    if column then
      for y = py, py + pole.height - 1 do
        if column[y] then return false end
      end
    end
  end
  return true
end

-- Row-major scan order is load-bearing: every tie-break below is "first found in this order
-- wins", which is what makes the whole pass deterministic without tie-break tables.
local function candidate_positions(occ, width, height, pole)
  local out = {}
  local half_w, half_h = pole.width / 2, pole.height / 2
  for py = 0, height - pole.height do
    for px = 0, width - pole.width do
      if fits(occ, width, height, px, py, pole) then
        out[#out + 1] = { dx = px, dy = py, cx = px + half_w, cy = py + half_h }
      end
    end
  end
  return out
end

-- The one owner of "which utility column wholly contains this footprint". The columns arrive
-- from layout.build sorted by x and disjoint, so the only column that can contain it is the
-- last whose x is at or left of it -- a binary search, where the plain footprints-times-columns
-- scan grew quadratic with the physical column count. Exported for planner's held-column
-- credit in the shrink ladder, poles.overlap's own reason: a second hand-maintained copy of
-- the boundary rule is how the two passes would drift.
function poles.column_at(columns, dx, width)
  local lo, hi, found = 1, #columns, nil
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if columns[mid].x <= dx then
      found = columns[mid]
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  if found and dx + width <= found.x + found.width then return found end
  return nil
end

-- The candidates lying wholly inside a utility column -- the pole's own dedicated ground.
-- Pipes already sit in those columns as ordinary occupied tiles, so a fluid plan's east edge
-- excludes itself without this function knowing pipes exist.
local function within_columns(candidates, columns, pole)
  local kept = {}
  for index = 1, #candidates do
    local c = candidates[index]
    if poles.column_at(columns, c.dx, pole.width) then
      kept[#kept + 1] = c
    end
  end
  return kept
end

-- Consumer indices filed by tile column, so a candidate only asks about the consumers its
-- supply square could possibly reach. A consumer is filed under every column its tile rect
-- spans; a candidate queries the columns its supply square spans. That is always a superset
-- of the true answer -- a pole that covers a consumer must overlap it in x, and the margin
-- only ever shrinks the consumer inside the columns it was filed under -- so the list this
-- produces is exactly the list the plain scan produced.
--
-- A plan is one tier column per quality tier, so both the candidates and the consumers grow
-- with the tier count and the plain scan was their product. That was fine while the chain
-- was five tiers and unnoticeable at the 32 the planner used to cap it at; a mod that adds
-- 250 makes it the whole cost of the solve.
local function index_consumers(consumers)
  local columns = {}
  for i = 1, #consumers do
    local c = consumers[i]
    for x = math.floor(c.dx), math.ceil(c.dx + c.w) do
      local bucket = columns[x]
      if not bucket then
        bucket = {}
        columns[x] = bucket
      end
      bucket[#bucket + 1] = i
    end
  end
  return columns
end

-- One solve's derived state: the column index, built once, and the per-candidate coverage
-- lists, filled lazily.
local function memo_for(consumers)
  return { columns = index_consumers(consumers), lists = {} }
end

-- Which consumers a candidate covers, as an array of consumer indices, memoised in
-- `memo.lists` on first use. The geometry never changes while poles are placed -- only
-- membership in `uncovered` does -- so the greedy pass, the free-tile retry and the final
-- honesty tally all share one answer per candidate instead of re-running the overlap
-- arithmetic per round. Lazy rather than precomputed for the whole plan: a solve whose
-- utility columns already cover never asks about the free tiles at all. Keyed by the
-- candidate table itself, which every pass preserves.
--
-- `seen` is not an optimisation. A consumer wider than one tile is filed in several columns,
-- and counting it twice would inflate the greedy pass's gain and change which pole it picks.
local function coverage(memo, pole, candidate, consumers)
  local list = memo.lists[candidate]
  if not list then
    list = {}
    local d = pole.supply_distance
    local seen = {}
    for x = math.floor(candidate.cx - d), math.ceil(candidate.cx + d) do
      local bucket = memo.columns[x]
      if bucket then
        for bi = 1, #bucket do
          local i = bucket[bi]
          if not seen[i] then
            seen[i] = true
            if covers(pole, candidate, consumers[i]) then list[#list + 1] = i end
          end
        end
      end
    end
    memo.lists[candidate] = list
  end
  return list
end

-- A binary max-heap over (score, position) pairs, ordered score DESC then position ASC --
-- exactly the "first candidate in scan order wins a tie" rule every plain scan here kept, so
-- swapping a scan for the heap moves no pick. Two parallel arrays rather than entry tables:
-- the heap is the inner loop of both the greedy pass and the spanning tree. The spanning
-- tree wants (distance ASC, order ASC) and gets it from the same functions by negating the
-- distance.
local function heap_push(hs, hp, score, position)
  local i = #hs + 1
  hs[i], hp[i] = score, position
  while i > 1 do
    local parent = math.floor(i / 2)
    local ps, pp = hs[parent], hp[parent]
    if score > ps or (score == ps and position < pp) then
      hs[i], hp[i] = ps, pp
      hs[parent], hp[parent] = score, position
      i = parent
    else
      break
    end
  end
end

local function heap_pop(hs, hp)
  local n = #hs
  local top_s, top_p = hs[1], hp[1]
  local s, p = hs[n], hp[n]
  hs[n], hp[n] = nil, nil
  n = n - 1
  if n > 0 then
    local i = 1
    while true do
      local child = 2 * i
      if child > n then break end
      local cs, cp = hs[child], hp[child]
      local right = child + 1
      if right <= n then
        local rs, rp = hs[right], hp[right]
        if rs > cs or (rs == cs and rp < cp) then child, cs, cp = right, rs, rp end
      end
      if cs > s or (cs == s and cp < p) then
        hs[i], hp[i] = cs, cp
        i = child
      else
        break
      end
    end
    hs[i], hp[i] = s, p
  end
  return top_s, top_p
end

-- `>` and never `>=`: the first candidate in scan order to reach the best count keeps it --
-- here as the heap's tie rule rather than a rescanning loop. Gains are maintained exactly:
-- covering one consumer decrements the gain of every candidate that also covers it (the
-- transpose index), so a popped entry whose recorded gain still matches is the true maximum
-- and a stale one is re-filed at its current gain. Gains only ever decrease, which is what
-- makes the lazy re-file sound. The plain scan re-walked every candidate every round, and
-- both factors grow with the chain -- the whole cost of a long solve.
local function greedy_cover(candidates, consumers, pole, cover_of, dead, mark_dead)
  local placed = {}
  local uncovered, remaining = {}, #consumers
  for i = 1, #consumers do uncovered[i] = true end

  local gain, covering = {}, {}
  local heap_s, heap_p = {}, {}
  for ci = 1, #candidates do
    local list = coverage(cover_of, pole, candidates[ci], consumers)
    local g = #list
    gain[ci] = g
    if g > 0 then
      for li = 1, #list do
        local consumer = list[li]
        local bucket = covering[consumer]
        if not bucket then
          bucket = {}
          covering[consumer] = bucket
        end
        bucket[#bucket + 1] = ci
      end
      heap_push(heap_s, heap_p, g, ci)
    end
  end

  while remaining > 0 do
    local best
    while heap_s[1] do
      local g, ci = heap_pop(heap_s, heap_p)
      if not dead[candidates[ci]] then
        local current = gain[ci]
        if current == g then
          best = ci
          break
        elseif current > 0 then
          heap_push(heap_s, heap_p, current, ci)
        end
      end
    end
    if not best then break end

    local candidate = candidates[best]
    placed[#placed + 1] = candidate
    local list = cover_of.lists[candidate]
    for li = 1, #list do
      local consumer = list[li]
      if uncovered[consumer] then
        uncovered[consumer] = nil
        remaining = remaining - 1
        local bucket = covering[consumer]
        for bi = 1, #bucket do
          local cj = bucket[bi]
          gain[cj] = gain[cj] - 1
        end
      end
    end
    mark_dead(candidate)
  end

  return placed
end

-- Connected components over wire reach, members in ascending index order -- that order is
-- spanning_wires' tie-break vocabulary, so the bucketed neighbour walk collects, sorts and
-- only then visits, reproducing the plain ascending scan exactly. The buckets answer "which
-- poles could be in reach" by centre column, the coverage index's own superset argument; the
-- plain scan was poles squared, and the pole count tracks the physical column count.
local function components_of(placed, pole)
  local reach = pole.wire_distance
  local reach_sq = reach * reach
  local buckets = {}
  for i = 1, #placed do
    local x = math.floor(placed[i].cx)
    local bucket = buckets[x]
    if not bucket then
      bucket = {}
      buckets[x] = bucket
    end
    bucket[#bucket + 1] = i
  end

  local visited, components = {}, {}
  for start = 1, #placed do
    if not visited[start] then
      visited[start] = true
      local component, stack = { start }, { start }
      while #stack > 0 do
        local i = stack[#stack]
        stack[#stack] = nil
        local p = placed[i]
        local near = {}
        for x = math.floor(p.cx - reach), math.ceil(p.cx + reach) do
          local bucket = buckets[x]
          if bucket then
            for bi = 1, #bucket do
              local j = bucket[bi]
              if not visited[j] and distance_sq(p, placed[j]) <= reach_sq then
                near[#near + 1] = j
              end
            end
          end
        end
        table.sort(near)
        for ni = 1, #near do
          local j = near[ni]
          visited[j] = true
          component[#component + 1] = j
          stack[#stack + 1] = j
        end
      end
      components[#components + 1] = component
    end
  end
  return components
end

-- Joins stray islands: repeatedly the free position reaching the most separate components,
-- until one network remains or no position joins two. Terminates because the component count
-- strictly drops on every accepted pole.
--
-- The old pass rescanned every candidate against every placed pole every round, and the round
-- count, the candidate count and the pole count all grow with the chain -- what hung the game
-- on a 254-tier chain (a 5x5 machine and a medium pole: 82 s for one solve), and still most
-- of a big-columns solve after the first index. This one maintains the state exactly instead.
-- Each alive candidate carries its in-reach pole list (built once through column buckets,
-- appended to push-style when a pole lands near it) and its exact count of distinct
-- components touched, kept current under merges by relabelling only the SMALLER merged
-- components' poles and recounting only the candidates that reach them -- so a round costs
-- the merge's own size, never the candidate count. The pick comes off the shared lazy heap
-- ordered (count, then scan position): the same strict-improvement, first-in-scan-order rule
-- as the rescanning loop, and the accept threshold of two is the heap's admission rule, so
-- an empty heap is exactly the old "no position joins two" break.
local function bridge(placed, candidates, pole, dead, mark_dead, by_dx)
  local components = components_of(placed, pole)
  if #components <= 1 then return end

  local reach = pole.wire_distance
  local reach_sq = reach * reach

  -- Stable component labels: a merge keeps the largest component's label and relabels the
  -- rest, so counts can be maintained rather than recomputed -- labels never renumber the way
  -- the old per-round rebuild did, and which label survives cannot change any count, since a
  -- count only asks how many DISTINCT labels a list touches.
  local root_of, members = {}, {}
  for label, component in pairs(components) do
    members[label] = component
    for _, i in pairs(component) do root_of[i] = label end
  end
  local roots_left = #components

  local pole_columns = {}
  for i = 1, #placed do
    local x = math.floor(placed[i].cx)
    local bucket = pole_columns[x]
    if not bucket then
      bucket = {}
      pole_columns[x] = bucket
    end
    bucket[#bucket + 1] = i
  end

  -- Per alive candidate: the in-reach pole list, its transpose (which candidates reach a
  -- pole -- the recount obligations a merge or a new pole creates), and the exact distinct-
  -- label count. The stamp table serves every recount; bumping the stamp is the reset.
  local list_of, reached_by, count = {}, {}, {}
  local heap_s, heap_p = {}, {}
  local stamp, stamped = 0, {}
  local position_of = {}

  local function recount(position)
    local list = list_of[position]
    stamp = stamp + 1
    local c = 0
    for li = 1, #list do
      local label = root_of[list[li]]
      if stamped[label] ~= stamp then
        stamped[label] = stamp
        c = c + 1
      end
    end
    return c
  end

  for position = 1, #candidates do
    local candidate = candidates[position]
    if not dead[candidate] then
      position_of[candidate] = position
      local list = {}
      for x = math.floor(candidate.cx - reach), math.ceil(candidate.cx + reach) do
        local bucket = pole_columns[x]
        if bucket then
          for bi = 1, #bucket do
            local i = bucket[bi]
            if distance_sq(candidate, placed[i]) <= reach_sq then
              list[#list + 1] = i
              local rev = reached_by[i]
              if not rev then
                rev = {}
                reached_by[i] = rev
              end
              rev[#rev + 1] = position
            end
          end
        end
      end
      list_of[position] = list
      local c = recount(position)
      count[position] = c
      if c >= 2 then heap_push(heap_s, heap_p, c, position) end
    end
  end

  -- A changed count re-files the candidate at its current value; the entry at the old value
  -- pops as stale and drops. A candidate below two is not filed -- a later gain refiles it.
  local function refile(position)
    local c = recount(position)
    if c ~= count[position] then
      count[position] = c
      if c >= 2 then heap_push(heap_s, heap_p, c, position) end
    end
  end

  while roots_left > 1 do
    local best
    while heap_s[1] do
      local c, position = heap_pop(heap_s, heap_p)
      if not dead[candidates[position]] and c == count[position] then
        best = position
        break
      end
    end
    if not best then break end

    -- The winner's touched labels, deduplicated in first-appearance order, and the survivor:
    -- the largest merged component keeps its label -- the small-to-large rule that bounds
    -- the whole pass, since only the smaller components' poles relabel below.
    local best_list = list_of[best]
    stamp = stamp + 1
    local touched = {}
    for li = 1, #best_list do
      local label = root_of[best_list[li]]
      if stamped[label] ~= stamp then
        stamped[label] = stamp
        touched[#touched + 1] = label
      end
    end
    local survivor = touched[1]
    for ti = 2, #touched do
      if #members[touched[ti]] > #members[survivor] then survivor = touched[ti] end
    end

    local new_pole = candidates[best]
    placed[#placed + 1] = new_pole
    local new_index = #placed
    mark_dead(new_pole)

    -- Relabel the absorbed components; every alive candidate reaching one of their poles
    -- recounts, once per round however many absorbed poles it reaches.
    local survivor_members = members[survivor]
    local pending, queued, pending_n = {}, {}, 0
    for ti = 1, #touched do
      local label = touched[ti]
      if label ~= survivor then
        local absorbed = members[label]
        for mi = 1, #absorbed do
          local i = absorbed[mi]
          root_of[i] = survivor
          survivor_members[#survivor_members + 1] = i
          local rev = reached_by[i]
          if rev then
            for ri = 1, #rev do
              local position = rev[ri]
              if not queued[position] and not dead[candidates[position]] then
                queued[position] = true
                pending_n = pending_n + 1
                pending[pending_n] = position
              end
            end
          end
        end
        members[label] = nil
        roots_left = roots_left - 1
      end
    end

    -- The new pole joins the survivor, and every alive candidate within reach of it gains it
    -- -- push-style through the candidate buckets, the window a superset and the distance
    -- check the decider, so nothing is ever rescanned.
    root_of[new_index] = survivor
    survivor_members[#survivor_members + 1] = new_index
    local rev = {}
    reached_by[new_index] = rev
    for x = math.floor(new_pole.cx - reach) - pole.width, math.ceil(new_pole.cx + reach) + pole.width do
      local bucket = by_dx[x]
      if bucket then
        for bi = 1, #bucket do
          local candidate = bucket[bi]
          if not dead[candidate] and distance_sq(candidate, new_pole) <= reach_sq then
            local position = position_of[candidate]
            local list = list_of[position]
            list[#list + 1] = new_index
            rev[#rev + 1] = position
            if not queued[position] then
              queued[position] = true
              pending_n = pending_n + 1
              pending[pending_n] = position
            end
          end
        end
      end
    end

    for pi = 1, pending_n do refile(pending[pi]) end
  end
end

local function largest_component(components)
  local best, best_size = {}, 0
  for _, component in pairs(components) do
    if #component > best_size then best, best_size = component, #component end
  end
  return best
end

-- One full attempt against one candidate set: cover, bridge, tally. Every placed pole is a
-- candidate reference -- greedy and bridge both pick from the candidate arrays -- so the
-- coverage lists answer the honesty tally too.
--
-- A placed pole retires the candidates its footprint overlaps. They are marked dead in a
-- per-attempt set -- through a per-column index, since footprints only reach a footprint's
-- width -- where the old pass rebuilt the whole candidate array per placement (~17% of a
-- long solve). The scan-order promises hold: every consumer of the array walks it in its
-- original order, skipping the dead.
local function attempt(candidates, consumers, pole, cover_of)
  local dead = {}
  local by_dx = {}
  for index = 1, #candidates do
    local candidate = candidates[index]
    local bucket = by_dx[candidate.dx]
    if not bucket then
      bucket = {}
      by_dx[candidate.dx] = bucket
    end
    bucket[#bucket + 1] = candidate
  end
  local function mark_dead(taken)
    for x = taken.dx - pole.width + 1, taken.dx + pole.width - 1 do
      local bucket = by_dx[x]
      if bucket then
        for bi = 1, #bucket do
          local candidate = bucket[bi]
          if candidate.dy > taken.dy - pole.height and candidate.dy < taken.dy + pole.height then
            dead[candidate] = true
          end
        end
      end
    end
  end

  local placed = greedy_cover(candidates, consumers, pole, cover_of, dead, mark_dead)
  bridge(placed, candidates, pole, dead, mark_dead, by_dx)

  local lit = {}
  for _, i in pairs(largest_component(components_of(placed, pole))) do
    local list = coverage(cover_of, pole, placed[i], consumers)
    for li = 1, #list do lit[list[li]] = true end
  end
  local unpowered = 0
  for i = 1, #consumers do
    if not lit[i] then unpowered = unpowered + 1 end
  end

  return placed, unpowered
end

-- One copper wire per pole, to its nearest already-wired neighbour -- a spanning tree per
-- component rather than a mesh, so the built network reads as a line, not a cobweb. Every
-- chosen edge is within reach: a connected component always has SOME in-reach edge across
-- any cut, and the minimum-distance pair can only be shorter. Computed here rather than in
-- the serialiser because which pole can reach which is this module's geometry; blueprint.lua just
-- executes the list.
local function spanning_wires(placed, pole)
  local wires = {}
  local reach = pole.wire_distance
  local reach_sq = reach * reach
  for _, component in pairs(components_of(placed, pole)) do
    -- Prim's, with two exact economies over the rescanning original. Offers go only to the
    -- poles within wire reach of the newly added one (through per-column buckets): sound
    -- because the pole popped each round carries the cut's minimum edge, which is always
    -- within reach -- the same in-reach-cross-edge fact the mesh comment above states -- so
    -- an out-of-reach best could never be popped anyway. And the pop itself is the shared
    -- lazy heap ordered (distance, then component position) instead of a full walk of the
    -- component per added pole -- poles squared, most of a long solve.
    --
    -- The tie-breaks are the old scan's and are reproduced exactly: among equal distances the
    -- earliest component position wins, at BOTH ends of the edge. That second half is the one
    -- worth stating, because a ring plan is full of equal distances and nothing in the suite
    -- pins a wire_to value -- a rewired plan would still be connected, and still pass.
    local order = {}
    for position, i in pairs(component) do order[i] = position end

    local buckets = {}
    for _, i in pairs(component) do
      local x = math.floor(placed[i].cx)
      local bucket = buckets[x]
      if not bucket then
        bucket = {}
        buckets[x] = bucket
      end
      bucket[#bucket + 1] = i
    end

    local best_dist, best_to = {}, {}
    local in_tree = { [component[1]] = true }
    local heap_s, heap_p = {}, {}

    -- Every pole within reach of the one just added reconsiders its edge against it. A
    -- strictly shorter edge re-files the pole at its new distance; an equal one only moves
    -- the far end to the earlier tree position, leaving the filed distance true.
    local function offer(j)
      local pj = placed[j]
      for x = math.floor(pj.cx - reach), math.ceil(pj.cx + reach) do
        local bucket = buckets[x]
        if bucket then
          for bi = 1, #bucket do
            local i = bucket[bi]
            if not in_tree[i] then
              local dist = distance_sq(placed[i], pj)
              if dist <= reach_sq then
                local current = best_dist[i]
                if not current or dist < current then
                  best_dist[i], best_to[i] = dist, j
                  heap_push(heap_s, heap_p, -dist, order[i])
                elseif dist == current and order[j] < order[best_to[i]] then
                  best_to[i] = j
                end
              end
            end
          end
        end
      end
    end
    offer(component[1])

    for _ = 2, #component do
      local best_from
      while heap_s[1] do
        local negated, position = heap_pop(heap_s, heap_p)
        local i = component[position]
        -- Stale entries -- re-filed shorter since, or already in the tree -- pop and drop;
        -- the entry matching the pole's current best is always still filed.
        if not in_tree[i] and -negated == best_dist[i] then
          best_from = i
          break
        end
      end
      in_tree[best_from] = true
      wires[best_from] = best_to[best_from]
      offer(best_from)
    end
  end
  return wires
end

-- pole: { name, quality, width, height, supply_distance, wire_distance } -- plain values;
-- the planner resolves them, this file never touches prototypes. consumer_margins maps
-- entity names to the collision-box margin their stand-in is shrunk by, false for entities
-- that draw no power.
--
-- Returns { entities, unpowered }: pole entity dicts each carrying wire_to -- the index, in
-- their own order, of the pole it wires back to, which planner.plan rebases onto plan indices
-- when it appends them -- and how many
-- consumers no pole of the main network reaches.
function poles.plan(built, pole, consumer_margins)
  local consumers = consumers_of(built.entities, consumer_margins)
  local candidates = candidate_positions(occupied(built.entities), built.width, built.height, pole)
  -- One memo for the whole solve: the column index up front, the coverage lists lazily.
  local cover_of = memo_for(consumers)

  -- Columns first, free tiles as the honest fallback: the layout already sized the utility
  -- columns to this pole, so the tidy vertical line is the common case -- but a pole whose
  -- supply cannot cover from the columns alone still gets the full free-tile search rather
  -- than a shrug. The fallback is kept only when it powers strictly more, so a tie stays
  -- with the columns.
  local placed, unpowered
  local column_candidates = built.utility_columns
    and within_columns(candidates, built.utility_columns, pole) or {}
  if #column_candidates > 0 then
    placed, unpowered = attempt(column_candidates, consumers, pole, cover_of)
  end
  if not placed or unpowered > 0 then
    local free_placed, free_unpowered = attempt(candidates, consumers, pole, cover_of)
    if not placed or free_unpowered < unpowered then
      placed, unpowered = free_placed, free_unpowered
    end
  end

  local wires = spanning_wires(placed, pole)
  local entities = {}
  for i, p in pairs(placed) do
    entities[i] = {
      name = pole.name, quality = pole.quality,
      dx = p.dx, dy = p.dy, w = pole.width, h = pole.height,
      wire_to = wires[i],
    }
  end

  return { entities = entities, unpowered = unpowered }
end

return poles
