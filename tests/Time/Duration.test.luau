--!strict

-- Duration tests
-- by @vuppyan

local test = require("@std/test")
local types = require("@std/test/types")
local Helpers = require("../Helpers")
local Duration = require("../../src/luautils/Time/Duration")

type Duration = Duration.Duration

local INF = Duration.INFINITE
local NEG_INF = Duration.INFINITE:negated()

local function secs(n: number): Duration
    return Duration.fromSeconds(n)
end

local function millis(n: number): Duration
    return Duration.fromMillis(n)
end

local function nanos(n: number): Duration
    return Duration.fromNanos(n)
end

-- asserts the exact internal seconds and nanoseconds of a Duration
local function assertParts(
    asserts: types.Asserts,
    duration: Duration,
    expectedSecs: number,
    expectedNanos: number
)
    local s, n = duration:toSecondsAndNanos()
    asserts.eq(expectedSecs, s)
    asserts.eq(expectedNanos, n)
end

test.suite("new()", function(suite)
    suite:case("new() stores seconds and nanoseconds", function(asserts)
        assertParts(asserts, Duration.new(1, 500), 1, 500)
        assertParts(asserts, Duration.new(0, 0), 0, 0)
    end)

    suite:case("new() carries nanoseconds into seconds", function(asserts)
        assertParts(asserts, Duration.new(1, 1_500_000_000), 2, 500_000_000)
        assertParts(asserts, Duration.new(0, 1_000_000_000), 1, 0)
        assertParts(asserts, Duration.new(0, 3_000_000_001), 3, 1)
    end)

    suite:case("new() borrows negative nanoseconds", function(asserts)
        assertParts(asserts, Duration.new(2, -500_000_000), 1, 500_000_000)
        assertParts(asserts, Duration.new(0, -1), -1, 999_999_999)
        assertParts(asserts, Duration.new(0, -1_000_000_000), -1, 0)
    end)

    suite:case("new() splits fractional seconds", function(asserts)
        assertParts(asserts, Duration.new(1.5, 0), 1, 500_000_000)
        assertParts(asserts, Duration.new(-1.5, 0), -2, 500_000_000)
        assertParts(asserts, Duration.new(0.25, 250_000_000), 0, 500_000_000)
    end)

    suite:case(
        "new() rounds fractional nanoseconds half away from zero",
        function(asserts)
            assertParts(asserts, Duration.new(0, 1.4), 0, 1)
            assertParts(asserts, Duration.new(0, 1.5), 0, 2)
            assertParts(asserts, Duration.new(0, -1.5), -1, 999_999_998)
        end
    )

    suite:case("new() keeps nanoseconds in range", function(asserts)
        for _, n in { -2_500_000_001, -1, 0, 1, 999_999_999, 7_000_000_123 } do
            local _, ns = Duration.new(0, n):toSecondsAndNanos()
            asserts.eq(true, ns >= 0 and ns <= 999_999_999)
        end
    end)

    suite:case("new() with infinite seconds is infinite", function(asserts)
        assertParts(asserts, Duration.new(math.huge, 5), math.huge, 0)
        assertParts(asserts, Duration.new(-math.huge, 5), -math.huge, 0)
    end)

    suite:case("new() with infinite nanoseconds is infinite", function(asserts)
        assertParts(asserts, Duration.new(5, math.huge), math.huge, 0)
        assertParts(asserts, Duration.new(5, -math.huge), -math.huge, 0)
    end)

    suite:case(
        "new() with infinities of the same sign is infinite",
        function(asserts)
            Helpers.eqByStr(asserts, INF, Duration.new(math.huge, math.huge))
            Helpers.eqByStr(
                asserts,
                NEG_INF,
                Duration.new(-math.huge, -math.huge)
            )
        end
    )

    suite:case(
        "new() with infinities of different signs throws",
        function(asserts)
            Helpers.throwsWith(
                asserts,
                function()
                    Duration.new(math.huge, -math.huge)
                end,
                "[Duration.new()]: Cannot build a Duration from infinities with different signs"
            )
        end
    )

    suite:case("new() with NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Duration.new(0 / 0, 0)
        end, "[Duration.new()]: Cannot create a Duration from NaN values")
        Helpers.throwsWith(asserts, function()
            Duration.new(0, 0 / 0)
        end, "[Duration.new()]: Cannot create a Duration from NaN values")
    end)
end)

test.suite("immutability", function(suite)
    suite:case("Durations are frozen", function(asserts)
        asserts.eq(true, table.isfrozen(Duration.new(1, 0)))
        asserts.eq(true, table.isfrozen(Duration.ZERO))
        asserts.eq(true, table.isfrozen(INF))
    end)

    suite:case("modifying a Duration throws", function(asserts)
        local ok = pcall(function()
            (Duration.SECOND :: any)._secs = 2
        end)
        asserts.eq(false, ok)
        assertParts(asserts, Duration.SECOND, 1, 0)
    end)
end)

test.suite("constants", function(suite)
    suite:case("unit constants have the expected lengths", function(asserts)
        assertParts(asserts, Duration.ZERO, 0, 0)
        assertParts(asserts, Duration.NANOSECOND, 0, 1)
        assertParts(asserts, Duration.MICROSECOND, 0, 1_000)
        assertParts(asserts, Duration.MILLISECOND, 0, 1_000_000)
        assertParts(asserts, Duration.SECOND, 1, 0)
        assertParts(asserts, Duration.MINUTE, 60, 0)
        assertParts(asserts, Duration.HOUR, 3_600, 0)
        assertParts(asserts, Duration.DAY, 86_400, 0)
        assertParts(asserts, Duration.WEEK, 604_800, 0)
    end)

    suite:case("INFINITE is positive and infinite", function(asserts)
        asserts.eq(true, INF:isInf())
        asserts.eq(true, INF:isPositive())
        assertParts(asserts, INF, math.huge, 0)
    end)

    suite:case("negating INFINITE is negative infinity", function(asserts)
        asserts.eq(true, (-INF):isInf())
        asserts.eq(true, (-INF):isNegative())
    end)
end)

test.suite("from*()", function(suite)
    suite:case("from*() creates Durations of each unit", function(asserts)
        assertParts(asserts, Duration.fromNanos(5), 0, 5)
        assertParts(asserts, Duration.fromMicros(5), 0, 5_000)
        assertParts(asserts, Duration.fromMillis(5), 0, 5_000_000)
        assertParts(asserts, Duration.fromSeconds(5), 5, 0)
        assertParts(asserts, Duration.fromMinutes(5), 300, 0)
        assertParts(asserts, Duration.fromHours(5), 18_000, 0)
        assertParts(asserts, Duration.fromDays(5), 432_000, 0)
        assertParts(asserts, Duration.fromWeeks(5), 3_024_000, 0)
    end)

    suite:case("from*() accepts fractional values", function(asserts)
        assertParts(asserts, Duration.fromNanos(2.5), 0, 3)
        assertParts(asserts, Duration.fromMicros(1.5), 0, 1_500)
        assertParts(asserts, Duration.fromMillis(1_500), 1, 500_000_000)
        assertParts(asserts, Duration.fromSeconds(0.001), 0, 1_000_000)
        assertParts(asserts, Duration.fromMinutes(0.5), 30, 0)
        assertParts(asserts, Duration.fromHours(1.5), 5_400, 0)
        assertParts(asserts, Duration.fromDays(0.5), 43_200, 0)
        assertParts(asserts, Duration.fromWeeks(0.5), 302_400, 0)
    end)

    suite:case("from*() accepts negative values", function(asserts)
        assertParts(asserts, Duration.fromNanos(-1), -1, 999_999_999)
        assertParts(asserts, Duration.fromMillis(-1_500), -2, 500_000_000)
        assertParts(asserts, Duration.fromMinutes(-1), -60, 0)
    end)

    suite:case("from*() accepts infinities", function(asserts)
        Helpers.eqByStr(asserts, INF, Duration.fromNanos(math.huge))
        Helpers.eqByStr(asserts, INF, Duration.fromSeconds(math.huge))
        Helpers.eqByStr(asserts, NEG_INF, Duration.fromWeeks(-math.huge))
    end)

    suite:case("from*() with NaN throws from new()", function(asserts)
        for _, fn in
            {
                Duration.fromNanos,
                Duration.fromMicros,
                Duration.fromMillis,
                Duration.fromSeconds,
                Duration.fromMinutes,
                Duration.fromHours,
                Duration.fromDays,
                Duration.fromWeeks,
            } :: { (number) -> Duration }
        do
            Helpers.throwsWith(asserts, function()
                fn(0 / 0)
            end, "[Duration.new()]: Cannot create a Duration from NaN values")
        end
    end)
end)

test.suite("fromParts()", function(suite)
    suite:case("fromParts({}) is zero", function(asserts)
        Helpers.eqByStr(asserts, Duration.ZERO, Duration.fromParts({}))
    end)

    suite:case("fromParts() sums every part", function(asserts)
        assertParts(
            asserts,
            Duration.fromParts({
                days = 1,
                hours = 2,
                minutes = 3,
                seconds = 4,
                millis = 5,
                micros = 6,
                nanos = 7,
            }),
            93_784,
            5_006_007
        )
    end)

    suite:case("fromParts() carries parts past their ranges", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.fromParts({ hours = 2, minutes = 30 }),
            Duration.fromParts({ hours = 1, minutes = 90 })
        )
        Helpers.eqByStr(
            asserts,
            Duration.SECOND,
            Duration.fromParts({ millis = 1_000 })
        )
    end)

    suite:case("fromParts() negates with negative = true", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.fromMinutes(-5),
            Duration.fromParts({ negative = true, minutes = 5 })
        )
        Helpers.eqByStr(
            asserts,
            millis(-1_500),
            Duration.fromParts({ negative = true, seconds = 1, millis = 500 })
        )
    end)

    suite:case(
        "fromParts() doubly-negates negative parts with negative = true",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                Duration.fromMinutes(5),
                Duration.fromParts({ negative = true, minutes = -5 })
            )
        end
    )

    suite:case("fromParts() accepts mixed signs", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.fromMinutes(59),
            Duration.fromParts({ hours = 1, minutes = -1 })
        )
    end)

    suite:case("fromParts() round-trips with toParts()", function(asserts)
        for _, d in
            {
                Duration.ZERO,
                millis(-90_061_500),
                nanos(123_456_789),
                INF,
                NEG_INF,
            } :: { Duration }
        do
            Helpers.eqByStr(asserts, d, Duration.fromParts(d:toParts()))
        end
    end)

    suite:case("fromParts() with NaN parts throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Duration.fromParts({ seconds = 0 / 0 })
        end, "[Duration.new()]: Cannot create a Duration from NaN values")
    end)

    suite:case(
        "fromParts() with opposite infinite parts throws",
        function(asserts)
            Helpers.throwsWith(asserts, function()
                Duration.fromParts({ days = math.huge, hours = -math.huge })
            end, "[Duration.new()]: Cannot create a Duration from NaN values")
        end
    )
