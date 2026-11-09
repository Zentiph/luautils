--!strict

-- Stopwatch tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers")
local Duration = require("../../src/luautils/Time/Duration")
local Stopwatch = require("../../src/luautils/Time/Stopwatch")

type Duration = Duration.Duration
type Stopwatch = Stopwatch.Stopwatch

local function secs(n: number): Duration
    return Duration.fromSeconds(n)
end

-- a manually controlled clock, so timings are exact and deterministic
local function fakeClock(start: number?): {
    now: number,
    fn: () -> number,
    advance: (by: number) -> (),
}
    local clock = {} :: any
    clock.now = start or 0
    clock.fn = function(): number
        return clock.now
    end
    clock.advance = function(by: number)
        clock.now += by
    end
    return clock
end

test.suite("new()", function(suite)
    suite:case("new() is stopped and at zero", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.new(clock.fn)
        asserts.eq(false, stopwatch:isRunning())
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
    end)

    suite:case("new() does not count time before starting", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.new(clock.fn)
        clock.advance(5)
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
    end)

    suite:case("new() uses the given clock", function(asserts)
        local spy = Helpers.spy(function(): number
            return 0
        end)
        local stopwatch = Stopwatch.new(spy.fn)
        stopwatch:start()
        asserts.eq(1, spy.calls)
    end)

    suite:case("new() defaults to os.clock", function(asserts)
        local stopwatch = Stopwatch.new()
        stopwatch:start()
        asserts.eq(false, stopwatch:elapsed():isNegative())
    end)
end)

test.suite("startNew()", function(suite)
    suite:case("startNew() is running and at zero", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        asserts.eq(true, stopwatch:isRunning())
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
    end)

    suite:case("startNew() counts time immediately", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(2)
        Helpers.eqByStr(asserts, secs(2), stopwatch:elapsed())
    end)
end)

test.suite("start()", function(suite)
    suite:case("start() starts the stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.new(clock.fn)
        stopwatch:start()
        asserts.eq(true, stopwatch:isRunning())
        clock.advance(1.5)
        Helpers.eqByStr(asserts, secs(1.5), stopwatch:elapsed())
    end)

    suite:case("start() resumes from the accumulated time", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:stop()
        clock.advance(10)
        stopwatch:start()
        clock.advance(2)
        Helpers.eqByStr(asserts, secs(3), stopwatch:elapsed())
    end)

    suite:case("start() does nothing if already running", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:start()
        clock.advance(1)
        Helpers.eqByStr(asserts, secs(2), stopwatch:elapsed())
    end)
end)

test.suite("stop()", function(suite)
    suite:case("stop() stops the stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:stop()
        asserts.eq(false, stopwatch:isRunning())
        Helpers.eqByStr(asserts, secs(1), stopwatch:elapsed())
    end)

    suite:case("stop() does not count time while stopped", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:stop()
        clock.advance(5)
        Helpers.eqByStr(asserts, secs(1), stopwatch:elapsed())
    end)

    suite:case("stop() does nothing if already stopped", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:stop()
        clock.advance(1)
        stopwatch:stop()
        Helpers.eqByStr(asserts, secs(1), stopwatch:elapsed())
    end)

    suite:case("stop() accumulates across intervals", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.new(clock.fn)
        for _ = 1, 4 do
            stopwatch:start()
            clock.advance(0.25)
            stopwatch:stop()
            clock.advance(100)
        end
        Helpers.eqByStr(asserts, secs(1), stopwatch:elapsed())
    end)
end)

test.suite("reset()", function(suite)
    suite:case("reset() stops and zeroes a running stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(3)
        stopwatch:reset()
        asserts.eq(false, stopwatch:isRunning())
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
        clock.advance(3)
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
    end)

    suite:case("reset() zeroes a stopped stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(3)
        stopwatch:stop()
        stopwatch:reset()
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
    end)

    suite:case("reset() clears the last lap", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(3)
        stopwatch:lap()
        stopwatch:reset()
        stopwatch:start()
        clock.advance(1)
        Helpers.eqByStr(asserts, secs(1), stopwatch:lap())
    end)
end)

