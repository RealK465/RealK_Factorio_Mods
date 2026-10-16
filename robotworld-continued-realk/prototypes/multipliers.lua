local lib = require("prototypes.lib")
local util = require("util")
local setting = lib.setting
local multiply_energy = lib.multiply_energy

-- kind is "construction" or "logistics"; health is shared by both.
local function robot_multipliers(kind)
  return {
    battery = setting(kind .. "-robot-battery-size-multiplier"),
    energy = setting(kind .. "-robot-energy-usage-multiplier"),
    payload = setting(kind .. "-robot-carry-size-multiplier"),
    speed = setting(kind .. "-robot-speed-multiplier"),
    health = setting("robot-health-multiplier"),
  }
end

local function scale_robot(robot, m)
  robot.max_energy = multiply_energy(robot.max_energy, m.battery)
  -- One energy setting covers both flying and hovering.
  robot.energy_per_move = multiply_energy(robot.energy_per_move, m.energy)
  robot.energy_per_tick = multiply_energy(robot.energy_per_tick, m.energy)

  -- Cargo size must be a whole number, and the after-bonus caps must stay at or above
  -- the new base values or the game refuses to load.
  local payload = math.max(1, math.floor(robot.max_payload_size * m.payload + 0.5))
  robot.max_payload_size = payload
  if robot.max_payload_size_after_bonus and robot.max_payload_size_after_bonus < payload then
    robot.max_payload_size_after_bonus = payload
  end

  robot.speed = robot.speed * m.speed
  if robot.max_speed and robot.max_speed < robot.speed then
    robot.max_speed = robot.speed
  end

  -- 10 is the engine default for an entity that leaves max_health unset.
  robot.max_health = (robot.max_health or 10) * m.health
end

-- Hidden robots belong to other mods' own mechanics.
local scaled = {}
for kind, robot_type in pairs({logistics = "logistic-robot", construction = "construction-robot"}) do
  local m = robot_multipliers(kind)
  for name, robot in pairs(data.raw[robot_type]) do
    if not robot.hidden then
      scale_robot(robot, m)
      scaled[name] = true
    end
  end
end

-- An item places a robot through place_result, whatever either is named.
local stack_size = setting("robot-stack-size")
for _, item in pairs(data.raw.item) do
  if item.place_result and scaled[item.place_result] then
    item.stack_size = stack_size
  end
end

local only_vanilla = setting("only-modify-vanilla-roboport")
local logistics_multiplier = setting("roboport-logistics-radius-multiplier")
local construction_multiplier = setting("roboport-construction-radius-multiplier")
local charging_multiplier = setting("roboport-charging-rate-multiplier")
local usage_multiplier = setting("roboport-energy-usage-multiplier")

-- Hidden roboports belong to other mods' own mechanics too, such as Factorissimo's inside
-- factory buildings.
for name, roboport in pairs(data.raw.roboport) do
  if not roboport.hidden and (name == "roboport" or not only_vanilla) then
    -- The buffer grows with the charging rate, so a faster port does not run itself dry. The
    -- restart level after a blackout scales with it, or a smaller buffer could never reach it.
    local source = roboport.energy_source
    source.buffer_capacity = multiply_energy(source.buffer_capacity, charging_multiplier)
    source.input_flow_limit = multiply_energy(source.input_flow_limit, charging_multiplier)
    roboport.recharge_minimum = multiply_energy(roboport.recharge_minimum, charging_multiplier)
    roboport.charging_energy = multiply_energy(roboport.charging_energy, charging_multiplier)
    roboport.energy_usage = multiply_energy(roboport.energy_usage, usage_multiplier)
    -- The engine refuses a restart level below one tick of idle power.
    local idle = util.parse_energy(roboport.energy_usage)
    if util.parse_energy(roboport.recharge_minimum) < idle then
      roboport.recharge_minimum = math.ceil(idle) .. "J"
    end

    roboport.logistics_radius = roboport.logistics_radius * logistics_multiplier
    roboport.construction_radius = roboport.construction_radius * construction_multiplier

    -- The engine requires the connection distance to cover the logistics radius.
    if roboport.logistics_connection_distance and roboport.logistics_radius > roboport.logistics_connection_distance then
      roboport.logistics_connection_distance = roboport.logistics_radius
    end
  end
end

local inserter_speed = setting("inserter-speed-multiplier")
for _, inserter in pairs(data.raw.inserter) do
  inserter.extension_speed = inserter.extension_speed * inserter_speed
  inserter.rotation_speed = inserter.rotation_speed * inserter_speed
end
