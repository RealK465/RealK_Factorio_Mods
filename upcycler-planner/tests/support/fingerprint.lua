-- A structural digest of a plain table, so a spec can pin "this output did not move" against a
-- number captured from an earlier tree -- the belt goldens' whole job, where comparing two
-- builds of the same code proves nothing. Pure and interpreter-neutral, since the pure tier
-- runs it on the host and in the game: keys sorted, numbers written as integers only, and a
-- modular hash with no bit operations, every intermediate an exact integer under both. No
-- float ever reaches a format string: the game's %.17g prints 0.15 as "0.15" where host Lua
-- prints "0.14999999999999999" (measured 2026-11-27, the lamp colour), and tostring differs
-- on integral floats ("3" against "3.0") -- so a fraction is scaled to micro-units first.

local fingerprint = {}

local function serialise(value, out)
  local kind = type(value)
  if kind == "table" then
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    out[#out + 1] = "{"
    for _, key in ipairs(keys) do
      serialise(key, out)
      out[#out + 1] = "="
      serialise(value[key], out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  elseif kind == "number" then
    if value == math.floor(value) then
      out[#out + 1] = string.format("%d", value)
    else
      out[#out + 1] = "~" .. string.format("%d", math.floor(value * 1000000 + 0.5))
    end
  elseif kind == "string" then
    out[#out + 1] = string.format("%q", value)
  else
    out[#out + 1] = tostring(value)
  end
end

function fingerprint.text(value)
  local out = {}
  serialise(value, out)
  return table.concat(out)
end

-- Length plus two independent hashes: a collision would have to fool all three at once.
function fingerprint.of(value)
  local text = fingerprint.text(value)
  local h1, h2 = 0, 7
  for i = 1, #text do
    local b = text:byte(i)
    h1 = (h1 * 31 + b) % 2147483647
    h2 = (h2 * 131 + b) % 1000000007
  end
  return #text .. ":" .. h1 .. ":" .. h2
end

return fingerprint
