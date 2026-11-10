--!strict

-- Cooldown tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers")
local Cooldown = require("../../src/luautils/Time/Cooldown")
local Duration = require("../../src/luautils/Time/Duration")

type Cooldown<K> = Cooldown.Cooldown<K>
type Duration = Duration.Duration

local NAN = 0 / 0

local function secs(n: number): Duration
    return Duration.fromSeconds(n)
end

type FakeClock = {
    now: number,
    fn: () -> number,
    advance: (by: number) -> (),
}

-- a manually controlled clock, so timings are exact and deterministic
local function fakeClock(start: number?): FakeClock
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

-- creates a Cooldown driven by a fake clock
local function newCooldown(
    length: number,
    maxCharges: number?
): (Cooldown<any>, FakeClock)
    local clock = fakeClock()
    local cooldown = Cooldown.new(secs(length), {
        clock = clock.fn,
        maxCharges = maxCharges,
    })
    return cooldown, clock
end

test.suite("new()", function(suite)
    suite:case("new() defaults to one charge", function(asserts)
        local cooldown = Cooldown.new(secs(5))
        asserts.eq(1, cooldown:maxCharges())
        asserts.eq(1, cooldown:charges("a"))
    end)

    suite:case("new() stores the length", function(asserts)
        local cooldown = Cooldown.new(secs(5))
        Helpers.eqByStr(asserts, secs(5), cooldown:getLength())
    end)

    suite:case("new() uses the given max charges", function(asserts)
        local cooldown = newCooldown(5, 3)
        asserts.eq(3, cooldown:maxCharges())
        asserts.eq(3, cooldown:charges("a"))
    end)

    suite:case("new() uses the given clock", function(asserts)
        local spy = Helpers.spy(function(): number
            return 0
        end)
        local cooldown = Cooldown.new(secs(5), { clock = spy.fn })
        cooldown:tryUse("a")
        asserts.eq(1, spy.calls)
    end)

    suite:case("new() defaults to os.clock", function(asserts)
        local cooldown = Cooldown.new(secs(1_000))
        asserts.eq(true, cooldown:tryUse("a"))
        asserts.eq(false, cooldown:isReady("a"))
    end)

    suite:case("new() accepts a zero length", function(asserts)
        local cooldown = newCooldown(0)
        Helpers.eqByStr(asserts, Duration.ZERO, cooldown:getLength())
    end)

    suite:case("new() starts with no entries", function(asserts)
        local cooldown = newCooldown(5)
        asserts.eq(0, cooldown:prune())
    end)

    suite:case("new() rejects a negative length", function(asserts)
        Helpers.throwsWith(asserts, function()
            Cooldown.new(secs(-1))
        end, "[Cooldown.new()]: Length cannot be negative")
    end)

    suite:case("new() rejects non-positive max charges", function(asserts)
        for _, maxCharges in { 0, -1 } do
            Helpers.throwsWith(asserts, function()
                Cooldown.new(secs(1), { maxCharges = maxCharges })
            end, "[Cooldown.new()]: Max charges must be a positive integer")
        end
    end)

    suite:case("new() rejects non-integer max charges", function(asserts)
        for _, maxCharges in { 1.5, math.huge, NAN } do
            Helpers.throwsWith(asserts, function()
                Cooldown.new(secs(1), { maxCharges = maxCharges })
            end, "[Cooldown.new()]: Max charges must be a positive integer")
        end
    end)
end)

