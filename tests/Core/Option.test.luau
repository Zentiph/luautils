--!strict

-- Option tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers")
local Option = require("../../src/luautils/Core/Option")

test.suite("some()", function(suite)
    suite:case("some(~nil) is some", function(asserts)
        asserts.eq(true, Option.some(1):isSome())
        asserts.eq(true, Option.some("a"):isSome())
        asserts.eq(true, Option.some(false):isSome())
        asserts.eq(true, Option.some({}):isSome())
    end)

    suite:case("some(nil) throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Option.some(nil)
        end, "Value cannot be nil")
    end)
end)

test.suite("none()", function(suite)
    suite:case("none() is none", function(asserts)
        asserts.eq(true, Option.none():isNone())
    end)

    suite:case("none() is a singleton", function(asserts)
        asserts.eq(true, rawequal(Option.none(), Option.none()))
    end)
end)

test.suite("fromNillable()", function(suite)
    suite:case("fromNillable(~nil) is some", function(asserts)
        asserts.eq(true, Option.fromNillable(1):isSome())
        asserts.eq(true, Option.fromNillable("a"):isSome())
        asserts.eq(true, Option.fromNillable(false):isSome())
        asserts.eq(true, Option.fromNillable({}):isSome())
    end)

    suite:case("fromNillable(nil) is none", function(asserts)
        asserts.eq(true, Option.fromNillable(nil):isNone())
    end)

    suite:case("fromNillable(nil) reuses the none singleton", function(asserts)
        asserts.eq(true, rawequal(Option.fromNillable(nil), Option.none()))
    end)
end)

test.suite("immutability", function(suite)
    suite:case("Options are frozen", function(asserts)
        asserts.eq(true, table.isfrozen(Option.some(1)))
        asserts.eq(true, table.isfrozen(Option.none() :: any))
    end)

    suite:case("modifying an Option throws", function(asserts)
        local ok = pcall(function()
            (Option.some(1) :: any)._value = 2
        end)
        asserts.eq(false, ok)
    end)
end)

test.suite("when()", function(suite)
    suite:case("when() returns some if condition is true", function(asserts)
        Helpers.eqByStr(asserts, Option.some(1), Option.when(true, 1))
        Helpers.eqByStr(asserts, Option.some(false), Option.when(true, false))
    end)

    suite:case("when() returns none if condition is false", function(asserts)
        Helpers.eqByStr(asserts, Option.none(), Option.when(false, 1))
    end)

    suite:case(
        "when() throws if condition is true and value is nil",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                Option.when(true, nil)
            end, "Value cannot be nil")
        end
    )

    suite:case(
        "when() does not throw if condition is false and value is nil",
        function(asserts)
            Helpers.eqByStr(asserts, Option.none(), Option.when(false, nil))
        end
    )
end)

test.suite("whenThen()", function(suite)
    local supplierSpy = Helpers.spy(function()
        return 1
    end)

    suite:afterEach(function()
        supplierSpy.calls = 0
    end)

    suite:case(
        "whenThen() returns supplied some if condition is true",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Option.some(1),
                Option.whenThen(true, supplierSpy.fn)
            )
            asserts.eq(1, supplierSpy.calls)
        end
    )

    suite:case(
        "whenThen() returns none without calling supplier if condition is false",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Option.none(),
                Option.whenThen(false, supplierSpy.fn)
            )
            asserts.eq(0, supplierSpy.calls)
        end
    )

    suite:case(
        "whenThen() returns an Option, not the raw value",
        function(asserts)
            asserts.eq(true, Option.is(Option.whenThen(true, supplierSpy.fn)))
        end
    )

    suite:case("whenThen() throws if supplier returns nil", function(asserts)
        Helpers.throwsWith(asserts, function()
            Option.whenThen(true, function()
                return nil
            end)
        end, "[Option.whenThen()]: Supplier returned nil for a some value")
    end)
end)

test.suite("toNillable()", function(suite)
    suite:case("toNillable() returns value if some", function(asserts)
        asserts.eq(1, Option.some(1):toNillable())
        asserts.eq("a", Option.some("a"):toNillable())
        asserts.eq(false, Option.some(false):toNillable())
        asserts.eq({}, Option.some({}):toNillable())
    end)

    suite:case("toNillable() returns nil if none", function(asserts)
        asserts.eq(nil, Option.none():toNillable())
    end)
end)

