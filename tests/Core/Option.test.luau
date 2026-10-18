--!strict

-- Option datatype tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers")
local Option = require("../../src/luautils/Core/Option")

test.suite("Option construction", function(suite)
    suite:case("some(nil) throws", function(asserts)
        asserts.throws(function()
            Option.some(nil)
        end)
    end)

    suite:case("Option.fromNillable(nil) is none", function(asserts)
        Helpers.eqByStr(asserts, Option.none(), Option.fromNillable(nil))
    end)

    suite:case(
        "Option.some(false) and Option.fromNillable(false) are some",
        function(asserts)
            asserts.eq(true, Option.some(false):isSome())
            asserts.eq(true, Option.fromNillable(false):isSome())
            asserts.eq(false, Option.some(false):unwrap())
        end
    )

    suite:case("Option:isNone()", function(asserts)
        asserts.eq(true, Option.none():isNone())
        asserts.eq(false, Option.some(1):isNone())
    end)

    suite:case("Option.none() is a singleton", function(asserts)
        asserts.eq(true, rawequal(Option.none(), Option.none()))
    end)
end)

test.suite("Equality", function(suite)
    suite:case("Option.some() of same value", function(asserts)
        Helpers.eqByStr(asserts, Option.some(5), Option.some(5))
    end)

    suite:case("Option.some(any) ~= Option.none()", function(asserts)
        Helpers.neqByStr(asserts, Option.none(), Option.some(5))
        Helpers.neqByStr(asserts, Option.none(), Option.some("a"))
        Helpers.neqByStr(asserts, Option.none(), Option.some(false))
        Helpers.neqByStr(asserts, Option.none(), Option.some({}))
    end)
end)

test.suite("Stringification", function(suite)
    suite:case(
        "Option.some() has different string repr",
        function(asserts)
            asserts.eq("Some(5)", tostring(Option.some(5)))
            asserts.eq('Some("5")', tostring(Option.some("5")))
        end
    )

    suite:case("Option.none()", function(asserts)
        asserts.eq("None", tostring(Option.none()))
    end)

    suite:case("Option.some(false)", function(asserts)
        asserts.eq("Some(false)", tostring(Option.some(false)))
    end)
end)

test.suite("Return values", function(suite)
    suite:case("map transforms the value", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(2),
            Option.some(1):map(function(x: number)
                return x * 2
            end)
        )
    end)

    suite:case("andThen can return none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1):andThen(function()
                return Option.none()
            end)
        )
    end)

    suite:case("orElse uses the supplier's result", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(9),
            Option.none():orElse(function()
                return Option.some(9)
            end)
        )
        Helpers.eqByStr(
            asserts,
            Option.some(1),
            Option.some(1):orElse(function()
                return Option.none()
            end)
        )
    end)

    suite:case("filter with a false predicate is none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Option.some(1):filter(function()
                return false
            end)
        )
    end)

    suite:case(
        "unwrap, unwrapOr, unwrapOrElse, expect values",
        function(asserts)
            asserts.eq(1, Option.some(1):unwrap())
            asserts.eq(1, Option.some(1):expect("unused"))
            asserts.eq(1, Option.some(1):unwrapOr(0))
            asserts.eq(0, Option.none():unwrapOr(0))
            asserts.eq(
                7,
                Option.none():unwrapOrElse(function()
                    return 7
                end)
            )
        end
    )

    suite:case("mapOr returns the default on none", function(asserts)
        asserts.eq(
            "default",
            Option.none():mapOr("default", function()
                return "mapped"
            end)
        )
    end)
end)

test.suite("Predicates", function(suite)
    local isEven = function(x: number)
        return x % 2 == 0
    end

    suite:case("isSomeAnd", function(asserts)
        asserts.eq(true, Option.some(2):isSomeAnd(isEven))
        asserts.eq(false, Option.some(1):isSomeAnd(isEven))
        asserts.eq(
            false,
            (Option.none() :: Option.Option<number>):isSomeAnd(isEven)
        )
    end)

    suite:case("isNoneOr", function(asserts)
        asserts.eq(true, Option.some(2):isNoneOr(isEven))
        asserts.eq(false, Option.some(1):isNoneOr(isEven))
        asserts.eq(
            true,
            (Option.none() :: Option.Option<number>):isNoneOr(isEven)
        )
    end)
end)

