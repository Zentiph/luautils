--!strict

-- Duration type
-- by @vuppyan

local Core = require("../Core")

local fail = require("../_internal").Errors.errorWithScope("Duration")

-- TODO: add enum creators with type support
-- TODO: other oop tools like "final class" metatable locking, easy interface checking, etc

--- A fixed-length span of time with nanosecond precision and no upper bound.
---
--- Internally, a `Duration` is represented by two `number` fields. The first
--- represents whole seconds with any sign, unbounded. The second represents a
--- nanosecond adjustment in [0, 999_999_999], which is always non-negative,
--- since the sign of the `Duration` lives in the seconds field. This avoids
--- float64 mantissa loss, as a single `number` storing nanoseconds loses
--- precision beyond ~104 days. Splitting into seconds and nanoseconds gives
--- exact time arithmetic at both scales without any practical upper limit.
---
--- Supports `==` and `~=` comparison, `tostring()`, `+`, `-`, `//`, and `%`
--- arithmetic with other `Duration`s, `*` and `/` arithmetic with a scalar, and
--- `-` negation.
---
--- @class Duration
local Duration = {}
Duration.__index = Duration

type DurationData = {
    read _secs: number,
    read _nanos: number,
}

--- A fixed-length span of time.
---
--- @type Duration Duration
--- @within Duration
export type Duration = typeof(setmetatable({} :: DurationData, Duration))

-- TODO: if possible add typing helpers like OptionalTable<> that turns a
-- table with components like a: number, b: string into a: number?, b: string?

--- An input set of parts in a `Duration`.
---
--- All fields are optional, and will default to 0 (or false, in `negative`'s
--- case).
---
--- @type TimePartsI
--- @within Duration
export type TimePartsI = {
    negative: boolean?,
    days: number?,
    hours: number?,
    minutes: number?,
    seconds: number?,
    millis: number?,
    micros: number?,
    nanos: number?,
}

--- An output set of parts in a `Duration`.
---
--- @type TimePartsO
--- @within Duration
export type TimePartsO = {
    negative: boolean,
    days: number,
    hours: number,
    minutes: number,
    seconds: number,
    millis: number,
    micros: number,
    nanos: number,
}

--- A unit of time that can be used in human-readable string formatting.
---
--- @type HumanStringUnit
--- @within Duration
export type HumanStringUnit =
    "days"
    | "hours"
    | "minutes"
    | "seconds"
    | "millis"

--- Options for `Duration:toHumanString()`.
---
--- @interface HumanStringOptions
--- @within Duration
--- @field maxUnits number? -- How many units to show, from the largest non-zero one (defaults to all)
--- @field smallestUnit HumanStringUnit? -- The smallest unit to show (defaults to "millis")
export type HumanStringOptions = {
    maxUnits: number?,
    smallestUnit: HumanStringUnit?,
}

local NANOS_MIN = 0
local NANOS_MAX = 999_999_999

-- TODO: maybe extract these to a separate time constants file where it makes sense?
local NANOS_PER_MICRO = 1_000
local NANOS_PER_MILLI = 1_000_000
local NANOS_PER_SECOND = 1_000_000_000
local MICROS_PER_MILLI = 1_000
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3_600
local SECONDS_PER_DAY = 86_400
local SECONDS_PER_WEEK = 604_800
local MINUTES_PER_HOUR = 60
local HOURS_PER_DAY = 24

local DATE_UNITS: { [string]: { rank: number, secs: number } } = {
    W = { rank = 1, secs = SECONDS_PER_WEEK },
    D = { rank = 2, secs = SECONDS_PER_DAY },
}
local TIME_UNITS: { [string]: { rank: number, secs: number } } = {
    H = { rank = 3, secs = SECONDS_PER_HOUR },
    M = { rank = 4, secs = SECONDS_PER_MINUTE },
    S = { rank = 5, secs = 1 },
}

local HUMAN_UNITS: { { name: HumanStringUnit, suffix: string } } = {
    { name = "days", suffix = "d" },
    { name = "hours", suffix = "h" },
    { name = "minutes", suffix = "m" },
    { name = "seconds", suffix = "s" },
    { name = "millis", suffix = "ms" },
}

local MAX_SAFE_INT = 2 ^ 53

-- Helper for normalizing seconds and nanoseconds to their expected ranges
local function normalize(secs: number, nanos: number): (number, number)
    local fracSecs = secs % 1
    secs -= fracSecs
    nanos = math.round(nanos + fracSecs * NANOS_PER_SECOND)

    local carry = math.floor(nanos / NANOS_PER_SECOND)
    return secs + carry, nanos - carry * NANOS_PER_SECOND
end

local function truncateTowardZero(x: number): number
    return if x >= 0 then math.floor(x) else math.ceil(x)
end

-- Splits a Duration into its sign and non-negative seconds/nanoseconds
local function toMagnitude(self: Duration): (number, number, number)
    if self._secs >= 0 then
        return 1, self._secs, self._nanos
    elseif self._nanos == 0 then
        return -1, -self._secs, 0
    end
    return -1, -self._secs - 1, NANOS_PER_SECOND - self._nanos
end

local function signedPart(sign: number, part: number): number
    return sign * part + 0 -- + 0 to handle -0
end

