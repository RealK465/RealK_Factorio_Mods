local function startup(setting_type, name, order, default, minimum)
  return {
    type = setting_type,
    name = "rwcr-" .. name,
    setting_type = "startup",
    default_value = default,
    minimum_value = minimum,
    order = order,
  }
end

local function multiplier(name, order, minimum)
  return startup("double-setting", name, order, 1, minimum or 0)
end

local function toggle(name, order, default)
  return startup("bool-setting", name, order, default or false)
end

local early_robots = startup("string-setting", "early-robots", "a-a", "off")
-- Each level includes everything before it; prototypes/lib.lua reads them in this order.
early_robots.allowed_values = {"off", "construction", "logistic", "logistic-system"}

data:extend({
  early_robots,
  toggle("cheap-recipes", "a-b", true),
  toggle("enable-quick-start", "a-c"),
  toggle("start-with-power-armor", "a-d"),

  multiplier("construction-robot-speed-multiplier", "b-a"),
  multiplier("construction-robot-carry-size-multiplier", "b-b"),
  multiplier("construction-robot-battery-size-multiplier", "b-c"),
  multiplier("construction-robot-energy-usage-multiplier", "b-d"),

  multiplier("logistics-robot-speed-multiplier", "c-a"),
  multiplier("logistics-robot-carry-size-multiplier", "c-b"),
  multiplier("logistics-robot-battery-size-multiplier", "c-c"),
  multiplier("logistics-robot-energy-usage-multiplier", "c-d"),

  -- The engine refuses a robot with 0 health.
  multiplier("robot-health-multiplier", "d-a", 0.01),
  startup("int-setting", "robot-stack-size", "d-b", 50, 1),

  multiplier("roboport-logistics-radius-multiplier", "e-a"),
  multiplier("roboport-construction-radius-multiplier", "e-b"),
  multiplier("roboport-charging-rate-multiplier", "e-c"),
  multiplier("roboport-energy-usage-multiplier", "e-d"),
  toggle("only-modify-vanilla-roboport", "e-e"),

  multiplier("inserter-speed-multiplier", "f-a"),
})
