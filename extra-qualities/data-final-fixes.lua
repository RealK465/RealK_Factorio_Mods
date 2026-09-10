-- The quality picker in machines, filters and logistic requests switches from a row of
-- buttons to a dropdown once there are quality_selector_dropdown_threshold qualities, and
-- core sets that to 6. Vanilla ships five, so any mod that adds a single tier trips it -
-- and losing the buttons is the thing players complain about most in the quality mods that
-- did not notice. Counted at final-fixes so other quality mods are included.

local shown = 0
for _, quality in pairs(data.raw.quality) do
  if not quality.hidden then
    shown = shown + 1
  end
end

-- A much longer ladder is left alone: a twenty-button row is worse than the dropdown.
if shown <= 8 then
  data.raw["utility-constants"]["default"].quality_selector_dropdown_threshold = shown + 1
end