-- Exactly computes `n * k` for integers 0 <= n < 1e9 and 0 <= k < 2^53.
-- Returns (carry, rem) such that n * k == carry * 1e9 + rem, 0 <= rem < 1e9.
-- The full product can reach ~2^83, so it's never formed directly.
-- Every intermediate value below stays under 2^53.
local function mulNanos(n: number, k: number): (number, number)
    local kHi = k // NANOS_PER_SECOND -- < 2^53 / 1e9 ~= 9.007e6
    local kLo = k - kHi * NANOS_PER_SECOND -- < 1e9

    -- n * kHi * 1e9 is exactly n * kHi whole seconds
    local carry = n * kHi -- < 1e9 * 9.007e6 ~= 9.007e15 < 2^53

    -- n * kLo can reach 1e18, so split kLo = a * 1e5 + b
    local a = kLo // 100_000 -- < 1e4
    local b = kLo - a * 100_000 -- < 1e5
    local x = n * a -- < 1e13
    local y = n * b -- < 1e14

    -- n * kLo = x * 1e5 + y, and x * 1e5 = (x // 1e4) * 1e9 + (x % 1e4) * 1e5
    carry += x // 10_000
    local rest = (x % 10_000) * 100_000 + y -- < 1e9 + 1e14
    carry += rest // NANOS_PER_SECOND
    return carry, rest % NANOS_PER_SECOND
end

-- Exactly computes (secs, nanos) * k for an integer k with |k| < 2^53.
-- Returns unnormalized (secs, nanos), meant to be passed to Duration.new().
-- Exact as long as the resulting seconds stay below 2^53.
local function mulExact(
    secs: number,
    nanos: number,
    k: number
): (number, number)
    local sign = if k < 0 then -1 else 1
    local carry, rem = mulNanos(nanos, math.abs(k))
    -- nanos * k == sign * (carry seconds + rem nanoseconds)
    return secs * k + sign * carry, sign * rem
end

-- Exact floored division returning (q, r) where a == b * q + r where r has the
-- sign of b, and |r| < |b|. Assumes b is non-zero.
local function divModFloor(
    a: Duration,
    b: Duration,
    functionName: string
): (number, Duration)
    -- float estimate; only off by a few for any representable quotient
    local q = math.floor(a:toSeconds() / b:toSeconds())
    if math.abs(q) >= MAX_SAFE_INT then
        fail("Quotient is too large to be represented exactly", 3, functionName)
    end

    -- exact remainder for the estimate, then step q until r is in range
    local r = a:minus(b:times(q))
    if b:isPositive() then
        -- want 0 <= r < b
        while r:isNegative() do
            q -= 1
            r = r:plus(b)
        end
        while r:compareTo(b) >= 0 do
            q += 1
            r = r:minus(b)
        end
    else
        -- want b < r <= 0
        while r:isPositive() do
            q -= 1
            r = r:plus(b)
        end
        while r:compareTo(b) <= 0 do
            q += 1
            r = r:minus(b)
        end
    end
    -- add 0 to handle -0
    return q + 0, r
end

-- Exact truncated division returning (q, r) where a == b * q + r where r has
-- the sign of a, and |r| < |b|. Assumes b is non-zero.
local function divModTruncated(
    a: Duration,
    b: Duration,
    functionName: string
): (number, Duration)
    local q, r = divModFloor(a, b, functionName)
    -- floor and truncation only differ when the exact quotient is negative and
    -- not whole; there's a remainder, and a and b have opposite signs
    if not r:isZero() and a:isNegative() ~= b:isNegative() then
        q += 1
        r = r:minus(b)
    end
    return q, r
end

local function assertDuration(
    value: any,
    operation: string,
    functionName: string
): Duration
    if not Duration.is(value) then
        fail(
            `Attempted to perform {operation} on a non-Duration value: {value}`,
            3,
            functionName
        )
    end
    return value :: Duration
end

-- Helper for generating Duration.parse()/tryParse() error messages
local function parseErrMsg(input: string, pos: number, reason: string): string
    return `Invalid ISO-8601 duration: "{input}" ({reason} at position {pos})`
end

-- TODO: handling for NaN or +/- infinity passed to constructors or
-- times or dividedBy

--- Creates a new `Duration` from the specified number of seconds and
--- additional nanoseconds.
---
--- Fractional seconds will be split into seconds and nanoseconds. Fractional
--- nanoseconds will be rounded. If the number of nanoseconds is greater than 1
--- billion (the number of nanoseconds in a second), then it will carry over
--- into the seconds provided.
---
--- @param secs number -- The number of seconds
--- @param nanos number -- The number of nanoseconds
--- @return Duration -- The new `Duration`
function Duration.new(secs: number, nanos: number): Duration
    if math.isnan(secs) or math.isnan(nanos) then
        fail("Cannot create a Duration from NaN values")
    end
    if math.isinf(secs) or math.isinf(nanos) then
        fail("Infinite durations are not yet supported")
    end

    local s, n = normalize(secs, nanos)
    return table.freeze(setmetatable({ _secs = s, _nanos = n }, Duration))
end

--- A duration of zero time.
---
--- @prop ZERO Duration
--- @within Duration
Duration.ZERO = Duration.new(0, 0)

--- A duration of one nanosecond.
---
--- @prop NANOSECOND Duration
--- @within Duration
Duration.NANOSECOND = Duration.new(0, 1)

--- A duration of one microsecond.
---
--- @prop MICROSECOND Duration
--- @within Duration
Duration.MICROSECOND = Duration.new(0, NANOS_PER_MICRO)

--- A duration of one millisecond.
---
--- @prop MILLISECOND Duration
--- @within Duration
Duration.MILLISECOND = Duration.new(0, NANOS_PER_MILLI)

--- A duration of one second.
---
--- @prop SECOND Duration
--- @within Duration
Duration.SECOND = Duration.new(1, 0)

--- A duration of one minute.
---
--- @prop MINUTE Duration
--- @within Duration
Duration.MINUTE = Duration.new(SECONDS_PER_MINUTE, 0)

--- A duration of one hour.
---
--- @prop HOUR Duration
--- @within Duration
Duration.HOUR = Duration.new(SECONDS_PER_HOUR, 0)

--- A duration of one day.
---
--- @prop DAY Duration
--- @within Duration
Duration.DAY = Duration.new(SECONDS_PER_DAY, 0)

--- A duration of one week.
---
--- @prop WEEK Duration
--- @within Duration
Duration.WEEK = Duration.new(SECONDS_PER_WEEK, 0)

--- Creates a new `Duration` from the specified number of nanoseconds.
---
--- @param nanos number -- The number of nanoseconds
--- @return Duration -- The new `Duration`
function Duration.fromNanos(nanos: number): Duration
    return Duration.new(0, nanos)
end

--- Creates a new `Duration` from the specified number of microseconds.
---
--- @param micros number -- The number of microseconds
--- @return Duration -- The new `Duration`
function Duration.fromMicros(micros: number): Duration
    return Duration.new(0, micros * NANOS_PER_MICRO)
end

--- Creates a new `Duration` from the specified number of milliseconds.
---
--- @param millis number -- The number of milliseconds
--- @return Duration -- The new `Duration`
function Duration.fromMillis(millis: number): Duration
    return Duration.new(0, millis * NANOS_PER_MILLI)
end

--- Creates a new `Duration` from the specified number of seconds.
---
--- @param secs number -- The number of seconds
--- @return Duration -- The new `Duration`
function Duration.fromSeconds(secs: number): Duration
    return Duration.new(secs, 0)
end

--- Creates a new `Duration` from the specified number of minutes.
---
--- @param minutes number -- The number of minutes
--- @return Duration -- The new `Duration`
function Duration.fromMinutes(minutes: number): Duration
    return Duration.new(minutes * SECONDS_PER_MINUTE, 0)
end

--- Creates a new `Duration` from the specified number of hours.
---
--- @param hours number -- The number of hours
--- @return Duration -- The new `Duration`
function Duration.fromHours(hours: number): Duration
    return Duration.new(hours * SECONDS_PER_HOUR, 0)
end

--- Creates a new `Duration` from the specified number of days.
---
--- @param days number -- The number of days
--- @return Duration -- The new `Duration`
function Duration.fromDays(days: number): Duration
    return Duration.new(days * SECONDS_PER_DAY, 0)
end

--- Creates a new `Duration` from the specified number of weeks.
---
--- @param weeks number -- The number of weeks
--- @return Duration -- The new `Duration`
function Duration.fromWeeks(weeks: number): Duration
    return Duration.new(weeks * SECONDS_PER_WEEK, 0)
end

--- Creates a new `Duration` from the specified table of parts.
---
--- Missing parts will be treated as zero, and an empty table will return a
--- `Duration` of zero time.
---
--- Providing negative = true with negative parts will
--- doubly-negate those parts.
---
--- @param parts TimePartsI -- The table of parts
--- @return Duration -- The new `Duration`
function Duration.fromParts(parts: TimePartsI): Duration
    local sign = parts.negative and -1 or 1
    local secs = sign
        * (
            (parts.days or 0) * SECONDS_PER_DAY
            + (parts.hours or 0) * SECONDS_PER_HOUR
            + (parts.minutes or 0) * SECONDS_PER_MINUTE
            + (parts.seconds or 0)
        )
    local nanos = sign
        * (
            (parts.millis or 0) * NANOS_PER_MILLI
            + (parts.micros or 0) * NANOS_PER_MICRO
            + (parts.nanos or 0)
        )
    return Duration.new(secs, nanos)
end

--- Returns the total number of nanoseconds contained by this `Duration`.
---
--- @method toNanos
--- @within Duration
--- @return number -- The total number of nanoseconds
function Duration.toNanos(self: Duration): number
    return self._secs * NANOS_PER_SECOND + self._nanos
end

--- Returns the total number of microseconds contained by this `Duration`.
---
--- @method toMicros
--- @within Duration
--- @return number -- The total number of microseconds
function Duration.toMicros(self: Duration): number
    return self:toNanos() / NANOS_PER_MICRO
end

--- Returns the total number of milliseconds contained by this `Duration`.
---
--- @method toMillis
--- @within Duration
--- @return number -- The total number of milliseconds
function Duration.toMillis(self: Duration): number
    return self:toNanos() / NANOS_PER_MILLI
end

--- Returns the total number of seconds contained by this `Duration`.
---
--- @method toSeconds
--- @within Duration
--- @return number -- The total number of seconds
function Duration.toSeconds(self: Duration): number
    return self._secs + self._nanos / NANOS_PER_SECOND
end

--- Returns the total number of minutes contained by this `Duration`.
---
--- @method toMinutes
--- @within Duration
--- @return number -- The total number of minutes
function Duration.toMinutes(self: Duration): number
    return self:toSeconds() / SECONDS_PER_MINUTE
end

--- Returns the total number of hours contained by this `Duration`.
---
--- @method toHours
--- @within Duration
--- @return number -- The total number of hours
function Duration.toHours(self: Duration): number
    return self:toSeconds() / SECONDS_PER_HOUR
end

--- Returns the total number of days contained by this `Duration`.
---
--- @method toDays
--- @within Duration
--- @return number -- The total number of days
function Duration.toDays(self: Duration): number
    return self:toSeconds() / SECONDS_PER_DAY
end

--- Returns the total number of whole nanoseconds contained by this `Duration`.
---
--- @method wholeNanos
--- @within Duration
--- @return number -- The total number of whole nanoseconds
function Duration.wholeNanos(self: Duration): number
    return truncateTowardZero(self:toNanos())
end

--- Returns the total number of whole microseconds contained by this `Duration`.
---
--- @method wholeMicros
--- @within Duration
--- @return number -- The total number of whole microseconds
function Duration.wholeMicros(self: Duration): number
    return truncateTowardZero(self:toMicros())
end

--- Returns the total number of whole milliseconds contained by this `Duration`.
---
--- @method wholeMillis
--- @within Duration
--- @return number -- The total number of whole milliseconds
function Duration.wholeMillis(self: Duration): number
    return truncateTowardZero(self:toMillis())
end

--- Returns the total number of whole seconds contained by this `Duration`.
---
--- @method wholeSeconds
--- @within Duration
--- @return number -- The total number of whole seconds
function Duration.wholeSeconds(self: Duration): number
    return truncateTowardZero(self:toSeconds())
end

--- Returns the total number of whole minutes contained by this `Duration`.
---
--- @method wholeMinutes
--- @within Duration
--- @return number -- The total number of whole minutes
function Duration.wholeMinutes(self: Duration): number
    return truncateTowardZero(self:toMinutes())
end

--- Returns the total number of whole hours contained by this `Duration`.
---
--- @method wholeHours
--- @within Duration
--- @return number -- The total number of whole hours
function Duration.wholeHours(self: Duration): number
    return truncateTowardZero(self:toHours())
end

--- Returns the total number of whole days contained by this `Duration`.
---
--- @method wholeDays
--- @within Duration
--- @return number -- The total number of whole days
function Duration.wholeDays(self: Duration): number
    return truncateTowardZero(self:toDays())
end

--- Returns the nanoseconds component of this `Duration`.
---
--- @method nanosPart
--- @within Duration
--- @return number -- The nanoseconds
function Duration.nanosPart(self: Duration): number
    local sign, _, nanos = toMagnitude(self)
    return signedPart(sign, nanos % NANOS_PER_MICRO)
end

--- Returns the microseconds component of this `Duration`.
---
--- @method microsPart
--- @within Duration
--- @return number -- The microseconds
function Duration.microsPart(self: Duration): number
    local sign, _, nanos = toMagnitude(self)
    return signedPart(
        sign,
        math.floor(nanos / NANOS_PER_MICRO) % MICROS_PER_MILLI
    )
end

--- Returns the milliseconds component of this `Duration`.
---
--- @method millisPart
--- @within Duration
--- @return number -- The milliseconds
function Duration.millisPart(self: Duration): number
    local sign, _, nanos = toMagnitude(self)
    return signedPart(sign, math.floor(nanos / NANOS_PER_MILLI))
end

--- Returns the seconds component of this `Duration`.
---
--- @method secondsPart
--- @within Duration
--- @return number -- The seconds
function Duration.secondsPart(self: Duration): number
    local sign, secs = toMagnitude(self)
    return signedPart(sign, secs % SECONDS_PER_MINUTE)
end

--- Returns the minutes component of this `Duration`.
---
--- @method minutesPart
--- @within Duration
--- @return number -- The minutes
function Duration.minutesPart(self: Duration): number
    local sign, secs = toMagnitude(self)
    return signedPart(
        sign,
        math.floor(secs / SECONDS_PER_MINUTE) % MINUTES_PER_HOUR
    )
end

--- Returns the hours component of this `Duration`.
---
--- @method hoursPart
--- @within Duration
--- @return number -- The hours
function Duration.hoursPart(self: Duration): number
    local sign, secs = toMagnitude(self)
    return signedPart(sign, math.floor(secs / SECONDS_PER_HOUR) % HOURS_PER_DAY)
end

--- Returns the days component of this `Duration`.
---
--- @method daysPart
--- @within Duration
--- @return number -- The days
function Duration.daysPart(self: Duration): number
    local sign, secs = toMagnitude(self)
    return signedPart(sign, math.floor(secs / SECONDS_PER_DAY))
end

--- Returns each component of this `Duration` as a table.
---
--- @method toParts
--- @within Duration
--- @return TimePartsO -- The parts
function Duration.toParts(self: Duration): TimePartsO
    return {
        negative = self:isNegative(),
        days = math.abs(self:daysPart()),
        hours = math.abs(self:hoursPart()),
        minutes = math.abs(self:minutesPart()),
        seconds = math.abs(self:secondsPart()),
        millis = math.abs(self:millisPart()),
        micros = math.abs(self:microsPart()),
        nanos = math.abs(self:nanosPart()),
    }
end

--- Returns the seconds and nanoseconds components of this `Duration`.
---
--- @method toSecondsAndNanos
--- @within Duration
--- @return number, number -- The seconds and nanoseconds
function Duration.toSecondsAndNanos(self: Duration): (number, number)
    return self._secs, self._nanos
end

--- Creates a new `Duration` from the specified start time.
---
--- Both parameters passed should use the same clock source:
--- * `os.clock()` for local elapsed time (the default)
--- * `os.time()` for Unix seconds with whole-second precision
--- * `Workspace:GetServerTimeNow()` for ensuring synchronized values between
---   client and server
---
--- @param start number -- The start time
--- @param now number? -- The end time (defaults to `os.clock()`)
--- @return Duration -- The new `Duration`
function Duration.since(start: number, now: number?): Duration
    return Duration.new((now or os.clock()) - start, 0)
end

--- Creates a new `Duration` from the specified start time and end time.
---
--- Both parameters passed should use the same clock source:
--- * `os.clock()` for local elapsed time (the default)
--- * `os.time()` for Unix seconds with whole-second precision
--- * `Workspace:GetServerTimeNow()` for ensuring synchronized values between
---   client and server
---
--- @param start number -- The start time
--- @param stop number -- The end time
--- @return Duration -- The new `Duration`
function Duration.between(start: number, stop: number): Duration
    return Duration.new(stop - start, 0)
end

--- Returns whether this `Duration` is zero.
---
--- @method isZero
--- @within Duration
--- @return boolean -- Whether this `Duration` is zero
function Duration.isZero(self: Duration): boolean
    return self._secs == 0 and self._nanos == 0
end

--- Returns whether this `Duration` is negative.
---
--- @method isNegative
--- @within Duration
--- @return boolean -- Whether this `Duration` is negative
function Duration.isNegative(self: Duration): boolean
    return self._secs < 0
end

--- Returns whether this `Duration` is positive.
---
--- A `Duration` is not positive if it is zero. Use `Duration.isZero` to check
--- for zero.
---
--- @method isPositive
--- @within Duration
--- @return boolean -- Whether this `Duration` is positive
function Duration.isPositive(self: Duration): boolean
    return self._secs > 0 or (self._secs == 0 and self._nanos > 0)
end

--- Returns the result of adding this `Duration` and another.
---
--- @method plus
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The sum
function Duration.plus(self: Duration, other: Duration): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "addition", "plus")
    assertDuration(other, "addition", "plus")

    return Duration.new(self._secs + other._secs, self._nanos + other._nanos)
