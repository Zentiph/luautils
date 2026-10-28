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

test.suite("immutability", function(suite)
    suite:case("Results are frozen", function(asserts)
        asserts.eq(true, table.isfrozen(Result.ok(1) :: any))
        asserts.eq(true, table.isfrozen(Result.err(1) :: any))
    end)

    suite:case("modifying a Result throws", function(asserts)
        local ok = pcall(function()
            (Result.ok(1) :: any)._value = 2
        end)
        asserts.eq(false, ok)
    end)
end)

test.suite("toNillable()", function(suite)
    suite:case("toNillable() returns value if ok", function(asserts)
        asserts.eq(1, Result.ok(1):toNillable())
        asserts.eq("a", Result.ok("a"):toNillable())
        asserts.eq(false, Result.ok(false):toNillable())
        asserts.eq({}, Result.ok({}):toNillable())
    end)

    suite:case("toNillable() returns nil if err", function(asserts)
        asserts.eq(nil, Result.err(1):toNillable())
    end)

    suite:case("toNillable() returns nil if ok holds nil", function(asserts)
        asserts.eq(nil, Result.ok(nil):toNillable())
    end)
end)

test.suite("errToNillable()", function(suite)
    suite:case("errToNillable() returns error value if err", function(asserts)
        asserts.eq(1, Result.err(1):errToNillable())
        asserts.eq("a", Result.err("a"):errToNillable())
        asserts.eq(false, Result.err(false):errToNillable())
        asserts.eq({}, Result.err({}):errToNillable())
    end)

    suite:case("errToNillable() returns nil if ok", function(asserts)
        asserts.eq(nil, Result.ok(1):errToNillable())
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

test.suite("fromOption()", function(suite)
    suite:case("fromOption() returns ok if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(1),
            Result.fromOption(Option.some(1), "Error")
        )
    end)

    suite:case("fromOption() returns err if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err("Error"),
            Result.fromOption(Option.none(), "Error")
        )
    end)

    suite:case("fromOption() throws if none and error is nil", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.fromOption(Option.none(), nil)
        end, "[Result.fromOption()]: Given error produced a nil error")
    end)

    suite:case(
        "fromOption() does not throw if some and error is nil",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.ok(1),
                Result.fromOption(Option.some(1), nil)
            )
        end
    )
end)

test.suite("fromOptionElse()", function(suite)
    local supplierSpy = Helpers.spy(function()
        return "Error"
    end)

    suite:afterEach(function()
        supplierSpy.calls = 0
    end)

    suite:case("fromOptionElse() returns ok if some", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(1),
            Result.fromOptionElse(Option.some(1), supplierSpy.fn)
        )
        asserts.eq(0, supplierSpy.calls)
    end)

    suite:case("fromOptionElse() returns err if none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err("Error"),
            Result.fromOptionElse(Option.none(), supplierSpy.fn)
        )
        asserts.eq(1, supplierSpy.calls)
    end)

    suite:case(
        "fromOptionElse() throws if supplier returns nil",
        function(asserts)
            Helpers.throwsWith(
                asserts,
                function()
                    Result.fromOptionElse(Option.none(), function()
                        return nil
                    end)
                end,
                "[Result.fromOptionElse()]: Error supplier produced a nil error"
            )
        end
    )
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

    suite:case("asErr() returns some if err holds false", function(asserts)
        Helpers.eqByStr(asserts, Option.some(false), Result.err(false):asErr())
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

    suite:case("mapOrElse() passes error to default", function(asserts)
        asserts.eq(
            "Error!",
            (Result.err("Error") :: Result.Result<number, string>):mapOrElse(
                function(err)
                    return err .. "!"
                end,
                tostring
            )
        )
    end)
end)