end)

test.suite("to*()", function(suite)
    suite:case("to*() returns totals in each unit", function(asserts)
        local d = millis(90_000) -- 1.5 minutes
        asserts.eq(90_000_000_000, d:toNanos())
        asserts.eq(90_000_000, d:toMicros())
        asserts.eq(90_000, d:toMillis())
        asserts.eq(90, d:toSeconds())
        asserts.eq(1.5, d:toMinutes())
        asserts.eq(0.025, d:toHours())
        asserts.eq(1.5, Duration.fromHours(36):toDays())
    end)

    suite:case("to*() returns fractional values", function(asserts)
        asserts.eq(1.5, millis(1_500):toSeconds())
        asserts.eq(0.001, Duration.MICROSECOND:toMillis())
    end)

    suite:case("to*() handles negative Durations", function(asserts)
        asserts.eq(-1.5, millis(-1_500):toSeconds())
        asserts.eq(-1_500_000_000, millis(-1_500):toNanos())
        asserts.eq(-1, nanos(-1):toNanos())
    end)

    suite:case(
        "to*() returns infinities for infinite Durations",
        function(asserts)
            asserts.eq(math.huge, INF:toNanos())
            asserts.eq(math.huge, INF:toSeconds())
            asserts.eq(-math.huge, NEG_INF:toDays())
        end
    )
end)

test.suite("whole*()", function(suite)
    suite:case("whole*() truncates positive totals", function(asserts)
        local d = Duration.new(5_400, 1_999) -- 1.5 hours + 1.999 micros
        asserts.eq(5_400_000_001_999, d:wholeNanos())
        asserts.eq(5_400_000_001, d:wholeMicros())
        asserts.eq(5_400_000, d:wholeMillis())
        asserts.eq(5_400, d:wholeSeconds())
        asserts.eq(90, d:wholeMinutes())
        asserts.eq(1, d:wholeHours())
        asserts.eq(0, d:wholeDays())
    end)

    suite:case(
        "whole*() truncates negative totals toward zero",
        function(asserts)
            asserts.eq(-1, millis(-1_500):wholeSeconds())
            asserts.eq(-1, Duration.fromMinutes(-90):wholeHours())
            asserts.eq(0, millis(-999):wholeSeconds())
        end
    )

    suite:case("whole*() never returns negative zero", function(asserts)
        -- -0 == 0, so compare the strings
        asserts.eq("0", tostring(millis(-999):wholeSeconds()))
        asserts.eq("0", tostring(nanos(-1):wholeMicros()))
        asserts.eq("0", tostring(secs(-59):wholeMinutes()))
        asserts.eq("0", tostring(Duration.fromHours(-23):wholeDays()))
    end)

    suite:case(
        "whole*() returns infinities for infinite Durations",
        function(asserts)
            asserts.eq(math.huge, INF:wholeSeconds())
            asserts.eq(-math.huge, NEG_INF:wholeDays())
        end
    )
end)

test.suite("*Part()", function(suite)
    -- 1d 2h 3m 4s 5ms 6us 7ns
    local d = Duration.fromParts({
        days = 1,
        hours = 2,
        minutes = 3,
        seconds = 4,
        millis = 5,
        micros = 6,
        nanos = 7,
    })

    suite:case("*Part() returns each component", function(asserts)
        asserts.eq(1, d:daysPart())
        asserts.eq(2, d:hoursPart())
        asserts.eq(3, d:minutesPart())
        asserts.eq(4, d:secondsPart())
        asserts.eq(5, d:millisPart())
        asserts.eq(6, d:microsPart())
        asserts.eq(7, d:nanosPart())
    end)

    suite:case(
        "*Part() returns components with the sign of the Duration",
        function(asserts)
            local n = -d
            asserts.eq(-1, n:daysPart())
            asserts.eq(-2, n:hoursPart())
            asserts.eq(-3, n:minutesPart())
            asserts.eq(-4, n:secondsPart())
            asserts.eq(-5, n:millisPart())
            asserts.eq(-6, n:microsPart())
            asserts.eq(-7, n:nanosPart())
        end
    )

    suite:case("*Part() wraps components into their ranges", function(asserts)
        asserts.eq(-1, secs(-90):minutesPart())
        asserts.eq(-30, secs(-90):secondsPart())
        asserts.eq(12, Duration.fromHours(36):hoursPart())
        asserts.eq(1, Duration.fromHours(36):daysPart())
        asserts.eq(500, millis(1_500):millisPart())
    end)

    suite:case("*Part() is exact past 2^53 seconds", function(asserts)
        -- 2^60 + 3328 = 13_343_998_895_912d 14h 51m 44s
        local big = Duration.new(2 ^ 60 + 3328, 123_456_789)
        asserts.eq(14, big:hoursPart())
        asserts.eq(51, big:minutesPart())
        asserts.eq(44, big:secondsPart())
        asserts.eq(123, big:millisPart())
        asserts.eq(456, big:microsPart())
        asserts.eq(789, big:nanosPart())

        local neg = Duration.new(-(2 ^ 60 + 3328), 0)
        asserts.eq(-14, neg:hoursPart())
        asserts.eq(-51, neg:minutesPart())
        asserts.eq(-44, neg:secondsPart())
    end)

    suite:case("*Part() of zero is zero, not negative zero", function(asserts)
        local negSecond = -Duration.SECOND
        -- -1s has zero sub-second parts, which should not be -0
        asserts.eq("0", tostring(negSecond:millisPart()))
        asserts.eq("0", tostring(negSecond:nanosPart()))
    end)

    suite:case("*Part() of infinite Durations", function(asserts)
        asserts.eq(math.huge, INF:daysPart())
        asserts.eq(-math.huge, NEG_INF:daysPart())
        asserts.eq(0, INF:hoursPart())
        asserts.eq(0, NEG_INF:minutesPart())
        asserts.eq(0, INF:secondsPart())
        asserts.eq(0, INF:millisPart())
        asserts.eq(0, INF:microsPart())
        asserts.eq(0, INF:nanosPart())
    end)
end)

test.suite("toParts()", function(suite)
    suite:case("toParts() returns every part", function(asserts)
        local parts = Duration.fromParts({
            days = 3,
            hours = 4,
            minutes = 5,
            seconds = 6,
            millis = 7,
            micros = 8,
            nanos = 9,
        }):toParts()
        asserts.eq(false, parts.negative)
        asserts.eq(3, parts.days)
        asserts.eq(4, parts.hours)
        asserts.eq(5, parts.minutes)
        asserts.eq(6, parts.seconds)
        asserts.eq(7, parts.millis)
        asserts.eq(8, parts.micros)
        asserts.eq(9, parts.nanos)
    end)

    suite:case(
        "toParts() stores the sign in negative with non-negative parts",
        function(asserts)
            local parts = millis(-90_061_500):toParts()
            asserts.eq(true, parts.negative)
            asserts.eq(1, parts.days)
            asserts.eq(1, parts.hours)
            asserts.eq(1, parts.minutes)
            asserts.eq(1, parts.seconds)
            asserts.eq(500, parts.millis)
            asserts.eq(0, parts.micros)
            asserts.eq(0, parts.nanos)
        end
    )

    suite:case("toParts() of infinite Durations", function(asserts)
        local parts = NEG_INF:toParts()
        asserts.eq(true, parts.negative)
        asserts.eq(math.huge, parts.days)
        asserts.eq(0, parts.hours)
        asserts.eq(0, parts.nanos)
        asserts.eq(false, INF:toParts().negative)
    end)
end)

test.suite("toSecondsAndNanos()", function(suite)
    suite:case("toSecondsAndNanos() returns the internals", function(asserts)
        assertParts(asserts, millis(1_500), 1, 500_000_000)
    end)

    suite:case(
        "toSecondsAndNanos() keeps nanoseconds non-negative",
        function(asserts)
            assertParts(asserts, millis(-1_500), -2, 500_000_000)
        end
    )

    suite:case("toSecondsAndNanos() round-trips with new()", function(asserts)
        for _, d in { millis(-1_500), nanos(1), INF, NEG_INF } :: { Duration } do
            Helpers.eqByStr(asserts, d, Duration.new(d:toSecondsAndNanos()))
        end
    end)
end)

test.suite("since()", function(suite)
    suite:case("since() measures from start to now", function(asserts)
        Helpers.eqByStr(asserts, millis(2_500), Duration.since(10, 12.5))
    end)

    suite:case("since() is negative if start is after now", function(asserts)
        Helpers.eqByStr(asserts, secs(-2), Duration.since(5, 3))
    end)

    suite:case("since() defaults now to os.clock()", function(asserts)
        local elapsed = Duration.since(os.clock())
        asserts.eq(false, elapsed:isNegative())
        asserts.eq(true, elapsed:compareTo(Duration.SECOND) < 0)
    end)
end)

test.suite("between()", function(suite)
    suite:case("between() measures from start to stop", function(asserts)
        Helpers.eqByStr(asserts, millis(2_500), Duration.between(10, 12.5))
    end)

    suite:case("between() is negative if start is after stop", function(asserts)
        Helpers.eqByStr(asserts, secs(-2), Duration.between(5, 3))
    end)
end)

