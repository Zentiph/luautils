--!strict

-- Stopwatch type
-- by @vuppyan

local Core = require("../Core")
type Supplier<T> = Core.Supplier<T>
type TupleFactory<T..., A...> = Core.TupleFactory<T..., A...>

local Duration = require("./Duration")
type Duration = Duration.Duration

-- rename to "fail" if ever used
local _fail = Core.Errors.errorWithScope("Stopwatch")

--[=[
    A mutable stopwatch for measuring elapsed time, which can be started,
    stopped, and lapped.

    Time accumulates across every interval the `Stopwatch` runs for, and does
    not count while it is stopped. Readings come from a clock function, which
    is `os.clock` by default and can be swapped out through [Stopwatch.new].
    If the clock ever goes backwards, the affected interval counts as zero
    rather than negative.

    Unlike `Duration`s, `Stopwatch`s are not frozen, and their methods modify
    them in place.

    Supports `tostring()`.

    ```lua
    local stopwatch = Stopwatch.startNew()
    doWork()
    stopwatch:stop()
    doUntimedWork() -- not counted
    stopwatch:start()
    doMoreWork()
    print(stopwatch:elapsed():toHumanString()) -- e.g. "1s 250ms"
    ```

    @tag mutable
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

    The clock function should return the current time in seconds, and should
    not go backwards.
    Common choices are:
    * `os.clock` for local elapsed time (the default)
    * `os.time` for Unix seconds with whole-second precision
    * `function() return Workspace:GetServerTimeNow() end` for time
      synchronized between client and server

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
    Creates a new `Stopwatch` that starts running from zero.

    Equivalent to calling [Stopwatch.new] followed by [Stopwatch:start].

    @param clock Supplier<number>? -- The clock function to use (defaults to `os.clock`)
    @return Stopwatch -- The new `Stopwatch`
]=]
function Stopwatch.startNew(clock: Supplier<number>?): Stopwatch
    local stopwatch = Stopwatch.new(clock)
    stopwatch:start()
    return stopwatch
end

--[=[
    Starts (or resumes) this `Stopwatch`, keeping the time accumulated so far.

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
    Stops (pauses) this `Stopwatch`, adding the current interval to its total.

    The accumulated time is kept, so calling [Stopwatch:start] resumes from
    where it left off. Does nothing if this `Stopwatch` is already stopped.

    @method stop
    @within Stopwatch
]=]
function Stopwatch.stop(self: Stopwatch): ()
    if self._startedAt ~= nil then
        self._accumulated += Duration.between(self._startedAt, self._clock())
            :max(Duration.ZERO)
        self._startedAt = nil
    end
end

--[=[
    Resets this `Stopwatch` to zero, stopping it if it is running.

    This also clears the last lap, so the next [Stopwatch:lap] measures from
    zero.

    @method reset
    @within Stopwatch
]=]
function Stopwatch.reset(self: Stopwatch): ()
    self._startedAt = nil
    self._accumulated = Duration.ZERO
    self._lapMark = Duration.ZERO
end

--[=[
    Resets this `Stopwatch` to zero, and then starts it again.

    Equivalent to calling [Stopwatch:reset] followed by [Stopwatch:start].

    @method restart
    @within Stopwatch
]=]
function Stopwatch.restart(self: Stopwatch): ()
    self._startedAt = self._clock()
    self._accumulated = Duration.ZERO
    self._lapMark = Duration.ZERO
end

--[=[
    Returns the total time this `Stopwatch` has been running, including the
    current interval if it is running.

    Time spent stopped is not counted.

    @method elapsed
    @within Stopwatch
    @return Duration -- The total running time
]=]
function Stopwatch.elapsed(self: Stopwatch): Duration
    local interval = if self._startedAt ~= nil
        then Duration.between(self._startedAt, self._clock()):max(Duration.ZERO)
        else Duration.ZERO
    return interval + self._accumulated
end

--[=[
    Returns whether this `Stopwatch` is running.

    @method isRunning
    @within Stopwatch
    @return boolean -- Whether this `Stopwatch` is running
]=]
function Stopwatch.isRunning(self: Stopwatch): boolean
    return self._startedAt ~= nil
end

--[=[
    Returns the running time since the last call to [Stopwatch:lap], and marks
    a new lap.

    The first lap is measured from when this `Stopwatch` was created, reset,
    or restarted. Like [Stopwatch:elapsed], laps only count running time, so
    time spent stopped is not included in any lap. This method does not stop
    or start this `Stopwatch`.

    ```lua
    local stopwatch = Stopwatch.startNew()
    -- 1 second later
    stopwatch:lap() -- 1 second
    -- 2 seconds later
    stopwatch:lap() -- 2 seconds
    -- 1 second later
    stopwatch:lap() -- 1 second
    ```

    @method lap
    @within Stopwatch
    @return Duration -- The running time since the last lap
]=]
function Stopwatch.lap(self: Stopwatch): Duration
    local now = self:elapsed()
    self._lapMark = now - self._lapMark
    return self._lapMark
end

--[=[
    Calls `fn` with the given arguments, returning how long it took to run,
    followed by all of its return values.

    The time is always measured with `os.clock`, not a custom clock. Errors
    thrown by `fn` are not caught; use [Result.try] to catch them.

    ```lua
    local elapsed, sum = Stopwatch.measure(function(a, b)
        return a + b
    end, 1, 2)
    print(elapsed:toHumanString(), sum) -- e.g. "0ms" 3
    ```

    @param fn TupleFactory<R..., A...> -- The function to call
    @param ... A... -- The arguments to pass to `fn`
    @return Duration -- How long `fn` took to run
    @return R... -- The values returned by `fn`
]=]
function Stopwatch.measure<A..., R...>(
    fn: TupleFactory<R..., A...>,
    ...: A...
): (Duration, R...)
    local start = os.clock()
    local results = table.pack(fn(...) :: any)
    local elapsed = Duration.between(start, os.clock()):max(Duration.ZERO)
    return elapsed, table.unpack(results, 1, results.n)
end

--[=[
    Returns whether the given value is a `Stopwatch`.

    Only values created by `Stopwatch` functions are considered `Stopwatch`s;
    tables with the same fields are not.

    @param value any -- The value to check
    @return boolean -- Whether the value is a `Stopwatch`
]=]
function Stopwatch.is(value: any): boolean
    return getmetatable(value) == Stopwatch
end

--[=[
    Returns the elapsed time of this `Stopwatch` as a human-readable string.

    The time is formatted with [Duration:toHumanString], followed by
    `" (running)"` if this `Stopwatch` is running.

    Also used by `tostring()`.

    ```lua
    local stopwatch = Stopwatch.startNew()
    -- 1.25 seconds later
    stopwatch:toString() -- "1s 250ms (running)"
    stopwatch:stop()
    tostring(stopwatch) -- "1s 250ms"
    ```

    @method toString
    @within Stopwatch
    @return string -- The human-readable string
]=]
function Stopwatch.toString(self: Stopwatch): string
    return self:elapsed():toHumanString()
        .. if self:isRunning() then " (running)" else ""
end
Stopwatch.__tostring = Stopwatch.toString

return table.freeze(Stopwatch)