test.suite("toArray()", function(suite)
    suite:case("toArray() returns array of value if some", function(asserts)
        asserts.eq({ 1 }, Option.some(1):toArray())
        asserts.eq({ false }, Option.some(false):toArray())
    end)

    suite:case("toArray() returns empty array if none", function(asserts)
        asserts.eq({}, Option.none():toArray())
    end)

    suite:case("toArray() returns a new table each call", function(asserts)
        local opt = Option.some(1)
        asserts.eq(false, rawequal(opt:toArray(), opt:toArray()))
    end)
end)

test.suite("isSome()", function(suite)
    suite:case("isSome() returns true if some", function(asserts)
        asserts.eq(true, Option.some(1):isSome())
    end)

    suite:case("isSome() returns false if none", function(asserts)
        asserts.eq(false, Option.none():isSome())
    end)
end)

test.suite("isSomeAnd()", function(suite)
    local predicateSpy = Helpers.spy(function(x)
        return x > 0
    end)

    suite:afterEach(function()
        predicateSpy.calls = 0
    end)

    suite:case("isSomeAnd() runs predicate if some", function(asserts)
        asserts.eq(true, Option.some(1):isSomeAnd(predicateSpy.fn))
        asserts.eq(1, predicateSpy.calls)

        asserts.eq(false, Option.some(-1):isSomeAnd(predicateSpy.fn))
        asserts.eq(2, predicateSpy.calls)
    end)

    suite:case("isSomeAnd() does not run predicate if none", function(asserts)
        asserts.eq(
            false,
            (Option.none() :: Option.Option<number>):isSomeAnd(predicateSpy.fn)
        )
        asserts.eq(0, predicateSpy.calls)
    end)
end)

test.suite("isNone()", function(suite)
    suite:case("isNone() returns true if none", function(asserts)
        asserts.eq(true, Option.none():isNone())
    end)

    suite:case("isNone() returns false if some", function(asserts)
        asserts.eq(false, Option.some(1):isNone())
    end)
end)

test.suite("isNoneOr()", function(suite)
    local predicateSpy = Helpers.spy(function(x)
        return x > 0
    end)

    suite:afterEach(function()
        predicateSpy.calls = 0
    end)

    suite:case("isNoneOr() runs predicate if some", function(asserts)
        asserts.eq(true, Option.some(1):isNoneOr(predicateSpy.fn))
        asserts.eq(1, predicateSpy.calls)

        asserts.eq(false, Option.some(-1):isNoneOr(predicateSpy.fn))
        asserts.eq(2, predicateSpy.calls)
    end)

    suite:case("isNoneOr() does not run predicate if none", function(asserts)
        asserts.eq(
            true,
            (Option.none() :: Option.Option<number>):isNoneOr(predicateSpy.fn)
        )
        asserts.eq(0, predicateSpy.calls)
    end)
end)

test.suite("contains()", function(suite)
    suite:case("contains() returns true if some holds value", function(asserts)
        asserts.eq(true, Option.some(1):contains(1))
        asserts.eq(true, Option.some(false):contains(false))
    end)

    suite:case(
        "contains() returns false if some holds another value",
        function(asserts)
            asserts.eq(false, Option.some(1):contains(2))
        end
    )

    suite:case("contains() returns false if none", function(asserts)
        asserts.eq(false, (Option.none() :: Option.Option<number>):contains(1))
        asserts.eq(false, Option.none():contains(nil))
    end)

    suite:case("contains() compares tables by reference", function(asserts)
        local t = {}
        asserts.eq(true, Option.some(t):contains(t))
        asserts.eq(false, Option.some({}):contains({}))
    end)
end)

test.suite("expect()", function(suite)
    suite:case("expect() returns value if some", function(asserts)
        asserts.eq(1, Option.some(1):expect("Should always be some"))
    end)

    suite:case("expect() throws if none", function(asserts)
        Helpers.throwsWith(asserts, function()
            Option.none():expect("Unexpected issue")
        end, "[Option.expect()]: Unexpected issue")
    end)
end)

test.suite("unwrap()", function(suite)
    suite:case("unwrap() returns value if some", function(asserts)
        asserts.eq(1, Option.some(1):unwrap())
    end)

    suite:case("unwrap() throws if none", function(asserts)
        Helpers.throwsWith(asserts, function()
            Option.none():unwrap()
        end, 'Attempted to unwrap an Option that was "none"')
    end)
end)