test.suite("sign predicates", function(suite)
    suite:case("isZero() is only true for zero", function(asserts)
        asserts.eq(true, Duration.ZERO:isZero())
        asserts.eq(true, Duration.new(0, 0):isZero())
        asserts.eq(false, Duration.NANOSECOND:isZero())
        asserts.eq(false, nanos(-1):isZero())
        asserts.eq(false, INF:isZero())
    end)

    suite:case("isPositive() excludes zero", function(asserts)
        asserts.eq(true, Duration.NANOSECOND:isPositive())
        asserts.eq(true, INF:isPositive())
        asserts.eq(false, Duration.ZERO:isPositive())
        asserts.eq(false, nanos(-1):isPositive())
        asserts.eq(false, NEG_INF:isPositive())
    end)

    suite:case("isNegative() excludes zero", function(asserts)
        asserts.eq(true, nanos(-1):isNegative())
        asserts.eq(true, NEG_INF:isNegative())
        asserts.eq(false, Duration.ZERO:isNegative())
        asserts.eq(false, Duration.NANOSECOND:isNegative())
        asserts.eq(false, INF:isNegative())
    end)

    suite:case(
        "negated zero is neither positive nor negative",
        function(asserts)
            local z = Duration.ZERO:negated()
            asserts.eq(true, z:isZero())
            asserts.eq(false, z:isPositive())
            asserts.eq(false, z:isNegative())
        end
    )

    suite:case("isInf() and isFinite() are opposites", function(asserts)
        for _, d in { Duration.ZERO, secs(-5), INF, NEG_INF } :: { Duration } do
            asserts.eq(not d:isInf(), d:isFinite())
        end
        asserts.eq(true, INF:isInf())
        asserts.eq(true, NEG_INF:isInf())
        asserts.eq(true, secs(1e15):isFinite())
    end)
end)

test.suite("plus()", function(suite)
    suite:case("plus() adds Durations", function(asserts)
        Helpers.eqByStr(asserts, secs(3), secs(1):plus(secs(2)))
        Helpers.eqByStr(asserts, secs(-1), secs(1):plus(secs(-2)))
    end)

    suite:case("plus() carries nanoseconds", function(asserts)
        assertParts(asserts, millis(700):plus(millis(800)), 1, 500_000_000)
        assertParts(
            asserts,
            Duration.new(0, 999_999_999):plus(Duration.NANOSECOND),
            1,
            0
        )
    end)

    suite:case("plus() is exact at large magnitudes", function(asserts)
        local big = Duration.new(2 ^ 52, 1)
        assertParts(asserts, big:plus(Duration.NANOSECOND), 2 ^ 52, 2)
    end)

    suite:case("plus() is used by +", function(asserts)
        Helpers.eqByStr(asserts, secs(3), secs(1) + secs(2))
    end)

    suite:case("plus() with infinities", function(asserts)
        Helpers.eqByStr(asserts, INF, INF + secs(5))
        Helpers.eqByStr(asserts, NEG_INF, secs(5) + NEG_INF)
        Helpers.eqByStr(asserts, INF, INF + INF)
        Helpers.eqByStr(asserts, NEG_INF, NEG_INF + NEG_INF)
    end)

    suite:case(
        "plus() with infinities of different signs throws",
        function(asserts)
            Helpers.throwsWith(
                asserts,
                function()
                    local _ = INF + NEG_INF
                end,
                "[Duration.plus()]: Adding infinities with different signs is undefined"
            )
        end
    )

    suite:case("plus() with a non-Duration throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                local _ = Duration.SECOND + (5 :: any)
            end,
            "[Duration.plus()]: Attempted to perform addition on a non-Duration value: 5"
        )
        Helpers.throwsWith(
            asserts,
            function()
                local _ = (5 :: any) + Duration.SECOND
            end,
            "[Duration.plus()]: Attempted to perform addition on a non-Duration value: 5"
        )
    end)
end)

test.suite("minus()", function(suite)
    suite:case("minus() subtracts Durations", function(asserts)
        Helpers.eqByStr(asserts, secs(-1), secs(1):minus(secs(2)))
        Helpers.eqByStr(asserts, secs(3), secs(1):minus(secs(-2)))
    end)

    suite:case("minus() borrows nanoseconds", function(asserts)
        assertParts(asserts, secs(1):minus(Duration.NANOSECOND), 0, 999_999_999)
        assertParts(asserts, Duration.ZERO:minus(millis(1)), -1, 999_000_000)
    end)

    suite:case("minus() is used by binary -", function(asserts)
        Helpers.eqByStr(asserts, secs(-1), secs(1) - secs(2))
    end)

    suite:case("minus() with infinities", function(asserts)
        Helpers.eqByStr(asserts, INF, INF - secs(5))
        Helpers.eqByStr(asserts, NEG_INF, secs(5) - INF)
        Helpers.eqByStr(asserts, INF, INF - NEG_INF)
        Helpers.eqByStr(asserts, NEG_INF, NEG_INF - INF)
    end)

    suite:case(
        "minus() with infinities of the same sign throws",
        function(asserts)
            Helpers.throwsWith(
                asserts,
                function()
                    local _ = INF - INF
                end,
                "[Duration.minus()]: Subtracting infinities with the same sign is undefined"
            )
            Helpers.throwsWith(
                asserts,
                function()
                    local _ = NEG_INF - NEG_INF
                end,
                "[Duration.minus()]: Subtracting infinities with the same sign is undefined"
            )
        end
    )

    suite:case("minus() with a non-Duration throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                local _ = Duration.SECOND - ("a" :: any)
            end,
            "[Duration.minus()]: Attempted to perform subtraction on a non-Duration value: a"
        )
    end)
end)

test.suite("times()", function(suite)
    suite:case("times() multiplies by integers", function(asserts)
        Helpers.eqByStr(asserts, secs(3), Duration.SECOND:times(3))
        Helpers.eqByStr(asserts, secs(-3), Duration.SECOND:times(-3))
        Helpers.eqByStr(asserts, Duration.ZERO, Duration.SECOND:times(0))
        assertParts(asserts, millis(-1_500):times(2), -3, 0)
    end)

    suite:case("times() is exact for large integer scalars", function(asserts)
        assertParts(
            asserts,
            Duration.new(0, 123_456_789):times(1e9),
            123_456_789,
            0
        )
        assertParts(
            asserts,
            Duration.new(0, 999_999_999):times(1e15),
            999_999_999_000_000,
            0
        )
        assertParts(
            asserts,
            Duration.new(1, 1):times(2 ^ 40),
            2 ^ 40 + 1_099,
            511_627_776
        )
    end)

    suite:case(
        "times() rounds fractional products to the nearest nanosecond",
        function(asserts)
            Helpers.eqByStr(asserts, millis(1_500), Duration.SECOND:times(1.5))
            Helpers.eqByStr(asserts, nanos(1), Duration.NANOSECOND:times(0.5))
            Helpers.eqByStr(
                asserts,
                Duration.ZERO,
                Duration.NANOSECOND:times(0.4)
            )
        end
    )

    suite:case("times() is used by * in either order", function(asserts)
        Helpers.eqByStr(asserts, secs(3), Duration.SECOND * 3)
        Helpers.eqByStr(asserts, secs(3), 3 * Duration.SECOND)
    end)

    suite:case("times() with infinities", function(asserts)
        Helpers.eqByStr(asserts, INF, INF:times(2))
        Helpers.eqByStr(asserts, NEG_INF, INF:times(-0.5))
        Helpers.eqByStr(asserts, INF, NEG_INF:times(-2))
        Helpers.eqByStr(asserts, INF, Duration.SECOND:times(math.huge))
        Helpers.eqByStr(asserts, NEG_INF, Duration.SECOND:times(-math.huge))
        Helpers.eqByStr(asserts, INF, secs(-1):times(-math.huge))
    end)

    suite:case("times() of infinity and zero throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            INF:times(0)
        end, "[Duration.times()]: Infinity multiplied by 0 is undefined")
        Helpers.throwsWith(asserts, function()
            Duration.ZERO:times(math.huge)
        end, "[Duration.times()]: Infinity multiplied by 0 is undefined")
    end)

    suite:case("times() with NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Duration.SECOND:times(0 / 0)
        end, "[Duration.times()]: Multiplication by NaN is undefined")
    end)

    suite:case("times() with invalid operands throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Duration.SECOND:times("2" :: any)
            end,
            "[Duration.times()]: Attempted to multiply a Duration by a non-number"
        )
        Helpers.throwsWith(
            asserts,
            function()
                local _ = Duration.SECOND * (Duration.SECOND :: any)
            end,
            "[Duration.times()]: Attempted to multiply a Duration by a non-number"
        )
        Helpers.throwsWith(
            asserts,
            function()
                Duration.times(5 :: any, 2)
            end,
            "[Duration.times()]: Attempted to perform multiplication on a non-Duration value: 5"
        )
    end)
end)

test.suite("dividedBy()", function(suite)
    suite:case("dividedBy() divides by integers", function(asserts)
        Helpers.eqByStr(asserts, millis(500), Duration.SECOND:dividedBy(2))
        Helpers.eqByStr(asserts, millis(-500), Duration.SECOND:dividedBy(-2))
        Helpers.eqByStr(asserts, millis(500), secs(-1):dividedBy(-2))
        assertParts(asserts, Duration.SECOND:dividedBy(3), 0, 333_333_333)
    end)

    suite:case(
        "dividedBy() rounds to the nearest nanosecond, halves away from zero",
        function(asserts)
            Helpers.eqByStr(asserts, nanos(1), nanos(2):dividedBy(3))
            Helpers.eqByStr(asserts, nanos(1), nanos(1):dividedBy(2))
            Helpers.eqByStr(asserts, nanos(3), nanos(5):dividedBy(2))
            Helpers.eqByStr(asserts, nanos(-3), nanos(-5):dividedBy(2))
            Helpers.eqByStr(asserts, nanos(-3), nanos(5):dividedBy(-2))
            Helpers.eqByStr(asserts, Duration.ZERO, nanos(1):dividedBy(3))
        end
    )

    suite:case("dividedBy() is exact at large magnitudes", function(asserts)
        assertParts(asserts, Duration.new(2 ^ 52, 0):dividedBy(2), 2 ^ 51, 0)
        assertParts(asserts, Duration.new(1e15, 1):dividedBy(1_000), 1e12, 0)
        assertParts(asserts, Duration.new(1e15, 2):dividedBy(4), 2.5e14, 1)
    end)

    suite:case("dividedBy() divides by fractional scalars", function(asserts)
        Helpers.eqByStr(asserts, secs(2), Duration.SECOND:dividedBy(0.5))
        Helpers.eqByStr(asserts, secs(-4), secs(1):dividedBy(-0.25))
    end)

    suite:case("dividedBy() is used by /", function(asserts)
        Helpers.eqByStr(asserts, millis(500), Duration.SECOND / 2)
    end)

    suite:case("dividedBy() with infinities", function(asserts)
        Helpers.eqByStr(asserts, INF, INF / 2)
        Helpers.eqByStr(asserts, NEG_INF, INF / -2)
        Helpers.eqByStr(asserts, INF, NEG_INF / -2)
        Helpers.eqByStr(asserts, Duration.ZERO, Duration.SECOND / math.huge)
        Helpers.eqByStr(asserts, Duration.ZERO, secs(-1) / -math.huge)
    end)

    suite:case("dividedBy() by zero throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            local _ = Duration.SECOND / 0
        end, "[Duration.dividedBy()]: Attempted to divide by 0")
    end)

    suite:case("dividedBy() with NaN throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            local _ = Duration.SECOND / (0 / 0)
        end, "[Duration.dividedBy()]: Division by NaN is undefined")
    end)

    suite:case("dividedBy() of two infinities throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            local _ = INF / math.huge
        end, "[Duration.dividedBy()]: Dividing two infinities is undefined")
    end)

    suite:case("dividedBy() with invalid operands throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                local _ = Duration.SECOND / (Duration.SECOND :: any)
            end,
            "[Duration.dividedBy()]: Attempted to divide a Duration by a non-number"
        )
        Helpers.throwsWith(
            asserts,
            function()
                local _ = (5 :: any) / Duration.SECOND
            end,
            "[Duration.dividedBy()]: Attempted to perform division on a non-Duration value: 5"
        )
    end)
