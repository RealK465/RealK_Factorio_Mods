-- The planner window: one form in three sections -- what the cell MAKES (item, recipe, machine
-- and its modules), what it is BUILT from (logistics, beacons, pole), how it is STOCKED
-- (requests, stock limit) -- then a status area and Place. Every option sits on the form itself,
-- one click from use: a row is a caption beside its controls, and pickers stand in slot strips.
--
-- Every picker is always shown, each with its quality box; only what cannot apply hides: the
-- recipe list when one recipe makes the item, the module picker on a machine without slots,
-- the pipe when the recipe takes no fluid. Pickers offer what the force has researched unless
-- the per-player "show unresearched" setting is on, toggled from the titlebar.
--
-- A production chain shows in the first section: beside each machine, the ingredients a cell
-- could make, lit when they are made in the chain; under the machine, one row per ingredient
-- cell with its own machine, modules, recipe and ingredients (chain.lua). Everything below the
-- first section is the whole chain's.
--
-- Built from scratch on every open and destroyed on close: stale state is impossible rather
-- than merely unlikely, and nothing about the frame is kept in storage -- only the choices.
-- Handlers are reached through the tag dispatcher, so saved state only ever holds name strings.
--
-- The shell -- an invisible screen container with the window and its side panel as sibling
-- columns, the element-chooser presumption under the Confirm key, the closes the engine never
-- announces -- is Upcycler Planner's, measured there (its api.md §17, §19, §20, §22, §23, §28).

local gui = {}

local util = require("util")
local calc = require("scripts.calc")
local dispatch = require("scripts.dispatch")
local proto = require("scripts.proto")
local plan = require("scripts.plan")
local chain = require("scripts.chain")
local blueprint = require("scripts.blueprint")
local state = require("scripts.state")

local FRAME = "apl-frame"
local INGREDIENTS_FRAME = "apl-ingredients"
-- The shortcut and its hotkey custom-input share this prototype name, so the button, the key
-- and the tooltip's keybind hint rename together.
local SHORTCUT = "apl-open"
local SHOW_ALL_SETTING = "assembly-planner-show-all"

gui.FRAME = FRAME
gui.INGREDIENTS_FRAME = INGREDIENTS_FRAME
gui.SHORTCUT = SHORTCUT
gui.SHOW_ALL_SETTING = SHOW_ALL_SETTING

local COLOR_ERROR = { r = 1, g = 0.35, b = 0.35 }
local COLOR_WARNING = { r = 1, g = 0.7, b = 0.3 }
local COLOR_PLAIN = { r = 1, g = 1, b = 1 }
local COLOR_HINT = { r = 0.7, g = 0.7, b = 0.7 }
-- The balanced count in a count drop-down, a soft green.
local BALANCED_COLOR = "#80e080"
local ICON_WARNING = "[img=utility/warning_icon] "
local ICON_ERROR = "[img=utility/not_available] "

-- One caption width in every section, or the three sections' controls stagger.
local LABEL_WIDTH = 76
-- The two rule drop-downs share a width so their number fields line up; the beacon counts
-- hold two digits.
local MODE_WIDTH = 136
local COUNT_WIDTH = 56
-- A row's cell count reads "×10" at most.
local COPIES_WIDTH = 72
local NUMBER_WIDTH = 64
-- Status lines wrap inside the window instead of widening it.
local STATUS_WIDTH = 400
-- A chain row's product steps this far right per level, within the caption column.
local INDENT = 12
local SLOT = 40
-- A chain row is a slot strip and the form's spacing. The rows scroll past what the screen
-- leaves once the rest of the window, a few status lines included, is drawn -- never fewer
-- than two, never more than the cap's seven.
local ROW = SLOT + 8
local CHAIN_MIN, CHAIN_MAX = 2 * ROW, 7 * ROW
local WINDOW_WITHOUT_CHAIN = 700

local function frame_of(player)
  local frame = player.gui.screen[FRAME]
  if frame and frame.valid then return frame end
  return nil
end

local function panel_of(player)
  local frame = frame_of(player)
  local panel = frame and frame[INGREDIENTS_FRAME]
  if panel and panel.valid then return panel end
  return nil
end

-- The window's sections, by name, so refresh and the handlers reach a control without walking.
local function section_of(player, name)
  local frame = frame_of(player)
  return frame and frame["apl-main"]["apl-content"][name]
end

-- A chain row's product slot, by the item the row makes; nil when no row makes it.
local function product_of(pane, item)
  local caption = pane["apl-chain"]["apl-cell-caption/" .. item]
  return caption and caption["apl-cell-strip/" .. item]["apl-cell/" .. item]
end

-- How many copies of a row's cell to build, "×1" up, the balanced count in green. gui.refresh
-- repaints it, since the balanced count moves with the plan.
local function count_items(best)
  local items = {}
  for n = 1, chain.MAX_COUNT do
    items[n] = n == best and ("[color=" .. BALANCED_COLOR .. "]×" .. n .. "[/color]") or ("×" .. n)
  end
  return items
end

-- A row's count drop-down: the root's in the machine row, an ingredient cell's in its own row.
local function count_of(player, index, item)
  if index == 1 then return section_of(player, "apl-make")["apl-machine-row"]["apl-count"] end
  local pane = section_of(player, "apl-chain-pane")
  local row = pane and pane["apl-chain"]["apl-cell-row/" .. item]
  return row and row["apl-count/" .. item]
end

function gui.is_setting(name)
  return name == SHOW_ALL_SETTING
end

-- The game's own "show all items in selection lists" option is not readable by mods, so this
-- per-player setting stands in for it.
local function show_all(player)
  return player.mod_settings[SHOW_ALL_SETTING].value
end

-- The researched subset of a list unless show-all is on; an empty subset falls back to the
-- whole list, so the window explains itself through the status line instead of dead-ending.
local function offered(player, names, narrow)
  if not show_all(player) then
    local unlocked = narrow(player.force, names)
    if #unlocked > 0 then return unlocked end
  end
  return names
end

-- An empty name list is not a legal filter, and nil means NO filter -- the picker would offer
-- every prototype of its kind -- so an empty list disables the picker instead (see picker()).
local function name_filter(names)
  if #names == 0 then return nil end
  return { { filter = "name", name = names } }
end

-- The engine's element chooser is invisible to mods: nothing announces it and it never touches
-- player.opened. What IS visible is the click that opens one, and any later gui event means it
-- closed. So a left click on one of our pickers presumes a chooser open until the next gui
-- event for that player. In storage, never a module local: a player joining mid-presumption
-- would otherwise take a different branch on the same press of E -- a desync.
local function note_gui_event(event)
  local element = event.element
  if event.name == defines.events.on_gui_click and element and element.valid
    and (event.button == nil or event.button == defines.mouse_button_type.left)
    and element.type == "choose-elem-button" and element.tags[dispatch.TAG] then
    state.of(event.player_index).chooser_maybe_open = true
  else
    local entry = state.peek(event.player_index)
    if entry then entry.chooser_maybe_open = nil end
  end
