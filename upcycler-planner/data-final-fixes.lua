-- The shortcut's gate, read off the finished data so other mods' technology changes are in
-- first. prototypes/planner/gate.lua says why the gate moves at all.
local gate = require("prototypes.planner.gate")

local shortcut = data.raw.shortcut["upl-open"]
local technology = gate.technology(data.raw, defines.prototypes.item)
if technology == false then
  shortcut.technology_to_unlock = nil
  shortcut.unavailable_until_unlocked = nil
elseif technology then
  shortcut.technology_to_unlock = technology
end