test.suite("tryUse()", function(suite)
    suite:case("tryUse() succeeds when ready", function(asserts)
        local cooldown = newCooldown(5)
        asserts.eq(true, cooldown:tryUse("a"))
    end)

    suite:case("tryUse() fails while recharging", function(asserts)
        local cooldown, clock = newCooldown(5)
        cooldown:tryUse("a")
        clock.advance(4.9)
        asserts.eq(false, cooldown:tryUse("a"))
    end)

    suite:case("tryUse() succeeds once the length has passed", function(asserts)
        local cooldown, clock = newCooldown(5)
        cooldown:tryUse("a")
        clock.advance(5)
        asserts.eq(true, cooldown:tryUse("a"))
    end)

    suite:case("tryUse() does nothing when it fails", function(asserts)
        local cooldown, clock = newCooldown(5)
        cooldown:tryUse("a")
        clock.advance(2)
        cooldown:tryUse("a")
        Helpers.eqByStr(asserts, secs(3), cooldown:remaining("a"))
    end)

    suite:case("tryUse() spends one charge per use", function(asserts)
        local cooldown = newCooldown(3, 2)
        asserts.eq(true, cooldown:tryUse("a"))
        asserts.eq(1, cooldown:charges("a"))
        asserts.eq(true, cooldown:tryUse("a"))
        asserts.eq(0, cooldown:charges("a"))
        asserts.eq(false, cooldown:tryUse("a"))
    end)

    suite:case("tryUse() recharges one charge at a time", function(asserts)
        local cooldown, clock = newCooldown(3, 3)
        for _ = 1, 3 do
            cooldown:tryUse("a")
        end
        clock.advance(3)
        asserts.eq(1, cooldown:charges("a"))
        clock.advance(3)
        asserts.eq(2, cooldown:charges("a"))
        clock.advance(3)
        asserts.eq(3, cooldown:charges("a"))
    end)

    suite:case(
        "tryUse() recovers several charges after a long gap",
        function(asserts)
            local cooldown, clock = newCooldown(3, 3)
            for _ = 1, 3 do
                cooldown:tryUse("a")
            end
            clock.advance(7)
            asserts.eq(2, cooldown:charges("a"))
            Helpers.eqByStr(asserts, secs(2), cooldown:remaining("a"))
        end
    )

    suite:case(
        "tryUse() with charges left doesn't restart the timer",
        function(asserts)
            local cooldown, clock = newCooldown(10, 2)
            cooldown:tryUse("a")
            clock.advance(4)
            cooldown:tryUse("a")
            Helpers.eqByStr(asserts, secs(6), cooldown:remaining("a"))
        end
    )

    suite:case("tryUse() applies a length override", function(asserts)
        local cooldown, clock = newCooldown(1)
        asserts.eq(true, cooldown:tryUse("a", secs(4)))
        clock.advance(1)
        asserts.eq(false, cooldown:isReady("a"))
        clock.advance(3)
        asserts.eq(true, cooldown:isReady("a"))
    end)

    suite:case(
        "tryUse() ignores an override while a charge recharges",
        function(asserts)
            local cooldown = newCooldown(10, 2)
            cooldown:tryUse("a")
            cooldown:tryUse("a", secs(100))
            Helpers.eqByStr(asserts, secs(10), cooldown:remaining("a"))
        end
    )

    suite:case(
        "tryUse() charges after an override use the normal length",
        function(asserts)
            local cooldown, clock = newCooldown(10, 2)
            cooldown:tryUse("a", secs(4))
            cooldown:tryUse("a")
            clock.advance(4)
            asserts.eq(1, cooldown:charges("a"))
            Helpers.eqByStr(asserts, secs(10), cooldown:remaining("a"))
        end
    )

    suite:case(
        "tryUse() with a zero override doesn't spend a charge",
        function(asserts)
            local cooldown = newCooldown(5)
            asserts.eq(true, cooldown:tryUse("a", Duration.ZERO))
            asserts.eq(1, cooldown:charges("a"))
            asserts.eq(0, cooldown:prune())
        end
    )

    suite:case(
        "tryUse() on a zero-length Cooldown is always free",
        function(asserts)
            local cooldown = newCooldown(0)
            for _ = 1, 3 do
                asserts.eq(true, cooldown:tryUse("a"))
            end
            asserts.eq(1, cooldown:charges("a"))
        end
    )

    suite:case(
        "tryUse() with a zero override still needs a charge",
        function(asserts)
            local cooldown = newCooldown(5)
            cooldown:tryUse("a")
            asserts.eq(false, cooldown:tryUse("a", Duration.ZERO))
        end
    )

    suite:case("tryUse() keeps keys independent", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:tryUse("a")
        asserts.eq(true, cooldown:tryUse("b"))
        asserts.eq(false, cooldown:tryUse("a"))
    end)

    suite:case("tryUse() accepts table keys", function(asserts)
        local cooldown = newCooldown(5)
        local player = {}
        cooldown:tryUse(player)
        asserts.eq(false, cooldown:isReady(player))
        asserts.eq(true, cooldown:isReady({}))
    end)

    suite:case("tryUse() rejects nil and NaN keys", function(asserts)
        local cooldown = newCooldown(5)
        for _, key in { NAN, "nil" } do
            local actual = if key == "nil" then nil else key
            Helpers.throwsWith(asserts, function()
                cooldown:tryUse(actual)
            end, "[Cooldown.tryUse()]: Key cannot be nil or NaN")
        end
    end)

    suite:case("tryUse() rejects a negative override", function(asserts)
        local cooldown = newCooldown(5)
        Helpers.throwsWith(asserts, function()
            cooldown:tryUse("a", secs(-1))
        end, "[Cooldown.tryUse()]: Length cannot be negative")
    end)
end)