end

-- The pickers, by choice key. `quality` names the key holding the pick's quality; `clear`
-- means emptying the picker is a real choice (nothing there), and `flag` records that choice
-- where nil already means "use the default"; `rebuild` reopens the window, for picks other
-- options depend on. `names(r)` lists what the picker can offer, `narrow(force, names)` keeps
-- the researched part.
local PICKERS = {
  item = { elem_type = "item-with-quality", quality = "recipe_quality", rebuild = true,
    narrow = proto.unlocked_items, names = proto.items },
  machine = { elem_type = "entity-with-quality", quality = "machine_quality", rebuild = true,
    narrow = proto.buildable,
    names = function(r)
      local recipe = r.recipe and prototypes.recipe[r.recipe]
      return recipe and proto.machines_for(recipe) or proto.machine_candidates()
    end },
  module = { elem_type = "item-with-quality", quality = "module_quality", clear = true,
    narrow = proto.unlocked,
    names = function(r)
      local machine = r.machine and prototypes.entity[r.machine]
      if not machine then return {} end
      return proto.modules_for(machine, r.recipe and prototypes.recipe[r.recipe])
    end },
  inserter = { elem_type = "entity-with-quality", quality = "inserter_quality",
    narrow = proto.buildable, names = proto.inserters },
  requester = { elem_type = "entity-with-quality", quality = "requester_quality",
    narrow = proto.buildable, names = function() return proto.chests("requester") end },
  output = { elem_type = "entity-with-quality", quality = "output_quality",
    narrow = proto.buildable, names = function() return proto.chests("output") end },
  pipe = { elem_type = "entity", narrow = proto.buildable, names = proto.pipes },
  beacon = { elem_type = "entity-with-quality", quality = "beacon_quality", clear = true,
    rebuild = true, narrow = proto.buildable, names = proto.beacons },
  beacon_module = { elem_type = "item-with-quality", quality = "beacon_module_quality",
    clear = true, flag = "no_beacon_module", narrow = proto.unlocked,
    names = function(r)
      local beacon = r.beacon and prototypes.entity[r.beacon]
      return beacon and proto.modules_for(beacon) or {}
    end },
  pole = { elem_type = "entity-with-quality", quality = "pole_quality", clear = true,
    narrow = proto.buildable, names = proto.poles },
}

-- The value a picker shows: the remembered name at its quality, in the shape the picker's
-- elem_type takes -- a bare string for the pipe, which has no quality to pick.
local function shown(spec, choices, key)
  local name = choices[key]
  if not name then return nil end
  if not spec.quality then return name end
  return proto.with_quality(name, choices[spec.quality])
end

-- Every per-ingredient amount, dropped: they were sized against one recipe and one rule.
local function clear_request_overrides(choices)
  for key in pairs(choices) do
    if key:match("^request_") then choices[key] = nil end
  end
end

-- A new request rule or number resizes every cell of the chain.
local function clear_all_request_overrides(entry)
  clear_request_overrides(entry.choices)
  for _, cell in pairs(entry.cells) do clear_request_overrides(cell) end
end

-- The table a control writes: an ingredient cell's own entry when `cell` names one, else the
-- root's choices.
local function target_of(entry, cell)
  if cell then return entry.cells[cell] end
  return entry.choices
end

-- The whole set of choices a cell is planned from, for reading.
local function choices_of(entry, cell)
  if not cell then return entry.choices end
  return chain.derive(entry.choices, entry.cells[cell] or {}, cell)
end

-- A cell's suffix on its controls' names: none for the root, "/<item>" for an ingredient cell.
-- A slash cannot occur in a prototype name, so no two names collide.
local function suffix(cell)
  return cell and ("/" .. cell) or ""
end

-- Writes the resolved defaults back, so the pickers show what would really be placed. Only
-- prototype picks: an untouched NUMBER stays unstored, so it keeps following its default.
local function apply_defaults(player, choices)
  local r = plan.picks(player.force, choices)
  choices.machine = r.machine
  choices.inserter = r.inserter
  choices.requester = r.requester
  choices.output = r.output
  choices.pipe = r.pipe
  if r.beacon and not choices.no_beacon_module then choices.beacon_module = r.beacon_module end
  return r
end

-- The same for each ingredient cell's machine, the one pick a cell resolves on its own. Into
-- the node's choices too: they were derived before the write, and the row's picker shows them.
local function apply_cell_defaults(entry, nodes)
  for index = 2, #nodes do
    local node = nodes[index]
    entry.cells[node.item].machine = node.picks.machine
    node.choices.machine = node.picks.machine
  end
end

local function status_line(status, name, caption, color)
  local line = status.add({ type = "label", name = name, caption = caption })
  line.style.single_line = false
  line.style.maximal_width = STATUS_WIDTH
  line.style.font_color = color
  return line
end

-- A tooltip for a control whose caption is not beside it: a bold title, then the explanation.
local function titled(title, body)
  return { "", "[font=default-bold]", title, "[/font]\n", body }
end

local function titled_tooltip(key)
  return titled({ "apl-gui." .. key }, { "apl-gui." .. key .. "-tooltip" })
end

-- The amounts panel's groups, one per cell: { item, cell, rows }, `cell` naming an ingredient
-- cell's entry and nil for the root. From the plan when one stands, priced at each cell's real
-- pace; from the picks alone when it is refused.
local function request_groups(player, p)
  local groups = {}
  if p then
    for index, c in ipairs(p.cells) do
      groups[index] = { item = c.item, cell = index > 1 and c.item or nil, rows = c.request_rows }
    end
    return groups
  end
  local entry = state.of(player.index)
  for index, node in ipairs(chain.walk(player.force, entry.choices, entry.cells)) do
    groups[index] = {
      item = node.item, cell = index > 1 and node.item or nil, rows = plan.sizing(player.force, node.choices),
    }
  end
  return groups
end

-- A request field's name ends in the ingredient, after its cell's item for an ingredient cell.
local function request_suffix(group, row)
  return group.cell and (group.cell .. "/" .. row.name) or row.name
end

-- The ingredient fields brought up to date: every default in the tags, and the text of every
-- field the player has not set by hand. A hand-set field is never rewritten -- it may be the
-- one being typed in.
local function repaint_request_rows(player, groups)
  local panel = panel_of(player)
  local list = panel and panel[INGREDIENTS_FRAME .. "-content"]["apl-ingredients-list"]
  if not list then return end
  local entry = state.of(player.index)
  for _, group in ipairs(groups) do
    local values = target_of(entry, group.cell) or {}
    for _, row in ipairs(group.rows) do
      local name = request_suffix(group, row)
      local line = list["apl-request-row-" .. name]
      local field = line and line["apl-request-" .. name]
      if field then
        local tags = field.tags
        if tags.default ~= row.default then
          tags.default = row.default
          field.tags = tags
        end
        local text = tostring(row.default)
        if values["request_" .. row.name] == nil and field.text ~= text then field.text = text end
      end
    end
  end