end
Duration.__add = Duration.plus

--- Returns the result of subtracting another `Duration` from this one.
---
--- @method minus
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The difference
function Duration.minus(self: Duration, other: Duration): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "subtraction", "minus")
    assertDuration(other, "subtraction", "minus")

    return Duration.new(self._secs - other._secs, self._nanos - other._nanos)
end
Duration.__sub = Duration.minus

--- Returns the result of multiplying this `Duration` and a scalar.
---
--- @method times
--- @within Duration
--- @param scalar number -- The scalar
--- @return Duration -- The product
function Duration.times(self: Duration, scalar: number): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "multiplication", "times")
    if type(scalar) ~= "number" then
        fail("Attempted to multiply a Duration by a non-number")
    end

    -- integer scalars take the exact path, while fractional scalars can't be
    -- exact anyway, so they round to the nearest nanosecond through normalize()
    return if scalar % 1 == 0 and math.abs(scalar) < MAX_SAFE_INT
        then Duration.new(mulExact(self._secs, self._nanos, scalar))
        else Duration.new(self._secs * scalar, self._nanos * scalar)
end
Duration.__mul = function(
    durationOrScalar1: Duration | number,
    durationOrScalar2: Duration | number
): Duration
    if Duration.is(durationOrScalar1) then
        -- may fail, but times will handle it
        return (durationOrScalar1 :: Duration):times(durationOrScalar2 :: any)
    elseif Duration.is(durationOrScalar2) then
        -- same as above
        return (durationOrScalar2 :: Duration):times(durationOrScalar1 :: any)
    else
        -- both are numbers, should be unreachable
        error("Unreachable", 2)
    end
