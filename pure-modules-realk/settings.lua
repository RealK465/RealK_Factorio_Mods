-- Startup settings: read in the data stage, so they are locked once a save
-- exists. All four change prototypes, none of them runtime state.
--
-- The mods table is available here, not just in the data stage -- the settings
-- and prototype stages are built the same way. So a setting that would mean
-- nothing can simply not exist rather than sit in the GUI doing nothing.

local settings_to_add = {
  {
    type = "bool-setting",
    name = "pure-modules-realk-restrict-to-pure-beacon",
    setting_type = "startup",
    default_value = true,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "pure-modules-realk-beacon-allow-productivity",
    setting_type = "startup",
    default_value = false,
    order = "c",
  },
}

-- A setting that would mean nothing is not defined at all, rather than sitting
-- in the GUI doing nothing. Both of these have a cost if left in: the Aquilo
-- one would gate recipes against a planet that does not exist, and the quality
-- one would charge the beacon an extra megawatt to transmit an effect no
-- module can produce. Anything reading either must short-circuit on the mods
-- check first -- indexing a setting that was never defined is an error, not a
-- nil.
if mods["quality"] then
  settings_to_add[#settings_to_add + 1] = {
    type = "bool-setting",
    name = "pure-modules-realk-beacon-allow-quality",
    setting_type = "startup",
    default_value = false,
    order = "d",
  }
end

if mods["space-age"] then
  table.insert(settings_to_add, 1, {
    type = "bool-setting",
    name = "pure-modules-realk-aquilo-only",
    setting_type = "startup",
    default_value = true,
    order = "a",
  })
end

data:extend(settings_to_add)
