--!strict

-- Values tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers")
local Values = require("../../src/luautils/Core/Values")

local NAN = 0 / 0

-- protocol fixtures

-- an Equatable, Comparable, Stringable, Keyable, and Cloneable box around a
-- number, without any metamethods, so only the protocol methods are used
local Box = {}
Box.__index = Box

type Box = typeof(setmetatable({} :: { value: number }, Box))

local function box(value: number): Box
    return setmetatable({ value = value }, Box)
end

function Box.equals(self: Box, other: Box): boolean
    return self.value == other.value
end

function Box.compareTo(self: Box, other: Box): number
    return self.value - other.value
end

function Box.toString(self: Box): string
    return `Box({self.value})`
end

function Box.toKey(self: Box): string
    return `Box:{self.value}`
end

function Box.clone(self: Box): Box
    return box(self.value)
end

test.suite("module", function(suite)
    suite:case("Values is frozen", function(asserts)
        asserts.eq(true, table.isfrozen(Values))
    end)
end)

test.suite("is()", function(suite)
    suite:case("matches the first type", function(asserts)
        asserts.eq(true, Values.is(5, "number"))
        asserts.eq(true, Values.is(nil, "nil"))
    end)

    suite:case("matches any additional type", function(asserts)
        asserts.eq(true, Values.is("hi", "number", "string"))
        asserts.eq(true, Values.is({}, "number", "string", "table"))
    end)

    suite:case("returns false for no matching type", function(asserts)
        asserts.eq(false, Values.is(5, "string"))
        asserts.eq(false, Values.is(5, "string", "boolean", "table"))
    end)

    suite:case("uses type(), not typeof()", function(asserts)
        asserts.eq(true, Values.is(box(1), "table"))
        asserts.eq(true, Values.is(vector.create(1, 2, 3), "vector"))
    end)
end)

test.suite("isPrimitive()", function(suite)
    suite:case("primitives are primitive", function(asserts)
        asserts.eq(true, Values.isPrimitive("hi"))
        asserts.eq(true, Values.isPrimitive(1))
        asserts.eq(true, Values.isPrimitive(NAN))
        asserts.eq(true, Values.isPrimitive(false))
        asserts.eq(true, Values.isPrimitive(nil))
    end)

    suite:case("non-primitives are not primitive", function(asserts)
        asserts.eq(false, Values.isPrimitive({}))
        asserts.eq(false, Values.isPrimitive(print))
        asserts.eq(false, Values.isPrimitive(coroutine.create(print)))
        asserts.eq(false, Values.isPrimitive(buffer.create(1)))
        asserts.eq(false, Values.isPrimitive(vector.create(1, 2, 3)))
    end)
end)

test.suite("isImmutable()", function(suite)
    suite:case("immutable values are immutable", function(asserts)
        asserts.eq(true, Values.isImmutable("hi"))
        asserts.eq(true, Values.isImmutable(1))
        asserts.eq(true, Values.isImmutable(false))
        asserts.eq(true, Values.isImmutable(nil))
        asserts.eq(true, Values.isImmutable(vector.create(1, 2, 3)))
        asserts.eq(true, Values.isImmutable(print))
    end)

    suite:case("mutable values are not immutable", function(asserts)
        asserts.eq(false, Values.isImmutable({}))
        asserts.eq(false, Values.isImmutable(coroutine.create(print)))
        asserts.eq(false, Values.isImmutable(buffer.create(1)))
    end)

    suite:case("frozen tables are not immutable", function(asserts)
        asserts.eq(false, Values.isImmutable(table.freeze({})))
    end)
end)

test.suite("isComparable()", function(suite)
    suite:case("numbers and strings are comparable", function(asserts)
        asserts.eq(true, Values.isComparable(1, 2))
        asserts.eq(true, Values.isComparable("a", "b"))
    end)

    suite:case("NaN is comparable by type", function(asserts)
        asserts.eq(true, Values.isComparable(NAN, 1))
    end)

    suite:case("Comparable tables are comparable", function(asserts)
        asserts.eq(true, Values.isComparable(box(1), box(2)))
    end)

    suite:case("mismatched types are not comparable", function(asserts)
        asserts.eq(false, Values.isComparable(1 :: any, "1"))
        asserts.eq(false, Values.isComparable(box(1) :: any, 1))
        asserts.eq(false, Values.isComparable(1 :: any, box(1)))
    end)

    suite:case("requires both tables to be Comparable", function(asserts)
        asserts.eq(false, Values.isComparable(box(1) :: any, {}))
        asserts.eq(false, Values.isComparable({} :: any, box(1)))
        asserts.eq(false, Values.isComparable({}, {}))
    end)

    suite:case("unordered types are not comparable", function(asserts)
        asserts.eq(false, Values.isComparable(true, false))
        asserts.eq(false, Values.isComparable(nil, nil))
        asserts.eq(false, Values.isComparable(print, print))
        asserts.eq(
            false,
            Values.isComparable(vector.create(1, 2, 3), vector.create(1, 2, 3))
        )
    end)
end)

