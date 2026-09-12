require("prototypes.planner.shortcut")
require("prototypes.planner.input")

-- The data-stage twin of control.lua's test guard: a prototype the specs stand by name, built
-- only when the test framework mod is present. tests/** never ships, so in a player's copy the
-- file is absent and, behind the guard, never asked for.
if mods["factorio-test"] then
  require("tests.fixtures.data-port-assembler")
end