test.suite("unwrapOr()", function(suite)
    suite:case("unwrapOr() returns value if some", function(asserts)
        asserts.eq(1, Option.some(1):unwrapOr(2))
    end)

    suite:case("unwrapOr() returns default if none", function(asserts)
        asserts.eq(2, Option.none():unwrapOr(2))
    end)
end)

test.suite("unwrapOrElse()", function(suite)
    local defaultSpy = Helpers.spy(function()
        return 2
    end)

    suite:afterEach(function()
        defaultSpy.calls = 0
    end)

    suite:case(
        "unwrapOrElse() returns value and does not run default generator if some",
        function(asserts)
            asserts.eq(1, Option.some(1):unwrapOrElse(defaultSpy.fn))
            asserts.eq(0, defaultSpy.calls)
        end
    )

    suite:case("unwrapOrElse() calculates default if none", function(asserts)
        asserts.eq(2, Option.none():unwrapOrElse(defaultSpy.fn))
        asserts.eq(1, defaultSpy.calls)
    end)
end)

test.suite("unwrapOrThrow()", function(suite)
    local errorSupplierSpy = Helpers.spy(function()
        return "Error"
    end)

    suite:afterEach(function()
        errorSupplierSpy.calls = 0
    end)

    suite:case(
        "unwrapOrThrow() returns value without calling supplier if some",
        function(asserts)
            asserts.eq(1, Option.some(1):unwrapOrThrow(errorSupplierSpy.fn))
            asserts.eq(0, errorSupplierSpy.calls)
        end
    )

    suite:case(
        "unwrapOrThrow() throws supplied error if none",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                Option.none():unwrapOrThrow(errorSupplierSpy.fn)
            end, "Error")
            asserts.eq(1, errorSupplierSpy.calls)
        end
    )

    suite:case(
        "unwrapOrThrow() blames the caller for string errors",
        function(asserts)
            local ok, err = pcall(function()
                Option.none():unwrapOrThrow(errorSupplierSpy.fn)
            end)
            asserts.eq(false, ok)
            asserts.strContains(tostring(err), "Option.test.luau:")
        end
    )

    suite:case("unwrapOrThrow() throws table errors as-is", function(asserts)
        local errValue = { code = 1 }
        local ok, err = pcall(function()
            Option.none():unwrapOrThrow(function()
                return errValue
            end)
        end)
        asserts.eq(false, ok)
        asserts.eq(true, rawequal(errValue, err))
    end)
end)

test.suite("map()", function(suite)
    local mapperSpy = Helpers.spy(function(x: number): string
        return tostring(x)
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("map() applies mapper to value if some", function(asserts)
        asserts.eq("1", Option.some(1):map(mapperSpy.fn):unwrap())
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("map() returns none if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<number>):map(mapperSpy.fn)
        )
        asserts.eq(0, mapperSpy.calls)
    end)

    suite:case("map() returns none if mapper returns nil", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1):map(function(_)
                return nil
            end)
        )
    end)
end)

