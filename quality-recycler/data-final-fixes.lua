-- Size the result inventory to the widest recipe the machine can run.
--
-- A furnace cannot craft a recipe with more products than it has result
-- slots, and an inserter then refuses the ingredient: the machine sits idle
-- with nothing in it and no message. The vanilla recycler ships 12 slots for
-- scrap recycling's 12 results, and this machine shipped that number for a
-- day -- but other mods add results. Krastorio 2 Spaced Out inserts a 13th
-- into scrap recycling and widens the VANILLA recycler to match in its own
-- final-fixes, which left every other recycler at 12 and unable to take
-- scrap at all. Measured 2026-09-12 under the owner's mod set. The prototype
-- now says 25, the owner's floor; this file only ever raises it.
--
-- So the number is read off the recipes here, after every mod has had its
-- say, and only ever grows. A recipe names its categories in the plural on
-- 2.1 and the singular on 2.0; both spellings are still legal, so both are
-- read.
local machine = data.raw["furnace"]["quality-recycler"]
local mine = {}
for _, c in pairs(machine.crafting_categories) do mine[c] = true end

local widest = machine.result_inventory_size or 0
for _, recipe in pairs(data.raw["recipe"]) do
  local categories = recipe.categories or { recipe.category or "crafting" }
  for _, c in pairs(categories) do
    if mine[c] and recipe.results and #recipe.results > widest then
      widest = #recipe.results
    end
  end
end
machine.result_inventory_size = widest