test.suite("Nesting", function(suite)
    suite:case("flatten", function(asserts)
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
        Helpers.eqByStr(
            asserts,
            Option.none(),
            (Option.none() :: Option.Option<Option.Option<any>>):flatten()
        )
    end)

    suite:case("flatten on a non-nested Option throws", function(asserts)
        asserts.throws(function()
            (Option.some(5) :: any):flatten()
        end)
    end)

    suite:case("nested equality and printing", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(Option.some(1)),
            Option.some(Option.some(1))
        )
        asserts.eq("Some(Some(1))", tostring(Option.some(Option.some(1))))
    end)
end)

test.suite("Type checks", function(suite)
    suite:case("is() checks the metatable", function(asserts)
        asserts.eq(true, Option.is(Option.some(1)))
        asserts.eq(true, Option.is(Option.none()))
        asserts.eq(false, Option.is({ _value = 1 }))
        asserts.eq(false, Option.is(nil))
    end)

    suite:case("equals rejects non-Options", function(asserts)
        asserts.eq(false, Option.none() == ({} :: any))
        asserts.eq(false, Option.some(1) == (5 :: any))
    end)

    suite:case("table values compare by identity", function(asserts)
        local t = {}
        asserts.eq(true, Option.some(t) == Option.some(t))
        asserts.eq(false, Option.some({}) == Option.some({}))
    end)
end)

test.suite("Laziness", function(suite)
    suite:case(
        "Option:orElse() doesn't call callbacks on some",
        function(asserts)
            local supplierSpy = Helpers.spy(function()
                return Option.some(0)
            end)

            Option.some(1):orElse(supplierSpy.fn)
            asserts.eq(0, supplierSpy.calls)

            supplierSpy.calls = 0

            Option.none():orElse(supplierSpy.fn)
            asserts.eq(1, supplierSpy.calls)
        end
    )

    suite:case(
        "Option:unwrapOrElse() doesn't call callbacks on some",
        function(asserts)
            local callbackSpy = Helpers.spy(function()
                return 0
            end)

            Option.some(1):unwrapOrElse(callbackSpy.fn)
            asserts.eq(0, callbackSpy.calls)

            callbackSpy.calls = 0

            Option.none():unwrapOrElse(callbackSpy.fn)
            asserts.eq(1, callbackSpy.calls)
        end
    )

    suite:case(
        "Option:mapOr() only calls mapper on some",
        function(asserts)
            local mapperSpy = Helpers.spy(function()
                return "mapped"
            end)

            Option.some(1):mapOr("default", mapperSpy.fn)
            asserts.eq(1, mapperSpy.calls)

            mapperSpy.calls = 0

            Option.none():mapOr("default", mapperSpy.fn)
            asserts.eq(0, mapperSpy.calls)
        end
    )

    suite:case(
        "Option.mapOrElse() calls exactly one callback",
        function(asserts)
            local defaultSpy, mapperSpy =
                Helpers.spy(function()
                    return "default"
                end), Helpers.spy(function()
                    return "mapped"
                end)

            asserts.eq(
                "mapped",
                Option.some(1):mapOrElse(defaultSpy.fn, mapperSpy.fn)
            )
            asserts.eq(0, defaultSpy.calls)
            asserts.eq(1, mapperSpy.calls)

            defaultSpy.calls = 0
            mapperSpy.calls = 0

            asserts.eq(
                "default",
                Option.none():mapOrElse(defaultSpy.fn, mapperSpy.fn)
            )
            asserts.eq(1, defaultSpy.calls)
            asserts.eq(0, mapperSpy.calls)
        end
    )

    suite:case(
        "Option:andThen() doesn't call callbacks on none",
        function(asserts)
            local mapperSpy = Helpers.spy(function()
                return Option.some(0)
            end)

            Option.none():andThen(mapperSpy.fn)
            asserts.eq(0, mapperSpy.calls)

            mapperSpy.calls = 0

            Option.some(1):andThen(mapperSpy.fn)
            asserts.eq(1, mapperSpy.calls)
        end
    )

    suite:case(
        "Option:map() doesn't call callbacks on none",
        function(asserts)
            local mapperSpy = Helpers.spy(function()
                return 0
            end)

            Option.none():map(mapperSpy.fn)
            asserts.eq(0, mapperSpy.calls)

            mapperSpy.calls = 0

            Option.some(1):map(mapperSpy.fn)
            asserts.eq(1, mapperSpy.calls)
        end
    )

    suite:case(
        "Option:filter() doesn't call callbacks on none",
        function(asserts)
            local predicateSpy = Helpers.spy(function()
                return true
            end)

            Option.none():filter(predicateSpy.fn)
            asserts.eq(0, predicateSpy.calls)

            predicateSpy.calls = 0

            Option.some(1):filter(predicateSpy.fn)
            asserts.eq(1, predicateSpy.calls)
        end
    )

    suite:case(
        "Option:zip() doesn't call callbacks on none",
        function(asserts)
            local zipperSpy = Helpers.spy(function()
                return 0
            end)

            Option.none():zip(Option.none(), zipperSpy.fn)
            asserts.eq(0, zipperSpy.calls)

            zipperSpy.calls = 0

            Option.none():zip(Option.some(1), zipperSpy.fn)
            asserts.eq(0, zipperSpy.calls)

            zipperSpy.calls = 0

            Option.some(1):zip(Option.none(), zipperSpy.fn)
            asserts.eq(0, zipperSpy.calls)

            zipperSpy.calls = 0

            Option.some(1):zip(Option.some(1), zipperSpy.fn)
            asserts.eq(1, zipperSpy.calls)
        end
    )

    suite:case(
        "Option:inspect() doesn't call callbacks on none",
        function(asserts)
            local callbackSpy = Helpers.spy(function() end)

            Option.none():inspect(callbackSpy.fn)
            asserts.eq(0, callbackSpy.calls)

            callbackSpy.calls = 0

            Option.some(1):inspect(callbackSpy.fn)
            asserts.eq(1, callbackSpy.calls)
        end
    )

    suite:case(
        "Option:match() doesn't call callbacks on wrong paths",
        function(asserts)
            local someSpy, noneSpy =
                Helpers.spy(function() end), Helpers.spy(function() end)

            Option.some(1):match(someSpy.fn, noneSpy.fn)
            asserts.eq(1, someSpy.calls)
            asserts.eq(0, noneSpy.calls)

            someSpy.calls = 0
            noneSpy.calls = 0

            Option.none():match(someSpy.fn, noneSpy.fn)
            asserts.eq(0, someSpy.calls)
            asserts.eq(1, noneSpy.calls)
        end
    )

    suite:case(
        "Option:iter() runs once for some, zero times for none",
        function(asserts)
            local callbackSpy = Helpers.spy(function() end)

            for _ in Option.some(1):iter() do
                callbackSpy.fn()
            end
            asserts.eq(1, callbackSpy.calls)

            callbackSpy.calls = 0

            for _ in Option.none():iter() do
                callbackSpy.fn()
            end
            asserts.eq(0, callbackSpy.calls)
        end
    )
end)