test.suite("mapOr()", function(suite)
    local mapperSpy = Helpers.spy(function(x: number): string
        return tostring(x)
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("mapOr() applies mapper to value if some", function(asserts)
        asserts.eq("1", Option.some(1):mapOr("2", mapperSpy.fn))
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("mapOr() returns default if none", function(asserts)
        asserts.eq(
            "2",
            (Option.none() :: Option.Option<number>):mapOr("2", mapperSpy.fn)
        )
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("mapOrElse()", function(suite)
    local defaultSpy = Helpers.spy(function()
        return "2"
    end)
    local mapperSpy = Helpers.spy(function(x: number): string
        return tostring(x)
    end)

    suite:afterEach(function()
        defaultSpy.calls = 0
        mapperSpy.calls = 0
    end)

    suite:case("mapOrElse() applies mapper to value if some", function(asserts)
        asserts.eq("1", Option.some(1):mapOrElse(defaultSpy.fn, mapperSpy.fn))
        asserts.eq(0, defaultSpy.calls)
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("mapOrElse() returns default if none", function(asserts)
        asserts.eq(
            "2",
            (Option.none() :: Option.Option<number>):mapOrElse(
                defaultSpy.fn,
                mapperSpy.fn
            )
        )
        asserts.eq(1, defaultSpy.calls)
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("inspect()", function(suite)
    local callbackSpy = Helpers.spy(function(_)
        -- do something...
    end)

    suite:afterEach(function()
        callbackSpy.calls = 0
    end)

    suite:case("inspect() runs callback if some", function(asserts)
        Option.some(1):inspect(callbackSpy.fn)
        asserts.eq(1, callbackSpy.calls)
    end)

    suite:case("inspect() does not run callback if none", function(asserts)
        Option.none():inspect(callbackSpy.fn)
        asserts.eq(0, callbackSpy.calls)
    end)

    suite:case("inspect() passes value and returns self", function(asserts)
        local received
        local opt = Option.some(1)
        asserts.eq(
            true,
            rawequal(
                opt,
                opt:inspect(function(x)
                    received = x
                end)
            )
        )
        asserts.eq(1, received)
    end)
end)

test.suite("andOption()", function(suite)
    suite:case("andOption() returns other if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(2),
            Option.some(1):andOption(Option.some(2))
        )
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1):andOption(Option.none())
        )
    end)

    suite:case("andOption() returns none if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.none():andOption(Option.some(2))
        )
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.none():andOption(Option.none())
        )
    end)
end)

test.suite("andThen()", function(suite)
    local mapperSpy = Helpers.spy(function(x: number): Option.Option<string>
        return Option.some(tostring(x))
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("andThen() applies mapper if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some("1"),
            Option.some(1):andThen(mapperSpy.fn)
        )
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("andThen() returns none if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<number>):andThen(mapperSpy.fn)
        )
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("filter()", function(suite)
    local predicateSpy = Helpers.spy(function(x)
        return x > 0
    end)

    suite:afterEach(function()
        predicateSpy.calls = 0
    end)

    suite:case("filter() applies predicate if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(1):filter(predicateSpy.fn)
        )
        asserts.eq(1, predicateSpy.calls)

        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(-1):filter(predicateSpy.fn)
        )
        asserts.eq(2, predicateSpy.calls)
    end)

    suite:case("filter() returns the same instance if kept", function(asserts)
        local opt = Option.some(1)
        asserts.eq(true, rawequal(opt, opt:filter(predicateSpy.fn)))
    end)

    suite:case("filter() returns none if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<number>):filter(predicateSpy.fn)
        )
        asserts.eq(0, predicateSpy.calls)
    end)
end)

test.suite("orOption()", function(suite)
    suite:case("orOption() returns self if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(1):orOption(Option.some(2))
        )
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(1):orOption(Option.none())
        )
    end)

    suite:case("orOption() returns other if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(2),
            Option.none():orOption(Option.some(2))
        )
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.none():orOption(Option.none())
        )
    end)
end)

test.suite("orElse()", function(suite)
    local supplierSpy = Helpers.spy(function()
        return Option.some(2)
    end)

    suite:afterEach(function()
        supplierSpy.calls = 0
    end)

    suite:case("orElse() returns self if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(1):orElse(supplierSpy.fn)
        )
        asserts.eq(0, supplierSpy.calls)
    end)

    suite:case("orElse() returns supplier if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(2),
            Option.none():orElse(supplierSpy.fn)
        )
        asserts.eq(1, supplierSpy.calls)
    end)
end)

test.suite("match()", function(suite)
    local consumerSpy = Helpers.spy(function(_) end)
    local actionSpy = Helpers.spy(function() end)

    suite:afterEach(function()
        consumerSpy.calls = 0
        actionSpy.calls = 0
    end)

    suite:case("match() calls consumer if some", function(asserts)
        Option.some(1):match(consumerSpy.fn, actionSpy.fn)
        asserts.eq(1, consumerSpy.calls)
        asserts.eq(0, actionSpy.calls)
    end)

    suite:case("match() calls action if none", function(asserts)
        Option.none():match(consumerSpy.fn, actionSpy.fn)
        asserts.eq(0, consumerSpy.calls)
        asserts.eq(1, actionSpy.calls)
    end)

    suite:case("match() passes contained value", function(asserts)
        local received
        Option.some(1):match(function(x)
            received = x
        end, actionSpy.fn)
        asserts.eq(1, received)
    end)
end)

test.suite("xor()", function(suite)
    suite:case("xor() returns none if both some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1):xor(Option.some(2))
        )
    end)

    suite:case("xor() returns some if one is some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(1):xor(Option.none())
        )
        Helpers.eqByStr(
            asserts,
            Option.some(2),
            Option.none():xor(Option.some(2))
        )
    end)

    suite:case("xor() returns none if both none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.none():xor(Option.none())
        )
    end)
end)

