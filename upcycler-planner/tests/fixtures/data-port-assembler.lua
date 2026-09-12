-- A test-only assembling machine carrying what Muluna (planet-muluna,
-- prototypes/final-fixes/data-cells.lua, 2.7.22) adds to every assembling machine 3 and its
-- modded peers: the two vanilla fluid boxes copied as "data"-category ports on the OTHER
-- faces -- the input turned from north to east, the output from south to west -- each behind
-- 28 dummy linked boxes, and use_mirroring switched on. The copies keep their production
-- type, so the east one reads as a fluid input in every respect but the category, which is
-- exactly what fooled the rotation rule (portal thread 6aa5301e3f44270ff33f555a, 2026-09-12).
--
-- Loaded from data.lua only when the test framework mod is present, so it never reaches a
-- player's game. No item places it, which keeps it out of the machine picker and every other
-- spec's default picks; fluid_spec stands it by name.
local util = require("util")

local function dummy_fluidbox(production_type, flow_direction, id)
  return {
    volume = 0.5 ^ 24,
    production_type = production_type,
    pipe_connections = {{
      flow_direction = flow_direction, connection_type = "linked",
      hide_connection_info = true, linked_connection_id = id,
    }},
  }
end

local function rotate_position(position)
  local x = position.x or position[1]
  local y = position.y or position[2]
  return { -y, x }
end

local turned = {
  [defines.direction.north] = defines.direction.east,
  [defines.direction.south] = defines.direction.west,
  [defines.direction.east] = defines.direction.north,
  [defines.direction.west] = defines.direction.south,
}

local machine = util.table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
machine.name = "upl-test-data-port-assembler"
machine.localised_name = "Test assembler with a data port"
machine.minable = nil
machine.hidden = true

local id = 100
local input = util.table.deepcopy(machine.fluid_boxes[1])
local output = util.table.deepcopy(machine.fluid_boxes[2])
for _, box in pairs({ input, output }) do
  for _ = 1, 28 do
    id = id + 1
    table.insert(machine.fluid_boxes,
      dummy_fluidbox(box.production_type, box.pipe_connections[1].flow_direction, id))
  end
  box.pipe_picture = nil
  box.pipe_covers = nil
  for _, connection in pairs(box.pipe_connections) do
    connection.position = rotate_position(connection.position)
    connection.connection_category = "data"
    connection.direction = turned[connection.direction] or connection.direction
  end
  table.insert(machine.fluid_boxes, box)
end
machine.use_mirroring = true

data:extend({ machine })