test.suite("start()", function(suite)
    suite:case("start() empties every charge", function(asserts)
        local cooldown = newCooldown(5, 3)
        cooldown:start("a")
        asserts.eq(0, cooldown:charges("a"))
        asserts.eq(false, cooldown:isReady("a"))
        Helpers.eqByStr(asserts, secs(5), cooldown:remaining("a"))
    end)

    suite:case("start() applies a length override", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:start("a", secs(2))
        Helpers.eqByStr(asserts, secs(2), cooldown:remaining("a"))
    end)

    suite:case(
        "start() charges after the first use the normal length",
        function(asserts)
            local cooldown, clock = newCooldown(5, 3)
            cooldown:start("a", secs(2))
            clock.advance(2)
            asserts.eq(1, cooldown:charges("a"))
            clock.advance(5)
            asserts.eq(2, cooldown:charges("a"))
        end
    )

    suite:case("start() replaces a recharge in progress", function(asserts)
        local cooldown, clock = newCooldown(10, 2)
        cooldown:tryUse("a")
        clock.advance(8)
        cooldown:start("a", secs(3))
        asserts.eq(0, cooldown:charges("a"))
        Helpers.eqByStr(asserts, secs(3), cooldown:remaining("a"))
    end)

    suite:case("start() with a zero length resets the entry", function(asserts)
        local cooldown = newCooldown(5, 2)
        cooldown:start("a")
        cooldown:start("a", Duration.ZERO)
        asserts.eq(2, cooldown:charges("a"))
        asserts.eq(0, cooldown:prune())
    end)

    suite:case("start() rejects nil and NaN keys", function(asserts)
        local cooldown = newCooldown(5)
        for _, key in { NAN, "nil" } do
            local actual = if key == "nil" then nil else key
            Helpers.throwsWith(asserts, function()
                cooldown:start(actual)
            end, "[Cooldown.start()]: Key cannot be nil or NaN")
        end
    end)

    suite:case("start() rejects a negative override", function(asserts)
        local cooldown = newCooldown(5)
        Helpers.throwsWith(asserts, function()
            cooldown:start("a", secs(-1))
        end, "[Cooldown.start()]: Length cannot be negative")
    end)
end)

test.suite("adjust()", function(suite)
    suite:case("adjust() does nothing without an entry", function(asserts)
        local cooldown = newCooldown(5, 2)
        cooldown:adjust("a", secs(10))
        asserts.eq(2, cooldown:charges("a"))
        asserts.eq(0, cooldown:prune())
    end)

    suite:case("adjust() lengthens with a positive delta", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:tryUse("a")
        cooldown:adjust("a", secs(3))
        Helpers.eqByStr(asserts, secs(8), cooldown:remaining("a"))
    end)

    suite:case("adjust() shortens with a negative delta", function(asserts)
        local cooldown = newCooldown(10)
        cooldown:tryUse("a")
        cooldown:adjust("a", secs(-4))
        Helpers.eqByStr(asserts, secs(6), cooldown:remaining("a"))
    end)

    suite:case(
        "adjust() finishing a single charge removes the entry",
        function(asserts)
            local cooldown = newCooldown(10)
            cooldown:tryUse("a")
            cooldown:adjust("a", secs(-10))
            asserts.eq(true, cooldown:isReady("a"))
            asserts.eq(0, cooldown:prune())
        end
    )

    suite:case(
        "adjust() past the current charge recovers only one charge",
        function(asserts)
            local cooldown = newCooldown(10, 3)
            for _ = 1, 3 do
                cooldown:tryUse("a")
            end
            cooldown:adjust("a", secs(-12))
            asserts.eq(1, cooldown:charges("a"))
            Helpers.eqByStr(asserts, secs(8), cooldown:remaining("a"))
        end
    )

    suite:case(
        "adjust() carries leftover time across several charges",
        function(asserts)
            local cooldown = newCooldown(10, 3)
            for _ = 1, 3 do
                cooldown:tryUse("a")
            end
            cooldown:adjust("a", secs(-25))
            asserts.eq(2, cooldown:charges("a"))
            Helpers.eqByStr(asserts, secs(5), cooldown:remaining("a"))
        end
    )

    suite:case("adjust() rejects nil and NaN keys", function(asserts)
        local cooldown = newCooldown(5)
        for _, key in { NAN, "nil" } do
            local actual = if key == "nil" then nil else key
            Helpers.throwsWith(asserts, function()
                cooldown:adjust(actual, secs(1))
            end, "[Cooldown.adjust()]: Key cannot be nil or NaN")
        end
    end)
end)

