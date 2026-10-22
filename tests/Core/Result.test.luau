--!strict

-- Result tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers")
local Result = require("../../src/luautils/Core/Result")

local Option = require("../../src/luautils/Core/Option")

test.suite("ok()", function(suite)
    suite:case("ok(any) is ok", function(asserts)
        asserts.eq(true, Result.ok(1):isOk())
        asserts.eq(true, Result.ok("a"):isOk())
        asserts.eq(true, Result.ok(false):isOk())
        asserts.eq(true, Result.ok({}):isOk())
        asserts.eq(true, Result.ok(nil):isOk())
    end)
end)

test.suite("err()", function(suite)
    suite:case("err(~nil) is err", function(asserts)
        asserts.eq(true, Result.err(1):isErr())
        asserts.eq(true, Result.err("a"):isErr())
        asserts.eq(true, Result.err(false):isErr())
        asserts.eq(true, Result.err({}):isErr())
    end)

    suite:case("err(nil) throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.err(nil)
        end, "Error cannot be nil")
    end)
end)

test.suite("isOk()", function(suite)
    suite:case("isOk() returns true if ok", function(asserts)
        asserts.eq(true, Result.ok(1):isOk())
    end)

    suite:case("isOk() returns false if err", function(asserts)
        asserts.eq(false, Result.err(1):isOk())
    end)
end)

test.suite("isOkAnd()", function(suite)
    local predicateSpy = Helpers.spy(function(x)
        return x > 0
    end)

    suite:afterEach(function()
        predicateSpy.calls = 0
    end)

    suite:case("isOkAnd() runs predicate if ok", function(asserts)
        asserts.eq(true, Result.ok(1):isOkAnd(predicateSpy.fn))
        asserts.eq(1, predicateSpy.calls)

        asserts.eq(false, Result.ok(-1):isOkAnd(predicateSpy.fn))
        asserts.eq(2, predicateSpy.calls)
    end)

    suite:case("isOkAnd() does not run predicate if err", function(asserts)
        asserts.eq(
            false,
            (Result.err(1) :: Result.Result<number, number>):isOkAnd(
                predicateSpy.fn
            )
        )
        asserts.eq(0, predicateSpy.calls)
    end)
end)

test.suite("isErr()", function(suite)
    suite:case("isErr() returns true if err", function(asserts)
        asserts.eq(true, Result.err(1):isErr())
    end)

    suite:case("isErr() returns false if ok", function(asserts)
        asserts.eq(false, Result.ok(1):isErr())
    end)
end)

test.suite("isErrAnd()", function(suite)
    local predicateSpy = Helpers.spy(function(x)
        return x > 0
    end)

    suite:afterEach(function()
        predicateSpy.calls = 0
    end)

    suite:case("isErrAnd() runs predicate if err", function(asserts)
        asserts.eq(true, Result.err(1):isErrAnd(predicateSpy.fn))
        asserts.eq(1, predicateSpy.calls)

        asserts.eq(false, Result.err(-1):isErrAnd(predicateSpy.fn))
        asserts.eq(2, predicateSpy.calls)
    end)

    suite:case("isErrAnd() does not run predicate if ok", function(asserts)
        asserts.eq(
            false,
            (Result.ok(1) :: Result.Result<number, number>):isErrAnd(
                predicateSpy.fn
            )
        )
        asserts.eq(0, predicateSpy.calls)
    end)
end)

test.suite("asOk()", function(suite)
    suite:case("asOk() returns some if ok", function(asserts)
        Helpers.eqByStr(asserts, Option.some(1), Result.ok(1):asOk())
    end)

    suite:case("asOk() returns none if nil", function(asserts)
        Helpers.eqByStr(asserts, Option.none(), Result.ok(nil):asOk())
    end)

    suite:case("asOk() returns none if err", function(asserts)
        Helpers.eqByStr(asserts, Option.none(), Result.err(1):asOk())
    end)
end)

test.suite("asErr()", function(suite)
    suite:case("asErr() returns some if err", function(asserts)
        Helpers.eqByStr(asserts, Option.some(1), Result.err(1):asErr())
    end)

    suite:case("asErr() returns none if ok", function(asserts)
        Helpers.eqByStr(asserts, Option.none(), Result.ok(1):asErr())
    end)
end)