end

--- Returns the result of dividing this `Duration` by a scalar, rounded to the
--- nearest nanosecond.
---
--- @method dividedBy
--- @within Duration
--- @param scalar number -- The scalar
--- @return Duration -- The quotient
function Duration.dividedBy(self: Duration, scalar: number): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "division", "dividedBy")
    if type(scalar) ~= "number" then
        fail("Attempted to divide a Duration by a non-number")
    end
    if scalar == 0 then
        fail("Attempted to divide by 0")
    end

    local mag = self:abs()
    local absScalar = math.abs(scalar)
    local q = math.floor(mag._secs / absScalar)
    local rem = (mag._secs - q * absScalar) * NANOS_PER_SECOND + mag._nanos
    local result = Duration.new(q, rem / absScalar)
    return if self:isNegative() ~= (scalar < 0)
        then result:negated()
        else result
end
Duration.__div = Duration.dividedBy

--- Returns how many times another whole `Duration` can fit into this one.
---
--- @method floorDividedBy
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The quotient
function Duration.floorDividedBy(self: Duration, other: Duration): number
    -- type validation for metamethod error handling
    assertDuration(self, "floor division", "floorDividedBy")
    assertDuration(other, "floor division", "floorDividedBy")
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    local q = divModFloor(self, other, "floorDividedBy")
    return q