test.suite("reset()", function(suite)
    suite:case("reset() restores every charge", function(asserts)
        local cooldown = newCooldown(5, 2)
        cooldown:tryUse("a")
        cooldown:tryUse("a")
        cooldown:reset("a")
        asserts.eq(2, cooldown:charges("a"))
        asserts.eq(0, cooldown:prune())
    end)

    suite:case("reset() leaves other keys alone", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:tryUse("a")
        cooldown:tryUse("b")
        cooldown:reset("a")
        asserts.eq(true, cooldown:isReady("a"))
        asserts.eq(false, cooldown:isReady("b"))
    end)

    suite:case("reset() does nothing without an entry", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:reset("a")
        asserts.eq(true, cooldown:isReady("a"))
    end)

    suite:case("reset() rejects nil and NaN keys", function(asserts)
        local cooldown = newCooldown(5)
        for _, key in { NAN, "nil" } do
            local actual = if key == "nil" then nil else key
            Helpers.throwsWith(asserts, function()
                cooldown:reset(actual)
            end, "[Cooldown.reset()]: Key cannot be nil or NaN")
        end
    end)
end)

test.suite("resetAll()", function(suite)
    suite:case("resetAll() removes every entry", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:tryUse("a")
        cooldown:tryUse("b")
        cooldown:resetAll()
        asserts.eq(true, cooldown:isReady("a"))
        asserts.eq(true, cooldown:isReady("b"))
        asserts.eq(0, cooldown:prune())
    end)
end)

test.suite("prune()", function(suite)
    suite:case("prune() counts entries still recharging", function(asserts)
        local cooldown, clock = newCooldown(5)
        cooldown:tryUse("a")
        clock.advance(2)
        cooldown:tryUse("b")
        asserts.eq(2, cooldown:prune())
        clock.advance(3)
        asserts.eq(1, cooldown:prune())
        clock.advance(2)
        asserts.eq(0, cooldown:prune())
    end)

    suite:case(
        "prune() keeps entries with charges still recharging",
        function(asserts)
            local cooldown, clock = newCooldown(10, 3)
            for _ = 1, 3 do
                cooldown:tryUse("a")
            end
            clock.advance(10)
            asserts.eq(1, cooldown:prune())
            asserts.eq(1, cooldown:charges("a"))
        end
    )

    suite:case("prune() doesn't change any readings", function(asserts)
        local cooldown, clock = newCooldown(10, 3)
        for _ = 1, 3 do
            cooldown:tryUse("a")
        end
        clock.advance(14)
        cooldown:prune()
        asserts.eq(1, cooldown:charges("a"))
        Helpers.eqByStr(asserts, secs(6), cooldown:remaining("a"))
        Helpers.eqByStr(asserts, secs(16), cooldown:remainingUntilFull("a"))
    end)
end)

test.suite("isReady()", function(suite)
    suite:case("isReady() is true without an entry", function(asserts)
        local cooldown = newCooldown(5)
        asserts.eq(true, cooldown:isReady("a"))
    end)

    suite:case("isReady() is false with no charges", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:tryUse("a")
        asserts.eq(false, cooldown:isReady("a"))
    end)

    suite:case("isReady() is true with charges left", function(asserts)
        local cooldown = newCooldown(5, 2)
        cooldown:tryUse("a")
        asserts.eq(true, cooldown:isReady("a"))
    end)

    suite:case("isReady() does not spend a charge", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:isReady("a")
        asserts.eq(1, cooldown:charges("a"))
    end)
end)