test.suite("tryMap()", function(suite)
    local mapperSpy = Helpers.spy(function(x: number): string
        if x == 0 then
            error("Error")
        end
        return tostring(x)
    end)

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("tryMap() maps value if ok", function(asserts)
        asserts.eq("1", Result.ok(1):tryMap(mapperSpy.fn):unwrap())
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("tryMap() does not map value if err", function(asserts)
        asserts.eq(
            true,
            (Result.err(1) :: Result.Result<number, number>)
                :tryMap(mapperSpy.fn)
                :isErr()
        )
        asserts.eq(0, mapperSpy.calls)
    end)

    suite:case("tryMap() returns err if mapper throws", function(asserts)
        local res = Result.ok(0):tryMap(mapperSpy.fn)
        asserts.eq(true, res:isErr())
        asserts.strContains(res:unwrapErr() :: string, "Error")
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case(
        "tryMap() returns custom err message if mapper throws nil",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.err("error(nil) was called"),
                Result.ok(1):tryMap(function(_)
                    error(nil)
                    return 0 -- for the type checker
                end)
            )
        end
    )
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

    suite:case("mapErr() throws if mapper maps to nil", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.err(1):mapErr(function()
                return nil
            end)
        end, 'Mapper produced a nil error; "err" Results cannot hold nil')
    end)

    suite:case(
        "mapErr() blames the caller if mapper maps to nil",
        function(asserts)
            local ok, err = pcall(function()
                Result.err(1):mapErr(function()
                    return nil
                end)
            end)
            asserts.eq(false, ok)
            asserts.strContains(tostring(err), "[Result.mapErr()]")
            asserts.strContains(tostring(err), "Result.test.luau:")
        end
    )
end)

test.suite("filterOrElse()", function(suite)
    local predicateSpy = Helpers.spy(function(x: number): boolean
        return x == 1
    end)
    local errorFactorySpy = Helpers.spy(function(x: number): string
        return tostring(x)
    end)

    suite:afterEach(function()
        predicateSpy.calls = 0
        errorFactorySpy.calls = 0
    end)

    suite:case(
        "filterOrElse() returns ok if predicate is met",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.ok(1),
                Result.ok(1):filterOrElse(predicateSpy.fn, errorFactorySpy.fn)
            )
            asserts.eq(1, predicateSpy.calls)
            asserts.eq(0, errorFactorySpy.calls)
        end
    )

    suite:case(
        "filterOrElse() returns err from error factory if predicate fails",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.err("2"),
                Result.ok(2):filterOrElse(predicateSpy.fn, errorFactorySpy.fn)
            )
            asserts.eq(1, predicateSpy.calls)
            asserts.eq(1, errorFactorySpy.calls)
        end
    )

    suite:case("filterOrElse() returns self if err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err(1),
            (Result.err(1) :: Result.Result<number, number>):filterOrElse(
                predicateSpy.fn,
                errorFactorySpy.fn
            )
        )
        asserts.eq(0, predicateSpy.calls)
        asserts.eq(0, errorFactorySpy.calls)
    end)

    suite:case(
        "filterOrElse() throws if error factory returns nil",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                Result.ok(2):filterOrElse(predicateSpy.fn, function(_)
                    return nil
                end)
            end, "[Result.filterOrElse()]: Error factory produced a nil error")
        end
    )
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

    suite:case("inspect() passes value and returns self", function(asserts)
        local received
        local res = Result.ok(1)
        asserts.eq(
            true,
            rawequal(
                res,
                res:inspect(function(x)
                    received = x
                end)
            )
        )
        asserts.eq(1, received)
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

    suite:case("inspectErr() passes error and returns self", function(asserts)
        local received
        local res = Result.err(1)
        asserts.eq(
            true,
            rawequal(
                res,
                res:inspectErr(function(x)
                    received = x
                end)
            )
        )
        asserts.eq(1, received)
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
        end, 'Unexpected issue: "Problem"')
    end)
end)

test.suite("unwrap()", function(suite)
    suite:case("unwrap() returns value if ok", function(asserts)
        asserts.eq(1, Result.ok(1):unwrap())
    end)

    suite:case("unwrap() throws if err", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.err("Problem"):unwrap()
        end, "[Result.unwrap()]: Problem")
    end)

    suite:case("unwrap() throws table errors as-is", function(asserts)
        local errValue = { code = 1 }
        local ok, err = pcall(function()
            Result.err(errValue):unwrap()
        end)
        asserts.eq(false, ok)
        asserts.eq(true, rawequal(errValue, err))
    end)

    suite:case("unwrap() returns nil if ok holds nil", function(asserts)
        asserts.eq(nil, Result.ok(nil):unwrap())
    end)
end)

test.suite("expectErr()", function(suite)
    suite:case("expectErr() returns value if err", function(asserts)
        asserts.eq(1, Result.err(1):expectErr("Should always be err"))
    end)

    suite:case("expectErr() throws if ok", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.ok(1):expectErr("Unexpected issue")
        end, "Unexpected issue: 1")
    end)
