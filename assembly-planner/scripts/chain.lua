-- Production chains: the root item plus every ticked ingredient reachable from it through ticked
-- ingredients, each one a normal mall cell, stood side by side in one blueprint and powered as
-- one. An item is one row whatever uses it: robots carry it from that row's output chests to
-- every cell that requests it. A row stands `count` copies of its cell, the root's included --
-- the chain's ratio, which the player sets and the plan balances on request
-- (.ai-support/chain-design.md).
--
-- The window and Place both go through chain.walk, so the rows the window shows are exactly the
-- cells the blueprint holds.

local proto = require("scripts.proto")
local cell = require("scripts.cell")
local row = require("scripts.row")
local plan = require("scripts.plan")

local chain = {}

-- The window's height, the blueprint's width and the pole pass's cost all grow with these: rows
-- in a chain, copies in a row, cells in the blueprint.
chain.MAX_CELLS = 8
chain.MAX_COUNT = 10
chain.MAX_TOTAL = 32

-- What a cell owns; every other choice is the chain's, read from the root's. The network count
-- and the split override are numbers about the root's item, so an ingredient cell keeps its
-- own defaults for both; the count is each row's own.
local OWN = {
  item = true, recipe = true, machine = true, machine_quality = true, module = true,
  module_quality = true, split = true, cap_count = true, count = true,
}

-- A row's count as stored, or 1: a whole number from 1 to MAX_COUNT.
function chain.count_of(value)
  if type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > chain.MAX_COUNT then
    return 1
  end
  return value
end

-- The choices an ingredient cell is planned from: the chain's, with the cell's own entry on top.
function chain.derive(choices, entry, item)
  local out = {}
  for key, value in pairs(choices) do
    if not (OWN[key] or key:match("^request_")) then out[key] = value end
  end
  for key, value in pairs(entry) do
    if key ~= "on" then out[key] = value end
  end
  out.item = item
  return out
end