end
Duration.__idiv = Duration.floorDividedBy

--- Returns the floored remainder of dividing this `Duration` by another, with
--- the sign of `other`.
---
--- @method mod
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The remainder
function Duration.mod(self: Duration, other: Duration): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "modulus", "mod")
    assertDuration(other, "modulus", "mod")
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    local _, r = divModFloor(self, other, "mod")
    return r
end
Duration.__mod = Duration.mod

--- Returns a `Duration` with the opposite sign of this one.
---
--- @method negated
--- @within Duration
--- @return Duration -- The negated `Duration`
function Duration.negated(self: Duration): Duration
    return Duration.new(-self._secs, -self._nanos)
end
Duration.__unm = Duration.negated

--- Returns the truncated quotient of dividing this `Duration` by another.
---
--- @method truncatedDividedBy
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The quotient
function Duration.truncatedDividedBy(self: Duration, other: Duration): number
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    local q = divModTruncated(self, other, "truncatedDividedBy")
    return q
end

--- Returns the truncated remainder of dividing this `Duration` by another, with
--- the sign of `self`.
---
--- @method remainder
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The remainder
function Duration.remainder(self: Duration, other: Duration): Duration
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    local _, r = divModTruncated(self, other, "remainder")
    return r
end

--- Returns the ratio between this `Duration` and another.
---
--- @method ratio
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The ratio
function Duration.ratio(self: Duration, other: Duration): number
    if other:isZero() then
        fail("Attempted to calculate a ratio with a zero Duration")
    end
    return self:toNanos() / other:toNanos()