end)

-- (a, b) pairs covering every sign combination and sub-second values
local DIVISION_PAIRS: { { Duration } } = {
    { secs(7), secs(2) },
    { secs(-7), secs(2) },
    { secs(7), secs(-2) },
    { secs(-7), secs(-2) },
    { secs(6), secs(2) },
    { secs(-6), secs(2) },
    { millis(2_500), Duration.SECOND },
    { millis(-2_500), Duration.SECOND },
    { secs(1), millis(300) },
    { nanos(-1), Duration.SECOND },
    { Duration.ZERO, secs(3) },
    { Duration.new(1e6, 123), nanos(7) },
}

test.suite("floorDividedBy()", function(suite)
    suite:case(
        "floorDividedBy() floors toward negative infinity",
        function(asserts)
            asserts.eq(3, secs(7):floorDividedBy(secs(2)))
            asserts.eq(-4, secs(-7):floorDividedBy(secs(2)))
            asserts.eq(-4, secs(7):floorDividedBy(secs(-2)))
            asserts.eq(3, secs(-7):floorDividedBy(secs(-2)))
            asserts.eq(-3, secs(-6):floorDividedBy(secs(2)))
        end
    )

    suite:case("floorDividedBy() handles sub-second values", function(asserts)
        asserts.eq(2, millis(2_500):floorDividedBy(Duration.SECOND))
        asserts.eq(3, secs(1):floorDividedBy(millis(300)))
        asserts.eq(-1, nanos(-1):floorDividedBy(Duration.SECOND))
    end)

    suite:case("floorDividedBy() is exact at large quotients", function(asserts)
        asserts.eq(
            1_000_000_000_000_000,
            secs(1_000_000):floorDividedBy(Duration.NANOSECOND)
        )
        asserts.eq(
            999_999_999_999_999,
            Duration.new(999_999, 999_999_999)
                :floorDividedBy(Duration.NANOSECOND)
        )
    end)

    suite:case("floorDividedBy() returns 0 instead of -0", function(asserts)
        asserts.eq("0", tostring(Duration.ZERO:floorDividedBy(secs(-3))))
    end)

    suite:case("floorDividedBy() is used by //", function(asserts)
        asserts.eq(-4, secs(-7) // secs(2))
    end)

    suite:case("floorDividedBy() by zero throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            local _ = secs(1) // Duration.ZERO
        end, "[Duration.floorDividedBy()]: Attempted to divide by 0")
    end)

    suite:case("floorDividedBy() with an infinity throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                local _ = INF // secs(1)
            end,
            "[Duration.floorDividedBy()]: Floor division with an infinity is undefined"
        )
        Helpers.throwsWith(
            asserts,
            function()
                local _ = secs(1) // NEG_INF
            end,
            "[Duration.floorDividedBy()]: Floor division with an infinity is undefined"
        )
    end)

    suite:case(
        "floorDividedBy() with too large a quotient throws",
        function(asserts)
            Helpers.throwsWith(
                asserts,
                function()
                    local _ = secs(2 ^ 60) // Duration.NANOSECOND
                end,
                "[Duration.floorDividedBy()]: Quotient is too large to be represented exactly"
            )
        end
    )

    suite:case("floorDividedBy() with a non-Duration throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                local _ = secs(1) // (2 :: any)
            end,
            "[Duration.floorDividedBy()]: Attempted to perform floor division on a non-Duration value: 2"
        )
    end)
end)

test.suite("mod()", function(suite)
    suite:case("mod() has the sign of other", function(asserts)
        Helpers.eqByStr(asserts, secs(1), secs(7):mod(secs(2)))
        Helpers.eqByStr(asserts, secs(1), secs(-7):mod(secs(2)))
        Helpers.eqByStr(asserts, secs(-1), secs(7):mod(secs(-2)))
        Helpers.eqByStr(asserts, secs(-1), secs(-7):mod(secs(-2)))
        Helpers.eqByStr(asserts, Duration.ZERO, secs(-6):mod(secs(2)))
    end)

    suite:case("mod() handles sub-second values", function(asserts)
        Helpers.eqByStr(
            asserts,
            millis(500),
            millis(2_500):mod(Duration.SECOND)
        )
        Helpers.eqByStr(asserts, millis(100), secs(1):mod(millis(300)))
        Helpers.eqByStr(
            asserts,
            Duration.new(0, 999_999_999),
            nanos(-1):mod(Duration.SECOND)
        )
    end)

    suite:case("mod() pairs with floorDividedBy()", function(asserts)
        for _, pair in DIVISION_PAIRS do
            local a, b = pair[1], pair[2]
            local q, r = a // b, a % b
            Helpers.eqByStr(asserts, a, b * q + r)
            -- r has the sign of b (or is zero), and |r| < |b|
            asserts.eq(false, r:isPositive() and b:isNegative())
            asserts.eq(false, r:isNegative() and b:isPositive())
            asserts.eq(true, r:abs() < b:abs())
        end
    end)

    suite:case("mod() is used by %", function(asserts)
        Helpers.eqByStr(asserts, secs(1), secs(-7) % secs(2))
    end)

    suite:case("mod() by zero throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            local _ = secs(1) % Duration.ZERO
        end, "[Duration.mod()]: Attempted to divide by 0")
    end)

    suite:case("mod() with an infinity throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            local _ = secs(1) % INF
        end, "[Duration.mod()]: Modulus with an infinity is undefined")
    end)

    suite:case("mod() with too large a quotient throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                local _ = secs(2 ^ 60) % Duration.NANOSECOND
            end,
            "[Duration.mod()]: Quotient is too large to be represented exactly"
        )
    end)

    suite:case("mod() with a non-Duration throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                local _ = secs(1) % (2 :: any)
            end,
            "[Duration.mod()]: Attempted to perform modulus on a non-Duration value: 2"
        )
    end)
end)

test.suite("truncatedDividedBy()", function(suite)
    suite:case("truncatedDividedBy() truncates toward zero", function(asserts)
        asserts.eq(3, secs(7):truncatedDividedBy(secs(2)))
        asserts.eq(-3, secs(-7):truncatedDividedBy(secs(2)))
        asserts.eq(-3, secs(7):truncatedDividedBy(secs(-2)))
        asserts.eq(3, secs(-7):truncatedDividedBy(secs(-2)))
        asserts.eq(-3, secs(-6):truncatedDividedBy(secs(2)))
        asserts.eq(0, nanos(-1):truncatedDividedBy(Duration.SECOND))
    end)

    suite:case("truncatedDividedBy() by zero throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            secs(1):truncatedDividedBy(Duration.ZERO)
        end, "[Duration.truncatedDividedBy()]: Attempted to divide by 0")
    end)

    suite:case("truncatedDividedBy() with an infinity throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                NEG_INF:truncatedDividedBy(secs(1))
            end,
            "[Duration.truncatedDividedBy()]: Truncated division with an infinity is undefined"
        )
    end)

    suite:case(
        "truncatedDividedBy() with too large a quotient throws",
        function(asserts)
            Helpers.throwsWith(
                asserts,
                function()
                    secs(2 ^ 60):truncatedDividedBy(Duration.NANOSECOND)
                end,
                "[Duration.truncatedDividedBy()]: Quotient is too large to be represented exactly"
            )
        end
    )
end)

test.suite("remainder()", function(suite)
    suite:case("remainder() has the sign of self", function(asserts)
        Helpers.eqByStr(asserts, secs(1), secs(7):remainder(secs(2)))
        Helpers.eqByStr(asserts, secs(-1), secs(-7):remainder(secs(2)))
        Helpers.eqByStr(asserts, secs(1), secs(7):remainder(secs(-2)))
        Helpers.eqByStr(asserts, secs(-1), secs(-7):remainder(secs(-2)))
        Helpers.eqByStr(asserts, Duration.ZERO, secs(-6):remainder(secs(2)))
        Helpers.eqByStr(
            asserts,
            nanos(-1),
            nanos(-1):remainder(Duration.SECOND)
        )
    end)

    suite:case("remainder() pairs with truncatedDividedBy()", function(asserts)
        for _, pair in DIVISION_PAIRS do
            local a, b = pair[1], pair[2]
            local q, r = a:truncatedDividedBy(b), a:remainder(b)
            Helpers.eqByStr(asserts, a, b * q + r)
            -- r has the sign of a (or is zero), and |r| < |b|
            asserts.eq(false, r:isPositive() and a:isNegative())
            asserts.eq(false, r:isNegative() and a:isPositive())
            asserts.eq(true, r:abs() < b:abs())
        end
    end)

    suite:case("remainder() by zero throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            secs(1):remainder(Duration.ZERO)
        end, "[Duration.remainder()]: Attempted to divide by 0")
    end)

    suite:case("remainder() with an infinity throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            secs(1):remainder(INF)
        end, "[Duration.remainder()]: Remainder with an infinity is undefined")
    end)
end)