end)

test.suite("unwrapErr()", function(suite)
    suite:case("unwrapErr() returns value if err", function(asserts)
        asserts.eq(1, Result.err(1):unwrapErr())
    end)

    suite:case("unwrapErr() throws if ok", function(asserts)
        Helpers.throwsWith(asserts, function()
            Result.ok(1):unwrapErr()
        end, "Called on an ok value: 1")
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

test.suite("tryAndThen()", function(suite)
    local mapperSpy = Helpers.spy(
        function(x: number): Result.Result<string, unknown>
            if x == 0 then
                error("Error")
            end
            return Result.ok(tostring(x))
        end
    )

    suite:afterEach(function()
        mapperSpy.calls = 0
    end)

    suite:case("tryAndThen() calls mapper if ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok("1"),
            Result.ok(1):tryAndThen(mapperSpy.fn)
        )
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("tryAndThen() does not call mapper if err", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err(1),
            (Result.err(1) :: Result.Result<number, number>):tryAndThen(
                mapperSpy.fn
            )
        )
        asserts.eq(0, mapperSpy.calls)
    end)

    suite:case("tryAndThen() returns err if mapper throws", function(asserts)
        local res = Result.ok(0):tryAndThen(mapperSpy.fn)
        asserts.eq(true, res:isErr())
        asserts.strContains(res:unwrapErr() :: string, "Error")
        asserts.eq(1, mapperSpy.calls)
    end)

    suite:case("tryAndThen() returns err returned by mapper", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.err("Error"),
            Result.ok(1):tryAndThen(function(_)
                return Result.err("Error")
            end)
        )
    end)

    suite:case(
        "tryAndThen() throws if mapper returns a non-Result",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                Result.ok(1):tryAndThen(function(_)
                    return 1 :: any
                end)
            end, "Called flatten on a Result that does not contain a Result")
        end
    )
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

    suite:case("orElse() can recover to ok", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(2),
            Result.err(1):orElse(function(x)
                return Result.ok(x + 1)
            end)
        )
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

    suite:case("unwrapOrElse() passes error to mapper", function(asserts)
        asserts.eq(
            "Error!",
            (Result.err("Error") :: Result.Result<string, string>):unwrapOrElse(
                function(err)
                    return err .. "!"
                end
            )
        )
    end)

    suite:case("unwrapOrElse() returns value if ok", function(asserts)
        asserts.eq(1, Result.ok(1):unwrapOrElse(mapperSpy.fn))
        asserts.eq(0, mapperSpy.calls)
    end)
end)