end

--- Returns the result of subtracting another `Duration` from this one, clamped
--- at zero.
---
--- @method saturatingMinus
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The difference
function Duration.saturatingMinus(self: Duration, other: Duration): Duration
    return if self:compareTo(other) <= 0
        then Duration.ZERO
        else self:minus(other)
end

--- Returns the absolute value of this `Duration`.
---
--- @method abs
--- @within Duration
--- @return Duration -- The absolute value
function Duration.abs(self: Duration): Duration
    local sign = toMagnitude(self)
    return if sign >= 0 then self else self:negated()
end

--- Returns the result of truncating this `Duration` to a multiple of `unit`,
--- toward zero.
---
--- It is generally expected to pass a `Duration` unit constant to `unit`, such
--- as `Duration.SECOND`, but any `Duration` is valid.
---
--- @method truncatedTo
--- @within Duration
--- @param unit Duration -- The unit to truncate to
--- @return Duration -- The truncated `Duration`
function Duration.truncatedTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot truncate using a non-positive unit")
    end
    return unit:times(self:truncatedDividedBy(unit))
end

--- Returns the result of flooring this `Duration` to a multiple of `unit`,
--- toward negative infinity.
---
--- It is generally expected to pass a `Duration` unit constant to `unit`, such
--- as `Duration.SECOND`, but any `Duration` is valid.
---
--- @method flooredTo
--- @within Duration
--- @param unit Duration -- The unit to floor to
--- @return Duration -- The floored `Duration`
function Duration.flooredTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot floor using a non-positive unit")
    end
    return unit:times(self:floorDividedBy(unit))
end

--- Returns the result of ceiling this `Duration` to a multiple of `unit`,
--- toward positive infinity.
---
--- It is generally expected to pass a `Duration` unit constant to `unit`, such
--- as `Duration.SECOND`, but any `Duration` is valid.
---
--- @method ceiledTo
--- @within Duration
--- @param unit Duration -- The unit to ceil to
--- @return Duration -- The ceiled `Duration`
function Duration.ceiledTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot ceil using a non-positive unit")
    end
    -- computes floor(-(x / unit)), which equals -ceil(x / unit)
    -- which is then multiplied by -unit, equalling ceil(x / unit) * unit
    return unit:times(self:floorDividedBy(unit:negated())):negated()
end

--- Returns the result of rounding this `Duration` to the nearest multiple of
--- `unit`.
---
--- Rounding is performed by moving away from zero if the `Duration` is exactly
--- halfway or closer to the next multiple of `unit`.
---
--- It is generally expected to pass a `Duration` unit constant to `unit`, such
--- as `Duration.SECOND`, but any `Duration` is valid.
---
--- @method roundedTo
--- @within Duration
--- @param unit Duration -- The unit to round to
--- @return Duration -- The rounded `Duration`
function Duration.roundedTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot round using a non-positive unit")
    end
    local q = self:truncatedDividedBy(unit)
    local r = self:minus(unit:times(q))
    -- if the remainder's magnitude is at least half the unit,
    -- round away from zero
    if (r:abs():times(2)):compareTo(unit) >= 0 then
        local sign = toMagnitude(self)
        return unit:times(q + sign)
    else
        return unit:times(q)
    end
end

--- Returns whether the given value is a `Duration`.
---
--- @param value any -- The value to check
--- @return boolean -- Whether the value is a `Duration`
function Duration.is(value: any): boolean
    return getmetatable(value) == Duration
end

--- Returns `true` if both `Duration`s represent the same span of time.
---
--- @method equals
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return boolean -- Whether the two `Duration`s are equal
function Duration.equals(self: Duration, other: Duration): boolean
    return Duration.is(other)
        and self._secs == other._secs
        and self._nanos == other._nanos
end
Duration.__eq = Duration.equals

--- Compares two `Duration`s with total ordering, returning -1 if `self` is
--- "less than" `other`, 0 if they are equal, and 1 if `self` is "greater than"
--- `other`.
---
--- @method compareTo
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The result of the comparison
function Duration.compareTo(self: Duration, other: Duration): number
    -- type validation for metamethod error handling
    assertDuration(self, "comparison", "compareTo")
    assertDuration(other, "comparison", "compareTo")

    return if self._secs < other._secs
        then -1
        elseif self._secs > other._secs then 1
        elseif self._nanos < other._nanos then -1
        elseif self._nanos > other._nanos then 1
        else 0
end
Duration.__lt = function(self: Duration, other: Duration): boolean
    return self:compareTo(other) < 0
end
Duration.__le = function(self: Duration, other: Duration): boolean
    return self:compareTo(other) <= 0
end

--- Returns the smaller of `self` and `other`.
---
--- @method min
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The smaller of `self` and `other`
function Duration.min(self: Duration, other: Duration): Duration
    return if self:compareTo(other) <= 0 then self else other
end

--- Returns the larger of `self` and `other`.
---
--- @method max
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The larger of `self` and `other`
function Duration.max(self: Duration, other: Duration): Duration
    return if self:compareTo(other) >= 0 then self else other
end

--- Returns the result of clamping `self` between `min` and `max`.
---
--- @method clamp
--- @within Duration
--- @param min Duration -- The minimum `Duration`
--- @param max Duration -- The maximum `Duration`
--- @return Duration -- The clamped `Duration`
function Duration.clamp(self: Duration, min: Duration, max: Duration): Duration
    if min:compareTo(max) > 0 then
        fail("Clamp value min must be less than or equal to max")
    end
    return self:min(max):max(min)
end