test.suite("ratio()", function(suite)
    suite:case("ratio() divides two Durations", function(asserts)
        asserts.eq(60, Duration.MINUTE:ratio(Duration.SECOND))
        asserts.eq(0.5, millis(500):ratio(Duration.SECOND))
        asserts.eq(-2, secs(-2):ratio(Duration.SECOND))
        asserts.eq(0, Duration.ZERO:ratio(Duration.SECOND))
    end)

    suite:case("ratio() with one infinity", function(asserts)
        asserts.eq(math.huge, INF:ratio(Duration.SECOND))
        asserts.eq(-math.huge, INF:ratio(secs(-1)))
        asserts.eq(math.huge, NEG_INF:ratio(secs(-1)))
        asserts.eq(0, Duration.SECOND:ratio(INF))
    end)

    suite:case("ratio() never returns negative zero", function(asserts)
        -- -0 == 0, so compare the strings
        asserts.eq("0", tostring(Duration.ZERO:ratio(secs(-1))))
        asserts.eq("0", tostring(Duration.SECOND:ratio(NEG_INF)))
        asserts.eq("0", tostring(secs(-1):ratio(INF)))
    end)

    suite:case("ratio() with a zero Duration throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Duration.SECOND:ratio(Duration.ZERO)
            end,
            "[Duration.ratio()]: Attempted to calculate a ratio with a zero Duration"
        )
    end)

    suite:case("ratio() of two infinities throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            INF:ratio(NEG_INF)
        end, "[Duration.ratio()]: Dividing two infinities is undefined")
    end)
end)

test.suite("saturatingMinus()", function(suite)
    suite:case(
        "saturatingMinus() subtracts when the result is positive",
        function(asserts)
            Helpers.eqByStr(
                asserts,
                secs(59),
                Duration.MINUTE:saturatingMinus(Duration.SECOND)
            )
        end
    )

    suite:case("saturatingMinus() clamps at zero", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.ZERO,
            Duration.SECOND:saturatingMinus(Duration.MINUTE)
        )
        Helpers.eqByStr(
            asserts,
            Duration.ZERO,
            Duration.SECOND:saturatingMinus(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            Duration.ZERO,
            secs(-5):saturatingMinus(secs(-1))
        )
    end)

    suite:case(
        "saturatingMinus() never throws for infinities",
        function(asserts)
            Helpers.eqByStr(asserts, Duration.ZERO, INF:saturatingMinus(INF))
            Helpers.eqByStr(
                asserts,
                Duration.ZERO,
                NEG_INF:saturatingMinus(NEG_INF)
            )
            Helpers.eqByStr(asserts, INF, INF:saturatingMinus(NEG_INF))
            Helpers.eqByStr(
                asserts,
                Duration.ZERO,
                NEG_INF:saturatingMinus(INF)
            )
        end
    )
end)

test.suite("negated()", function(suite)
    suite:case("negated() flips the sign", function(asserts)
        Helpers.eqByStr(asserts, secs(-1), Duration.SECOND:negated())
        Helpers.eqByStr(asserts, millis(1_500), millis(-1_500):negated())
        Helpers.eqByStr(asserts, NEG_INF, INF:negated())
        Helpers.eqByStr(asserts, INF, NEG_INF:negated())
    end)

    suite:case("negated() of zero is zero", function(asserts)
        Helpers.eqByStr(asserts, Duration.ZERO, Duration.ZERO:negated())
    end)

    suite:case("negated() twice is the original", function(asserts)
        local d = Duration.new(-3, 123)
        Helpers.eqByStr(asserts, d, d:negated():negated())
    end)

    suite:case("negated() is used by unary -", function(asserts)
        Helpers.eqByStr(asserts, secs(-1), -Duration.SECOND)
    end)
end)

test.suite("abs()", function(suite)
    suite:case("abs() returns the magnitude", function(asserts)
        Helpers.eqByStr(asserts, millis(1_500), millis(-1_500):abs())
        Helpers.eqByStr(asserts, INF, NEG_INF:abs())
        Helpers.eqByStr(asserts, Duration.ZERO, Duration.ZERO:abs())
    end)

    suite:case("abs() returns self if not negative", function(asserts)
        local d = millis(1_500)
        asserts.eq(true, rawequal(d, d:abs()))
    end)
end)

test.suite("truncatedTo()", function(suite)
    suite:case("truncatedTo() truncates toward zero", function(asserts)
        Helpers.eqByStr(
            asserts,
            secs(1),
            millis(1_500):truncatedTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            secs(-1),
            millis(-1_500):truncatedTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            Duration.fromMinutes(30),
            Duration.fromMinutes(37):truncatedTo(Duration.fromMinutes(15))
        )
    end)

    suite:case("truncatedTo() keeps exact multiples", function(asserts)
        Helpers.eqByStr(
            asserts,
            secs(-3),
            secs(-3):truncatedTo(Duration.SECOND)
        )
    end)

    suite:case("truncatedTo() returns infinities unchanged", function(asserts)
        Helpers.eqByStr(asserts, INF, INF:truncatedTo(Duration.SECOND))
        Helpers.eqByStr(asserts, NEG_INF, NEG_INF:truncatedTo(Duration.SECOND))
    end)

    suite:case("truncatedTo() with an invalid unit throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                secs(1):truncatedTo(Duration.ZERO)
            end,
            "[Duration.truncatedTo()]: Cannot truncate using a non-positive unit"
        )
        Helpers.throwsWith(
            asserts,
            function()
                secs(1):truncatedTo(secs(-1))
            end,
            "[Duration.truncatedTo()]: Cannot truncate using a non-positive unit"
        )
        Helpers.throwsWith(asserts, function()
            secs(1):truncatedTo(INF)
        end, "[Duration.truncatedTo()]: Truncating to infinity is undefined")
    end)
end)

test.suite("flooredTo()", function(suite)
    suite:case("flooredTo() floors toward negative infinity", function(asserts)
        Helpers.eqByStr(
            asserts,
            secs(1),
            millis(1_500):flooredTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            secs(-2),
            millis(-1_500):flooredTo(Duration.SECOND)
        )
    end)

    suite:case("flooredTo() keeps exact multiples", function(asserts)
        Helpers.eqByStr(asserts, secs(-3), secs(-3):flooredTo(Duration.SECOND))
    end)

    suite:case("flooredTo() returns infinities unchanged", function(asserts)
        Helpers.eqByStr(asserts, NEG_INF, NEG_INF:flooredTo(Duration.SECOND))
    end)

    suite:case("flooredTo() with an invalid unit throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            secs(1):flooredTo(Duration.ZERO)
        end, "[Duration.flooredTo()]: Cannot floor using a non-positive unit")
        Helpers.throwsWith(asserts, function()
            secs(1):flooredTo(INF)
        end, "[Duration.flooredTo()]: Flooring to infinity is undefined")
    end)
end)

test.suite("ceiledTo()", function(suite)
    suite:case("ceiledTo() ceils toward positive infinity", function(asserts)
        Helpers.eqByStr(
            asserts,
            secs(2),
            millis(1_500):ceiledTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            secs(-1),
            millis(-1_500):ceiledTo(Duration.SECOND)
        )
        Helpers.eqByStr(asserts, secs(1), nanos(1):ceiledTo(Duration.SECOND))
    end)

    suite:case("ceiledTo() keeps exact multiples", function(asserts)
        Helpers.eqByStr(asserts, secs(3), secs(3):ceiledTo(Duration.SECOND))
        Helpers.eqByStr(
            asserts,
            Duration.ZERO,
            Duration.ZERO:ceiledTo(Duration.SECOND)
        )
    end)

    suite:case("ceiledTo() returns infinities unchanged", function(asserts)
        Helpers.eqByStr(asserts, INF, INF:ceiledTo(Duration.SECOND))
    end)

    suite:case("ceiledTo() with an invalid unit throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            secs(1):ceiledTo(secs(-1))
        end, "[Duration.ceiledTo()]: Cannot ceil using a non-positive unit")
        Helpers.throwsWith(asserts, function()
            secs(1):ceiledTo(INF)
        end, "[Duration.ceiledTo()]: Ceiling to infinity is undefined")
    end)
end)

test.suite("roundedTo()", function(suite)
    suite:case("roundedTo() rounds to the nearest multiple", function(asserts)
        Helpers.eqByStr(
            asserts,
            secs(1),
            millis(1_499):roundedTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            secs(2),
            millis(1_501):roundedTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            secs(-1),
            millis(-1_499):roundedTo(Duration.SECOND)
        )
        local quarterHour = Duration.fromMinutes(15)
        Helpers.eqByStr(
            asserts,
            Duration.fromMinutes(30),
            Duration.fromMinutes(37):roundedTo(quarterHour)
        )
        Helpers.eqByStr(
            asserts,
            Duration.fromMinutes(45),
            Duration.fromMinutes(38):roundedTo(quarterHour)
        )
    end)

    suite:case("roundedTo() rounds halves away from zero", function(asserts)
        Helpers.eqByStr(
            asserts,
            secs(2),
            millis(1_500):roundedTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            secs(-2),
            millis(-1_500):roundedTo(Duration.SECOND)
        )
        Helpers.eqByStr(
            asserts,
            secs(1),
            millis(500):roundedTo(Duration.SECOND)
        )
    end)

    suite:case("roundedTo() returns infinities unchanged", function(asserts)
        Helpers.eqByStr(asserts, NEG_INF, NEG_INF:roundedTo(Duration.SECOND))
    end)

    suite:case("roundedTo() with an invalid unit throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            secs(1):roundedTo(Duration.ZERO)
        end, "[Duration.roundedTo()]: Cannot round using a non-positive unit")
        Helpers.throwsWith(asserts, function()
            secs(1):roundedTo(INF)
        end, "[Duration.roundedTo()]: Rounding to infinity is undefined")
    end)
end)

test.suite("is()", function(suite)
    suite:case("is() returns true for Durations", function(asserts)
        asserts.eq(true, Duration.is(Duration.ZERO))
        asserts.eq(true, Duration.is(INF))
        asserts.eq(true, Duration.is(millis(-5)))
    end)

    suite:case("is() returns false for non-Durations", function(asserts)
        asserts.eq(false, Duration.is(nil))
        asserts.eq(false, Duration.is(1))
        asserts.eq(false, Duration.is("PT1S"))
        asserts.eq(false, Duration.is({}))
    end)

    suite:case(
        "is() returns false for tables with the same fields",
        function(asserts)
            asserts.eq(false, Duration.is({ _secs = 1, _nanos = 0 }))
        end
    )
end)

