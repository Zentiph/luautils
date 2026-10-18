--!strict

-- Option datatype tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers") -- TODO: replace eq checks with eqBy, called checks with spy, etc.
local Option = require("../../src/luautils/Core/Option")

test.suite("Option construction", function(suite)
    suite:case("some(nil) throws", function(asserts)
        asserts.throws(function()
            Option.some(nil)
        end)
    end)

    suite:case("Option.from(nil) is none", function(asserts)
        asserts.eq(true, Option.none() == Option.from(nil))
    end)

    suite:case(
        "Option.some(false) and Option.from(false) are some",
        function(asserts)
            asserts.eq(true, Option.some(false):isSome())
            asserts.eq(true, Option.from(false):isSome())
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
        asserts.eq(true, Option.some(5) == Option.some(5))
    end)

    suite:case("Option.some(any) ~= Option.none()", function(asserts)
        asserts.eq(false, Option.none() == Option.some(5))
        asserts.eq(false, Option.none() == Option.some("a"))
        asserts.eq(false, Option.none() == Option.some(false))
        asserts.eq(false, Option.none() == Option.some({}))
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
        asserts.eq(
            true,
            Option.some(2)
                == Option.some(1):map(function(x: number)
                    return x * 2
                end)
        )
    end)

    suite:case("andThen can return none", function(asserts)
        asserts.eq(
            true,
            Option.none()
                == Option.some(1):andThen(function()
                    return Option.none()
                end)
        )
    end)

    suite:case("orElse uses the supplier's result", function(asserts)
        asserts.eq(true, Option.some(9) == Option.none():orElse(function()
            return Option.some(9)
        end))
        asserts.eq(true, Option.none() == Option.none():orElse(function()
            return Option.none()
        end))
    end)

    suite:case("filter with a false predicate is none", function(asserts)
        asserts.eq(true, Option.none() == Option.some(1):filter(function()
            return false
        end))
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
        asserts.eq(
            true,
            Option.some(1) == Option.some(Option.some(1)):flatten()
        )
        asserts.eq(
            true,
            Option.none() == Option.some(Option.none()):flatten()
        )
        asserts.eq(
            true,
            Option.none()
                == (Option.none() :: Option.Option<Option.Option<any>>):flatten()
        )
    end)

    suite:case("flatten on a non-nested Option throws", function(asserts)
        asserts.throws(function()
            (Option.some(5) :: any):flatten()
        end)
    end)

    suite:case("nested equality and printing", function(asserts)
        asserts.eq(
            true,
            Option.some(Option.some(1)) == Option.some(Option.some(1))
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
            local called = false
            Option.some(1):orElse(function()
                called = true
                return Option.some(0)
            end)
            asserts.eq(false, called)

            called = false
            Option.none():orElse(function()
                called = true
                return Option.some(0)
            end)
            asserts.eq(true, called)
        end
    )

    suite:case(
        "Option:unwrapOrElse() doesn't call callbacks on some",
        function(asserts)
            local called = false
            Option.some(1):unwrapOrElse(function()
                called = true
                return 0
            end)
            asserts.eq(false, called)

            called = false
            Option.none():unwrapOrElse(function()
                called = true
                return 0
            end)
            asserts.eq(true, called)
        end
    )

    suite:case(
        "Option:mapOr() only calls mapper on some",
        function(asserts)
            local called = false
            Option.some(1):mapOr("default", function()
                called = true
                return "mapped"
            end)
            asserts.eq(true, called)

            called = false
            Option.none():mapOr("default", function()
                called = true
                return "mapped"
            end)
            asserts.eq(false, called)
        end
    )

    suite:case(
        "Option.mapOrElse() calls exactly one callback",
        function(asserts)
            local defaultCalled, mapperCalled = false, false
            local function default()
                defaultCalled = true
                return "default"
            end
            local function mapper()
                mapperCalled = true
                return "mapped"
            end

            asserts.eq(
                "mapped",
                Option.some(1):mapOrElse(default, mapper)
            )
            asserts.eq(false, defaultCalled)
            asserts.eq(true, mapperCalled)

            defaultCalled, mapperCalled = false, false
            asserts.eq(
                "default",
                Option.none():mapOrElse(default, mapper)
            )
            asserts.eq(true, defaultCalled)
            asserts.eq(false, mapperCalled)
        end
    )

    suite:case(
        "Option:andThen() doesn't call callbacks on none",
        function(asserts)
            local called = false
            Option.none():andThen(function()
                called = true
                return Option.some(0)
            end)
            asserts.eq(false, called)

            called = false
            Option.some(1):andThen(function()
                called = true
                return Option.some(0)
            end)
            asserts.eq(true, called)
        end
    )

    suite:case(
        "Option:map() doesn't call callbacks on none",
        function(asserts)
            local called = false
            Option.none():map(function()
                called = true
                return 0
            end)
            asserts.eq(false, called)

            called = false
            Option.some(1):map(function()
                called = true
                return 0
            end)
            asserts.eq(true, called)
        end
    )

    suite:case(
        "Option:filter() doesn't call callbacks on none",
        function(asserts)
            local called = false
            Option.none():filter(function()
                called = true
                return true
            end)
            asserts.eq(false, called)

            called = false
            Option.some(1):filter(function()
                called = true
                return true
            end)
            asserts.eq(true, called)
        end
    )

    suite:case(
        "Option:zip() doesn't call callbacks on none",
        function(asserts)
            local called = false
            Option.none():zip(Option.none(), function()
                called = true
                return 0
            end)
            asserts.eq(false, called)

            called = false
            Option.none():zip(Option.some(1), function()
                called = true
                return 0
            end)
            asserts.eq(false, called)

            called = false
            Option.some(1):zip(Option.none(), function()
                called = true
                return 0
            end)
            asserts.eq(false, called)

            called = false
            Option.some(1):zip(Option.some(1), function()
                called = true
                return 0
            end)
            asserts.eq(true, called)
        end
    )

    suite:case(
        "Option:inspect() doesn't call callbacks on none",
        function(asserts)
            local called = false
            Option.none():inspect(function()
                called = true
            end)
            asserts.eq(false, called)

            called = false
            Option.some(1):inspect(function()
                called = true
            end)
            asserts.eq(true, called)
        end
    )
end)

test.suite("Nil handling", function(suite)
    suite:case(
        "Option:map() with a callback that returns nil produces none",
        function(asserts)
            asserts.eq(true, Option.some(1):map(function()
                return nil
            end) == Option.none())
        end
    )

    suite:case(
        "Option:zip() with a callback that returns nil produces none",
        function(asserts)
            asserts.eq(true, Option.some(1):zip(Option.some(1), function()
                return nil
            end) == Option.none())
        end
    )

    suite:case(
        "Option:reduce() with a callback that returns nil produces none",
        function(asserts)
            asserts.eq(
                true,
                Option.some(1):reduce(Option.some(1), function()
                    return nil
                end) == Option.none()
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
                asserts.eq(
                    true,
                    expected[i] == Option.xor(pair[1], pair[2])
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
                asserts.eq(
                    true,
                    expected[i]
                        == Option.reduce(pair[1], pair[2], function(a, b)
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
                asserts.eq(
                    true,
                    expected[i] == Option.orOption(pair[1], pair[2])
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
                asserts.eq(
                    true,
                    expected[i] == Option.andOption(pair[1], pair[2])
                )
            end
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
