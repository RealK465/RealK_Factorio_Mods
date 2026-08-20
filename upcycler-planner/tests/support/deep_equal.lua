-- Structural equality for the determinism specs: two plans built from the same input must be
-- the same plan, field for field. Shared by the two pure specs -- layout and poles both make
-- the "same input, same output" promise, and each carrying its own comparator is how the two
-- would drift on the first missed field. Pure by construction: standard Lua only, so the host
-- runner loads it identically to the game.

-- false and nil compare unequal on purpose: a field that flips between "explicitly off" and
-- "absent" is exactly the kind of drift a determinism spec exists to catch.
local function deep_equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for key, value in pairs(a) do
    if not deep_equal(value, b[key]) then return false end
  end
  for key in pairs(b) do
    if a[key] == nil then return false end
  end
  return true
end

return deep_equal