test.suite("equals()", function(suite)
    suite:case("equals() compares spans of time", function(asserts)
        Helpers.eqByStr(asserts, secs(1), secs(1))
        Helpers.eqByStr(asserts, Duration.new(0, 1e9), Duration.SECOND)
        Helpers.eqByStr(asserts, millis(60_000), Duration.MINUTE)
        Helpers.neqByStr(asserts, secs(1), secs(-1))
        Helpers.neqByStr(asserts, secs(1), Duration.new(1, 1))
    end)

    suite:case("equals() compares infinities by sign", function(asserts)
        Helpers.eqByStr(asserts, INF, Duration.fromDays(math.huge))
        Helpers.neqByStr(asserts, INF, NEG_INF)
        Helpers.neqByStr(asserts, INF, secs(1e300))
    end)

    suite:case("equals() is used by == and ~=", function(asserts)
        asserts.eq(true, secs(1) == secs(1))
        asserts.eq(true, secs(1) ~= secs(2))
        asserts.eq(true, secs(1):equals(secs(1)))
    end)

    suite:case("Duration and non-Duration are not equal", function(asserts)
        asserts.eq(false, Duration.SECOND:equals(1 :: any))
        asserts.eq(
            false,
            Duration.SECOND:equals({ _secs = 1, _nanos = 0 } :: any)
        )
        Helpers.neqByStr(asserts, Duration.SECOND :: any, 1)
    end)
end)

test.suite("compareTo()", function(suite)
    suite:case("compareTo() orders Durations", function(asserts)
        asserts.eq(-1, secs(1):compareTo(secs(2)))
        asserts.eq(1, secs(2):compareTo(secs(1)))
        asserts.eq(0, secs(1):compareTo(secs(1)))
        asserts.eq(-1, secs(-2):compareTo(secs(-1)))
    end)

    suite:case("compareTo() compares nanoseconds", function(asserts)
        asserts.eq(-1, Duration.new(1, 1):compareTo(Duration.new(1, 2)))
        asserts.eq(1, nanos(-1):compareTo(nanos(-2)))
    end)

    suite:case("compareTo() orders infinities at the ends", function(asserts)
        asserts.eq(-1, NEG_INF:compareTo(secs(-1e300)))
        asserts.eq(1, INF:compareTo(secs(1e300)))
        asserts.eq(-1, NEG_INF:compareTo(INF))
        asserts.eq(0, INF:compareTo(INF))
    end)

    suite:case("compareTo() is used by <, <=, >, and >=", function(asserts)
        asserts.eq(true, secs(1) < secs(2))
        asserts.eq(false, secs(2) < secs(2))
        asserts.eq(true, secs(2) <= secs(2))
        asserts.eq(true, secs(3) > secs(2))
        asserts.eq(true, secs(2) >= secs(2))
        asserts.eq(false, secs(1) >= secs(2))
    end)

    suite:case("compareTo() with a non-Duration throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                secs(1):compareTo(1 :: any)
            end,
            "[Duration.compareTo()]: Attempted to perform comparison on a non-Duration value: 1"
        )
    end)
end)

test.suite("min() and max()", function(suite)
    suite:case("min() returns the smaller Duration", function(asserts)
        Helpers.eqByStr(asserts, secs(1), secs(1):min(secs(2)))
        Helpers.eqByStr(asserts, secs(-2), secs(1):min(secs(-2)))
        Helpers.eqByStr(asserts, NEG_INF, NEG_INF:min(secs(-1e300)))
    end)

    suite:case("max() returns the larger Duration", function(asserts)
        Helpers.eqByStr(asserts, secs(2), secs(1):max(secs(2)))
        Helpers.eqByStr(asserts, secs(1), secs(1):max(secs(-2)))
        Helpers.eqByStr(asserts, INF, secs(1e300):max(INF))
    end)

    suite:case("min() and max() return self on ties", function(asserts)
        local a, b = Duration.new(0, 1e9), Duration.SECOND
        asserts.eq(true, rawequal(a, a:min(b)))
        asserts.eq(true, rawequal(a, a:max(b)))
    end)
end)

test.suite("clamp()", function(suite)
    suite:case("clamp() clamps between min and max", function(asserts)
        local lo, hi = Duration.ZERO, Duration.MINUTE
        Helpers.eqByStr(asserts, secs(30), secs(30):clamp(lo, hi))
        Helpers.eqByStr(asserts, hi, secs(90):clamp(lo, hi))
        Helpers.eqByStr(asserts, lo, secs(-5):clamp(lo, hi))
        Helpers.eqByStr(asserts, hi, INF:clamp(lo, hi))
    end)

    suite:case("clamp() is inclusive", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.MINUTE,
            Duration.MINUTE:clamp(Duration.ZERO, Duration.MINUTE)
        )
        Helpers.eqByStr(asserts, secs(5), secs(1):clamp(secs(5), secs(5)))
    end)

    suite:case("clamp() accepts infinite bounds", function(asserts)
        Helpers.eqByStr(asserts, secs(-1e9), secs(-1e9):clamp(NEG_INF, INF))
    end)

    suite:case("clamp() with min greater than max throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                secs(1):clamp(Duration.MINUTE, Duration.SECOND)
            end,
            "[Duration.clamp()]: Clamp value min must be less than or equal to max"
        )
    end)
end)

test.suite("tryParse()", function(suite)
    local function parsed(s: string): Duration
        return Duration.tryParse(s):unwrap()
    end

    local function parseErr(s: string): string
        return Duration.tryParse(s):unwrapErr()
    end

    suite:case("tryParse() parses each component", function(asserts)
        Helpers.eqByStr(asserts, Duration.WEEK * 2, parsed("P2W"))
        Helpers.eqByStr(asserts, Duration.DAY * 3, parsed("P3D"))
        Helpers.eqByStr(asserts, Duration.HOUR * 4, parsed("PT4H"))
        Helpers.eqByStr(asserts, Duration.MINUTE * 5, parsed("PT5M"))
        Helpers.eqByStr(asserts, secs(6), parsed("PT6S"))
    end)

    suite:case("tryParse() parses combined components", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.fromParts({ days = 9, hours = 1, minutes = 2, seconds = 3 }),
            parsed("P1W2DT1H2M3S")
        )
        Helpers.eqByStr(asserts, Duration.fromMinutes(90), parsed("PT1H30M"))
    end)

    suite:case("tryParse() parses fractional seconds", function(asserts)
        Helpers.eqByStr(asserts, millis(1_500), parsed("PT1.5S"))
        Helpers.eqByStr(asserts, millis(1_500), parsed("PT1,5S"))
        Helpers.eqByStr(asserts, nanos(1), parsed("PT0.000000001S"))
    end)

    suite:case(
        "tryParse() truncates digits past nanosecond precision",
        function(asserts)
            assertParts(asserts, parsed("PT1.1234567899S"), 1, 123_456_789)
        end
    )

    suite:case("tryParse() parses signs", function(asserts)
        Helpers.eqByStr(asserts, millis(-250), parsed("-PT0.25S"))
        Helpers.eqByStr(asserts, secs(5), parsed("+PT5S"))
    end)

    suite:case("tryParse() is case-insensitive", function(asserts)
        Helpers.eqByStr(asserts, parsed("P1W2DT3.5S"), parsed("p1w2dt3.5s"))
    end)

    suite:case("tryParse() parses zero", function(asserts)
        Helpers.eqByStr(asserts, Duration.ZERO, parsed("PT0S"))
        Helpers.eqByStr(asserts, Duration.ZERO, parsed("P0D"))
    end)

    suite:case("tryParse() parses infinities", function(asserts)
        Helpers.eqByStr(asserts, INF, parsed("Infinity"))
        Helpers.eqByStr(asserts, INF, parsed("+infinity"))
        Helpers.eqByStr(asserts, NEG_INF, parsed("-INFINITY"))
    end)

    suite:case("tryParse() round-trips with toString()", function(asserts)
        for _, d in
            {
                Duration.ZERO,
                nanos(1),
                millis(-250),
                Duration.WEEK,
                Duration.fromParts({ days = 400, hours = 23, seconds = 59.5 }),
                Duration.new(1e12, 123_456_789),
                INF,
                NEG_INF,
            } :: { Duration }
        do
            Helpers.eqByStr(asserts, d, parsed(d:toString()))
        end
    end)

    suite:case("tryParse() returns err for invalid strings", function(asserts)
        asserts.eq(
            "Invalid ISO-8601 duration: \"1H\" (missing 'P' prefix at position 1)",
            parseErr("1H")
        )
        asserts.strContains(parseErr(""), "missing 'P' prefix")
        asserts.strContains(parseErr("P"), "no components at position 2")
        asserts.strContains(parseErr("PT"), "no components")
        asserts.strContains(
            parseErr("P1DT"),
            "'T' must be followed by a time component"
        )
        asserts.strContains(parseErr("PTT1S"), "repeated 'T' prefix")
        asserts.strContains(parseErr("PT1"), "expected a number and unit")
        asserts.strContains(parseErr("PTS"), "expected a number and unit")
        asserts.strContains(parseErr("P-1D"), "expected a number and unit")
        asserts.strContains(parseErr("PT1S "), "expected a number and unit")
    end)

    suite:case("tryParse() rejects years and months", function(asserts)
        asserts.strContains(
            parseErr("P1Y"),
            "years and months have no fixed length"
        )
        asserts.strContains(
            parseErr("P1M"),
            "years and months have no fixed length"
        )
    end)

    suite:case("tryParse() rejects misplaced units", function(asserts)
        asserts.strContains(parseErr("P1H"), "'H' is not valid before 'T'")
        asserts.strContains(parseErr("PT1D"), "'D' is not valid after 'T'")
        asserts.strContains(parseErr("PT1X"), "'X' is not valid after 'T'")
    end)

    suite:case(
        "tryParse() rejects repeated or out of order units",
        function(asserts)
            asserts.strContains(
                parseErr("PT1M1H"),
                "H is repeated or out of order at position 5"
            )
            asserts.strContains(
                parseErr("P1D1D"),
                "D is repeated or out of order"
            )
            asserts.strContains(
                parseErr("P1D1W"),
                "W is repeated or out of order"
            )
        end
    )

    suite:case("tryParse() rejects fractional non-seconds", function(asserts)
        asserts.strContains(
            parseErr("PT1.5M"),
            "only seconds may be fractional"
        )
        asserts.strContains(parseErr("P1.5D"), "only seconds may be fractional")
        asserts.strContains(
            parseErr("PT1.S"),
            "missing digits after decimal separator"
        )
    end)

    suite:case("tryParse() reports the original input", function(asserts)
        asserts.strContains(parseErr("pt1x"), '"pt1x"')
    end)

    suite:case("tryParse() rejects more than 2^53 seconds", function(asserts)
        -- 104_249_991_375 days is just over 2^53 seconds
        asserts.eq(
            'Invalid ISO-8601 duration: "P104249991375D" '
                .. "(this Duration is too large to parse exactly)",
            parseErr("P104249991375D")
        )
        asserts.strContains(
            parseErr("PT9007199254740994S"),
            "too large to parse exactly"
        )
        -- the limit applies to the total, not each component
        asserts.strContains(
            parseErr("P104249991374DT8H"),
            "too large to parse exactly"
        )
    end)

    suite:case(
        "tryParse() rejects digit strings that overflow to infinity",
        function(asserts)
            local digits = string.rep("9", 400)
            asserts.eq(math.huge, tonumber(digits))
            asserts.strContains(
                parseErr(`P{digits}D`),
                "too large to parse exactly"
            )
            asserts.strContains(
                parseErr(`-PT{digits}S`),
                "too large to parse exactly"
            )
        end
    )

    suite:case("tryParse() accepts values up to 2^53 seconds", function(asserts)
        assertParts(asserts, parsed("P104249991374D"), 9_007_199_254_713_600, 0)
        assertParts(
            asserts,
            parsed("PT9007199254740991.5S"),
            9_007_199_254_740_991,
            500_000_000
        )
        assertParts(
            asserts,
            parsed("-PT9007199254740991S"),
            -9_007_199_254_740_991,
            0
        )
    end)