test.suite("restart()", function(suite)
    suite:case("restart() zeroes and starts the stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(3)
        stopwatch:restart()
        asserts.eq(true, stopwatch:isRunning())
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
        clock.advance(2)
        Helpers.eqByStr(asserts, secs(2), stopwatch:elapsed())
    end)

    suite:case("restart() starts a stopped stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.new(clock.fn)
        stopwatch:restart()
        asserts.eq(true, stopwatch:isRunning())
    end)

    suite:case("restart() clears the last lap", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(3)
        stopwatch:lap()
        stopwatch:restart()
        clock.advance(1)
        Helpers.eqByStr(asserts, secs(1), stopwatch:lap())
    end)
end)

test.suite("elapsed()", function(suite)
    suite:case("elapsed() includes the current interval", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:stop()
        stopwatch:start()
        clock.advance(0.5)
        Helpers.eqByStr(asserts, secs(1.5), stopwatch:elapsed())
    end)

    suite:case("elapsed() does not stop the stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        stopwatch:elapsed()
        asserts.eq(true, stopwatch:isRunning())
    end)

    suite:case("elapsed() works with a nonzero clock start", function(asserts)
        local clock = fakeClock(1_000)
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(2)
        Helpers.eqByStr(asserts, secs(2), stopwatch:elapsed())
    end)

    suite:case(
        "elapsed() treats a backwards clock as zero time",
        function(asserts)
            local clock = fakeClock(5)
            local stopwatch = Stopwatch.startNew(clock.fn)
            clock.advance(-3)
            Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:elapsed())
        end
    )

    suite:case("stop() with a backwards clock adds zero time", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(2)
        stopwatch:stop()
        stopwatch:start()
        clock.advance(-1)
        stopwatch:stop()
        Helpers.eqByStr(asserts, secs(2), stopwatch:elapsed())
    end)
end)

test.suite("isRunning()", function(suite)
    suite:case("isRunning() tracks start and stop", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.new(clock.fn)
        asserts.eq(false, stopwatch:isRunning())
        stopwatch:start()
        asserts.eq(true, stopwatch:isRunning())
        stopwatch:stop()
        asserts.eq(false, stopwatch:isRunning())
    end)
end)

test.suite("lap()", function(suite)
    suite:case("lap() first lap measures from the start", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        Helpers.eqByStr(asserts, secs(1), stopwatch:lap())
    end)

    suite:case("lap() measures since the previous lap", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        Helpers.eqByStr(asserts, secs(1), stopwatch:lap())
        clock.advance(2)
        Helpers.eqByStr(asserts, secs(2), stopwatch:lap())
        clock.advance(1)
        Helpers.eqByStr(asserts, secs(1), stopwatch:lap())
        clock.advance(0.5)
        Helpers.eqByStr(asserts, secs(0.5), stopwatch:lap())
    end)

    suite:case("lap() laps add up to elapsed()", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        local total = Duration.ZERO
        for _, step in { 1, 3, 0.5, 2, 0.25 } do
            clock.advance(step)
            total += stopwatch:lap()
        end
        Helpers.eqByStr(asserts, stopwatch:elapsed(), total)
    end)

    suite:case("lap() twice without time passing is zero", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:lap()
        Helpers.eqByStr(asserts, Duration.ZERO, stopwatch:lap())
    end)

    suite:case("lap() does not count time while stopped", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1)
        stopwatch:lap()
        clock.advance(1)
        stopwatch:stop()
        clock.advance(10)
        Helpers.eqByStr(asserts, secs(1), stopwatch:lap())
    end)

    suite:case("lap() does not stop or start the stopwatch", function(asserts)
        local clock = fakeClock()
        local running = Stopwatch.startNew(clock.fn)
        running:lap()
        asserts.eq(true, running:isRunning())

        local stopped = Stopwatch.new(clock.fn)
        stopped:lap()
        asserts.eq(false, stopped:isRunning())
    end)