--- Creates a new `Duration` from an ISO 8601 duration string.
---
--- @param s string -- The ISO 8601 duration string
--- @return Duration -- The new `Duration`
--- @error "Failed to parse duration" -- If the string could not be parsed
function Duration.parse(s: string): Duration
    local res = Duration.tryParse(s)
    if res:isErr() then
        fail(
            `Failed to parse duration: {res:unwrapErr()}`
                .. ". If you are working with potentially malformed strings, "
                .. "use Duration.tryParse() instead."
        )
    end
    return res:unwrap()
end

--- Tries to create a new `Duration` from an ISO 8601 duration string.
---
--- @param s string -- The ISO 8601 duration string
--- @return Core.Result<Duration, string> -- The result of parsing the string
function Duration.tryParse(s: string): Core.Result<Duration, string>
    local str = string.upper(s)
    local pos = 1
    local negative = false

    local first = string.sub(str, 1, 1)
    if first == "-" or first == "+" then
        negative = first == "-"
        pos += 1
    end
    if string.sub(str, pos, pos) ~= "P" then
        return Core.Result.err(parseErrMsg(s, pos, "missing 'P' prefix"))
    end
    pos += 1

    local secs = 0
    local nanos = 0
    local inTime = false
    local lastRank = 0

    while pos <= #str do
        if string.sub(str, pos, pos) == "T" then
            if inTime then
                return Core.Result.err(
                    parseErrMsg(s, pos, "repeated 'T' prefix")
                )
            end
            inTime = true
            pos += 1
            continue
        end

        -- digits, optional decimal separator + digits,
        -- unit letter, end position
        local whole, sep, frac, unit, nextPos =
            string.match(str, "^(%d+)([%.,]?)(%d*)(%a)()", pos)
        if not whole or not sep or not frac or not unit or not nextPos then
            return Core.Result.err(
                parseErrMsg(s, pos, "expected a number and unit")
            )
        end

        local info = (if inTime then TIME_UNITS else DATE_UNITS)[unit]
        if not info then
            if not inTime and (unit == "Y" or unit == "M") then
                return Core.Result.err(
                    parseErrMsg(s, pos, "years and months have no fixed length")
                )
            end
            local where = if inTime then "after" else "before"
            return Core.Result.err(
                parseErrMsg(s, pos, `'{unit}' is not valid {where} 'T'`)
            )
        end

        if info.rank <= lastRank then
            return Core.Result.err(
                parseErrMsg(s, pos, `{unit} is repeated or out of order`)
            )
        end
        if sep ~= "" then
            if unit ~= "S" then
                return Core.Result.err(
                    parseErrMsg(s, pos, "only seconds may be fractional")
                )
            elseif frac == "" then
                return Core.Result.err(
                    parseErrMsg(
                        s,
                        pos,
                        "missing digits after decimal separator"
                    )
                )
            end
        end

        lastRank = info.rank
        -- safe :: number cast; whole was validated by string.match
        secs += (tonumber(whole) :: number) * info.secs
        if frac ~= "" then
            -- pad/truncate to 9 digits so the fraction parses as nanos
            -- (another safe cast due to string.match)
            nanos = tonumber(string.sub(frac .. "000000000", 1, 9)) :: number
        end
        pos = nextPos
    end

    if lastRank == 0 then
        return Core.Result.err(parseErrMsg(s, pos, "no components"))
    end
    if inTime and lastRank < TIME_UNITS.H.rank then
        return Core.Result.err(
            parseErrMsg(s, pos, "'T' must be followed by a time component")
        )
    end

    local duration = if negative
        then Duration.new(-secs, -nanos)
        else Duration.new(secs, nanos)
    return Core.Result.ok(duration)
end

--- Converts this `Duration` to an ISO 8601 duration string.
---
--- @method toString
--- @within Duration
--- @return string -- The ISO 8601 duration string
function Duration.toString(self: Duration): string
    if self:isZero() then
        return "PT0S"
    end

    local negative = self:isNegative()
    local mag = self:abs()
    local secs = mag._secs
    local nanos = mag._nanos

    local d = math.floor(secs / SECONDS_PER_DAY)
    secs %= SECONDS_PER_DAY
    local h = math.floor(secs / SECONDS_PER_HOUR)
    secs %= SECONDS_PER_HOUR
    local m = math.floor(secs / SECONDS_PER_MINUTE)
    secs %= SECONDS_PER_MINUTE

    local result = (negative and "-" or "") .. "P"
    if d > 0 then
        result ..= string.format("%.0f", d) .. "D"
    end

    local t = ""
    if h > 0 then
        t ..= string.format("%.0f", h) .. "H"
    end
    if m > 0 then
        t ..= string.format("%.0f", m) .. "M"
    end

    if secs > 0 or nanos > 0 then
        if nanos == 0 then
            t ..= string.format("%.0f", secs) .. "S"
        else
            local fracStr = string.format("%09d", nanos):gsub("0+$", "")
            t ..= string.format("%.0f", secs) .. "." .. fracStr .. "S"
        end
    end

    if t ~= "" then
        result ..= "T" .. t
    end
    if result == "P" or result == "-P" then
        return "PT0S"
    end
    return result
end
Duration.__tostring = Duration.toString