-- The chain's rows in window order: the root, then each ticked ingredient under the first cell
-- that uses it, depth first, at most MAX_CELLS. Each node is { item, depth, count, choices,
-- picks, ingredients }, the ingredients being the ones a cell can make, each { name, amount,
-- on } with `on` when it is in the chain -- what the walk took, never the entry's own flag, so
-- the window lights exactly what the blueprint holds. Returns the nodes, and true when the cap
-- left a ticked ingredient out.
function chain.walk(force, choices, cells)
  local nodes, seen, cut = {}, {}, false
  if not choices.item then return nodes, cut end
  local function visit(item, cell_choices, depth)
    seen[item] = true
    local r = plan.picks(force, cell_choices)
    local node = {
      item = item, depth = depth, count = chain.count_of(cell_choices.count), choices = cell_choices,
      picks = r, ingredients = {},
    }
    nodes[#nodes + 1] = node
    local recipe = r.recipe and prototypes.recipe[r.recipe]
    if not recipe then return end
    for _, ingredient in ipairs((proto.item_ingredients(recipe))) do
      if proto.has_cell_recipe(ingredient.name) then
        node.ingredients[#node.ingredients + 1] = { name = ingredient.name, amount = ingredient.amount }
      end
    end
    for _, ingredient in ipairs(node.ingredients) do
      local entry = cells[ingredient.name]
      if entry and entry.on and not seen[ingredient.name] then
        if #nodes < chain.MAX_CELLS then
          visit(ingredient.name, chain.derive(choices, entry, ingredient.name), depth + 1)
        else
          cut = true
        end
      end
    end
  end
  visit(choices.item, choices, 0)
  for _, node in ipairs(nodes) do
    for _, ingredient in ipairs(node.ingredients) do ingredient.on = seen[ingredient.name] == true end
  end
  return nodes, cut
end

-- Warnings that read the same whichever cell raised them: shown once, without an icon.
local ONCE = {
  ["apl-message.network-cap"] = true,
  ["apl-message.quality-not-researched"] = true,
  ["apl-message.build-quality-not-researched"] = true,
  ["apl-message.cap-no-effect"] = true,
}

-- A shortfall smaller than this share stays quiet: the two rates would show the same number.
local SLACK = 0.01

local function icon(item)
  return "[item=" .. item .. "] "
end

-- The planned cells stood in a row, each row's copies side by side, every cell with extra
-- ground for poles when `extra` asks.
local function lay_out(nodes, planned, pole, extra)
  local entries = {}
  for i, c in ipairs(planned) do
    local built = c.built
    if extra then built = cell.build(plan.with_ground(c.params, pole, extra)) end
    for _ = 1, nodes[i].count do
      entries[#entries + 1] = { built = built, beacon = c.params.beacon, fluid = c.fluid }
    end
  end
  local placed = row.place(entries)
  local entities = {}
  for i, entry in ipairs(entries) do
    local at = placed.offsets[i]
    for _, e in ipairs(entry.built.entities) do
      local moved = {}
      for key, value in pairs(e) do moved[key] = value end
      moved.dx, moved.dy = e.dx + at.x, e.dy + at.y
      entities[#entities + 1] = moved
    end
  end
  return { entities = entities, width = placed.width, height = placed.height, shared = placed.shared }
end

-- Who takes each row's item: uses[i] lists { by, amount } for every other row whose recipe asks
-- for it, `by` its index and `amount` per craft.
local function uses_of(nodes)
  local index = {}
  for i, node in ipairs(nodes) do index[node.item] = i end
  local uses = {}
  for i = 1, #nodes do uses[i] = {} end
  for j, node in ipairs(nodes) do
    for _, ingredient in ipairs((proto.item_ingredients(prototypes.recipe[node.picks.recipe]))) do
      local i = index[ingredient.name]
      if i and i ~= j then table.insert(uses[i], { by = j, amount = ingredient.amount }) end
    end
  end
  return uses
end

-- What row i's item is taken at a minute, every user row at its count and its real rate.
local function taken(uses, planned, counts, i)
  local total = 0
  for _, use in ipairs(uses[i]) do
    total = total + counts[use.by] * planned[use.by].stats.crafts_per_minute * use.amount
  end
  return total
end

-- The fewest copies of a cell that keep up with `wanted` a minute, each making `made`: one at
-- least, MAX_COUNT at most, and never short by SLACK's measure.
local function copies_for(wanted, made)
  if wanted <= 0 or made <= 0 then return 1 end
  return math.max(1, math.min(chain.MAX_COUNT, math.ceil(wanted * (1 - SLACK) / made - 1e-9)))
end

-- The balanced counts: the root's as the player set it, then every other row just enough for
-- what its users take, users first -- so a row is sized against its users' balanced counts.
-- A cycle the order cannot settle is sized in walk order, against whatever its users have.
-- Returns the counts, and each row's exact need in copies.
local function balanced(nodes, planned, uses)
  local waiting, order, queued = {}, { 1 }, { [1] = true }
  for i = 1, #nodes do waiting[i] = #uses[i] end
  local head = 1
  while head <= #order do
    local j = order[head]
    head = head + 1
    for i = 2, #nodes do
      if not queued[i] then
        for _, use in ipairs(uses[i]) do
          if use.by == j then waiting[i] = waiting[i] - 1 end
        end
        if waiting[i] == 0 then
          order[#order + 1] = i
          queued[i] = true
        end
      end
    end
  end
  for i = 2, #nodes do
    if not queued[i] then order[#order + 1] = i end
  end

  local counts, need = { nodes[1].count }, {}
  for i = 2, #nodes do counts[i] = nodes[i].count end
  for k = 2, #order do
    local i = order[k]
    local made = planned[i].made_per_minute
    local wanted = taken(uses, planned, counts, i)
    need[i] = made > 0 and wanted / made or 0
    counts[i] = copies_for(wanted, made)
  end
  return counts, need
end

-- Every cell's warnings in one list: the root's, then each other cell's behind its icon, the
-- ONCE ones shown once per distinct text.
local function merged_warnings(nodes, planned)
  local warnings, shown = {}, {}
  local function add(warning)
    warnings[#warnings + 1] = warning
    shown[serpent.line(warning)] = true
  end
  for _, warning in ipairs(planned[1].warnings) do add(warning) end
  for i = 2, #nodes do
    for _, warning in ipairs(planned[i].warnings) do
      if not ONCE[warning[1]] then
        add({ "", icon(nodes[i].item), warning })
      elseif not shown[serpent.line(warning)] then
        add(warning)
      end
    end
  end
  return warnings
end

-- One entry per row, window order: { item, request_rows, count, best }, and for an ingredient
-- row what its copies make a minute against what the chain takes at the counts as set, whether
-- that falls short, and `need`, the exact copies a balanced chain wants. `best` is the
-- balanced count. Returns the list and how many rows fall short.
local function summaries(nodes, planned)
  local uses = uses_of(nodes)
  local counts = {}
  for i, node in ipairs(nodes) do counts[i] = node.count end
  local best, need = balanced(nodes, planned, uses)
  local out, short = {}, 0
  for i, node in ipairs(nodes) do
    local summary = {
      item = node.item, request_rows = planned[i].request_rows, count = node.count, best = best[i],
    }
    if i > 1 then
      summary.made = node.count * planned[i].made_per_minute
      summary.wanted = taken(uses, planned, counts, i)
      summary.short = summary.made < summary.wanted * (1 - SLACK)
      summary.need = need[i]
      if summary.short then short = short + 1 end
    end
    out[i] = summary
  end
  return out, short
end

-- The whole chain as one plan: plan.build's shape plus `cells`, the summaries above, and
-- `copies`, the cells in the blueprint. Its rate is every root copy's together. With nothing
-- ticked and one root cell it is plan.build's own plan, with a one-row list. A cell that
-- refuses refuses the chain, its icon saying which.
function chain.build(force, surface, choices, cells)
  local nodes, cut = chain.walk(force, choices, cells or {})
  if #nodes == 0 or (#nodes == 1 and nodes[1].count == 1) then
    local p, refusal = plan.build(force, surface, choices)
    if p then
      p.cells = { { item = p.product, request_rows = p.request_rows, count = 1, best = 1 } }
      p.copies = 1
    end
    return p, refusal
  end

  local copies = 0
  for _, node in ipairs(nodes) do copies = copies + node.count end
  if copies > chain.MAX_TOTAL then return nil, { "apl-message.chain-too-big", chain.MAX_TOTAL } end

  local planned = {}
  for i, node in ipairs(nodes) do
    local c, refusal = plan.cell(force, surface, node.choices, node.picks)
    if not c then
      if i == 1 then return nil, refusal end
      return nil, { "", icon(node.item), refusal }
    end
    planned[i] = c
  end

  local root = planned[1]
  local built, unpowered = lay_out(nodes, planned), 0
  if root.pole then
    built, unpowered = plan.power(built, root.pole, function(extra)
      return lay_out(nodes, planned, root.pole, extra)
    end)
  end

  local warnings = merged_warnings(nodes, planned)
  local list, short = summaries(nodes, planned)
  -- A short cell is marked on its own row; the status gets one line for all of them.
  if short > 0 then warnings[#warnings + 1] = { "apl-message.chain-short", short } end
  if cut then warnings[#warnings + 1] = { "apl-message.chain-full", chain.MAX_CELLS } end
  if built.shared then warnings[#warnings + 1] = { "apl-message.chain-beacons-shared" } end
  if unpowered > 0 then warnings[#warnings + 1] = { "apl-message.consumers-unpowered", unpowered } end

  local result = plan.result(root, built)
  result.warnings = warnings
  result.cells = list
  result.copies = copies
  local stats = {}
  for key, value in pairs(root.stats) do stats[key] = value end
  stats.crafts_per_minute = nodes[1].count * root.stats.crafts_per_minute
  stats.pace_per_minute = nodes[1].count * root.stats.pace_per_minute
  result.stats = stats
  return result
end

return chain