test.suite("map()", function(suite)
    local mapperSpy = Helpers.spy(function(x: number): string
        return tostring(x)
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("map() maps value if ok", function(asserts)
        asserts.eq("1", Result.ok(1):map(mapperSpy.fn):unwrap())
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("map() does not map value if err", function(asserts)
        asserts.eq(
            true,
            (Result.err(1) :: Result.Result<number, number>)
                :map(mapperSpy.fn)
                :isErr()
        )
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("mapOr()", function(suite)
    local mapperSpy = Helpers.spy(function(x: number): string
        return tostring(x)
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("mapOr() maps value if ok", function(asserts)
        asserts.eq("1", Result.ok(1):mapOr("2", mapperSpy.fn))
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("mapOr() returns default if err", function(asserts)
        asserts.eq(
            "2",
            (Result.err(1) :: Result.Result<number, number>):mapOr(
                "2",
                mapperSpy.fn
            )
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

    suite:case("mapOrElse() maps value if ok", function(asserts)
        asserts.eq("1", Result.ok(1):mapOrElse(defaultSpy.fn, mapperSpy.fn))
        asserts.eq(0, defaultSpy.calls)
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("mapOrElse() returns default if err", function(asserts)
        asserts.eq(
            "2",
            (Result.err(1) :: Result.Result<number, number>):mapOrElse(
                defaultSpy.fn,
                mapperSpy.fn
            )
        )
        asserts.eq(1, defaultSpy.calls)
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("mapErr()", function(suite)
    local mapperSpy = Helpers.spy(function(x: number): string
        return tostring(x)
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("mapErr() maps value if err", function(asserts)
        asserts.eq("1", Result.err(1):mapErr(mapperSpy.fn):unwrapErr())
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("mapErr() does not map value if ok", function(asserts)
        asserts.eq(
            true,
            (Result.ok(1) :: Result.Result<number, number>)
                :mapErr(mapperSpy.fn)
                :isOk()
        )
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("inspect()", function(suite)
    local consumerSpy = Helpers.spy(function(_) end)

    suite:afterEach(function()
        consumerSpy.calls = 0
    end)

    suite:case("inspect() calls consumer if ok", function(asserts)
        Result.ok(1):inspect(consumerSpy.fn)
        asserts.eq(1, consumerSpy.calls)
    end)

    suite:case("inspect() does not call consumer if err", function(asserts)
        Result.err(1):inspect(consumerSpy.fn)
        asserts.eq(0, consumerSpy.calls)
    end)
end)

test.suite("inspectErr()", function(suite)
    local consumerSpy = Helpers.spy(function(_) end)

    suite:afterEach(function()
        consumerSpy.calls = 0
    end)

    suite:case("inspectErr() calls consumer if err", function(asserts)
        Result.err(1):inspectErr(consumerSpy.fn)
        asserts.eq(1, consumerSpy.calls)
    end)

    suite:case("inspectErr() does not call consumer if ok", function(asserts)
        Result.ok(1):inspectErr(consumerSpy.fn)
        asserts.eq(0, consumerSpy.calls)
    end)
end)

test.suite("expect()", function(suite)
    suite:case("expect() returns value if ok", function(asserts)
        asserts.eq(1, Result.ok(1):expect("Should always be ok"))
    end)

    suite:case("expect() throws if err", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.err("Problem"):expect("Unexpected issue")
        end, "Unexpected issue: Problem")
    end)
end)

test.suite("unwrap()", function(suite)
    suite:case("unwrap() returns value if ok", function(asserts)
        asserts.eq(1, Result.ok(1):unwrap())
    end)

    suite:case("unwrap() throws if err", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.err("Problem"):unwrap()
        end, "Problem")
    end)
end)

test.suite("expectErr()", function(suite)
    suite:case("expectErr() returns value if err", function(asserts)
        asserts.eq(1, Result.err(1):expectErr("Should always be err"))
    end)

    suite:case("expectErr() throws if ok", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.ok(1):expectErr("Unexpected issue")
        end, "Unexpected issue")
    end)
end)

test.suite("unwrapErr()", function(suite)
    suite:case("unwrapErr() returns value if err", function(asserts)
        asserts.eq(1, Result.err(1):unwrapErr())
    end)

    suite:case("unwrapErr() throws if ok", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.ok(1):unwrapErr()
        end, "1")
    end)
end)

test.suite("andResult()", function(suite)
    suite:case("andResult() returns other if ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(2),
            Result.ok(1):andResult(Result.ok(2))
        )
        Helpers.eqByStr(
            asserts,
            Result.err("Error"),
            Result.ok(1):andResult(Result.err("Error"))
        )
    end)

    suite:case("andResult() returns self if err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err("Error1"),
            Result.err("Error1"):andResult(Result.ok(2))
        )
        Helpers.eqByStr(
            asserts,
            Result.err("Error1"),
            Result.err("Error1"):andResult(Result.err("Error2"))
        )
    end)
end)

test.suite("andThen()", function(suite)
    local mapperSpy = Helpers.spy(
        function(x: number): Result.Result<string, unknown>
            return Result.ok(tostring(x))
        end
    )

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("andThen() calls mapper if ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok("1"),
            Result.ok(1):andThen(mapperSpy.fn)
        )
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("andThen() does not call mapper if err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err(1),
            (Result.err(1) :: Result.Result<number, number>):andThen(
                mapperSpy.fn
            )
        )
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("orResult()", function(suite)
    suite:case("orResult() returns self if ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(1),
            Result.ok(1):orResult(Result.ok(2))
        )
        Helpers.eqByStr(
            asserts,
            Result.ok(1),
            Result.ok(1):orResult(Result.err("Error"))
        )
    end)

    suite:case("orResult() returns other if err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(2),
            Result.err("Error1"):orResult(Result.ok(2))
        )
        Helpers.eqByStr(
            asserts,
            Result.err("Error2"),
            Result.err("Error1"):orResult(Result.err("Error2"))
        )
    end)
end)

test.suite("orElse()", function(suite)
    local mapperSpy = Helpers.spy(
        function(x: number): Result.Result<unknown, string>
            return Result.err(tostring(x))
        end
    )

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("orElse() calls mapper if err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err("1"),
            Result.err(1):orElse(mapperSpy.fn)
        )
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("orElse() does not call mapper if ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(1),
            (Result.ok(1) :: Result.Result<number, number>):orElse(mapperSpy.fn)
        )
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("unwrapOr()", function(suite)
    suite:case("unwrapOr() returns value if ok", function(asserts)
        asserts.eq(1, Result.ok(1):unwrapOr(2))
    end)

    suite:case("unwrapOr() returns default if err", function(asserts)
        asserts.eq(2, Result.err(1):unwrapOr(2))
    end)
end)

test.suite("unwrapOrElse()", function(suite)
    local mapperSpy = Helpers.spy(function(_)
        return 2
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("unwrapOrElse() calls mapper if err", function(asserts)
        asserts.eq(2, Result.err(1):unwrapOrElse(mapperSpy.fn))
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("unwrapOrElse() returns value if ok", function(asserts)
        asserts.eq(1, Result.ok(1):unwrapOrElse(mapperSpy.fn))
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("try()", function(suite)
    local factorySpy = Helpers.spy(
        function(
            x: number,
            y: number,
            fail: boolean?,
            failNil: boolean?
        ): (number, number)
            if fail then
                error(if failNil then nil else "Error")
            end
            return y, x
        end
    )

    suite:afterEach(function()
        factorySpy.calls = 0
    end)

    suite:case("try() returns first value if factory is ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(2),
            Result.try(factorySpy.fn :: any, 1, 2)
        )
        asserts.eq(1, factorySpy.calls)
    end)

    suite:case("try() returns err if factory fails", function(asserts)
        local res = Result.try(factorySpy.fn :: any, 1, 2, true)
        asserts.eq(true, res:isErr())
        asserts.strContains(res:unwrapErr() :: string, "Error")
        asserts.eq(1, factorySpy.calls)
    end)

    suite:case(
        "try() returns custom err message if factory fails with nil error",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.err("error(nil) was called"),
                Result.try(factorySpy.fn :: any, 1, 2, true, true)
            )
            asserts.eq(1, factorySpy.calls)
        end
    )
end)

test.suite("tryPack()", function(suite)
    local factorySpy = Helpers.spy(
        function(
            x: number,
            y: number,
            fail: boolean?,
            failNil: boolean?
        ): (number, number)
            if fail then
                error(if failNil then nil else "Error")
            end
            return y, x
        end
    )

    suite:afterEach(function()
        factorySpy.calls = 0
    end)

    suite:case(
        "tryPack() returns packed table if factory is ok",
        function(asserts)
            local res = Result.tryPack(factorySpy.fn, 1, 2, nil, nil)
            asserts.eq(true, res:isOk())
            asserts.eq(2, res:unwrap()[1])
            asserts.eq(1, res:unwrap()[2])
            asserts.eq(1, factorySpy.calls)
        end
    )

    suite:case("tryPack() returns err if factory fails", function(asserts)
        local res = Result.tryPack(factorySpy.fn, 1, 2, true, nil)
        asserts.eq(true, res:isErr())
        asserts.strContains(res:unwrapErr() :: string, "Error")
        asserts.eq(1, factorySpy.calls)
    end)

    suite:case(
        "tryPack() returns custom err message if factory fails with nil error",
        function(asserts)
            local res = Result.tryPack(factorySpy.fn, 1, 2, true, true)
            asserts.eq(true, res:isErr())
            asserts.strContains(
                res:unwrapErr() :: string,
                "error(nil) was called"
            )
            asserts.eq(1, factorySpy.calls)
        end
    )
end)

test.suite("transpose()", function(suite)
    suite:case(
        "transpose() maps ok with some to some with ok",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Option.some(Result.ok(1)),
                Result.ok(Option.some(1)):transpose()
            )
        end
    )

    suite:case("transpose() maps ok with none to none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.none(),
            Result.ok(Option.none()):transpose()
        )
    end)

    suite:case("transpose() maps err to some with err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Option.some(Result.err(1)),
            (Result.err(1) :: Result.Result<Option.Option<number>, number>):transpose()
        )
    end)

    suite:case(
        "transpose() throws if ok and inner value is not an option",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                (Result.ok(1) :: any):transpose()
            end, "Called transpose on a Result that does not contain an Option")
        end
    )
end)

test.suite("flatten()", function(suite)
    suite:case("flatten() flattens ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(1),
            Result.ok(Result.ok(1)):flatten()
        )
        Helpers.eqByStr(
            asserts,
            Result.err(1),
            Result.ok(Result.err(1)):flatten()
        )
    end)

    suite:case("flatten() returns self if err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err(1),
            (
                Result.err(1) :: Result.Result<
                    Result.Result<number, number>,
                    number
                >
            ):flatten()
        )
    end)

    suite:case(
        "flatten() throws if ok and inner value is not a result",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                (Result.ok(1) :: any):flatten()
            end, "Called flatten on a Result that does not contain a Result")
        end
    )
end)

test.suite("is()", function(suite)
    suite:case("is() returns true for Results", function(asserts)
        asserts.eq(true, Result.is(Result.ok(1)))
        asserts.eq(true, Result.is(Result.err(1)))
    end)

    suite:case("is() returns false for non-Results", function(asserts)
        asserts.eq(false, Result.is(1))
        asserts.eq(false, Result.is("a"))
        asserts.eq(false, Result.is(false))
        asserts.eq(false, Result.is({}))
        asserts.eq(false, Result.is(nil))
    end)
end)

test.suite("equals()", function(suite)
    suite:case(
        "equals() returns true for equal states and inner values",
        function(asserts)
            Helpers.eqByStr(asserts, Result.ok(1), Result.ok(1))
            Helpers.neqByStr(asserts, Result.ok(1), Result.ok(2))
            Helpers.eqByStr(asserts, Result.err(1), Result.err(1))
            Helpers.neqByStr(asserts, Result.err(1), Result.err(2))
            Helpers.neqByStr(asserts, Result.ok(1), Result.err(1))
            Helpers.neqByStr(asserts, Result.err(1), Result.ok(1))
        end
    )

    suite:case("equals() returns false for non-Results", function(asserts)
        Helpers.neqByStr(asserts, Result.ok(1), 1)
        Helpers.neqByStr(asserts, Result.ok("a"), "a")
        Helpers.neqByStr(asserts, Result.ok(false), false)
        Helpers.neqByStr(asserts, Result.ok({}), {})
        Helpers.neqByStr(asserts, Result.ok(nil), nil)
    end)
end)

test.suite("toString()", function(suite)
    suite:case("toString() shows state and inner value", function(asserts)
        asserts.eq("Ok(1)", tostring(Result.ok(1)))
        asserts.eq('Err("Error")', tostring(Result.err("Error")))
    end)
end)
