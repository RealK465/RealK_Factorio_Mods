-- Host-interpreter runner for a mod's tests/pure/ specs: the same files factorio-test runs
-- in-game, executed on plain Lua in well under a second. Usage:
--
--   lua pure-runner.lua <mod-root> <spec-file> [<spec-file> ...]
--
-- Provides the minimal surface the pure specs use -- describe/test and real-valued
-- defines.direction -- and NOTHING more, on purpose: a pure spec that reaches for
-- before_each, storage or prototypes should fail loudly here, because that is the moment it
-- stopped being pure. The host is whatever Lua is on PATH (5.5 today) while the game runs a
-- modified 5.2; the same specs run in-game through factorio-test, so an interpreter-semantics
-- drift shows up as a split verdict rather than going unnoticed.

local mod_root = arg[1]
if not mod_root or not arg[2] then
  io.stderr:write("usage: lua pure-runner.lua <mod-root> <spec-file> [...]\n")
  os.exit(2)
end

-- require("scripts.layout") resolves against the mod root, matching Factorio's rule that
-- absolute requires start there.
package.path = mod_root .. "/?.lua;" .. package.path

-- The real 2.x sixteen-direction values, not sentinels: layout.lua only stores and compares
-- them, but matching the engine keeps a dumped plan comparable across the two tiers. The
-- guard metatables keep the promise below honest for defines too: a spec reaching for, say,
-- defines.inventory would otherwise get a silent nil here and a real table in-game.
local function guarded(name, table)
  return setmetatable(table, {
    __index = function(_, key)
      error(name .. "." .. tostring(key) .. " does not exist on the host runner -- "
        .. "pure specs may only use defines.direction", 2)
    end,
  })
end
_G.defines = guarded("defines", {
  direction = guarded("defines.direction", {
    north = 0, northeast = 2, east = 4, southeast = 6,
    south = 8, southwest = 10, west = 12, northwest = 14,
  }),
})

local names, failures, passed = {}, {}, 0

function _G.describe(name, body)
  names[#names + 1] = name
  body()
  names[#names] = nil
end

local function label(name)
  return table.concat(names, " > ") .. " > " .. name
end

function _G.test(name, body)
  local ok, err = pcall(body)
  if ok then
    passed = passed + 1
  else
    failures[#failures + 1] = label(name) .. "\n    " .. tostring(err)
    io.write("FAIL ", label(name), "\n")
  end
end

-- Anything else the in-game framework offers is deliberately absent; explain instead of
-- erroring with a bare nil-call when a spec drifts impure.
setmetatable(_G, {
  __index = function(_, key)
    error("'" .. tostring(key) .. "' does not exist on the host runner -- "
      .. "pure specs may only use describe, test, defines.direction and standard Lua", 2)
  end,
})

for i = 2, #arg do
  local chunk, err = loadfile(arg[i])
  if not chunk then
    io.stderr:write("cannot load " .. arg[i] .. ": " .. tostring(err) .. "\n")
    os.exit(2)
  end
  chunk()
end

io.write(("Pure tier: %d passed, %d failed\n"):format(passed, #failures))
for _, failure in ipairs(failures) do
  io.write(failure, "\n")
end
os.exit(#failures == 0 and 0 or 1)
