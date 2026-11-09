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
    Starts (or resumes) this `Stopwatch`, saving the total accumulated time.

    Does nothing if this `Stopwatch` is already running.

    @method start
    @within Stopwatch
]=]
function Stopwatch.start(self: Stopwatch): ()
    if self._startedAt == nil then
        self._startedAt = self._clock()
    end
end

--[=[
    Pauses this `Stopwatch` and adds the current interval to the total.

    Does nothing if this `Stopwatch` is already stopped.

    @method stop
    @within Stopwatch
]=]
function Stopwatch.stop(self: Stopwatch): ()
    if self._startedAt ~= nil then
        self._accumulated += Duration.between(self._startedAt, self._clock())
        self._startedAt = nil
    end
end

--[=[
    Resets this `Stopwatch` to zero, stopping it if it is running.

    @method reset
    @within Stopwatch
]=]
function Stopwatch.reset(self: Stopwatch): ()
    self._startedAt = nil
    self._accumulated = Duration.ZERO
    self._lapMark = Duration.ZERO
end

--[=[
    Resets this `Stopwatch` back to zero, and then starts it again.

    Equivalent to calling [Stopwatch.reset] followed by [Stopwatch.start].

    @method restart
    @within Stopwatch
]=]
function Stopwatch.restart(self: Stopwatch): ()
    self._startedAt = self._clock()
    self._accumulated = Duration.ZERO
    self._lapMark = Duration.ZERO
end

--[=[
    Returns the total accumulated time of this `Stopwatch` whether it is running
    or stopped.

    @method elapsed
    @within Stopwatch
    @return Duration -- The total accumulated time
]=]
function Stopwatch.elapsed(self: Stopwatch): Duration
    local total = Duration.ZERO
    if self._startedAt ~= nil then
        total += Duration.between(self._startedAt, self._clock())
    end
    return total + self._accumulated
end

--[=[
    Returns whether this `Stopwatch` is running.

    @method isRunning
    @within Stopwatch
]=]
function Stopwatch.isRunning(self: Stopwatch): boolean
    return self._startedAt ~= nil
end

--[=[
    Returns the time elapsed since the last `lap()`, or since starting.

    If called when stopped, this method still returns the time since the last
    lap.

    This method does not stop the stopwatch.

    @method lap
    @within Stopwatch
    @return Duration -- The elapsed time since the last lap
]=]
function Stopwatch.lap(self: Stopwatch): Duration
    if self._startedAt == nil then
        -- if stopped, return the time since last lap
        return self._lapMark
    end

    self._lapMark = Duration.between(self._startedAt, self._clock())
    return self._lapMark
end

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

--[=[
    Returns a string representation of this `Stopwatch`.

    @method toString
    @within Stopwatch
    @return string -- The string representation
]=]
function Stopwatch.toString(self: Stopwatch): string
    return self:elapsed():toHumanString()
        .. if self:isRunning() then " (running)" else ""
end
Stopwatch.__tostring = Stopwatch.toString

return table.freeze(Stopwatch)
