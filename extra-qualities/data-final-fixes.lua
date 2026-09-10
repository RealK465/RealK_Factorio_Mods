-- The quality picker in machines, filters and logistic requests switches from a row of
-- buttons to a dropdown once there are quality_selector_dropdown_threshold qualities, and
-- core sets that to 6 on 2.0 as well as 2.1. Vanilla trips it as soon as any mod adds a
-- tier, and losing the buttons is the thing players complain about most in the quality mods
-- that did not notice. Counted at final-fixes so other quality mods are included.
--
-- **2.0 counts every quality, hidden ones included, where the 2.1 file counts only the shown
-- ones.** The quality mod un-hides `normal` on 2.1 but not on 2.0, so with this mod installed
-- the shown count here is 6 against 2.1's 7, while both games build 8 qualities in total
-- (`quality-unknown` is hidden on both). `shown + 1` would therefore set the threshold to 7
-- and leave 8 qualities above it - which trips the dropdown if the engine counts the hidden
-- ones. Measured from the dumps, not assumed. Counting the total is right under either
-- reading, and an over-large threshold costs nothing.

local total = 0
for _ in pairs(data.raw.quality) do
  total = total + 1
end

-- A much longer ladder is left alone: a twenty-button row is worse than the dropdown.
if total <= 9 then
  data.raw["utility-constants"]["default"].quality_selector_dropdown_threshold = total + 1
end