test.suite("match()", function(suite)
    local okSpy = Helpers.spy(function(_) end)
    local errSpy = Helpers.spy(function(_) end)

    suite:afterEach(function()
        okSpy.calls = 0
        errSpy.calls = 0
    end)

    suite:case("match() calls ifOk() on ok", function(asserts)
        Result.ok(1):match(okSpy.fn, errSpy.fn)
        asserts.eq(1, okSpy.calls)
        asserts.eq(0, errSpy.calls)
    end)

    suite:case("match() calls ifErr() on err", function(asserts)
        Result.err(1):match(okSpy.fn, errSpy.fn)
        asserts.eq(0, okSpy.calls)
        asserts.eq(1, errSpy.calls)
    end)

    suite:case("match() passes contained values", function(asserts)
        local received
        Result.ok(1):match(function(x)
            received = x
        end, errSpy.fn)
        asserts.eq(1, received)

        Result.err(2):match(okSpy.fn, function(x)
            received = x
        end)
        asserts.eq(2, received)
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

test.suite("tryTrace()", function(suite)
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
    local onErrSpy = Helpers.spy(function(err: unknown): string?
        return if err == nil
            then nil
            else "Handled: " .. tostring(err) .. "\n" .. debug.traceback()
    end)

    suite:afterEach(function()
        factorySpy.calls = 0
        onErrSpy.calls = 0
    end)

    suite:case(
        "tryTrace() returns first value if factory is ok",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.ok(2),
                Result.tryTrace(factorySpy.fn :: any, onErrSpy.fn, 1, 2)
            )
            asserts.eq(1, factorySpy.calls)
            asserts.eq(0, onErrSpy.calls)
        end
    )

    suite:case("tryTrace() returns err if factory fails", function(asserts)
        local res =
            Result.tryTrace(factorySpy.fn :: any, onErrSpy.fn, 1, 2, true)
        asserts.eq(true, res:isErr())
        asserts.strContains(res:unwrapErr() :: string, "Handled:")
        asserts.strContains(res:unwrapErr() :: string, "Error")
        asserts.eq(1, factorySpy.calls)
        asserts.eq(1, onErrSpy.calls)
    end)

    suite:case(
        "tryTrace() returns custom err message if onErr returns nil",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.err("error handler returned nil"),
                Result.tryTrace(
                    factorySpy.fn :: any,
                    onErrSpy.fn,
                    1,
                    2,
                    true,
                    true
                )
            )
            asserts.eq(1, factorySpy.calls)
            asserts.eq(1, onErrSpy.calls)
        end
    )

    suite:case("tryTrace() passes thrown value to onErr", function(asserts)
        local thrown = { code = 1 }
        local received
        local res = Result.tryTrace(function()
            error(thrown)
            return 0 -- for the type checker
        end, function(err)
            received = err
            return "mapped"
        end)
        asserts.eq(thrown, received)
        Helpers.eqByStr(asserts, Result.err("mapped"), res)
    end)

    suite:case("tryTrace() passes thrown nil to onErr", function(asserts)
        local res = Result.tryTrace(function()
            error(nil)
            return 0 -- for the type checker
        end, function(err)
            return if err == nil then "was nil" else "was not nil"
        end)
        Helpers.eqByStr(asserts, Result.err("was nil"), res)
    end)
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

    suite:case("tryPack() preserves nil return values", function(asserts)
        local packed = Result.tryPack(function()
            return nil, 1, nil
        end):unwrap()
        asserts.eq(3, packed.n)
        asserts.eq(nil, packed[1])
        asserts.eq(1, packed[2])
        asserts.eq(nil, packed[3])
    end)

    suite:case("tryPack() packs zero return values", function(asserts)
        asserts.eq(0, Result.tryPack(function() end):unwrap().n)
    end)
end)

test.suite("wrap()", function(suite)
    local factorySpy = Helpers.spy(function(fail: boolean): number
        if fail then
            error("Error")
        else
            return 1
        end
    end)

    suite:afterEach(function()
        factorySpy.calls = 0
    end)

    suite:case(
        "wrap() returns function that returns ok on valid return",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.ok(1),
                Result.wrap(factorySpy.fn)(false)
            )
            asserts.eq(1, factorySpy.calls)
        end
    )

    suite:case(
        "wrap() returns function that returns err on thrown error",
        function(asserts)
            local res = Result.wrap(factorySpy.fn)(true)
            asserts.eq(true, res:isErr())
            asserts.strContains(res:unwrapErr() :: string, "Error")
            asserts.eq(1, factorySpy.calls)
        end
    )

    suite:case(
        "wrap() passes all arguments and keeps only the first return",
        function(asserts)
            local wrapped = Result.wrap(function(x: number, y: number)
                return x + y, x - y
            end :: any)
            Helpers.eqByStr(asserts, Result.ok(3), wrapped(1, 2))
        end
    )

    suite:case("wrap() does not call factory until invoked", function(asserts)
        Result.wrap(factorySpy.fn)
        asserts.eq(0, factorySpy.calls)
    end)
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

