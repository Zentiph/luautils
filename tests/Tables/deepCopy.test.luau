--!strict

-- deepCopy tests
-- by @vuppyan

local test = require("@std/test")
local types = require("@std/test/types")
local Helpers = require("../Helpers")
local deepCopy = require("../../src/luautils/Tables/deepCopy")

local function assertDeepCopy(
    asserts: types.Asserts,
    original: { [any]: any },
    copy: { [any]: any },
    seen: { [any]: any }?
)
    local visited = seen or {}
    if visited[original] then
        asserts.eq(visited[original], copy)
        return
    end
    visited[original] = copy

    asserts.neq(original, copy)
    asserts.eq(getmetatable(original :: any), getmetatable(copy :: any))

    for k, v in original do
        if type(v) == "table" then
            asserts.eq("table", type(copy[k]))
            assertDeepCopy(asserts, v, copy[k], visited)
        else
            asserts.eq(v, copy[k])
        end
    end
    for k in copy do
        asserts.neq(nil, original[k])
    end
end

test.suite("deepCopy", function(suite)
    suite:case("copies flat table normally", function(asserts)
        local t = { 1, 2, 3 }
        assertDeepCopy(asserts, t, deepCopy(t))
    end)

    suite:case("copies nested tables correctly", function(asserts)
        local t = { 1, { 2 }, { 3, { 4 } } }
        assertDeepCopy(asserts, t, deepCopy(t))
    end)

    suite:case("copies dictionaries and mixed tables", function(asserts)
        local t = {
            name = "a",
            list = { 1, 2 },
            [10] = true,
            nested = { x = { y = "z" } },
        }
        assertDeepCopy(asserts, t, deepCopy(t))
    end)

    suite:case("copies empty tables", function(asserts)
        local t = {}
        assertDeepCopy(asserts, t, deepCopy(t))
    end)

    suite:case("copy is independent of the original", function(asserts)
        local t = { inner = { 1 } }
        local copy = deepCopy(t)

        copy.inner[1] = 99
        copy.added = true

        asserts.eq(1, t.inner[1])
        asserts.eq(nil, (t :: any).added)
    end)

    suite:case("preserves cycles inside the copy", function(asserts)
        local t = { child = {} }
        t.self = t
        t.child.parent = t
        local copy = deepCopy(t)

        asserts.eq(copy, copy.self)
        asserts.eq(copy, copy.child.parent)
        asserts.neq(t, copy.self)
    end)

    suite:case("preserves shared references", function(asserts)
        local shared = { 1 }
        local t = { a = shared, b = shared }
        local copy = deepCopy(t)

        asserts.eq(copy.a, copy.b)
        asserts.eq(shared, copy.a)
    end)

    suite:case("preserves metatables", function(asserts)
        local mt = {
            __index = function()
                return "default"
            end,
        }
        local t = setmetatable({ inner = setmetatable({}, mt) }, mt)
        local copy = deepCopy(t)

        asserts.eq(mt, getmetatable(copy))
        asserts.eq(mt, getmetatable(copy.inner))
        asserts.eq("default", copy.missing)
    end)

    suite:case("fails on locked metatable", function(asserts)
        local mt = {
            __metatable = "locked",
        }
        local t = setmetatable({ inner = setmetatable({}, mt) }, mt)
        Helpers.throwsWith(asserts, function()
            deepCopy(t)
        end, "[Tables.deepCopy()]: Cannot copy a table with a locked metatable")
    end)

    suite:case("fails on nested locked metatable", function(asserts)
        local t = { a = { b = setmetatable({}, { __metatable = false }) } }
        Helpers.throwsWith(asserts, function()
            deepCopy(t)
        end, "[Tables.deepCopy()]: Cannot copy a table with a locked metatable")
    end)

    suite:case("locked metatable error points to the caller", function(asserts)
        local t = { a = { b = setmetatable({}, { __metatable = "locked" }) } }
        Helpers.throwsWith(asserts, function()
            deepCopy(t)
        end, "deepCopy.test")
    end)

    suite:case("returns non-table values as-is", function(asserts)
        local fn = function() end
        asserts.eq(5, deepCopy(5))
        asserts.eq("hi", deepCopy("hi"))
        asserts.eq(fn, deepCopy(fn))
        asserts.eq(nil, deepCopy(nil))
    end)

    suite:case("copies of frozen tables are frozen", function(asserts)
        local t = table.freeze({ 1, 2, 3 })
        local copy = deepCopy(t)

        assertDeepCopy(asserts, t, copy)
        asserts.eq(true, table.isfrozen(copy))
    end)

    suite:case("preserves frozen state of nested tables", function(asserts)
        local frozen = table.freeze({ 1 })
        local t = { frozen = frozen, open = { 2 } }
        local copy = deepCopy(t)

        asserts.eq(false, table.isfrozen(copy))
        asserts.eq(true, table.isfrozen(copy.frozen))
        asserts.eq(false, table.isfrozen(copy.open))
        asserts.neq(frozen, copy.frozen)
    end)

    suite:case("bypasses __iter metamethod", function(asserts)
        local mt = {
            __iter = function()
                return next, {}
            end,
        }
        local t = setmetatable({ a = 1, b = { 2 } }, mt)
        local copy: any = deepCopy(t)

        asserts.eq(mt, getmetatable(copy))
        asserts.eq(1, rawget(copy, "a"))
        asserts.eq(2, rawget(copy, "b")[1])
        asserts.neq(t.b, rawget(copy, "b"))
    end)

    suite:case("keeps non-table values by reference", function(asserts)
        local fn = function() end
        local t = { fn = fn, flag = false, str = "hi" }
        local copy = deepCopy(t)

        asserts.eq(fn, copy.fn)
        asserts.eq(false, copy.flag)
    end)

    suite:case("does not copy table keys", function(asserts)
        local key = {}
        local t = { [key] = 1 }
        local copy = deepCopy(t)

        asserts.eq(1, copy[key])
    end)
end)