test.suite("zip()", function(suite)
    local zipperSpy = Helpers.spy(
        function(errorcode: number, errormessage: string)
            return `{errormessage} (code {errorcode})`
        end
    )

    suite:afterEach(function()
        zipperSpy.calls = 0
    end)

    suite:case("zip() returns zipped option if both some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some("oops (code 1)"),
            Option.some(1):zip(Option.some("oops"), zipperSpy.fn)
        )
        asserts.eq(1, zipperSpy.calls)
    end)

    suite:case("zip() returns none if either none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1)
                :zip(Option.none() :: Option.Option<string>, zipperSpy.fn)
        )
        asserts.eq(0, zipperSpy.calls)

        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<number>):zip(
                Option.some("oops"),
                zipperSpy.fn
            )
        )
        asserts.eq(0, zipperSpy.calls)

        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<number>):zip(
                Option.none() :: Option.Option<string>,
                zipperSpy.fn
            )
        )
        asserts.eq(0, zipperSpy.calls)
    end)

    suite:case("zip() returns none if biMapper returns nil", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1):zip(Option.some(2), function(_, _)
                return nil
            end)
        )
    end)
end)

test.suite("reduce()", function(suite)
    local reducerSpy = Helpers.spy(function(a: number, b: number): number
        return a + b
    end)

    suite:afterEach(function()
        reducerSpy.calls = 0
    end)

    suite:case("reduce() returns reduced option if both some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(3),
            Option.some(1):reduce(Option.some(2), reducerSpy.fn)
        )
        asserts.eq(1, reducerSpy.calls)
    end)

    suite:case("reduce() returns some if one is some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(1)
                :reduce(Option.none() :: Option.Option<number>, reducerSpy.fn)
        )
        asserts.eq(0, reducerSpy.calls)

        Helpers.eqByStr(
            asserts,
            Option.some(2),
            (Option.none() :: Option.Option<number>):reduce(
                Option.some(2),
                reducerSpy.fn
            )
        )
        asserts.eq(0, reducerSpy.calls)
    end)

    suite:case("reduce() returns none if both none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<number>):reduce(
                Option.none() :: Option.Option<number>,
                reducerSpy.fn
            )
        )
        asserts.eq(0, reducerSpy.calls)
    end)

    suite:case("reduce() returns none if reducer returns nil", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1):reduce(Option.some(2), function(_, _)
                return nil
            end)
        )
    end)
end)

test.suite("flatten()", function(suite)
    suite:case("flatten() returns flattened option if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(Option.some(1)):flatten()
        )
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(Option.none()):flatten()
        )
    end)

    suite:case("flatten() returns none if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<Option.Option<number>>):flatten()
        )
    end)

    suite:case(
        "flatten() throws if inner value is not an Option",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                (Option.some(1) :: any):flatten()
            end, "Called flatten on an Option that does not contain an Option")
        end
    )

    suite:case("flatten() only removes one level", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(Option.some(1)),
            Option.some(Option.some(Option.some(1))):flatten()
        )
    end)
end)

test.suite("all()", function(suite)
    suite:case("all() returns some if all values some", function(asserts)
        local values = {
            Option.some(1),
            Option.some(2),
            Option.some(3),
        } :: { Option.Option<number> }
        local result = Option.all(values)
        asserts.eq(true, result:isSome())
        asserts.eq({ 1, 2, 3 }, result:unwrap())
    end)

    suite:case("all() returns none if any value none", function(asserts)
        local values = {
            Option.some(1),
            Option.none(),
            Option.some(3),
        } :: { Option.Option<number> }
        Helpers.eqByStr(asserts, Option.none(), Option.all(values))
    end)

    suite:case(
        "all() throws if the iter contains a non-Option",
        function(asserts)
            local values = { Option.some(1), 2, Option.some(3) }
            Helpers.throwsWith(asserts, function()
                Option.all(values :: any)
            end, "Called all on a table containing a non-Option value")
        end
    )

    suite:case("all() returns some with empty table if empty", function(asserts)
        local result = Option.all({})
        asserts.eq(true, result:isSome())
        asserts.eq({}, result:unwrap())
    end)

    suite:case("all() preserves keys", function(asserts)
        local values = {
            a = Option.some(1),
            b = Option.some(2),
        } :: { [string]: Option.Option<number> }
        asserts.eq({ a = 1, b = 2 }, Option.all(values):unwrap())
    end)
end)

