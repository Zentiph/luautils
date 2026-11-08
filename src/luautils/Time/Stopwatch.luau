--!strict

-- Stopwatch type
-- by @vuppyan

local Core = require("../Core")
type Supplier<T> = Core.Supplier<T>
type TupleFactory<T..., A...> = Core.TupleFactory<T..., A...>

local Duration = require("./Duration")
type Duration = Duration.Duration

local fail = Core.Errors.errorWithScope("Stopwatch")

--[=[
    A class for performing timings.

    `Stopwatch` is not thread-safe.

    @class Stopwatch
]=]
local Stopwatch = {}
Stopwatch.__index = Stopwatch

type StopwatchData = {
    read _clock: Supplier<number>,
    _startedAt: number?, -- clock reading when last started; nil if stopped
    _accumulated: Duration, -- running time from all finished intervals
    _lapMark: Duration, -- elapsed() at the last lap
}

export type Stopwatch = typeof(setmetatable({} :: StopwatchData, Stopwatch))

--[=[
    Creates a new `Stopwatch` that is stopped and at zero.

    @param clock Supplier<number>? -- The clock function to use (defaults to `os.clock`)
    @return Stopwatch -- The new `Stopwatch`
]=]
function Stopwatch.new(clock: Supplier<number>?): Stopwatch
    return setmetatable({
        _clock = clock or os.clock,
        _startedAt = nil,
        _accumulated = Duration.ZERO,
        _lapMark = Duration.ZERO,
    }, Stopwatch)
end

--[=[
    Creates an already running `Stopwatch` at zero.

    @param clock Supplier<number>? -- The clock function to use (defaults to `os.clock`)
    @return Stopwatch -- The new `Stopwatch`
]=]
function Stopwatch.startNew(clock: Supplier<number>?): Stopwatch
    local usedClock = clock or os.clock
    return setmetatable({
        _clock = usedClock,
        _startedAt = usedClock(),
        _accumulated = Duration.ZERO,
        _lapMark = Duration.ZERO,
    }, Stopwatch)
end

-- function Stopwatch.measure<A..., R...>(fn: TupleFactory<R..., A...>, ...: A...): (Duration, R...)
--     local stopwatch = Stopwatch.startNew()
--     local results = table.pack(fn(...))
--     return stopwatch:elapsed(), table.unpack(results)
-- end

--[=[
    Returns whether the given value is a `Stopwatch`.

    Only values created by `Stopwatch` functions are considered `Stopwatch`s;
    tables with the same fields are not.

    @param value any -- The value to check
    @return boolean -- Whether the given value is a `Stopwatch`
]=]
function Stopwatch.is(value: any): boolean
    return getmetatable(value) == Stopwatch
end

return table.freeze(Stopwatch)