test.suite("remaining()", function(suite)
    suite:case("remaining() is zero without an entry", function(asserts)
        local cooldown = newCooldown(5)
        Helpers.eqByStr(asserts, Duration.ZERO, cooldown:remaining("a"))
    end)

    suite:case("remaining() counts down", function(asserts)
        local cooldown, clock = newCooldown(5)
        cooldown:tryUse("a")
        Helpers.eqByStr(asserts, secs(5), cooldown:remaining("a"))
        clock.advance(2)
        Helpers.eqByStr(asserts, secs(3), cooldown:remaining("a"))
        clock.advance(3)
        Helpers.eqByStr(asserts, Duration.ZERO, cooldown:remaining("a"))
    end)

    suite:case(
        "remaining() is the charge in progress, not every charge",
        function(asserts)
            local cooldown, clock = newCooldown(10, 3)
            cooldown:tryUse("a")
            cooldown:tryUse("a")
            clock.advance(4)
            Helpers.eqByStr(asserts, secs(6), cooldown:remaining("a"))
            asserts.eq(true, cooldown:isReady("a"))
        end
    )
end)

test.suite("progress()", function(suite)
    suite:case("progress() is 1 without an entry", function(asserts)
        local cooldown = newCooldown(5)
        asserts.eq(1, cooldown:progress("a"))
    end)

    suite:case("progress() counts up", function(asserts)
        local cooldown, clock = newCooldown(10)
        cooldown:tryUse("a")
        asserts.eq(0, cooldown:progress("a"))
        clock.advance(4)
        asserts.eq(0.4, cooldown:progress("a"))
        clock.advance(6)
        asserts.eq(1, cooldown:progress("a"))
    end)

    suite:case("progress() follows a length override", function(asserts)
        local cooldown, clock = newCooldown(10)
        cooldown:tryUse("a", secs(4))
        clock.advance(1)
        asserts.eq(0.25, cooldown:progress("a"))
    end)

    suite:case("progress() resets for the next charge", function(asserts)
        local cooldown, clock = newCooldown(10, 2)
        cooldown:tryUse("a")
        cooldown:tryUse("a")
        clock.advance(12)
        asserts.eq(0.2, cooldown:progress("a"))
    end)
end)

test.suite("remainingUntilFull()", function(suite)
    suite:case(
        "remainingUntilFull() is zero without an entry",
        function(asserts)
            local cooldown = newCooldown(5, 3)
            Helpers.eqByStr(
                asserts,
                Duration.ZERO,
                cooldown:remainingUntilFull("a")
            )
        end
    )

    suite:case(
        "remainingUntilFull() includes every missing charge",
        function(asserts)
            local cooldown, clock = newCooldown(10, 3)
            cooldown:tryUse("a")
            cooldown:tryUse("a")
            clock.advance(4)
            Helpers.eqByStr(asserts, secs(16), cooldown:remainingUntilFull("a"))
        end
    )

    suite:case(
        "remainingUntilFull() matches remaining() with one charge",
        function(asserts)
            local cooldown, clock = newCooldown(10)
            cooldown:tryUse("a")
            clock.advance(3)
            Helpers.eqByStr(
                asserts,
                cooldown:remaining("a"),
                cooldown:remainingUntilFull("a")
            )
        end
    )

    suite:case(
        "remainingUntilFull() uses the current length for later charges",
        function(asserts)
            local cooldown = newCooldown(10, 2)
            cooldown:tryUse("a")
            cooldown:tryUse("a")
            cooldown:setLength(secs(4))
            Helpers.eqByStr(asserts, secs(14), cooldown:remainingUntilFull("a"))
        end
    )
end)

test.suite("progressUntilFull()", function(suite)
    suite:case("progressUntilFull() is 1 without an entry", function(asserts)
        local cooldown = newCooldown(5, 3)
        asserts.eq(1, cooldown:progressUntilFull("a"))
    end)

    suite:case(
        "progressUntilFull() counts the charge in progress as a fraction",
        function(asserts)
            local cooldown, clock = newCooldown(10, 3)
            cooldown:tryUse("a")
            cooldown:tryUse("a")
            clock.advance(4)
            asserts.eq((1 + 0.4) / 3, cooldown:progressUntilFull("a"))
        end
    )

    suite:case("progressUntilFull() is 0 when fully spent", function(asserts)
        local cooldown = newCooldown(10, 2)
        cooldown:tryUse("a")
        cooldown:tryUse("a")
        asserts.eq(0, cooldown:progressUntilFull("a"))
    end)
end)

