--!strict

-- retry tests
-- by @vuppyan

-- `task` does not exist outside of Roblox, so every case that sets `delay`
-- must also pass a `sleep` so `task.wait` is never reached.

local test = require("@std/test")
local Helpers = require("../Helpers")
local Core = require("../../src/luautils/Core")
local retry = require("../../src/luautils/Async/retry")

local Result = Core.Result
type Result<T, E> = Core.Result<T, E>

-- builds an attempt that fails `failures` times before returning "ok", and
-- records every attempt and sleep in `log`
local function failThenOk(
    failures: number,
    log: { string }
): () -> Result<string, string>
    local calls = 0
    return function(): Result<string, string>
        calls += 1
        table.insert(log, `attempt {calls}`)
        if calls <= failures then
            return Result.err(`err {calls}`) :: Result<string, string>
        end
        return Result.ok(`ok {calls}`) :: Result<string, string>
    end
end

local function recordSleep(log: { string }): (seconds: number) -> ()
    return function(seconds: number)
        table.insert(log, `sleep {seconds}`)
    end
end

test.suite("retry()", function(suite)
    suite:case("returns an immediate ok after one attempt", function(asserts)
        local log = {}
        local result = retry(failThenOk(0, log), { attempts = 3 })

        asserts.eq(true, result:isOk())
        asserts.eq("ok 1", result:unwrap())
        asserts.eq(1, #log)
    end)

    suite:case("returns the first ok after failures", function(asserts)
        local log = {}
        local result = retry(failThenOk(2, log), { attempts = 5 })

        asserts.eq(true, result:isOk())
        asserts.eq("ok 3", result:unwrap())
        asserts.eq(3, #log)
    end)

    suite:case("returns the last err when attempts run out", function(asserts)
        local log = {}
        local result = retry(failThenOk(math.huge, log), { attempts = 4 })

        asserts.eq(true, result:isErr())
        asserts.eq("err 4", result:unwrapErr())
        asserts.eq(4, #log)
    end)

    suite:case("makes exactly one attempt when attempts is 1", function(asserts)
        local log = {}
        local result = retry(failThenOk(math.huge, log), { attempts = 1 })

        asserts.eq("err 1", result:unwrapErr())
        asserts.eq(1, #log)
    end)

    suite:case("succeeds on the final attempt", function(asserts)
        local log = {}
        local result = retry(failThenOk(2, log), { attempts = 3 })

        asserts.eq("ok 3", result:unwrap())
        asserts.eq(3, #log)
    end)

    suite:case("does not sleep without a delay", function(asserts)
        local sleep = Helpers.spy(function(_seconds: number) end)
        local result = retry(failThenOk(math.huge, {}), {
            attempts = 3,
            sleep = sleep.fn,
        })

        asserts.eq("err 3", result:unwrapErr())
        asserts.eq(0, sleep.calls)
    end)

    suite:case(
        "sleeps for the delay between attempts but not after the last",
        function(asserts)
            local log = {}
            retry(failThenOk(math.huge, log), {
                attempts = 3,
                delay = 0.5,
                sleep = recordSleep(log),
            })

            asserts.eq(
                table.concat({
                    "attempt 1",
                    "sleep 0.5",
                    "attempt 2",
                    "sleep 0.5",
                    "attempt 3",
                }, ", "),
                table.concat(log, ", ")
            )
        end
    )

    suite:case("does not sleep after an ok", function(asserts)
        local log = {}
        local result = retry(failThenOk(1, log), {
            attempts = 5,
            delay = 2,
            sleep = recordSleep(log),
        })

        asserts.eq("ok 2", result:unwrap())
        asserts.eq("attempt 1, sleep 2, attempt 2", table.concat(log, ", "))
    end)

    suite:case("does not sleep with a single attempt", function(asserts)
        local sleep = Helpers.spy(function(_seconds: number) end)
        retry(failThenOk(math.huge, {}), {
            attempts = 1,
            delay = 1,
            sleep = sleep.fn,
        })

        asserts.eq(0, sleep.calls)
    end)

    suite:case(
        "retries a throwing function wrapped in Result.try",
        function(asserts)
            local calls = 0
            local result = retry(function()
                return Result.try(function(): number
                    calls += 1
                    if calls < 3 then
                        error("boom", 0)
                    end
                    return calls
                end)
            end, { attempts = 5 })

            asserts.eq(3, result:unwrap())
            asserts.eq(3, calls)
        end
    )

    suite:case(
        "returns the last thrown error from Result.try",
        function(asserts)
            local calls = 0
            local result = retry(function()
                return Result.try(function(): never
                    calls += 1
                    error(`boom {calls}`, 0)
                end)
            end, { attempts = 2 })

            asserts.eq("boom 2", result:unwrapErr())
            asserts.eq(2, calls)
        end
    )

    suite:case(
        "throws on a non-positive or fractional attempts",
        function(asserts)
            for _, attempts in { 0, -1, 1.5 } do
                local attempt = Helpers.spy(function(): Result<string, string>
                    return Result.ok("unreachable") :: Result<string, string>
                end)

                Helpers.throwsWith(asserts, function()
                    retry(attempt.fn, { attempts = attempts })
                end, "[Async.retry()]: Attempts must be a positive integer")
                asserts.eq(0, attempt.calls)
            end
        end
    )
end)