end)

test.suite("parse()", function(suite)
    suite:case("parse() returns the parsed Duration", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.fromMinutes(90),
            Duration.parse("PT1H30M")
        )
        Helpers.eqByStr(asserts, NEG_INF, Duration.parse("-Infinity"))
    end)

    suite:case("parse() throws for invalid strings", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Duration.parse("P1Y")
            end,
            '[Duration.parse()]: Failed to parse duration: Invalid ISO-8601 duration: "P1Y"'
        )
        Helpers.throwsWith(asserts, function()
            Duration.parse("nope")
        end, "use Duration.tryParse() instead")
    end)

    suite:case("parse() throws for values too large", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Duration.parse("P104249991375D")
            end,
            "[Duration.parse()]: Failed to parse duration: "
                .. 'Invalid ISO-8601 duration: "P104249991375D" '
                .. "(this Duration is too large to parse exactly)"
        )
    end)
end)

test.suite("toString()", function(suite)
    suite:case("toString() formats each component", function(asserts)
        asserts.eq("P1D", Duration.DAY:toString())
        asserts.eq("PT1H", Duration.HOUR:toString())
        asserts.eq("PT1M", Duration.MINUTE:toString())
        asserts.eq("PT1S", Duration.SECOND:toString())
        asserts.eq("P1DT2H3M4.5S", secs(93_784.5):toString())
    end)

    suite:case("toString() uses days instead of weeks", function(asserts)
        asserts.eq("P7D", Duration.WEEK:toString())
        asserts.eq("P400D", Duration.fromDays(400):toString())
    end)

    suite:case("toString() omits zero components", function(asserts)
        asserts.eq(
            "P1DT1S",
            Duration.fromParts({ days = 1, seconds = 1 }):toString()
        )
        asserts.eq(
            "PT1H0.5S",
            Duration.fromParts({ hours = 1, millis = 500 }):toString()
        )
    end)

    suite:case("toString() trims fractional zeros", function(asserts)
        asserts.eq("PT0.5S", millis(500):toString())
        asserts.eq("PT0.000000001S", nanos(1):toString())
        asserts.eq("PT0.12S", millis(120):toString())
    end)

    suite:case("toString() of zero", function(asserts)
        asserts.eq("PT0S", Duration.ZERO:toString())
        asserts.eq("PT0S", Duration.ZERO:negated():toString())
    end)

    suite:case("toString() prefixes negative Durations", function(asserts)
        asserts.eq("-PT0.25S", millis(-250):toString())
        asserts.eq(
            "-P1DT1S",
            Duration.fromParts({ negative = true, days = 1, seconds = 1 })
                :toString()
        )
    end)

    suite:case("toString() of infinities", function(asserts)
        asserts.eq("Infinity", INF:toString())
        asserts.eq("-Infinity", NEG_INF:toString())
    end)

    suite:case(
        "toString() formats large values without exponents",
        function(asserts)
            asserts.eq("P11574074074DT1H46M40S", secs(1e15):toString())
        end
    )

    suite:case("toString() round-trips up to 2^53 seconds", function(asserts)
        for _, d in
            {
                Duration.new(2 ^ 53 - 1, 999_999_999),
                Duration.new(-(2 ^ 53 - 1), 0),
                Duration.fromDays(104_249_991_374),
            } :: { Duration }
        do
            Helpers.eqByStr(asserts, d, Duration.parse(d:toString()))
        end
    end)

    suite:case(
        "toString() of values past 2^53 seconds does not parse",
        function(asserts)
            asserts.eq(true, Duration.tryParse(secs(2 ^ 54):toString()):isErr())
        end
    )

    suite:case(
        "toString() components are exact past 2^53 seconds",
        function(asserts)
            asserts.eq(
                "P13343998895912DT14H51M44S",
                secs(2 ^ 60 + 3328):toString()
            )
            asserts.eq(
                "-P13343998895912DT13H56M16S",
                secs(-(2 ^ 60)):toString()
            )
        end
    )

    suite:case("toString() is used by tostring()", function(asserts)
        asserts.eq("PT1.5S", tostring(millis(1_500)))
    end)
end)

test.suite("format()", function(suite)
    local d = Duration.fromParts({
        days = 2,
        hours = 3,
        minutes = 4,
        seconds = 5,
        millis = 6,
    })

    suite:case("format() replaces each specifier", function(asserts)
        asserts.eq("2 3 4 5 6", d:format("%d %H %M %S %f"))
    end)

    suite:case("format() is exact past 2^53 seconds", function(asserts)
        local big = Duration.new(2 ^ 60 + 3328, 6_000_000)
        asserts.eq("13343998895912 14 51 44 6", big:format("%d %H %M %S %f"))
    end)

    suite:case("format() zero-pads with a width", function(asserts)
        asserts.eq("03:04:05.006", d:format("%02H:%02M:%02S.%03f"))
        asserts.eq("1:02:05", secs(3_725):format("%H:%02M:%02S"))
    end)

    suite:case("format() accepts two-digit widths", function(asserts)
        local out = Duration.SECOND:format("%99S")
        asserts.eq(99, #out)
        asserts.eq("1", string.sub(out, -1))
    end)

    suite:case("format() with a three-digit width throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Duration.SECOND:format("%100S")
        end, "invalid format")
    end)

    suite:case("format() keeps literal text and %%", function(asserts)
        asserts.eq("100% done in 4m", d:format("100%% done in %Mm"))
    end)

    suite:case("format() keeps a trailing %", function(asserts)
        asserts.eq("4 %", d:format("%M %"))
    end)

    suite:case("format() wraps hours into days", function(asserts)
        asserts.eq("2 3", Duration.fromHours(51):format("%d %H"))
        asserts.eq("10", Duration.fromDays(10):format("%d"))
    end)

    suite:case("format() truncates instead of rounding", function(asserts)
        asserts.eq("0.999", Duration.new(0, 999_999_999):format("%S.%03f"))
    end)

    suite:case("format() prefixes negative Durations once", function(asserts)
        asserts.eq("-1:30", secs(-90):format("%M:%02S"))
    end)

    suite:case("format() of infinities ignores the pattern", function(asserts)
        asserts.eq("∞", INF:format("%H:%M"))
        asserts.eq("-∞", NEG_INF:format("%H:%M"))
    end)

    suite:case("format() with an unknown specifier throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            d:format("%x")
        end, "[Duration.format()]: Unknown specifier '%x'")
    end)
end)

test.suite("toHumanString()", function(suite)
    local d = millis(93_784_567) -- 1d 2h 3m 4s 567ms

    suite:case("toHumanString() shows every unit by default", function(asserts)
        asserts.eq("1d 2h 3m 4s 567ms", d:toHumanString())
    end)

    suite:case("toHumanString() omits zero components", function(asserts)
        asserts.eq("1d 5s", secs(86_405):toHumanString())
        asserts.eq("1m 30s", secs(90):toHumanString())
    end)

    suite:case("toHumanString() limits units with maxUnits", function(asserts)
        asserts.eq("1d", d:toHumanString({ maxUnits = 1 }))
        asserts.eq("1d 2h", d:toHumanString({ maxUnits = 2 }))
        asserts.eq(
            "1d 2h 3m 4s 567ms",
            d:toHumanString({ maxUnits = math.huge })
        )
    end)

    suite:case(
        "toHumanString() counts zero units toward maxUnits",
        function(asserts)
            asserts.eq("1d", secs(86_405):toHumanString({ maxUnits = 2 }))
            asserts.eq("1d 5s", secs(86_405):toHumanString({ maxUnits = 4 }))
        end
    )

    suite:case(
        "toHumanString() starts maxUnits at the largest non-zero unit",
        function(asserts)
            asserts.eq(
                "4s 567ms",
                millis(4_567):toHumanString({ maxUnits = 2 })
            )
        end
    )

    suite:case(
        "toHumanString() omits units below smallestUnit",
        function(asserts)
            asserts.eq(
                "1d 2h 3m",
                d:toHumanString({ smallestUnit = "minutes" })
            )
            asserts.eq("1d", d:toHumanString({ smallestUnit = "days" }))
            asserts.eq(
                "1m",
                secs(119):toHumanString({ smallestUnit = "minutes" })
            )
        end
    )

    suite:case("toHumanString() combines options", function(asserts)
        asserts.eq(
            "1d 2h",
            d:toHumanString({ maxUnits = 2, smallestUnit = "seconds" })
        )
    end)

    suite:case(
        "toHumanString() shows zero of the smallest unit if empty",
        function(asserts)
            asserts.eq("0ms", Duration.ZERO:toHumanString())
            asserts.eq("0ms", nanos(999):toHumanString())
            asserts.eq(
                "0s",
                millis(5):toHumanString({ smallestUnit = "seconds" })
            )
        end
    )

    suite:case("toHumanString() prefixes negative Durations", function(asserts)
        asserts.eq("-1m 30s", secs(-90):toHumanString())
    end)

    suite:case("toHumanString() of infinities", function(asserts)
        asserts.eq("∞", INF:toHumanString())
        asserts.eq("-∞", NEG_INF:toHumanString())
    end)

    suite:case("toHumanString() with invalid maxUnits throws", function(asserts)
        for _, maxUnits in { 0, -1, 1.5 } do
            Helpers.throwsWith(
                asserts,
                function()
                    d:toHumanString({ maxUnits = maxUnits })
                end,
                "[Duration.toHumanString()]: Max units should be a positive integer"
            )
        end
    end)
end)