test.suite("getLength() and setLength()", function(suite)
    suite:case("setLength() changes the length", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:setLength(secs(8))
        Helpers.eqByStr(asserts, secs(8), cooldown:getLength())
    end)

    suite:case("setLength() applies to new uses", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:setLength(secs(8))
        cooldown:tryUse("a")
        Helpers.eqByStr(asserts, secs(8), cooldown:remaining("a"))
    end)

    suite:case(
        "setLength() leaves the charge in progress unchanged",
        function(asserts)
            local cooldown, clock = newCooldown(10, 2)
            cooldown:tryUse("a")
            cooldown:tryUse("a")
            cooldown:setLength(secs(4))
            Helpers.eqByStr(asserts, secs(10), cooldown:remaining("a"))
            clock.advance(10)
            Helpers.eqByStr(asserts, secs(4), cooldown:remaining("a"))
        end
    )

    suite:case(
        "setLength() to zero recovers every charge once the current one finishes",
        function(asserts)
            local cooldown, clock = newCooldown(10, 3)
            for _ = 1, 3 do
                cooldown:tryUse("a")
            end
            cooldown:setLength(Duration.ZERO)
            clock.advance(10)
            asserts.eq(3, cooldown:charges("a"))
        end
    )

    suite:case("setLength() rejects a negative length", function(asserts)
        local cooldown = newCooldown(5)
        Helpers.throwsWith(asserts, function()
            cooldown:setLength(secs(-1))
        end, "[Cooldown.setLength()]: Length cannot be negative")
    end)
end)

test.suite("charges() and maxCharges()", function(suite)
    suite:case("charges() is max without an entry", function(asserts)
        local cooldown = newCooldown(5, 4)
        asserts.eq(4, cooldown:charges("a"))
    end)

    suite:case("charges() never exceeds max", function(asserts)
        local cooldown, clock = newCooldown(5, 2)
        cooldown:tryUse("a")
        clock.advance(1_000)
        asserts.eq(2, cooldown:charges("a"))
    end)

    suite:case("maxCharges() is unaffected by uses", function(asserts)
        local cooldown = newCooldown(5, 2)
        cooldown:tryUse("a")
        asserts.eq(2, cooldown:maxCharges())
    end)
end)

test.suite("is()", function(suite)
    suite:case("is() is true for Cooldowns", function(asserts)
        asserts.eq(true, Cooldown.is(Cooldown.new(secs(1))))
    end)

    suite:case("is() is false for non-Cooldowns", function(asserts)
        asserts.eq(false, Cooldown.is(nil))
        asserts.eq(false, Cooldown.is(1))
        asserts.eq(false, Cooldown.is("cooldown"))
        asserts.eq(false, Cooldown.is({}))
        asserts.eq(false, Cooldown.is(Duration.ZERO))
    end)

    suite:case("is() is false for lookalike tables", function(asserts)
        asserts.eq(
            false,
            Cooldown.is({
                _clock = os.clock,
                _length = 1,
                _maxCharges = 1,
                _entries = {},
            })
        )
    end)
end)

test.suite("toString()", function(suite)
    suite:case("toString() of a new Cooldown", function(asserts)
        local cooldown = newCooldown(5)
        asserts.eq("Cooldown(5s, 0 active)", cooldown:toString())
    end)

    suite:case("toString() counts active entries", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:tryUse("a")
        cooldown:tryUse("b")
        asserts.eq("Cooldown(5s, 2 active)", cooldown:toString())
    end)

    suite:case("toString() doesn't count recharged entries", function(asserts)
        local cooldown, clock = newCooldown(5)
        cooldown:tryUse("a")
        clock.advance(5)
        asserts.eq("Cooldown(5s, 0 active)", cooldown:toString())
    end)

    suite:case("tostring() uses toString()", function(asserts)
        local cooldown = newCooldown(5)
        cooldown:tryUse("a")
        asserts.eq(cooldown:toString(), tostring(cooldown))
    end)
end)

test.suite("mutability", function(suite)
    suite:case("Cooldowns are not frozen", function(asserts)
        asserts.eq(false, table.isfrozen(Cooldown.new(secs(1))))
    end)

    suite:case("the Cooldown module is frozen", function(asserts)
        asserts.eq(true, table.isfrozen(Cooldown))
    end)

    suite:case("Cooldowns are independent", function(asserts)
        local clock = fakeClock()
        local a = Cooldown.new(secs(5), { clock = clock.fn })
        local b = Cooldown.new(secs(5), { clock = clock.fn })
        a:tryUse("key")
        asserts.eq(false, a:isReady("key"))
        asserts.eq(true, b:isReady("key"))
    end)
end)