test.suite("equals()", function(suite)
    suite:case("primitives compare with ==", function(asserts)
        asserts.eq(true, Values.equals(1, 1))
        asserts.eq(true, Values.equals("a", "a"))
        asserts.eq(true, Values.equals(nil, nil))
        asserts.eq(false, Values.equals(1, 2))
        asserts.eq(false, Values.equals(1 :: any, "1"))
    end)

    suite:case("NaN is not equal to itself", function(asserts)
        asserts.eq(false, Values.equals(NAN, NAN))
    end)

    suite:case("the same table is equal to itself", function(asserts)
        local t = {}
        asserts.eq(true, Values.equals(t, t))
    end)

    suite:case("plain tables compare by reference", function(asserts)
        asserts.eq(false, Values.equals({}, {}))
    end)

    suite:case("Equatable tables compare with equals()", function(asserts)
        asserts.eq(true, Values.equals(box(1), box(1)))
        asserts.eq(false, Values.equals(box(1), box(2)))
    end)

    suite:case("skips equals() for the same table", function(asserts)
        local equalsSpy = Helpers.spy(function()
            return false
        end)
        local t = { equals = equalsSpy.fn }

        asserts.eq(true, Values.equals(t, t))
        asserts.eq(0, equalsSpy.calls)
    end)

    suite:case("uses __eq for tables without equals()", function(asserts)
        local mt = {
            __eq = function()
                return true
            end,
        }
        local a = setmetatable({}, mt)
        local b = setmetatable({}, mt)

        asserts.eq(true, Values.equals(a, b))
    end)
end)