test.suite("toKey()", function(suite)
    suite:case("toKey() matches toString()", function(asserts)
        asserts.eq(millis(1_500):toString(), millis(1_500):toKey())
        asserts.eq("Infinity", INF:toKey())
    end)

    suite:case("toKey() is identical for equal Durations", function(asserts)
        asserts.eq(
            Duration.new(1, 500_000_000):toKey(),
            Duration.new(0, 1.5e9):toKey()
        )
        local seen = {}
        seen[millis(1_500):toKey()] = true
        asserts.eq(true, seen[Duration.new(1, 500_000_000):toKey()])
    end)

    suite:case("toKey() differs for unequal Durations", function(asserts)
        asserts.neq(secs(1):toKey(), secs(-1):toKey())
        asserts.neq(INF:toKey(), NEG_INF:toKey())
    end)
end)

test.suite("serialize()", function(suite)
    suite:case("serialize() stores seconds and nanoseconds", function(asserts)
        local data = millis(-1_500):serialize()
        asserts.eq(-2, data.secs)
        asserts.eq(500_000_000, data.nanos)
        asserts.eq(nil, data.inf)
    end)

    suite:case("serialize() stores infinities by sign", function(asserts)
        asserts.eq(1, INF:serialize().inf)
        asserts.eq(-1, NEG_INF:serialize().inf)
        asserts.eq(nil, INF:serialize().secs)
    end)

    suite:case("serialize() round-trips with deserialize()", function(asserts)
        for _, d in
            {
                Duration.ZERO,
                millis(-1_500),
                Duration.new(1e15, 999_999_999),
                INF,
                NEG_INF,
            } :: { Duration }
        do
            Helpers.eqByStr(asserts, d, Duration.deserialize(d:serialize()))
        end
    end)
end)

test.suite("tryDeserialize()", function(suite)
    local function deserializeErr(data: any): string
        return Duration.tryDeserialize(data):unwrapErr()
    end

    suite:case("tryDeserialize() returns ok for valid data", function(asserts)
        Helpers.eqByStr(
            asserts,
            Duration.new(1, 5),
            Duration.tryDeserialize({ secs = 1, nanos = 5 }):unwrap()
        )
        Helpers.eqByStr(
            asserts,
            NEG_INF,
            Duration.tryDeserialize({ inf = -1 }):unwrap()
        )
    end)

    suite:case("tryDeserialize() returns err for non-tables", function(asserts)
        asserts.eq("Expected data to be a table", deserializeErr(nil))
        asserts.eq("Expected data to be a table", deserializeErr("PT1S"))
    end)

    suite:case(
        "tryDeserialize() returns err for missing keys",
        function(asserts)
            asserts.eq(
                "Expected key 'secs' in data table",
                deserializeErr({ nanos = 0 })
            )
            asserts.eq(
                "Expected key 'nanos' in data table",
                deserializeErr({ secs = 0 })
            )
        end
    )

    suite:case("tryDeserialize() returns err for non-numbers", function(asserts)
        asserts.eq(
            "Expected key 'secs' to be a number in data table",
            deserializeErr({ secs = "1", nanos = 0 })
        )
        asserts.eq(
            "Expected key 'nanos' to be a number in data table",
            deserializeErr({ secs = 1, nanos = "0" })
        )
    end)

    suite:case(
        "tryDeserialize() returns err for non-integers",
        function(asserts)
            asserts.eq(
                "Expected key 'secs' to be an integer in data table",
                deserializeErr({ secs = 1.5, nanos = 0 })
            )
            asserts.eq(
                "Expected key 'nanos' to be an integer in data table",
                deserializeErr({ secs = 1, nanos = 0.5 })
            )
            asserts.eq(
                "Expected key 'secs' to be an integer in data table",
                deserializeErr({ secs = math.huge, nanos = 0 })
            )
            asserts.eq(
                "Expected key 'secs' to be an integer in data table",
                deserializeErr({ secs = 0 / 0, nanos = 0 })
            )
        end
    )

    suite:case(
        "tryDeserialize() returns err for out of range nanos",
        function(asserts)
            asserts.eq(
                "Expected key 'nanos' to be greater than or equal to 0, got -1",
                deserializeErr({ secs = 1, nanos = -1 })
            )
            asserts.eq(
                "Expected key 'nanos' to be less than or equal to 999999999, got 1000000000",
                deserializeErr({ secs = 1, nanos = 1e9 })
            )
        end
    )

    suite:case("tryDeserialize() returns err for invalid inf", function(asserts)
        for _, inf in { 0, 2, "1", true } do
            asserts.eq(
                "Expected key 'inf' to be 1 or -1 in data table",
                deserializeErr({ inf = inf })
            )
        end
    end)
end)

test.suite("deserialize()", function(suite)
    suite:case("deserialize() returns the Duration", function(asserts)
        Helpers.eqByStr(
            asserts,
            millis(-1_500),
            Duration.deserialize({ secs = -2, nanos = 500_000_000 })
        )
    end)

    suite:case("deserialize() throws for invalid data", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Duration.deserialize({})
            end,
            "[Duration.deserialize()]: Failed to deserialize duration: Expected key 'secs' in data table"
        )
        Helpers.throwsWith(asserts, function()
            Duration.deserialize({})
        end, "use Duration.tryDeserialize() instead")
    end)
end)

test.suite("error blame", function(suite)
    -- each error should point at the caller's line, not inside Duration.luau
    local function blame(asserts: types.Asserts, fn: () -> ())
        local ok, err = pcall(fn)
        asserts.eq(false, ok)
        asserts.strContains(tostring(err), "Duration.test.luau:")
    end

    local big = secs(1e12)
    local tiny = Duration.NANOSECOND

    suite:case("operator errors blame the caller", function(asserts)
        blame(asserts, function()
            local _ = INF + NEG_INF
        end)
        blame(asserts, function()
            local _ = INF - INF
        end)
        blame(asserts, function()
            local _ = Duration.SECOND / 0
        end)
        blame(asserts, function()
            local _ = Duration.SECOND // Duration.ZERO
        end)
        blame(asserts, function()
            local _ = big // tiny
        end)
        blame(asserts, function()
            local _ = big % tiny
        end)
    end)

    suite:case("method errors blame the caller", function(asserts)
        blame(asserts, function()
            INF:plus(NEG_INF)
        end)
        blame(asserts, function()
            big:floorDividedBy(tiny)
        end)
        blame(asserts, function()
            big:mod(tiny)
        end)
        blame(asserts, function()
            Duration.SECOND:ratio(Duration.ZERO)
        end)
        blame(asserts, function()
            Duration.SECOND:format("%x")
        end)
        blame(asserts, function()
            Duration.parse("nope")
        end)
        blame(asserts, function()
            Duration.deserialize({})
        end)
    end)

    suite:case("type check errors blame the caller", function(asserts)
        blame(asserts, function()
            Duration.plus(5 :: any, Duration.SECOND)
        end)
        blame(asserts, function()
            Duration.minus(Duration.SECOND, 5 :: any)
        end)
        blame(asserts, function()
            Duration.dividedBy(5 :: any, 2)
        end)
        blame(asserts, function()
            Duration.mod(Duration.SECOND, 5 :: any)
        end)
        blame(asserts, function()
            Duration.compareTo(5 :: any, Duration.SECOND)
        end)
        blame(asserts, function()
            local _ = Duration.SECOND * ({} :: any)
        end)
    end)

    suite:case("multiplication errors blame the caller", function(asserts)
        blame(asserts, function()
            local _ = INF * 0
        end)
        blame(asserts, function()
            local _ = 0 * INF
        end)
        blame(asserts, function()
            local _ = Duration.SECOND * (0 / 0)
        end)
        blame(asserts, function()
            INF:times(0)
        end)
        blame(asserts, function()
            Duration.times(5 :: any, 2)
        end)
    end)

    suite:case("truncated division errors blame the caller", function(asserts)
        blame(asserts, function()
            big:truncatedDividedBy(tiny)
        end)
        blame(asserts, function()
            big:remainder(tiny)
        end)
    end)

    suite:case("rounding errors blame the caller", function(asserts)
        blame(asserts, function()
            big:truncatedTo(tiny)
        end)
        blame(asserts, function()
            big:flooredTo(tiny)
        end)
        blame(asserts, function()
            big:ceiledTo(tiny)
        end)
        blame(asserts, function()
            big:roundedTo(tiny)
        end)
    end)

    suite:case("rounding errors report their own name", function(asserts)
        for _, name in
            { "truncatedTo", "flooredTo", "ceiledTo", "roundedTo" } :: { string }
        do
            Helpers.throwsWith(
                asserts,
                function()
                    (big :: any)[name](big, tiny)
                end,
                `[Duration.{name}()]: Quotient is too large to be represented exactly`
            )
        end
    end)

    suite:case("constructor errors blame the caller", function(asserts)
        local nan = 0 / 0
        blame(asserts, function()
            Duration.new(nan, 0)
        end)
        blame(asserts, function()
            Duration.new(math.huge, -math.huge)
        end)
        blame(asserts, function()
            Duration.fromSeconds(nan)
        end)
        blame(asserts, function()
            Duration.fromMillis(nan)
        end)
        blame(asserts, function()
            Duration.fromParts({ days = nan })
        end)
        blame(asserts, function()
            Duration.fromParts({ days = math.huge, hours = -math.huge })
        end)
        blame(asserts, function()
            Duration.between(0, nan)
        end)
    end)
end)
