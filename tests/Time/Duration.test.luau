--!strict

-- Duration datatype tests
-- by @vuppyan

local test = require("@std/test")
local types = require("@std/test/types")
local Duration = require("../../src/luautils/Time/Duration")

local function eqDuration(
    asserts: types.Asserts,
    expected: Duration.Duration,
    actual: Duration.Duration
)
    asserts.eq(tostring(expected), tostring(actual))
end

-- true for +0, false for -0
local function isPositiveZero(x: number): boolean
    return x == 0 and 1 / x == math.huge
end

test.suite("Duration construction", function(suite)
    suite:case("moves fractional seconds into nanos", function(asserts)
        local s, n = Duration.ofSeconds(1.5):toSecondsAndNanoOffset()
        asserts.eq(1, s)
        asserts.eq(500_000_000, n)

        s, n = Duration.ofSeconds(1.1):toSecondsAndNanoOffset()
        asserts.eq(1, s)
        asserts.eq(100_000_000, n)
    end)

    suite:case("carries and borrows nanos", function(asserts)
        local s, n = Duration.ofNanos(1_500_000_000)
            :toSecondsAndNanoOffset()
        asserts.eq(1, s)
        asserts.eq(500_000_000, n)

        s, n = Duration.ofMillis(-1):toSecondsAndNanoOffset()
        asserts.eq(-1, s)
        asserts.eq(999_000_000, n)
    end)

    suite:case("of() combines mixed units and signs", function(asserts)
        eqDuration(asserts, Duration.ofHours(23), Duration.of(1, -1))
        eqDuration(
            asserts,
            Duration.ofMillis(1500),
            Duration.of(nil, nil, nil, 1, 500)
        )
    end)

    suite:case("rejects NaN and infinity", function(asserts)
        for _, v in { 0 / 0, math.huge, -math.huge } do
            asserts.throws(function()
                Duration.ofSeconds(v)
            end)
        end
    end)
end)

test.suite("Duration.parse()", function(suite)
    suite:case("round-trip canonical strings", function(asserts)
        for _, s in
            {
                "PT0S",
                "PT1.5S",
                "-PT1.5S",
                "P1DT2H3M4.005S",
                "-PT0.000000001S",
            }
        do
            asserts.eq(s, tostring(Duration.parse(s)))
        end
    end)

    suite:case("accepts weeks, commas, lowercase", function(asserts)
        asserts.eq("P7D", tostring(Duration.parse("P1W")))
        asserts.eq("PT1.25S", tostring(Duration.parse("pt1,25s")))
    end)

    suite:case("rejects malformed input", function(asserts)
        for _, s in
            {
                "",
                "P",
                "PT",
                "P1DT",
                "PT1.5H",
                "P1M",
                "PT1M1H",
                "PT1S1S",
                "PT1.S",
                "PT5",
                "1D",
            }
        do
            asserts.throws(function()
                Duration.parse(s)
            end)
        end
    end)
end)

test.suite("Duration conversions", function(suite)
    suite:case("to* return fractional totals", function(asserts)
        asserts.eq(-1.5, Duration.ofMillis(-1500):toSeconds())
        asserts.eq(1.5, Duration.ofSeconds(90):toMinutes())
        asserts.eq(36, Duration.ofDays(1.5):toHours())
        asserts.eq(-1000.5, Duration.parse("-PT1.0005S"):toMillis())
    end)

    suite:case("positive parts", function(asserts)
        local d = Duration.parse("P1DT2H3M4.005006007S")
        asserts.eq(1, d:daysPart())
        asserts.eq(2, d:hoursPart())
        asserts.eq(7, d:nanosPart())
    end)

    suite:case("zero parts are never -0", function(asserts)
        local d = Duration.ofDays(-1)
        asserts.eq(-1, d:daysPart())
        for _, part in
            {
                d:hoursPart(),
                d:minutesPart(),
                d:secondsPart(),
                d:millisPart(),
            }
        do
            asserts.eq(true, isPositiveZero(part))
        end
    end)
end)