test.suite("Nil handling", function(suite)
    suite:case(
        "Option:map() with a callback that returns nil produces none",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Option.none(),
                Option.some(1):map(function()
                    return nil
                end)
            )
        end
    )

    suite:case(
        "Option:zip() with a callback that returns nil produces none",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Option.none(),
                Option.some(1):zip(Option.some(1), function()
                    return nil
                end)
            )
        end
    )

    suite:case(
        "Option:reduce() with a callback that returns nil produces none",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Option.none(),
                Option.some(1):reduce(Option.some(1), function()
                    return nil
                end)
            )
        end
    )
end)

test.suite("Combinators", function(suite)
    suite:case(
        "Option:xor() only returns some if one option is some, otherwise none",
        function(asserts)
            local testPairs = {
                { Option.some(1), Option.some(2) },
                { Option.some(1), Option.none() },
                { Option.none(), Option.some(2) },
                { Option.none(), Option.none() },
            }
            local expected = {
                Option.none(),
                Option.some(1),
                Option.some(2),
                Option.none(),
            }

            for i, pair in ipairs(testPairs) do
                Helpers.eqByStr(
                    asserts,
                    expected[i],
                    Option.xor(pair[1], pair[2])
                )
            end
        end
    )

    suite:case(
        "Option:reduce() returns the reduced value if both are some, "
            .. "the only some if one is some, or none",
        function(asserts)
            local testPairs = {
                { Option.some(1), Option.some(2) },
                { Option.some(1), Option.none() },
                { Option.none(), Option.some(2) },
                { Option.none(), Option.none() },
            }
            local expected = {
                Option.some(3),
                Option.some(1),
                Option.some(2),
                Option.none(),
            }

            for i, pair in ipairs(testPairs) do
                Helpers.eqByStr(
                    asserts,
                    expected[i],
                    Option.reduce(pair[1], pair[2], function(a, b)
                        return a + b
                    end)
                )
            end
        end
    )

    suite:case(
        "Option:orOption() returns the first some option or none",
        function(asserts)
            local testPairs = {
                { Option.some(1), Option.some(2) },
                { Option.some(1), Option.none() },
                { Option.none(), Option.some(2) },
                { Option.none(), Option.none() },
            }
            local expected = {
                Option.some(1),
                Option.some(1),
                Option.some(2),
                Option.none(),
            }

            for i, pair in ipairs(testPairs) do
                Helpers.eqByStr(
                    asserts,
                    expected[i],
                    Option.orOption(pair[1], pair[2])
                )
            end
        end
    )

    suite:case(
        "Option:andOption() returns other if both are some otherwise none",
        function(asserts)
            local testPairs = {
                { Option.some(1), Option.some(2) },
                { Option.some(1), Option.none() },
                { Option.none(), Option.some(2) },
                { Option.none(), Option.none() },
            }
            local expected = {
                Option.some(2),
                Option.none(),
                Option.none(),
                Option.none(),
            }

            for i, pair in ipairs(testPairs) do
                Helpers.eqByStr(
                    asserts,
                    expected[i],
                    Option.andOption(pair[1], pair[2])
                )
            end
        end
    )

    suite:case("Option.all() returns the same values", function(asserts)
        local idx = 0
        local values = {
            Option.some(1),
            Option.some(2),
            Option.some(3),
        }
        local iter = function()
            idx += 1
            return if idx < #values then values[idx] else nil
        end

        local opt = Option.all(iter)

        asserts.eq(true, opt:isSome())
        for i, v in pairs(opt:unwrap()) do
            asserts.eq(values[i]:unwrap(), v)
        end
    end)

    suite:case(
        "Option.all() returns none for a none value",
        function(asserts)
            local idx = 0
            local values = {
                Option.some(1),
                Option.none(),
                Option.some(3),
            }
            local iter = function()
                idx += 1
                return if idx < #values then values[idx] else nil
            end

            local opt = Option.all(iter)

            asserts.eq(true, opt:isNone())
        end
    )

    suite:case(
        "Option.all() errors on non-Option iterator",
        function(asserts)
            local idx = 0
            local values = {
                Option.some(1),
                2,
                Option.some(3),
            }
            local iter = function()
                idx += 1
                return if idx < #values then values[idx] else nil
            end

            local ok, err = pcall(Option.all, iter :: any)
            asserts.eq(false, ok)
            asserts.strContains(
                tostring(err),
                "Called all on an Iterator that contains a non-Option value"
            )
        end
    )
end)

