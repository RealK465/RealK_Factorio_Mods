-- Network mode's maximum, kept editable on the limits combinator.
--
-- Network mode bakes its maximum into each gated entity as a logistic-condition constant,
-- which no combinator row can reach (circuits.lua, NETWORK MODE). So an edit to the limits
-- combinator's C row is copied onto every gated entity in its green network -- the wire the
-- plan already lays to each of them. Ghosts are walked and written too: a condition written
-- onto a ghost survives its revive (analysis/api.md S35).
--
-- A script's edit raises on_entity_logistic_slot_changed (measured, S35), and a player's has
-- since Wube's 2.0.10 fix for constant combinators; a player's paste raises only
-- on_entity_settings_pasted, hence both in control.lua. A blueprint stamped over the
-- combinator raises neither and needs neither: it rewrites the gated entities itself.

local util = require("util")
local circuits = require("scripts.circuits")

local retune = {}

local GREEN = defines.wire_connector_id.circuit_green

-- What network mode gates on the network: machines, recyclers and the two lamps.
local GATED = { ["assembling-machine"] = true, furnace = true, lamp = true }

local function kind_of(entity)
  return entity.type == "entity-ghost" and entity.ghost_type or entity.type
end

-- The C row's count and the quality it is badged with, the target's.
local function cap_row(behaviour)
  for _, section in pairs(behaviour.sections) do
    for _, filter in pairs(section.filters) do
      local value = filter.value
      if value and value.type == "virtual" and value.name == circuits.SIGNAL_CAP then
        return filter.min, value.quality
      end
    end
  end
end

function retune.from_combinator(combinator)
  -- The slot event fires for every logistic slot in the game -- requester chests, personal
  -- requests -- so the type check comes first.
  if not (combinator and combinator.valid and kind_of(combinator) == "constant-combinator") then
    return
  end
  if not util.string_starts_with(combinator.combinator_description, circuits.DESCRIPTION_PREFIX) then
    return
  end
  local behaviour = combinator.get_control_behavior()
  if not behaviour then return end

  -- A C of 0 or below is the pause the wire condition already holds, so the constants keep
  -- the last real maximum -- which also keeps the green lamp honest while paused.
  local maximum, quality = cap_row(behaviour)
  if not (maximum and maximum > 0) then return end

  local seen, stack = { [combinator.unit_number] = true }, { combinator }
  while #stack > 0 do
    local entity = stack[#stack]
    stack[#stack] = nil
    if GATED[kind_of(entity)] then
      local gate = entity.get_control_behavior()
      local condition = gate and gate.connect_to_logistic_network and gate.logistic_condition
      local signal = condition and condition.first_signal
      -- Matched on the target's quality: a cap compares product@target, and nothing else in
      -- the loop is gated on the network.
      if signal and signal.quality == quality and condition.constant ~= maximum then
        gate.logistic_condition =
          { comparator = condition.comparator, first_signal = signal, constant = maximum }
      end
    end
    local connector = entity.get_wire_connector(GREEN, false)
    for _, connection in pairs(connector and connector.connections or {}) do
      local other = connection.target.owner
      if not seen[other.unit_number] then
        seen[other.unit_number] = true
        stack[#stack + 1] = other
      end
    end
  end
end

return retune