test.suite("Duration arithmetic", function(suite)
    suite:case(
        "plus/minus carry across the second boundary",
        function(asserts)
            eqDuration(
                asserts,
                Duration.ofMillis(1300),
                Duration.ofMillis(700):plus(Duration.ofMillis(600))
            )
            eqDuration(
                asserts,
                Duration.ofMillis(-500),
                Duration.ofSeconds(1):minus(Duration.ofMillis(1500))
            )
        end
    )

    suite:case("times", function(asserts)
        eqDuration(
            asserts,
            Duration.ofMillis(1500),
            Duration.ofSeconds(3):times(0.5)
        )
        eqDuration(
            asserts,
            Duration.ofMillis(-1500),
            Duration.ofMillis(1500):times(-1)
        )
    end)

    suite:case(
        "dividedBy rounds to the nearest nanosecond",
        function(asserts)
            local s, n = Duration.ofSeconds(1)
                :dividedBy(3)
                :toSecondsAndNanoOffset()
            asserts.eq(0, s)
            asserts.eq(333_333_333, n)
        end
    )

    suite:case("dividedBy is symmetric under negation", function(asserts)
        for _, d in
            {
                Duration.ofNanos(1),
                Duration.ofNanos(3),
                Duration.ofMillis(7),
            }
        do
            eqDuration(
                asserts,
                d:dividedBy(2):negate(),
                d:negate():dividedBy(2)
            )
        end
    end)

    suite:case(
        "floorDividedBy rounds toward negative infinity",
        function(asserts)
            eqDuration(
                asserts,
                Duration.ofSeconds(2),
                Duration.ofSeconds(5):floorDividedBy(2)
            )
            eqDuration(
                asserts,
                Duration.ofSeconds(-2),
                Duration.ofMillis(-2500):floorDividedBy(2)
            )
        end
    )

    suite:case("mod handles fractional operands", function(asserts)
        eqDuration(
            asserts,
            Duration.ofMillis(1500),
            Duration.ofMillis(5500):mod(Duration.ofSeconds(2))
        )
    end)

    suite:case("mod result is in [0, b) for positive b", function(asserts)
        local b = Duration.ofMillis(1500)
        for ms = -5000, 5000, 137 do
            local r = Duration.ofMillis(ms):mod(b)
            asserts.eq(false, r:isNegative())
            asserts.eq(-1, r:compareTo(b))
        end
    end)

    suite:case("mod result is in (b, 0] for negative b", function(asserts)
        local b = Duration.ofMillis(-1500)
        for ms = -5000, 5000, 137 do
            local r = Duration.ofMillis(ms):mod(b)
            asserts.eq(false, r:isPositive())
            asserts.eq(1, r:compareTo(b))
            -- and a == b*q + r
            eqDuration(
                asserts,
                Duration.ofMillis(ms),
                b:times(math.floor(ms / -1500)):plus(r)
            )
        end
    end)

    suite:case("division by zero throws", function(asserts)
        local d = Duration.ofSeconds(1)
        asserts.throws(function()
            d:dividedBy(0)
        end)
        asserts.throws(function()
            d:floorDividedBy(0)
        end)
        asserts.throws(function()
            d:mod(Duration.zero())
        end)
    end)

    suite:case("negating zero stays zero", function(asserts)
        local z = Duration.zero():negate()
        asserts.eq(true, z:isZero())
        asserts.eq(false, z:isNegative())
        asserts.eq("PT0S", tostring(z))
    end)
end)

test.suite("Duration parts", function(suite)
    suite:case("negative parts sum back to the whole", function(asserts)
        local d = Duration.parse("-P1DT2H3M4.005006007S")
        asserts.eq(-1, d:daysPart())
        asserts.eq(-2, d:hoursPart())
        asserts.eq(-3, d:minutesPart())
        asserts.eq(-4, d:secondsPart())
        asserts.eq(-5, d:millisPart())
        asserts.eq(-6, d:microsPart())
        asserts.eq(-7, d:nanosPart())
    end)
end)