test.suite("Identity", function(suite)
    suite:case(
        "Option:filter() returns original option if predicate is true",
        function(asserts)
            local opt = Option.some(1)
            asserts.eq(
                true,
                rawequal(
                    opt:filter(function()
                        return true
                    end),
                    opt
                )
            )
        end
    )

    suite:case(
        "Option:orOption() returns original option if self is some",
        function(asserts)
            local opt = Option.some(1)
            asserts.eq(true, rawequal(opt:orOption(Option.none()), opt))
        end
    )

    suite:case(
        "orOption returns other itself when self is none",
        function(asserts)
            local other = Option.some(2)
            asserts.eq(
                true,
                rawequal(Option.none():orOption(other), other)
            )
        end
    )

    suite:case("inspect returns self", function(asserts)
        local opt = Option.some(1)
        asserts.eq(true, rawequal(opt:inspect(function() end), opt))
    end)
end)

test.suite("Errors", function(suite)
    suite:case("Option:unwrap() throws on none", function(asserts)
        asserts.throws(function()
            Option.none():unwrap()
        end)
    end)

    suite:case(
        "Option:expect() throws on none with message",
        function(asserts)
            local ok, err = pcall(function()
                Option.none():expect("error message")
            end)
            asserts.eq(false, ok)
            asserts.eq(
                true,
                string.find(tostring(err), "error message", 1, true)
                    ~= nil
            )
        end
    )
end)