test.suite("firstSome()", function(suite)
    suite:case("firstSome() returns first non-none", function(asserts)
        local values = {
            Option.none(),
            Option.none(),
            Option.some(3),
        } :: { Option.Option<number> }
        Helpers.eqByStr(asserts, Option.some(3), Option.firstSome(values))
    end)

    suite:case("firstSome() returns none if all none", function(asserts)
        local values = { Option.none(), Option.none(), Option.none() }
        Helpers.eqByStr(asserts, Option.none(), Option.firstSome(values))
    end)

    suite:case(
        "firstSome() throws if the iter contains a non-Option",
        function(asserts)
            local values = { Option.none(), 2, Option.none() }
            Helpers.throwsWith(asserts, function()
                Option.firstSome(values :: any)
            end, "Called firstSome on a table containing a non-Option value")
        end
    )

    suite:case("firstSome() returns the same instance", function(asserts)
        local first = Option.some(1)
        local values = {
            Option.none(),
            first,
            Option.some(2),
        } :: { Option.Option<number> }
        asserts.eq(true, rawequal(first, Option.firstSome(values)))
    end)

    suite:case("firstSome() returns none if empty", function(asserts)
        Helpers.eqByStr(asserts, Option.none(), Option.firstSome({}))
    end)
end)

test.suite("somes()", function(suite)
    suite:case("somes() returns contained values in order", function(asserts)
        local values = {
            Option.some(1),
            Option.none(),
            Option.some(3),
            Option.none(),
            Option.some(5),
        } :: { Option.Option<number> }
        asserts.eq({ 1, 3, 5 }, Option.somes(values))
    end)

    suite:case("somes() returns empty array if all none", function(asserts)
        local values = { Option.none(), Option.none() }
        asserts.eq({}, Option.somes(values))
    end)

    suite:case("somes() returns empty array if empty", function(asserts)
        asserts.eq({}, Option.somes({}))
    end)

    suite:case(
        "somes() throws if the iter contains a non-Option",
        function(asserts)
            local values = { Option.some(1), 2, Option.some(3) }
            Helpers.throwsWith(asserts, function()
                Option.somes(values :: any)
            end, "Called somes on a table containing a non-Option value")
        end
    )
end)

test.suite("is()", function(suite)
    suite:case("is() returns true if object is an Option", function(asserts)
        asserts.eq(true, Option.is(Option.some(1)))
        asserts.eq(true, Option.is(Option.none()))
    end)

    suite:case(
        "is() returns false if object is not an Option",
        function(asserts)
            asserts.eq(false, Option.is(1))
            asserts.eq(false, Option.is({ _value = 1 }))
        end
    )
end)

test.suite("equals()", function(suite)
    suite:case('two "some"s are equal by inner value', function(asserts)
        Helpers.eqByStr(asserts, Option.some(1), Option.some(1))
        Helpers.neqByStr(asserts, Option.some(1), Option.some(2))
    end)

    suite:case('two "none"s are equal', function(asserts)
        Helpers.eqByStr(asserts, Option.none(), Option.none())
    end)

    suite:case('"some" and "none" are not equal', function(asserts)
        Helpers.neqByStr(asserts, Option.some(1), Option.none())
        Helpers.neqByStr(asserts, Option.none(), Option.some(1))
    end)

    suite:case("equals() is used by == and ~=", function(asserts)
        asserts.eq(true, Option.some(1) == Option.some(1))
        asserts.eq(true, Option.some(1) ~= Option.none())
        asserts.eq(true, Option.some(1):equals(Option.some(1)))
    end)

    suite:case("equals() compares tables by reference", function(asserts)
        local t = {}
        asserts.eq(true, Option.some(t) == Option.some(t))
        asserts.eq(false, Option.some({}) == Option.some({}))
    end)

    suite:case("Option and non-Option are not equal", function(asserts)
        Helpers.neqByStr(asserts, Option.some(1), 1)
        Helpers.neqByStr(asserts, 1, Option.some(1))
    end)
end)

test.suite("toString()", function(suite)
    suite:case(
        "toString() returns string representation of inside if some",
        function(asserts)
            asserts.eq("Some(1)", tostring(Option.some(1)))
            asserts.eq('Some("a")', tostring(Option.some("a")))
            asserts.eq("Some(false)", tostring(Option.some(false)))
        end
    )

    suite:case("toString() nests inner Options", function(asserts)
        asserts.eq("Some(Some(1))", tostring(Option.some(Option.some(1))))
    end)

    suite:case('toString() returns "None" if none', function(asserts)
        asserts.eq("None", tostring(Option.none()))
    end)

    suite:case("toString() can be called directly", function(asserts)
        asserts.eq("Some(1)", Option.some(1):toString())
    end)
end)