test.suite("Duration comparison", function(suite)
    suite:case("operators use value semantics", function(asserts)
        asserts.eq(
            true,
            Duration.ofSeconds(1.5) == Duration.ofMillis(1500)
        )
        asserts.eq(true, Duration.ofSeconds(1) < Duration.ofSeconds(2))
        asserts.eq(true, Duration.ofSeconds(2) <= Duration.ofSeconds(2))
        asserts.eq(true, Duration.ofSeconds(2) > Duration.ofMillis(-1))
    end)

    suite:case("table.sort orders durations", function(asserts)
        local list = {
            Duration.ofSeconds(3),
            Duration.ofMillis(-1),
            Duration.zero(),
            Duration.ofSeconds(1),
        }
        table.sort(list)
        local out = {}
        for i, d in list do
            out[i] = tostring(d)
        end
        asserts.eq("-PT0.001S,PT0S,PT1S,PT3S", table.concat(out, ","))
    end)

    suite:case("min, max, clamp", function(asserts)
        local one, two, three =
            Duration.ofSeconds(1),
            Duration.ofSeconds(2),
            Duration.ofSeconds(3)
        eqDuration(asserts, one, one:min(two))
        eqDuration(asserts, two, one:max(two))
        eqDuration(asserts, two, three:clamp(one, two))
        eqDuration(asserts, one, Duration.zero():clamp(one, two))
        eqDuration(asserts, two, two:clamp(one, three))
    end)
end)

test.suite("Duration strings", function(suite)
    suite:case("toString shapes", function(asserts)
        asserts.eq("PT1M", tostring(Duration.ofMinutes(1)))
        asserts.eq("P1D", tostring(Duration.ofDays(1)))
        asserts.eq("PT1.1S", tostring(Duration.ofMillis(1100)))
        asserts.eq("-PT0.5S", tostring(Duration.ofMillis(-500)))
        asserts.eq("P1000000000000D", tostring(Duration.ofDays(1e12)))
    end)

    suite:case("parse normalizes and truncates", function(asserts)
        asserts.eq("PT1S", tostring(Duration.parse("+PT1S")))
        asserts.eq("PT0S", tostring(Duration.parse("-PT0S")))
        asserts.eq("P14D", tostring(Duration.parse("P2W")))
        asserts.eq("PT1H30M", tostring(Duration.parse("PT90M")))
        asserts.eq(
            "PT1.123456789S",
            tostring(Duration.parse("PT1.1234567891S"))
        )
    end)
end)

test.suite("Duration:format", function(suite)
    suite:case("pads, escapes, and signs", function(asserts)
        asserts.eq(
            "01:02:03",
            Duration.of(0, 1, 2, 3):format("%02H:%02M:%02S")
        )
        asserts.eq("1.250", Duration.ofMillis(1250):format("%S.%03f"))
        asserts.eq("-1d 2h", Duration.of(-1, -2):format("%dd %Hh"))
        asserts.eq("100%", Duration.zero():format("100%%"))
    end)

    suite:case("rejects unknown specifiers", function(asserts)
        asserts.throws(function()
            Duration.zero():format("%Q")
        end)
    end)
end)

test.suite("Duration utilities", function(suite)
    suite:case("serialize round-trips", function(asserts)
        for _, d in
            {
                Duration.zero(),
                Duration.ofMillis(-1500),
                Duration.ofDays(1e9),
            }
        do
            local data = d:serialize()
            asserts.eq(nil, getmetatable(data)) -- plain table, DataStore-safe
            eqDuration(asserts, d, Duration.deserialize(data))
        end
    end)

    suite:case("is() checks the metatable", function(asserts)
        asserts.eq(true, Duration.is(Duration.zero()))
        asserts.eq(false, Duration.is({ _secs = 1, _nanos = 0 }))
        asserts.eq(false, Duration.is(nil))
        asserts.eq(false, Duration.is(5))
    end)

    suite:case("between and since", function(asserts)
        eqDuration(
            asserts,
            Duration.ofMillis(1250),
            Duration.between(10, 11.25)
        )
        local elapsed = Duration.since(os.clock())
        asserts.eq(false, elapsed:isNegative())
        asserts.eq(true, elapsed:toSeconds() < 1)
    end)
end)
