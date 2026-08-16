---@meta
-- Type surface of the factorio-test framework (mod "factorio-test", 3.x) for emmylua_check /
-- EmmyLua. Hand-written against the framework's documented API -- the framework's own
-- .def.lua files live inside its zip, which the static tier does not unpack; this covers the
-- subset our specs use. Loaded via .emmyrc.json workspace.library.

---@param name string
---@param body fun()
function describe(name, body) end

---@class factorio-test.test
---@overload fun(name: string, body: fun())
test = {}

---@param name string
---@param body fun()? For todo, the body may be omitted.
function test.todo(name, body) end

---@param name string
---@param body fun()
function test.skip(name, body) end

---@param name string
---@param body fun()
function test.only(name, body) end

---@param values any[]
---@return fun(name: string, body: fun(...))
function test.each(values) end

it = test

---@param body fun()
function before_all(body) end

---@param body fun()
function after_all(body) end

---@param body fun()
function before_each(body) end

---@param body fun()
function after_each(body) end

---@param body fun()
function after_test(body) end

---@param ticks integer
---@param body fun()
function after_ticks(ticks, body) end

---@param timeout integer?
function async(timeout) end

function done() end

---@param body fun(): boolean?
function on_tick(body) end

---@param ticks integer
function ticks_between_tests(ticks) end

---@param ... string
function tags(...) end