end)

test.suite("measure()", function(suite)
    suite:case("measure() returns a non-negative Duration", function(asserts)
        local elapsed = Stopwatch.measure(function() end)
        asserts.eq(true, Duration.is(elapsed))
        asserts.eq(false, elapsed:isNegative())
    end)

    suite:case("measure() passes the arguments to fn", function(asserts)
        local _, sum = Stopwatch.measure(function(a: number, b: number)
            return a + b
        end, 1, 2)
        asserts.eq(3, sum)
    end)

    suite:case(
        "measure() returns every value, including nils",
        function(asserts)
            local results = table.pack(Stopwatch.measure(function()
                return 1, nil, 3, nil
            end))
            asserts.eq(5, results.n)
            asserts.eq(1, results[2])
            asserts.eq(nil, results[3])
            asserts.eq(3, results[4])
            asserts.eq(nil, results[5])
        end
    )

    suite:case("measure() with no return values", function(asserts)
        local results = table.pack(Stopwatch.measure(function() end))
        asserts.eq(1, results.n)
    end)

    suite:case("measure() calls fn exactly once", function(asserts)
        local spy = Helpers.spy()
        Stopwatch.measure(spy.fn)
        asserts.eq(1, spy.calls)
    end)

    suite:case("measure() does not catch errors", function(asserts)
        Helpers.throwsWith(asserts, function()
            Stopwatch.measure(function()
                error("boom")
            end)
        end, "boom")
    end)
end)

test.suite("is()", function(suite)
    suite:case("is() is true for Stopwatches", function(asserts)
        asserts.eq(true, Stopwatch.is(Stopwatch.new()))
        asserts.eq(true, Stopwatch.is(Stopwatch.startNew()))
    end)

    suite:case("is() is false for non-Stopwatches", function(asserts)
        asserts.eq(false, Stopwatch.is(nil))
        asserts.eq(false, Stopwatch.is(1))
        asserts.eq(false, Stopwatch.is("stopwatch"))
        asserts.eq(false, Stopwatch.is({}))
        asserts.eq(false, Stopwatch.is(Duration.ZERO))
    end)

    suite:case("is() is false for lookalike tables", function(asserts)
        asserts.eq(
            false,
            Stopwatch.is({
                _clock = os.clock,
                _startedAt = nil,
                _accumulated = Duration.ZERO,
                _lapMark = Duration.ZERO,
            })
        )
    end)
end)

test.suite("toString()", function(suite)
    suite:case("toString() of a new Stopwatch", function(asserts)
        local clock = fakeClock()
        asserts.eq("0ms", Stopwatch.new(clock.fn):toString())
    end)

    suite:case("toString() marks a running Stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1.25)
        asserts.eq("1s 250ms (running)", stopwatch:toString())
    end)

    suite:case("toString() of a stopped Stopwatch", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1.25)
        stopwatch:stop()
        asserts.eq("1s 250ms", stopwatch:toString())
    end)

    suite:case("tostring() uses toString()", function(asserts)
        local clock = fakeClock()
        local stopwatch = Stopwatch.startNew(clock.fn)
        clock.advance(1.25)
        asserts.eq(stopwatch:toString(), tostring(stopwatch))
    end)
end)

test.suite("mutability", function(suite)
    suite:case("Stopwatches are not frozen", function(asserts)
        asserts.eq(false, table.isfrozen(Stopwatch.new()))
    end)

    suite:case("the Stopwatch module is frozen", function(asserts)
        asserts.eq(true, table.isfrozen(Stopwatch))
    end)

    suite:case("Stopwatches are independent", function(asserts)
        local clock = fakeClock()
        local a = Stopwatch.startNew(clock.fn)
        local b = Stopwatch.new(clock.fn)
        clock.advance(1)
        b:start()
        clock.advance(1)
        a:stop()
        Helpers.eqByStr(asserts, secs(2), a:elapsed())
        Helpers.eqByStr(asserts, secs(1), b:elapsed())
    end)
end)