test.suite("compare()", function(suite)
    suite:case("compares numbers", function(asserts)
        asserts.eq(-1, Values.compare(1, 2))
        asserts.eq(0, Values.compare(2, 2))
        asserts.eq(1, Values.compare(3, 2))
        asserts.eq(-1, Values.compare(-math.huge, math.huge))
    end)

    suite:case("compares strings by byte value", function(asserts)
        asserts.eq(-1, Values.compare("a", "b"))
        asserts.eq(0, Values.compare("a", "a"))
        asserts.eq(1, Values.compare("b", "a"))
        asserts.eq(-1, Values.compare("B", "a"))
    end)

    suite:case("uses compareTo() for Comparable tables", function(asserts)
        asserts.eq(-2, Values.compare(box(1), box(3)))
        asserts.eq(0, Values.compare(box(3), box(3)))
        asserts.eq(2, Values.compare(box(3), box(1)))
    end)

    suite:case("mismatched types throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Values.compare(1 :: any, "a")
            end,
            "[Values.compare()]: Cannot meaningfully compare values of type "
                .. "number and string"
        )
    end)

    suite:case("unordered types throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Values.compare(true, false)
            end,
            "[Values.compare()]: Cannot meaningfully compare values of type "
                .. "boolean and boolean"
        )
        Helpers.throwsWith(
            asserts,
            function()
                Values.compare({}, {})
            end,
            "[Values.compare()]: Cannot meaningfully compare values of type "
                .. "table and table"
        )
    end)

    suite:case("NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.compare(NAN, 1)
        end, "[Values.compare()]: Cannot meaningfully compare NaN values")
        Helpers.throwsWith(asserts, function()
            Values.compare(1, NAN)
        end, "[Values.compare()]: Cannot meaningfully compare NaN values")
    end)

    suite:case("errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Values.compare(1 :: any, "a")
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Values.compare()]: `)
    end)
end)

test.suite("lessThan()", function(suite)
    suite:case("compares numbers and strings", function(asserts)
        asserts.eq(true, Values.lessThan(1, 2))
        asserts.eq(false, Values.lessThan(2, 2))
        asserts.eq(false, Values.lessThan(3, 2))
        asserts.eq(true, Values.lessThan("a", "b"))
    end)

    suite:case("uses compareTo() for Comparable tables", function(asserts)
        asserts.eq(true, Values.lessThan(box(1), box(2)))
        asserts.eq(false, Values.lessThan(box(2), box(1)))
    end)

    suite:case("sorts with table.sort", function(asserts)
        local numbers = { 3, 1, 2 }
        table.sort(numbers, Values.lessThan)
        asserts.eq(1, numbers[1])
        asserts.eq(2, numbers[2])
        asserts.eq(3, numbers[3])

        local boxes = { box(3), box(1), box(2) }
        table.sort(boxes, Values.lessThan)
        asserts.eq(1, boxes[1].value)
        asserts.eq(2, boxes[2].value)
        asserts.eq(3, boxes[3].value)
    end)

    suite:case("mismatched types throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Values.lessThan(1 :: any, "a")
            end,
            "[Values.lessThan()]: Cannot meaningfully compare values of type "
                .. "number and string"
        )
    end)

    suite:case("NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.lessThan(NAN, 1)
        end, "[Values.lessThan()]: Cannot meaningfully compare NaN values")
    end)
end)

test.suite("min()", function(suite)
    suite:case("returns the smaller value", function(asserts)
        asserts.eq(1, Values.min(3, 1))
        asserts.eq(1, Values.min(1, 3))
        asserts.eq("a", Values.min("b", "a"))
    end)

    suite:case("uses compareTo() for Comparable tables", function(asserts)
        local small, big = box(1), box(2)
        asserts.eq(true, rawequal(small, Values.min(big, small)))
        asserts.eq(true, rawequal(small, Values.min(small, big)))
    end)

    suite:case("returns a for equal values", function(asserts)
        local a, b = box(1), box(1)
        asserts.eq(true, rawequal(a, Values.min(a, b)))
    end)

    suite:case("mismatched types throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Values.min(1 :: any, "a")
            end,
            "[Values.min()]: Cannot meaningfully compare values of type "
                .. "number and string"
        )
    end)

    suite:case("NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.min(NAN, 1)
        end, "[Values.min()]: Cannot meaningfully compare NaN values")
        Helpers.throwsWith(asserts, function()
            Values.min(1, NAN)
        end, "[Values.min()]: Cannot meaningfully compare NaN values")
    end)
end)

test.suite("max()", function(suite)
    suite:case("returns the larger value", function(asserts)
        asserts.eq(3, Values.max(3, 1))
        asserts.eq(3, Values.max(1, 3))
        asserts.eq("b", Values.max("b", "a"))
    end)

    suite:case("uses compareTo() for Comparable tables", function(asserts)
        local small, big = box(1), box(2)
        asserts.eq(true, rawequal(big, Values.max(big, small)))
        asserts.eq(true, rawequal(big, Values.max(small, big)))
    end)

    suite:case("returns a for equal values", function(asserts)
        local a, b = box(1), box(1)
        asserts.eq(true, rawequal(a, Values.max(a, b)))
    end)

    suite:case("mismatched types throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Values.max(1 :: any, "a")
            end,
            "[Values.max()]: Cannot meaningfully compare values of type "
                .. "number and string"
        )
    end)

    suite:case("NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.max(NAN, 1)
        end, "[Values.max()]: Cannot meaningfully compare NaN values")
        Helpers.throwsWith(asserts, function()
            Values.max(1, NAN)
        end, "[Values.max()]: Cannot meaningfully compare NaN values")
    end)
end)

test.suite("clamp()", function(suite)
    suite:case("clamps numbers", function(asserts)
        asserts.eq(10, Values.clamp(15, 0, 10))
        asserts.eq(0, Values.clamp(-5, 0, 10))
        asserts.eq(5, Values.clamp(5, 0, 10))
        asserts.eq(0, Values.clamp(0, 0, 10))
        asserts.eq(10, Values.clamp(10, 0, 10))
    end)

    suite:case("clamps strings", function(asserts)
        asserts.eq("f", Values.clamp("m", "a", "f"))
        asserts.eq("c", Values.clamp("c", "a", "f"))
    end)

    suite:case("uses compareTo() for Comparable tables", function(asserts)
        local lo, hi = box(0), box(10)
        asserts.eq(true, rawequal(hi, Values.clamp(box(15), lo, hi)))
        asserts.eq(true, rawequal(lo, Values.clamp(box(-5), lo, hi)))

        local inside = box(5)
        asserts.eq(true, rawequal(inside, Values.clamp(inside, lo, hi)))
    end)

    suite:case("allows equal bounds", function(asserts)
        asserts.eq(5, Values.clamp(1, 5, 5))
    end)

    suite:case("lo greater than hi throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.clamp(5, 10, 0)
        end, "[Values.clamp()]: lo must be less than or equal to hi")
    end)

    suite:case("mismatched types throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Values.clamp(1 :: any, "a", 10)
            end,
            "[Values.clamp()]: Cannot meaningfully compare values of type "
                .. "number and string"
        )
        Helpers.throwsWith(
            asserts,
            function()
                Values.clamp(1 :: any, 0, "a")
            end,
            "[Values.clamp()]: Cannot meaningfully compare values of type "
                .. "number and string"
        )
    end)

    suite:case("NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.clamp(NAN, 0, 10)
        end, "[Values.clamp()]: Cannot meaningfully compare NaN values")
        Helpers.throwsWith(asserts, function()
            Values.clamp(5, NAN, 10)
        end, "[Values.clamp()]: Cannot meaningfully compare NaN values")
        Helpers.throwsWith(asserts, function()
            Values.clamp(5, 0, NAN)
        end, "[Values.clamp()]: Cannot meaningfully compare NaN values")
    end)
end)

test.suite("toKey()", function(suite)
    suite:case("primitives are their own key", function(asserts)
        asserts.eq(1, Values.toKey(1))
        asserts.eq("a", Values.toKey("a"))
        asserts.eq(false, Values.toKey(false))
    end)

    suite:case("plain tables are keyed by reference", function(asserts)
        local t = {}
        asserts.eq(true, rawequal(t, Values.toKey(t)))
    end)

    suite:case("uses toKey() for Keyable tables", function(asserts)
        asserts.eq("Box:1", Values.toKey(box(1)))
    end)

    suite:case("value-equal Keyables share a table slot", function(asserts)
        local seen = {}
        seen[Values.toKey(box(1))] = true
        asserts.eq(true, seen[Values.toKey(box(1))])
    end)

    suite:case("NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.toKey(NAN)
        end, "[Values.toKey()]: Cannot use NaN as a table key")
    end)

    suite:case("nil throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.toKey(nil)
        end, "[Values.toKey()]: Cannot use nil as a table key")
    end)
end)

test.suite("toString()", function(suite)
    suite:case("uses tostring() for primitives", function(asserts)
        asserts.eq("5", Values.toString(5))
        asserts.eq("hi", Values.toString("hi"))
        asserts.eq("nil", Values.toString(nil))
        asserts.eq("true", Values.toString(true))
    end)

    suite:case("uses toString() for Stringable tables", function(asserts)
        asserts.eq("Box(1)", Values.toString(box(1)))
    end)

    suite:case(
        "uses __tostring for tables without toString()",
        function(asserts)
            local t = setmetatable({}, {
                __tostring = function()
                    return "custom"
                end,
            })
            asserts.eq("custom", Values.toString(t))
        end
    )
end)

test.suite("clone()", function(suite)
    suite:case("returns immutable values as-is", function(asserts)
        local v = vector.create(1, 2, 3)

        asserts.eq(5, Values.clone(5))
        asserts.eq("hi", Values.clone("hi"))
        asserts.eq(nil, Values.clone(nil))
        asserts.eq(true, rawequal(v, Values.clone(v)))
        asserts.eq(true, rawequal(print, Values.clone(print)))
    end)

    suite:case("uses clone() for Cloneable tables", function(asserts)
        local original = box(1)
        local copy = Values.clone(original)

        asserts.eq(false, rawequal(original, copy))
        asserts.eq(1, copy.value)
    end)

    suite:case("plain tables throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.clone({})
        end, "[Values.clone()]: Cannot clone value of type table.")
    end)

    suite:case("other mutable values throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Values.clone(buffer.create(1))
        end, "[Values.clone()]: Cannot clone value of type buffer.")
        Helpers.throwsWith(asserts, function()
            Values.clone(coroutine.create(print))
        end, "[Values.clone()]: Cannot clone value of type thread.")
    end)
end)