end

-- The one line of numbers a standing plan earns: the cell count for a chain, the footprint, the
-- real rate, and the quality chance when there is one.
local function stats_caption(p)
  local rate = calc.format_rate(p.stats.crafts_per_minute)
  local quality = p.stats.quality > 0 and string.format("%.1f", p.stats.quality * 100) or nil
  local copies = p.copies or 1
  if copies > 1 then
    if quality then return { "apl-gui.stats-chain-quality", copies, p.width, p.height, rate, quality } end
    return { "apl-gui.stats-chain", copies, p.width, p.height, rate }
  end
  if quality then return { "apl-gui.stats-quality", p.width, p.height, rate, quality } end
  return { "apl-gui.stats", p.width, p.height, rate }
end

-- The cells a balanced chain would stand.
local function balanced_total(p)
  local total = 0
  for _, c in ipairs(p.cells) do total = total + c.best end
  return total
end

-- While any row's count differs from the balanced one, a line naming the balanced chain -- each
-- item at its count -- and the button that sets them all; disabled, saying why, when the
-- balanced chain would not fit in a blueprint.
local function add_balance_line(status, p)
  local off = false
  for index = 2, #p.cells do off = off or p.cells[index].count ~= p.cells[index].best end
  if not off then return end
  local counts = { "" }
  for _, c in ipairs(p.cells) do counts[#counts + 1] = "[item=" .. c.item .. "]×" .. c.best .. "  " end
  local line = status.add({ type = "flow", name = "apl-balance-row", direction = "horizontal" })
  line.style.vertical_align = "center"
  line.style.horizontal_spacing = 8
  line.add({ type = "label", name = "apl-balance-label", caption = { "apl-gui.balanced", counts } })
  local total = balanced_total(p)
  local fits = total <= chain.MAX_TOTAL
  line.add({
    type = "button", name = "apl-balance", caption = { "apl-gui.balance" },
    tooltip = fits and { "apl-gui.balance-tooltip" } or { "apl-gui.balance-too-big", total, chain.MAX_TOTAL },
    tags = dispatch.tags("balance"),
  }).enabled = fits
end

-- The plan the window stands for: the whole chain.
local function plan_of(player)
  local entry = state.of(player.index)
  return chain.build(player.force, player.surface, entry.choices, entry.cells)
end

-- Replans and repaints what depends on the plan. Returns the plan, nil when refused.
function gui.refresh(player)
  local frame = frame_of(player)
  if not frame then return nil end
  local choices = state.of(player.index).choices
  local main = frame["apl-main"]
  local status = main["apl-status"]

  local p, message = plan_of(player)
  main["apl-buttons"]["apl-confirm"].enabled = p ~= nil

  -- The split override is kept only while it disagrees with the automatic answer, so the box
  -- follows the modules again once the two agree. A refused plan has no automatic answer: the
  -- box shows the override itself.
  if p and choices.split ~= nil and choices.split == p.split_auto then choices.split = nil end
  section_of(player, "apl-stock")["apl-split-row"]["apl-split"].state = p and p.split or choices.split == true

  -- The amounts panel's defaults move with the pace in minutes mode -- a module or beacon pick
  -- changes them -- so it follows every refresh, not only a size edit.
  if panel_of(player) then repaint_request_rows(player, request_groups(player, p)) end

  -- Every row's count marks the balanced one, an ingredient cell's saying its exact need; a
  -- short row's product turns red, the two rates on hover. The status carries one line for all.
  local pane = main["apl-content"]["apl-chain-pane"]
  for index, c in ipairs(p and p.cells or {}) do
    local count = count_of(player, index, c.item)
    if count then
      -- The root sets the pace, so its count is never "balanced" against anything.
      count.items = count_items(index > 1 and c.best or nil)
      count.selected_index = c.count
      if index > 1 then count.tooltip = { "apl-gui.count-cell-tooltip", string.format("%.1f", c.need) } end
    end
    local product = index > 1 and pane and product_of(pane, c.item)
    if product then
      product.style = c.short and "red_slot_button" or "slot_button"
      product.tooltip = c.short
        and { "apl-gui.cell-short-tooltip", calc.format_rate(c.made), calc.format_rate(c.wanted) } or ""
    end
  end
  -- A refused plan has no balance to show, but every count still reads what is stored.
  if not p then
    local entry = state.of(player.index)
    for index, node in ipairs(chain.walk(player.force, entry.choices, entry.cells)) do
      local count = count_of(player, index, node.item)
      if count then count.selected_index = node.count end
    end
  end

  -- Before an item is picked the hint stands beside the item picker, so the area stays shut.
  status.clear()
  if p then
    status_line(status, "apl-stats", stats_caption(p), COLOR_PLAIN)
    add_balance_line(status, p)
    for index, warning in ipairs(p.warnings) do
      status_line(status, "apl-message-" .. index, { "", ICON_WARNING, warning }, COLOR_WARNING)
    end
  elseif message then
    status_line(status, "apl-message-1", { "", ICON_ERROR, message }, COLOR_ERROR)
  end
  status.visible = #status.children > 0
  return p
end

local function destroy_modal(player)
  local frame = frame_of(player)
  if frame then frame.destroy() end
end

function gui.close(player)
  destroy_modal(player)
  local entry = state.peek(player.index)
  if entry then entry.chooser_maybe_open = nil end
end

-- Dying, turning spectator and disconnecting close a player's GUIs without raising
-- on_gui_closed, which left the window standing with its focus gone. "Nothing at all is
-- focused" is the test, not "the window is not focused": a side panel dismissed by clicking a
-- chest leaves player.opened on the chest, deliberately.
function gui.close_if_unfocused(player)
  if frame_of(player) and player.opened == nil then gui.close(player) end
end

-- The draggable header: title, then a filler that is itself a drag handle. drag_target must be
-- an element in gui.screen, so a side panel passes the outer container.
local function add_titlebar(parent, name, caption, drag_target)
  local bar = parent.add({ type = "flow", name = name, direction = "horizontal" })
  bar.drag_target = drag_target
  bar.style.horizontal_spacing = 8
  bar.add({ type = "label", style = "frame_title", caption = caption, ignored_by_interaction = true })
  local filler = bar.add({ type = "empty-widget", style = "draggable_space_header" })
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  filler.drag_target = drag_target
  return bar
end

local function add_close(bar, name, handler)
  bar.add({
    type = "sprite-button", name = name, style = "frame_action_button", sprite = "utility/close",
    tooltip = { "gui.close" }, tags = dispatch.tags(handler),
  })
end

-- A numeric field for one of plan's field descriptors { key, value, default, min, max }. The
-- tags carry the untouched default, not the shown value, so Enter on an emptied field returns
-- to it and an untouched default is never stored.
local function number_field(parent, name, field, tooltip, extra)
  local tags = { key = field.key, default = field.default, min = field.min, max = field.max }
  for k, v in pairs(extra or {}) do tags[k] = v end
  local element = parent.add({
    type = "textfield", name = name, text = tostring(field.value),
    numeric = true, allow_decimal = false, allow_negative = false, lose_focus_on_confirm = true,
    tooltip = tooltip, tags = dispatch.tags("number", tags),
  })
  element.style.width = NUMBER_WIDTH
  return element
end

-- The per-ingredient amounts, each field the player's own number or the default the cell would
-- request, priced at the cell's real pace when a plan stands; grouped under each cell's item
-- once there is a chain. A side panel beside the window, inside the planner's own screen
-- element, so the pair cannot separate when dragged.
local function build_ingredients_panel(player, frame, p)
  local entry = state.of(player.index)
  local panel = frame.add({ type = "frame", name = INGREDIENTS_FRAME, direction = "vertical" })
  panel.style.left_margin = 12
  local bar = add_titlebar(panel, INGREDIENTS_FRAME .. "-titlebar", { "apl-gui.requests-title" }, frame)
  add_close(bar, INGREDIENTS_FRAME .. "-close", "ingredients-close")
  local content = panel.add({
    type = "frame", name = INGREDIENTS_FRAME .. "-content", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  local groups = request_groups(player, p)
  local any = false
  for _, group in ipairs(groups) do any = any or #group.rows > 0 end
  if not any then
    local hint = content.add({ type = "label", name = "apl-no-ingredients", caption = { "apl-gui.no-ingredients" } })
    hint.style.font_color = COLOR_HINT
    hint.style.single_line = false
    hint.style.maximal_width = 240
    return
  end
  local list = content.add({ type = "scroll-pane", name = "apl-ingredients-list", direction = "vertical" })
  list.style.maximal_height = 400
  for index, group in ipairs(groups) do
    if #groups > 1 and #group.rows > 0 then
      local head = list.add({
        type = "label", name = "apl-ingredients-head/" .. group.item, style = "semibold_label",
        caption = { "", "[item=" .. group.item .. "] ", prototypes.item[group.item].localised_name },
      })
      if index > 1 then head.style.top_margin = 8 end
    end
    local values = target_of(entry, group.cell) or {}
    for _, row in ipairs(group.rows) do
      local key = "request_" .. row.name
      local name = request_suffix(group, row)
      local line = list.add({ type = "flow", name = "apl-request-row-" .. name, direction = "horizontal" })
      line.style.vertical_align = "center"
      line.style.horizontal_spacing = 8
      local label = line.add({
        type = "label", caption = { "", "[item=" .. row.name .. "] ", prototypes.item[row.name].localised_name },
      })
      label.style.minimal_width = 160
      -- The floor is ONE, never zero: every ingredient keeps a request.
      number_field(line, "apl-request-" .. name, {
        key = key, default = row.default, min = 1, max = 2147483647, value = values[key] or row.default,
      }, { "apl-gui.request-count-tooltip" }, { cell = group.cell })
    end
  end
end

-- The amounts panel up or down, with the pencil that opens it showing which.
local function show_ingredients(player, show)
  local frame = frame_of(player)
  if not frame then return end
  local panel = panel_of(player)
  if show and not panel then build_ingredients_panel(player, frame, (plan_of(player))) end
  if not show and panel then panel.destroy() end
  section_of(player, "apl-stock")["apl-requests-row"]["apl-requests-edit"].toggled = show
end

-- A picker button for one choice key, of the root or of the ingredient cell `cell` names.
-- Disabled rather than unfiltered when it has nothing to offer at all (see name_filter).
local function picker(parent, player, choices, r, key, cell)
  local spec = PICKERS[key]
  local names = offered(player, spec.names(r), spec.narrow)
  local dashed = key:gsub("_", "-")
  local button = parent.add({
    type = "choose-elem-button", name = "apl-" .. dashed .. suffix(cell), style = "slot_button",
    elem_type = spec.elem_type, elem_filters = name_filter(names), tooltip = titled_tooltip(dashed),
    tags = dispatch.tags("pick", { key = key, cell = cell }),
  })
  -- elem_value is a runtime attribute, not a creation parameter: passed to add() it is silently
  -- ignored and the picker opens empty.
  button.elem_value = shown(spec, choices, key)
  button.enabled = #names > 0
  return button
end

-- Pickers side by side in one recessed strip, like a row of inventory slots.
local function slot_strip(row, name)
  return row.add({ type = "frame", name = name, style = "slot_button_deep_frame", direction = "horizontal" })
end

local function drop_down(parent, name, handler, items, selected, tooltip, extra)
  return parent.add({
    type = "drop-down", name = name, items = items,
    selected_index = (#items > 0) and selected or nil, tooltip = tooltip,
    tags = dispatch.tags(handler, extra),
  })
end

local function index_of(list, value)
  for i, v in ipairs(list) do
    if v == value then return i end
  end
  return 1
end

-- A rule drop-down: one locale key per mode, apl-gui.<prefix>-<mode>.
local function mode_drop_down(parent, name, prefix, modes, mode, tooltip)
  local items = {}
  for i, m in ipairs(modes) do items[i] = { "apl-gui." .. prefix .. "-" .. m } end
  local list = drop_down(parent, name, prefix .. "-mode", items, index_of(modes, mode), tooltip)
  list.style.width = MODE_WIDTH
  return list
end

-- A beacon count: its caption, then a narrow drop-down of exactly what fits.
local function count_drop_down(row, key, max, selected, enabled)
  local label = row.add({ type = "label", caption = { "apl-gui." .. key }, tooltip = { "apl-gui." .. key .. "-tooltip" } })
  label.style.left_margin = 4
  local items = {}
  for i = 0, max do items[#items + 1] = tostring(i) end
  local list = drop_down(row, "apl-" .. key, key, items, selected + 1, { "apl-gui." .. key .. "-tooltip" })
  list.style.width = COUNT_WIDTH
  list.enabled = enabled
end

-- One section of the form: captions in the first column, each row's controls in a flow in the
-- second.
local function section(content, name)
  local form = content.add({ type = "table", name = name, column_count = 2 })
  form.style.horizontal_spacing = 12
  form.style.vertical_spacing = 8
  form.style.vertical_align = "center"
  return form
end

-- A row: its caption, or none for a checkbox that belongs to the row above, then the flow its
-- controls go in.
local function form_row(form, key, caption)
  local label = form.add({ type = "label", name = "apl-" .. key .. "-label", caption = caption })
  label.style.width = LABEL_WIDTH
  local row = form.add({ type = "flow", name = "apl-" .. key .. "-row", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.style.horizontal_spacing = 8
  return row
end

local function separator(content)
  local line = content.add({ type = "line", style = "inside_shallow_frame_with_padding_line" })
  line.style.top_margin = 8
  line.style.bottom_margin = 8
end

-- The item, and beside it the recipe list when several recipes make it, else its name -- or
-- the hint before one is picked.
local function build_item_row(form, player, choices, r)
  local row = form_row(form, "item", { "apl-gui.group-item" })
  picker(slot_strip(row, "apl-item-strip"), player, choices, r, "item")

  -- A drop-down, not a picker: RecipePrototypeFilter has no name filter, so a recipe picker
  -- cannot be narrowed to the recipes making this item. The list rides in the tags.
  local items = {}
  for index, name in ipairs(r.recipes) do
    items[index] = { "", "[recipe=" .. name .. "] ", prototypes.recipe[name].localised_name }
  end
  local recipe_list = drop_down(row, "apl-recipe", "recipe", items, index_of(r.recipes, r.recipe),
    titled_tooltip("recipe"), { recipes = r.recipes })
  recipe_list.style.maximal_width = 260
  recipe_list.visible = #r.recipes > 1

  if not r.item then
    local hint = row.add({ type = "label", name = "apl-hint", caption = { "apl-gui.pick-an-item" } })
    hint.style.font_color = COLOR_HINT
  elseif not recipe_list.visible then
    -- A long modded name wraps beside the picker rather than widening the window.
    local name = row.add({ type = "label", name = "apl-item-name", style = "semibold_label",
      caption = prototypes.item[r.item].localised_name })
    name.style.single_line = false
    name.style.maximal_width = 260
  end
end

-- A cell's machine and its modules, the module picker hidden on a machine without slots.
local function machine_strip(row, player, choices, r, cell)
  local strip = slot_strip(row, "apl-machine-strip" .. suffix(cell))
  picker(strip, player, choices, r, "machine", cell)
  local machine = r.machine and prototypes.entity[r.machine]
  picker(strip, player, choices, r, "module", cell).visible =
    machine ~= nil and proto.module_slots(machine, r.machine_quality) > 0
end

-- Tooltips of an ingredient beside a machine, by its state.
local function ingredient_tooltip(ingredient, is_root, is_self, full)
  local body
  if is_root then
    body = { "apl-gui.chain-root-tooltip" }
  elseif is_self then
    body = { "apl-gui.chain-self-tooltip" }
  elseif ingredient.on then
    body = { "apl-gui.chain-remove-tooltip" }
  elseif full then
    body = { "apl-gui.chain-full-tooltip", chain.MAX_CELLS }
  else
    body = { "apl-gui.chain-add-tooltip" }
  end
  return titled(prototypes.item[ingredient.name].localised_name, body)
end

-- An ingredient strip wraps past this many, so a long recipe grows its row down rather than the
-- window across.
local INGREDIENT_COLUMNS = 4

-- The ingredients of one cell a cell of their own could make, as slots: the count per craft as
-- the number, the chain's quality as the badge, lit when made in the chain. A click ticks one
-- in or out of the chain. The root itself, met again down a cycle, and a cell's own product in
-- its own row (kovarex) stay lit and cannot be unticked there; with the chain full, an unlit
-- one waits. Unresearched ones hide unless the setting shows them, or the chain already makes
-- them. Returns the strip, nil when empty.
local function ingredient_strip(row, player, nodes, index)
  local node = nodes[index]
  if not node then return nil end
  local root = nodes[1]
  local full = #nodes >= chain.MAX_CELLS
  local quality = proto.build_quality(root.choices.recipe_quality)
  local strip, slots
  for _, ingredient in ipairs(node.ingredients) do
    if ingredient.on or show_all(player) or proto.is_cell_unlocked(player.force, ingredient.name) then
      if not slots then
        strip = slot_strip(row, "apl-chain-strip/" .. node.item)
        slots = strip.add({ type = "table", name = "apl-chain-slots/" .. node.item, style = "slot_table",
          column_count = INGREDIENT_COLUMNS })
      end
      local is_root = ingredient.name == root.item
      local is_self = ingredient.name == node.item
      local button = slots.add({
        type = "sprite-button", name = "apl-chain-" .. node.item .. "/" .. ingredient.name,
        style = ingredient.on and "yellow_slot_button" or "slot_button", sprite = "item/" .. ingredient.name,
        tooltip = ingredient_tooltip(ingredient, is_root, is_self, full),
        tags = dispatch.tags("chain", { item = ingredient.name, on = ingredient.on }),
      })
      button.number = ingredient.amount
      if quality ~= "normal" then button.quality = quality end
      button.enabled = not (is_root or is_self) and (ingredient.on or not full)
    end
  end
  return strip
end

-- The `index`th cell's machine strip and its count, then its ingredients behind an arrow
-- pointing into the machine. The root's picks are the window's own; an ingredient cell's are
-- its node's. Without a node (no item yet) the count waits for one.
local function machine_and_ingredients(row, player, choices, r, nodes, index)
  local node = nodes[index]
  local cell = index > 1 and node.item or nil
  machine_strip(row, player, choices, r, cell)
  local count = drop_down(row, "apl-count" .. suffix(cell), "count", count_items(nil),
    node and node.count or 1, { "apl-gui.count-tooltip" }, { cell = cell })
  count.style.width = COPIES_WIDTH
  count.enabled = node ~= nil
  local arrow = row.add({ type = "sprite", sprite = "utility/backward_arrow", ignored_by_interaction = true })
  local strip = ingredient_strip(row, player, nodes, index)
  arrow.visible = strip ~= nil
end

local function build_machine_row(form, player, choices, r, nodes)
  machine_and_ingredients(form_row(form, "machine", { "apl-gui.group-machine" }), player, choices, r, nodes, 1)
end

-- The recipe of an ingredient cell when several make its item: icons only, so the drop-down
-- stays as narrow as a beacon count.
local function cell_recipe_drop_down(row, node)
  local recipes = proto.recipes_for_item(node.item)
  if #recipes < 2 then return end
  local items = {}
  for index, name in ipairs(recipes) do items[index] = "[recipe=" .. name .. "]" end
  local list = drop_down(row, "apl-recipe/" .. node.item, "recipe", items, index_of(recipes, node.picks.recipe),
    titled_tooltip("recipe"), { recipes = recipes, cell = node.item })
  list.style.width = COUNT_WIDTH
end

-- How tall the chain's rows may grow before they scroll, in UI units.
local function chain_height(player)
  local screen = player.display_resolution.height / player.display_scale
  return math.max(CHAIN_MIN, math.min(CHAIN_MAX, screen - WINDOW_WITHOUT_CHAIN))
end

-- Where a rebuilt window may stand: as before, but lifted when its chain grew it past the
-- screen's bottom edge, so Place stays in reach. `keep` is in pixels, the sizes in UI units.
local function lifted(player, keep, nodes)
  if not keep or #nodes < 2 then return keep end
  local rows = math.min((#nodes - 1) * ROW, chain_height(player))
  local bottom = player.display_resolution.height - (WINDOW_WITHOUT_CHAIN + rows) * player.display_scale
  return { x = keep.x, y = math.max(0, math.min(keep.y, bottom)) }
end

-- One row per ingredient cell under the machine row, in the walk's order: its product, stepped
-- in by depth, then its machine, its own ingredients and its recipe. A table of its own in a
-- pane that scrolls, its caption column as wide as the form's so the strips line up.
local function build_chain_rows(content, player, nodes)
  if #nodes < 2 then return nil end
  local pane = content.add({
    type = "scroll-pane", name = "apl-chain-pane", style = "naked_scroll_pane", direction = "vertical",
    horizontal_scroll_policy = "never",
  })
  pane.style.top_margin = 8
  pane.style.maximal_height = chain_height(player)
  local form = section(pane, "apl-chain")
  for index = 2, #nodes do
    local node = nodes[index]
    local caption = form.add({ type = "flow", name = "apl-cell-caption/" .. node.item, direction = "horizontal" })
    caption.style.width = LABEL_WIDTH
    caption.style.left_padding = math.min(INDENT * node.depth, LABEL_WIDTH - SLOT)
    local product = slot_strip(caption, "apl-cell-strip/" .. node.item).add({
      type = "sprite-button", name = "apl-cell/" .. node.item, style = "slot_button",
      sprite = "item/" .. node.item,
    })
    product.elem_tooltip = { type = "item", name = node.item }
    local row = form.add({ type = "flow", name = "apl-cell-row/" .. node.item, direction = "horizontal" })
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 8
    machine_and_ingredients(row, player, node.choices, node.picks, nodes, index)
    cell_recipe_drop_down(row, node)
  end
  return pane
end

local function build_logistics_row(form, player, choices, r)
  local strip = slot_strip(form_row(form, "logistics", { "apl-gui.group-logistics" }), "apl-logistics-strip")
  picker(strip, player, choices, r, "inserter")
  picker(strip, player, choices, r, "requester")
  picker(strip, player, choices, r, "output")
  local recipe = r.recipe and prototypes.recipe[r.recipe]
  local fluids = recipe and select(2, proto.item_ingredients(recipe)) or {}
  picker(strip, player, choices, r, "pipe").visible = #fluids > 0
end

-- The beacon and its module, then the two counts, each a drop-down of exactly what fits.
local function build_beacon_row(form, player, choices, r)
  local row = form_row(form, "beacons", { "apl-gui.group-beacons" })
  local strip = slot_strip(row, "apl-beacon-strip")
  picker(strip, player, choices, r, "beacon")
  local module = picker(strip, player, choices, r, "beacon_module")
  module.enabled = module.enabled and r.beacon ~= nil
  local capacity = plan.capacity(player.force, choices, r)
  local side, above, side_max, above_max = 0, 0, 0, 0
  if capacity then
    side_max = capacity.side
    side, above, above_max = plan.beacon_counts(choices, capacity)
  end
  count_drop_down(row, "beacons-side", side_max, side, capacity ~= nil)
  count_drop_down(row, "beacons-above", above_max, above, capacity ~= nil)
end

local function build_power_row(form, player, choices, r)
  picker(slot_strip(form_row(form, "power", { "apl-gui.group-power" }), "apl-power-strip"),
    player, choices, r, "pole")
end

-- How the requester is sized: the rule, its number, and the pencil opening the per-ingredient
-- panel; the trash box under them.
local function build_requests_rows(form, choices, r, panel_open)
  local row = form_row(form, "requests", { "apl-gui.group-requests" })
  local field = plan.size_field(choices)
  mode_drop_down(row, "apl-size-mode", "size", plan.SIZE_MODES, field.mode, { "apl-gui.size-mode-tooltip" })
  number_field(row, "apl-size-value", field, { "apl-gui.size-value-tooltip" }, { requests = true })
  row.add({
    type = "sprite-button", name = "apl-requests-edit", style = "tool_button", sprite = "utility/rename_icon",
    toggled = panel_open, tooltip = titled({ "apl-gui.requests-title" }, { "apl-gui.requests-edit-tooltip" }),
    tags = dispatch.tags("requests"),
  }).enabled = r.recipe ~= nil
  form_row(form, "trash").add({
    type = "checkbox", name = "apl-trash", state = plan.trash(choices),
    caption = { "apl-gui.trash-unrequested" }, tooltip = { "apl-gui.trash-unrequested-tooltip" },
    tags = dispatch.tags("trash"),
  })
end

-- How the stock is capped, and the quality split under it.
local function build_stock_rows(form, choices, r)
  local row = form_row(form, "stock", { "apl-gui.group-stock" })
  local field = plan.cap_field(choices, r.item)
  mode_drop_down(row, "apl-cap-mode", "cap", plan.CAP_MODES, field.mode, { "apl-gui.cap-mode-tooltip" })
  if field.mode ~= "none" then
    number_field(row, "apl-cap-value", field, { "apl-gui.cap-" .. field.mode .. "-tooltip" })
  end
  form_row(form, "split").add({
    type = "checkbox", name = "apl-split", state = choices.split == true,
    caption = { "apl-gui.split" }, tooltip = { "apl-gui.split-tooltip" },
    tags = dispatch.tags("split"),
  }).enabled = proto.next_quality(r.recipe_quality) ~= nil
end

-- `focus`, when given, is the ingredient cell whose control rebuilt the window: its row is
-- scrolled back into view, since a rebuilt pane starts at the top.
function gui.open(player, focus)
  -- A rebuild keeps the window where it was: read off the OLD frame, since a new one reports 0,0
  -- until laid out. The side panel is a child, so it goes down with the frame and is re-created.
  local old = frame_of(player)
  local keep = old and old.location
  if keep and keep.x == 0 and keep.y == 0 then keep = nil end
  local had_panel = panel_of(player) ~= nil
  destroy_modal(player)

  local entry = state.of(player.index)
  entry.chooser_maybe_open = nil
  local choices = entry.choices
  local r = apply_defaults(player, choices)
  local nodes = chain.walk(player.force, choices, entry.cells)
  apply_cell_defaults(entry, nodes)
  keep = lifted(player, keep, nodes)

  local frame = player.gui.screen.add({
    type = "frame", name = FRAME, style = "invisible_frame", direction = "horizontal",
  })
  if keep then frame.location = keep else frame.auto_center = true end
  -- Esc and E close the window like every other; the container owns player.opened whether or
  -- not the side panel is up, and control.lua turns a close request into "panel first".
  player.opened = frame

  local main = frame.add({ type = "frame", name = "apl-main", direction = "vertical" })
  local titlebar = add_titlebar(main, "apl-titlebar", { "apl-gui.title" }, frame)
  -- The one setting, as a toggle: a click flips it, and the window reopens on the change.
  titlebar.add({
    type = "sprite-button", name = "apl-show-all", style = "frame_action_button",
    sprite = "apl-show-all", toggled = show_all(player),
    tooltip = titled({ "mod-setting-name." .. SHOW_ALL_SETTING }, { "mod-setting-description." .. SHOW_ALL_SETTING }),
    tags = dispatch.tags("show-all"),
  }).style.padding = 2
  add_close(titlebar, "apl-close", "close")

  local content = main.add({
    type = "frame", name = "apl-content", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  local make = section(content, "apl-make")
  build_item_row(make, player, choices, r)
  build_machine_row(make, player, choices, r, nodes)
  local pane = build_chain_rows(content, player, nodes)
  if pane and focus then
    local row = pane["apl-chain"]["apl-cell-row/" .. focus]
    if row then pane.scroll_to_element(row, "in-view") end
  end
  separator(content)
  local build = section(content, "apl-build")
  build_logistics_row(build, player, choices, r)
  build_beacon_row(build, player, choices, r)
  build_power_row(build, player, choices, r)
  separator(content)
  local stock = section(content, "apl-stock")
  build_requests_rows(stock, choices, r, had_panel)
  build_stock_rows(stock, choices, r)

  local status = main.add({ type = "flow", name = "apl-status", direction = "vertical" })
  status.style.top_margin = 8

  local buttons = main.add({
    type = "flow", name = "apl-buttons", style = "dialog_buttons_horizontal_flow", direction = "horizontal",
  })
  buttons.add({
    type = "button", name = "apl-cancel", style = "back_button", caption = { "apl-gui.cancel" },
    tags = dispatch.tags("close"),
  })
  local filler = buttons.add({ type = "empty-widget", style = "draggable_space" })
  filler.style.horizontally_stretchable = true
  filler.style.height = 32
  filler.drag_target = frame
  buttons.add({
    type = "button", name = "apl-confirm", style = "confirm_button", caption = { "apl-gui.confirm" },
    tooltip = { "apl-gui.confirm-tooltip" }, tags = dispatch.tags("confirm"),
  })

  local p = gui.refresh(player)
  if had_panel then build_ingredients_panel(player, frame, p) end
end

function gui.toggle(player)
  if frame_of(player) then gui.close(player) else gui.open(player) end
end

-- What the HOTKEY runs. A custom input fires whether or not the shortcut is unlocked, so the key
-- re-checks the engine's own per-save answer, and says why when it refuses -- a dead key reads
-- as a broken binding. Returns the refusal so a spec can pin it.
function gui.toggle_key(player)
  if not player.is_shortcut_available(SHORTCUT) then
    local tech = prototypes.shortcut[SHORTCUT].technology_to_unlock
    if not tech then return end
    local refusal = { "apl-message.planner-not-researched", tech.localised_name }
    player.print(refusal)
    return refusal
  end
  gui.toggle(player)
end

-- The gate is chosen at startup, so a changed mod set can move it onto a technology this save
-- researched long ago. Run on every configuration change: grants once the gate stands
-- researched, never revokes, so a scenario's scripted revoke holds until the next one.
function gui.unlock_shortcut(player)
  local tech = prototypes.shortcut[SHORTCUT].technology_to_unlock
  if not tech or player.force.technologies[tech.name].researched then
    player.set_shortcut_available(SHORTCUT, true)
  end
end

-- Closes the side panel when it is up. Returns whether it was -- control.lua's close request
-- goes "panel first" exactly when this says so.
function gui.close_side_panel(player)
  if not panel_of(player) then return false end
  show_ingredients(player, false)
  return true
end

dispatch.register("requests", function(event)
  local player = game.get_player(event.player_index)
  show_ingredients(player, panel_of(player) == nil)
end)

dispatch.register("ingredients-close", function(event)
  show_ingredients(game.get_player(event.player_index), false)
end)

-- Reopened rather than repainted when the setting flips: every picker's list depends on it.
function gui.on_setting_changed(player)
  if frame_of(player) then gui.open(player) end
end

-- Writing our own per-player setting raises on_runtime_mod_setting_changed just as the settings
-- menu does, so the reopen is left to that one handler.
dispatch.register("show-all", function(event)
  local player = game.get_player(event.player_index)
  player.mod_settings[SHOW_ALL_SETTING] = { value = not show_all(player) }
end)

dispatch.register("close", function(event)
  gui.close(game.get_player(event.player_index))
end)

-- A machine module or beacon module the new machine, recipe or beacon refuses is dropped, so
-- the picker falls back to its default instead of the plan refusing a pick nobody re-made.
-- Judged on the cell's whole choices, written to its own entry -- only the root holds a beacon
-- module.
local function drop_unfitting_modules(player, entry, cell)
  local choices, target = choices_of(entry, cell), target_of(entry, cell)
  local r = plan.picks(player.force, choices)
  local machine = r.machine and prototypes.entity[r.machine]
  local recipe = r.recipe and prototypes.recipe[r.recipe]
  if target.module and machine and not proto.module_fits(target.module, machine, recipe) then
    target.module = nil
  end
  local beacon = r.beacon and prototypes.entity[r.beacon]
  if target.beacon_module and beacon and not proto.module_fits(target.beacon_module, beacon) then
    target.beacon_module = nil
  end
end

-- What a pick of a NEW prototype changes beyond its own key; a quality change alone changes
-- nothing else.
local AFTER_PICK = {
  -- The amounts were sized against the old recipe, the recipe list is the new item's, and a
  -- new item starts a new chain.
  item = function(player, entry)
    clear_request_overrides(entry.choices)
    entry.choices.recipe = nil
    entry.cells = {}
    drop_unfitting_modules(player, entry)
  end,
  machine = drop_unfitting_modules,
  beacon = drop_unfitting_modules,
}

-- One click on a picker raises on_gui_click AND on_gui_elem_changed, both routed here, the
-- first carrying the value the button already holds -- and that click arrives as the engine
-- opens its chooser, so rebuilding on it would tear the chooser down. So nothing happens unless
-- the value actually changed, compared after normalising the quality (nil and "normal" are the
-- same pick).
dispatch.register("pick", function(event)
  local player = game.get_player(event.player_index)
  local entry = state.of(event.player_index)
  local cell = event.element.tags.cell
  -- The table this picker writes: an ingredient cell's own entry, or the root's choices.
  local choices = target_of(entry, cell)
  if not choices then return end
  local key = event.element.tags.key
  local spec = PICKERS[key]
  local value = event.element.elem_value
  local name, quality = value, nil
  if type(value) == "table" then name, quality = value.name, value.quality end
  local renamed = name ~= choices[key]

  if name == nil then
    if not spec.clear then
      -- Nothing to build without it: snap back to what holds.
      event.element.elem_value = shown(spec, choices, key)
      return
    end
    if choices[key] == nil and (not spec.flag or choices[spec.flag]) then return end
    choices[key] = nil
    if spec.flag then choices[spec.flag] = true end
  else
    local same_quality = not spec.quality
      or proto.build_quality(choices[spec.quality]) == proto.build_quality(quality)
    if not renamed and same_quality and not (spec.flag and choices[spec.flag]) then return end
    choices[key] = name
    if spec.quality then choices[spec.quality] = quality end
    if spec.flag then choices[spec.flag] = nil end
  end

  if renamed and AFTER_PICK[key] then AFTER_PICK[key](player, entry, cell) end
  if spec.rebuild then gui.open(player, cell) else gui.refresh(player) end
end)

-- Drop-downs: the click that opens one is routed here too, carrying the old selection, so only
-- a real selection change counts.
local function on_selection(name, fn)
  dispatch.register(name, function(event)
    if event.name ~= defines.events.on_gui_selection_state_changed then return end
    fn(game.get_player(event.player_index), state.of(event.player_index).choices, event.element)
  end)
end

-- The root's recipe list, or an ingredient cell's; either drops that cell's own amounts only.
on_selection("recipe", function(player, _, element)
  local entry = state.of(player.index)
  local cell = element.tags.cell
  local target = target_of(entry, cell)
  local name = element.tags.recipes[element.selected_index]
  if not (target and name) or name == plan.picks(player.force, choices_of(entry, cell)).recipe then return end
  target.recipe = name
  clear_request_overrides(target)
  drop_unfitting_modules(player, entry, cell)
  gui.open(player, cell)
end)

-- The count drop-downs store a number only once picked; until then nil means "as many as fit".
-- The side count decides how wide the row above may be, so it reopens the window.
on_selection("beacons-side", function(player, choices, element)
  choices.beacons_side = element.selected_index - 1
  gui.open(player)
end)

on_selection("beacons-above", function(player, choices, element)
  choices.beacons_above = element.selected_index - 1
  gui.refresh(player)
end)

-- A rule drop-down: store the mode and reopen, since its number field changes with it.
local function mode_handler(name, key, modes, current, on_change)
  on_selection(name, function(player, choices, element)
    local mode = modes[element.selected_index]
    if not mode or mode == current(choices) then return end
    choices[key] = mode
    if on_change then on_change(state.of(player.index)) end
    gui.open(player)
  end)
end

-- A new sizing rule replaces the amounts set by hand in every cell, which were sized by the old
-- one.
mode_handler("size-mode", "size_mode", plan.SIZE_MODES, plan.size_mode, clear_all_request_overrides)
mode_handler("cap-mode", "cap_mode", plan.CAP_MODES, plan.cap_mode)

-- A row's count: stored only above one, so an untouched row stays a single cell.
on_selection("count", function(player, _, element)
  local target = target_of(state.of(player.index), element.tags.cell)
  local n = element.selected_index
  if not target or n < 1 or chain.count_of(target.count) == n then return end
  target.count = n > 1 and n or nil
  gui.refresh(player)
end)

-- Every ingredient row set to its balanced count, the root's left as the player set it.
dispatch.register("balance", function(event)
  if event.name ~= defines.events.on_gui_click then return end
  local player = game.get_player(event.player_index)
  local p = plan_of(player)
  if not p or balanced_total(p) > chain.MAX_TOTAL then return end
  local entry = state.of(event.player_index)
  for index = 2, #p.cells do
    local c = p.cells[index]
    local target = entry.cells[c.item]
    if target then target.count = c.best > 1 and c.best or nil end
  end
  gui.refresh(player)
end)

-- An ingredient beside a machine: ticked into the chain or out of it. Unticking keeps the
-- cell's entry, so ticking it again brings the cell back as it was.
dispatch.register("chain", function(event)
  if event.name ~= defines.events.on_gui_click then return end
  local player = game.get_player(event.player_index)
  local entry = state.of(event.player_index)
  local tags = event.element.tags
  local cell = entry.cells[tags.item] or {}
  entry.cells[tags.item] = cell
  cell.on = (not tags.on) or nil
  gui.open(player, cell.on and tags.item or nil)
end)

-- Every number field -- the sizing number, the cap, each ingredient amount: every valid
-- keystroke commits, Enter snaps the display back to what holds, Enter on an emptied field
-- returns to the default, and an untouched default is never stored, so it keeps following its
-- default. Matches both event names on purpose: the dispatcher routes the focus click here too,
-- carrying the displayed value, which must never freeze into an override. A sizing change
-- replaces every per-ingredient amount.
dispatch.register("number", function(event)
  local player = game.get_player(event.player_index)
  local entry = state.of(event.player_index)
  local tags = event.element.tags
  -- An ingredient cell's amount lands in its own entry; every other number is the root's.
  local choices = target_of(entry, tags.cell)
  if not choices then return end
  local value = tonumber(event.element.text)
  local before = choices[tags.key]
  if event.name == defines.events.on_gui_confirmed then
    if not value then
      choices[tags.key] = nil
      event.element.text = tostring(tags.default)
    elseif before ~= nil or value ~= tags.default then
      value = util.clamp(value, tags.min, tags.max)
      choices[tags.key] = value
      event.element.text = tostring(value)
    end
  elseif event.name == defines.events.on_gui_text_changed then
    if not value then return end
    choices[tags.key] = util.clamp(value, tags.min, tags.max)
  else
    return
  end
  if choices[tags.key] == before then return end
  if tags.requests then clear_all_request_overrides(entry) end
  gui.refresh(player)
end)

dispatch.register("trash", function(event)
  local choices = state.of(event.player_index).choices
  if plan.trash(choices) == event.element.state then return end
  choices.trash_unrequested = event.element.state
  gui.refresh(game.get_player(event.player_index))
end)

-- The split box stores what was clicked; gui.refresh drops it again once it agrees with the
-- automatic answer.
dispatch.register("split", function(event)
  local choices = state.of(event.player_index).choices
  if choices.split == event.element.state then return end
  choices.split = event.element.state
  gui.refresh(game.get_player(event.player_index))
end)

function gui.confirm(player)
  if not frame_of(player) then return end
  local p = plan_of(player)
  if not p then return end
  -- Left open on a refusal, so freeing a hand and pressing Place again is the whole recovery.
  local given, reason = blueprint.give(player, p)
  if not given then
    player.print(reason)
    return
  end
  gui.close(player)
end

dispatch.register("confirm", function(event)
  gui.confirm(game.get_player(event.player_index))
end)

-- What the Confirm KEY runs. The key fires on every press of E, including one aimed at an
-- element chooser floating over the window, where confirming would trade the pick for a
-- blueprint -- so one press is swallowed while a chooser is presumed open, and the engine's own
-- confirm then lands on the chooser. With the side panel up the key places nothing: E belongs to
-- the panel, which the engine's own close then dismisses. The button takes neither guard.
function gui.confirm_key(player)
  local entry = state.peek(player.index)
  if entry and entry.chooser_maybe_open then
    entry.chooser_maybe_open = nil
    return
  end
  if panel_of(player) then return end
  gui.confirm(player)
end

dispatch.observe(note_gui_event)

return gui