--- Formats this `Duration` using the given pattern.
---
--- Allowed format specifiers are:
--- * %d - total days
--- * %H - hours (0-23)
--- * %M - minutes (0-59)
--- * %S - seconds (0-59)
--- * %f - milliseconds (0-999)
--- * %% - literal '%'
---
--- An optional zero-pad width may follow the '%' (e.g. '%02H'). Negative
--- `Duration`s are prefixed with a single '-'.
---
--- @method format
--- @within Duration
--- @param pattern string -- The pattern
--- @return string -- The formatted string
function Duration.format(self: Duration, pattern: string): string
    local mag = self:abs()
    local values = {
        d = math.floor(mag._secs / SECONDS_PER_DAY),
        H = math.floor(mag._secs % SECONDS_PER_DAY / SECONDS_PER_HOUR),
        M = math.floor(mag._secs % SECONDS_PER_HOUR / SECONDS_PER_MINUTE),
        S = mag._secs % SECONDS_PER_MINUTE,
        f = math.floor(mag._nanos / NANOS_PER_MILLI),
    }

    local result = string.gsub(
        pattern,
        "%%(%d*.)",
        function(token: string): string
            local spec = string.sub(token, -1)
            local width = string.sub(token, 1, -2)

            if spec == "%" then
                return "%"
            end
            local value = values[spec]
            if value == nil then
                fail(`Unknown specifier '%{spec}'`, 4, "format")
            end
            return string.format(`%0{width}.0f`, value)
        end
    )

    return if self:isNegative() then "-" .. result else result
end

--- Converts this `Duration` to a human-readable string, like
--- '2d 12h 18m 5s 123ms'.
---
--- Units smaller than `options.smallestUnit` are omitted, not rounded.
---
--- Zero-valued components are not included.
---
--- @method toHumanString
--- @within Duration
--- @param options HumanStringOptions? -- The options to apply (defaults to `{ maxUnits = math.huge, smallestUnit = "millis" }`)
--- @return string -- The human-readable string
function Duration.toHumanString(
    self: Duration,
    options: HumanStringOptions?
): string
    local maxUnits = options and options.maxUnits or math.huge
    local smallestUnit = options and options.smallestUnit or "millis"

    if maxUnits <= 0 or maxUnits % 1 ~= 0 then
        fail("Max units should be a positive integer")
    end

    local parts = self:toParts() :: any -- indexed by unit name
    local pieces = {}
    local windowUsed = 0
    local smallestSuffix = "ms"

    for _, unit in HUMAN_UNITS do
        local value = parts[unit.name]
        -- the window starts at the first non-zero unit
        if windowUsed > 0 or value > 0 then
            windowUsed += 1
            if value > 0 then
                table.insert(pieces, `{value}{unit.suffix}`)
            end
        end
        if unit.name == smallestUnit then
            smallestSuffix = unit.suffix
            break
        end
        if windowUsed >= maxUnits then
            break
        end
    end

    if #pieces == 0 then
        return `0{smallestSuffix}`
    end
    local result = table.concat(pieces, " ")
    return if parts.negative then "-" .. result else result
end

--- Converts this `Duration` to a string that can be used as a key in a table.
---
--- An object can be used as a key in a table if instances of that object that
--- are considered "equal" produce identical keys.
---
--- @method toKey
--- @within Duration
--- @return string -- The key
function Duration.toKey(self: Duration): string
    return self:toString()
end

--- Serializes this `Duration` into a `DataStore`-safe data table.
---
--- @method serialize
--- @within Duration
--- @return { secs: number, nanos: number } -- The serialized data
function Duration.serialize(self: Duration): { secs: number, nanos: number }
    return { secs = self._secs, nanos = self._nanos }
end

--- Creates a new `Duration` from a serialized data table.
---
--- This function guarantees to always deserialize valid `Duration`s serialized
--- using Duration:serialize(). Any other method of serialization is not
--- guaranteed to work with deserialization.
---
--- @param data Core.Map<any, any> -- The data table
--- @return Duration -- The new `Duration`
--- @error "Failed to deserialize duration" -- If the data could not be deserialized
function Duration.deserialize(data: Core.Map<any, any>): Duration
    local res = Duration.tryDeserialize(data)
    if res:isErr() then
        fail(
            `Failed to deserialize duration: {res:unwrapErr()}`
                .. ". If you are working with potentially malformed data, "
                .. "use Duration.tryDeserialize() instead."
        )
    end
    return res:unwrap()
end

--- Tries to create a new `Duration` from a serialized data table.
---
--- This function guarantees to always deserialize valid `Duration`s serialized
--- using Duration:serialize(). Any other method of serialization is not
--- guaranteed to work with deserialization.
---
--- @param data Core.Map<any, any> -- The data table
--- @return Core.Result<Duration, string> -- The result of parsing the data
function Duration.tryDeserialize(
    data: Core.Map<any, any>
): Core.Result<Duration, string>
    if type(data) ~= "table" then
        return Core.Result.err("Expected data to be a table")
    end

    local secs = data.secs
    local nanos = data.nanos

    if secs == nil then
        return Core.Result.err("Expected key 'secs' in data table")
    end
    if nanos == nil then
        return Core.Result.err("Expected key 'nanos' in data table")
    end

    if type(secs) ~= "number" then
        return Core.Result.err(
            "Expected key 'secs' to be a number in data table"
        )
    end
    if type(nanos) ~= "number" then
        return Core.Result.err(
            "Expected key 'nanos' to be a number in data table"
        )
    end

    if secs % 1 ~= 0 then
        return Core.Result.err(
            "Expected key 'secs' to be an integer in data table"
        )
    end
    if nanos % 1 ~= 0 then
        return Core.Result.err(
            "Expected key 'nanos' to be an integer in data table"
        )
    end

    if nanos < NANOS_MIN then
        return Core.Result.err(
            "Expected key 'nanos' to be greater than or equal "
                .. `to {NANOS_MIN}, got {nanos}`
        )
    end
    if nanos > NANOS_MAX then
        return Core.Result.err(
            "Expected key 'nanos' to be less than or equal "
                .. `to {NANOS_MAX}, got {nanos}`
        )
    end

    return Core.Result.ok(Duration.new(secs, nanos))
end

return Duration