test.suite("transposeOption()", function(suite)
    suite:case(
        "transposeOption() maps some with ok to ok with some",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.ok(Option.some(1)),
                Result.transposeOption(Option.some(Result.ok(1)))
            )
        end
    )

    suite:case(
        "transposeOption() maps some with err to the same err",
        function(asserts)
            local inner = Result.err("Error")
            local res = Result.transposeOption(Option.some(inner))
            Helpers.eqByStr(asserts, Result.err("Error"), res)
            asserts.eq(true, rawequal(inner, res))
        end
    )

    suite:case("transposeOption() maps none to ok with none", function(asserts)
        Helpers.eqByStr(
            asserts,
            Result.ok(Option.none()),
            Result.transposeOption(
                Option.none() :: Option.Option<Result.Result<number, string>>
            )
        )
    end)

    suite:case(
        "transposeOption() maps some with ok holding nil to ok with none",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Result.ok(Option.none()),
                Result.transposeOption(Option.some(Result.ok(nil)))
            )
        end
    )

    suite:case("transposeOption() undoes transpose()", function(asserts)
        local original = Result.ok(Option.some(1))
        Helpers.eqByStr(
            asserts,
            original,
            Result.transposeOption(original:transpose())
        )
    end)

    suite:case(
        "transposeOption() throws if some and inner value is not a result",
        function(asserts)
            Helpers.throwsWith(
                asserts,
                function()
                    Result.transposeOption(Option.some(1) :: any)
                end,
                "[Result.transposeOption()]: Called transposeOption on an Option "
                    .. "that does not contain a Result"
            )
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

test.suite("all()", function(suite)
    suite:case("all() returns ok if all are ok", function(asserts)
        local values = {
            Result.ok(1),
            Result.ok(2),
            Result.ok(3),
        } :: { Result.Result<number, number> }
        local result = Result.all(values)
        asserts.eq(true, result:isOk())
        asserts.eq({ 1, 2, 3 }, result:unwrap())
    end)

    suite:case("all() returns first error if error exists", function(asserts)
        local values = {
            Result.ok(1),
            Result.err(2),
            Result.ok(3),
        } :: { Result.Result<number, number> }
        local result = Result.all(values)
        asserts.eq(true, result:isErr())
        asserts.eq(2, result:unwrapErr())
    end)

    suite:case("all() throws if non-Result present", function(asserts)
        local values = { Result.ok(1), 2, Result.ok(3) }
        Helpers.throwsWith(asserts, function()
            Result.all(values :: any)
        end, "Called all on a table containing a non-Result value")
    end)

    suite:case("all() returns ok with empty table if empty", function(asserts)
        local result = Result.all({})
        asserts.eq(true, result:isOk())
        asserts.eq({}, result:unwrap())
    end)

    suite:case("all() preserves keys", function(asserts)
        local values = {
            a = Result.ok(1),
            b = Result.ok(2),
        } :: { [string]: Result.Result<number, number> }
        asserts.eq({ a = 1, b = 2 }, Result.all(values):unwrap())
    end)

    suite:case("all() omits ok values of nil", function(asserts)
        local values = {
            Result.ok(1),
            Result.ok(nil),
            Result.ok(3),
        } :: { Result.Result<number?, number> }
        asserts.eq({ [1] = 1, [3] = 3 }, Result.all(values):unwrap())
    end)
end)

test.suite("partition()", function(suite)
    suite:case("partition() returns oks and errs", function(asserts)
        local values = {
            Result.ok(1),
            Result.err(2),
            Result.ok(3),
            Result.err(4),
        } :: { Result.Result<number, number> }
        local oks, errs = Result.partition(values)
        asserts.eq({ [1] = 1, [3] = 3 }, oks)
        asserts.eq({ [2] = 2, [4] = 4 }, errs)
    end)

    suite:case("partition() preserves keys", function(asserts)
        local values = {
            a = Result.ok(1),
            b = Result.err(2),
        } :: { [string]: Result.Result<number, number> }
        local oks, errs = Result.partition(values)
        asserts.eq({ a = 1 }, oks)
        asserts.eq({ b = 2 }, errs)
    end)

    suite:case("partition() returns empty tables if empty", function(asserts)
        local oks, errs = Result.partition({})
        asserts.eq({}, oks)
        asserts.eq({}, errs)
    end)

    suite:case("partition() throws if non-Result present", function(asserts)
        local values = {
            Result.ok(1),
            Result.err(2),
            3,
        }
        Helpers.throwsWith(asserts, function()
            Result.partition(values :: any)
        end, "Called partition on a table containing a non-Result value")
    end)
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

    suite:case("equals() is used by == and ~=", function(asserts)
        asserts.eq(true, Result.ok(1) == Result.ok(1))
        asserts.eq(true, Result.ok(nil) == Result.ok(nil))
        asserts.eq(true, Result.ok(1) ~= Result.err(1))
        asserts.eq(true, Result.ok(1):equals(Result.ok(1)))
    end)

    suite:case("equals() compares tables by reference", function(asserts)
        local t = {}
        asserts.eq(true, Result.ok(t) == Result.ok(t))
        asserts.eq(false, Result.ok({}) == Result.ok({}))
    end)

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
        asserts.eq("Ok(nil)", tostring(Result.ok(nil)))
        asserts.eq("Ok(1)", Result.ok(1):toString())
    end)
end)
