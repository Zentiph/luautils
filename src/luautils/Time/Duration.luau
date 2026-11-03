--!strict

-- Duration type
-- by @vuppyan

local Core = require("../Core")

local fail = require("../_internal").Errors.errorWithScope("Duration")

-- TODO: add enum creators with type support
-- TODO: other oop tools like "final class" metatable locking, easy interface checking, etc
-- TODO: BigNumber class (data type able to represent bigger number values with exact precision)

--- A fixed-length span of time with nanosecond precision and no upper bound.
---
--- Internally, a `Duration` is represented by two `number` fields. The first
--- represents whole seconds with any sign, unbounded. The second represents a
--- nanosecond adjustment in [0, 999_999_999], which is always non-negative,
--- since the sign of the `Duration` lives in the seconds field. This avoids
--- float64 mantissa loss, as a single `number` storing nanoseconds loses
--- precision beyond ~104 days. Splitting into seconds and nanoseconds gives
--- exact time arithmetic at both scales without any practical upper limit.
--- Arithmetic is exact as long as the whole seconds stay below 2^53, and
--- conversions to a single `number`, such as [Duration:toNanos], are subject
--- to the usual float64 precision limits.
---
--- A `Duration` may also be positive or negative infinity (see
--- [Duration.INFINITE]). Infinite `Duration`s have no sub-second component,
--- and operations whose result would be undefined, such as adding infinities
--- with different signs or multiplying infinity by zero, throw. `NaN` is never
--- a valid input.
---
--- `Duration`s are frozen and cannot be modified.
---
--- Supports `==`, `~=`, `<`, `<=`, `>`, and `>=` comparison, `tostring()`,
--- `+`, `-`, `//`, and `%` arithmetic with other `Duration`s, `*` and `/`
--- arithmetic with a scalar, and `-` negation.
---
--- Error messages thrown by `Duration` functions are prefixed with the
--- function that threw them, such as `[Duration.plus()]: `, after the usual
--- position prefix added by `error()`. Operators report the method that backs
--- them, so `a + b` reports `[Duration.plus()]`. Errors thrown by internal
--- calls report the function that threw them, so [Duration.fromMillis] with
--- `NaN` reports `[Duration.new()]`.
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

--- An input set of parts in a `Duration`, used by [Duration.fromParts].
---
--- All fields are optional, and will default to 0 (or false, in `negative`'s
--- case). Parts are not limited to their usual ranges, so `{ hours = 36 }` is
--- the same as `{ days = 1, hours = 12 }`, and they may be fractional or
--- negative.
---
--- @interface TimePartsI
--- @within Duration
--- @field negative boolean? -- Whether to negate the whole `Duration` (defaults to `false`)
--- @field days number? -- The number of days (defaults to 0)
--- @field hours number? -- The number of hours (defaults to 0)
--- @field minutes number? -- The number of minutes (defaults to 0)
--- @field seconds number? -- The number of seconds (defaults to 0)
--- @field millis number? -- The number of milliseconds (defaults to 0)
--- @field micros number? -- The number of microseconds (defaults to 0)
--- @field nanos number? -- The number of nanoseconds (defaults to 0)
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

--- An output set of parts in a `Duration`, returned by [Duration:toParts].
---
--- All parts are non-negative and within their usual ranges (such as 0-23 for
--- `hours`), except `days`, which is unbounded. The sign of the `Duration` is
--- stored in `negative`. For infinite `Duration`s, `days` is `math.huge` and
--- every other part is 0.
---
--- @interface TimePartsO
--- @within Duration
--- @field negative boolean -- Whether the `Duration` is negative
--- @field days number -- The whole days
--- @field hours number -- The hours (0-23)
--- @field minutes number -- The minutes (0-59)
--- @field seconds number -- The seconds (0-59)
--- @field millis number -- The milliseconds (0-999)
--- @field micros number -- The microseconds (0-999)
--- @field nanos number -- The nanoseconds (0-999)
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

--- A unit of time that can be used in human-readable string formatting with
--- [Duration:toHumanString].
---
--- @type HumanStringUnit "days" | "hours" | "minutes" | "seconds" | "millis"
--- @within Duration
export type HumanStringUnit =
    "days"
    | "hours"
    | "minutes"
    | "seconds"
    | "millis"

--- Options for [Duration:toHumanString].
---
--- @interface HumanStringOptions
--- @within Duration
--- @field maxUnits number? -- How many units to show, counting from the largest non-zero one; must be a positive integer or `math.huge` (defaults to all)
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
    if math.isinf(secs) or math.isinf(nanos) then
        if math.isinf(secs) and math.isinf(nanos) and secs ~= nanos then
            fail(
                "Cannot build a Duration from infinities with different signs",
                3,
                "new"
            )
        end
        local sign = if math.isinf(secs)
            then math.sign(secs)
            else math.sign(nanos)
        return sign * math.huge, 0
    end

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

--- Creates a new `Duration` from the specified number of seconds and
--- additional nanoseconds.
---
--- Fractional seconds will be split into seconds and nanoseconds. Fractional
--- nanoseconds will be rounded to the nearest nanosecond, with halves rounded
--- away from zero. Nanoseconds outside of [0, 999_999_999] carry into (or
--- borrow from) the seconds provided, so both arguments may have any sign.
---
--- If either argument is infinite, the result is an infinite `Duration` with
--- that sign.
---
--- ```lua
--- Duration.new(1, 500_000_000) -- 1.5 seconds
--- Duration.new(1, 1_500_000_000) -- 2.5 seconds, since nanoseconds carry
--- Duration.new(2, -500_000_000) -- 1.5 seconds, since nanoseconds borrow
--- Duration.new(1.5, 0) -- 1.5 seconds
--- ```
---
--- @param secs number -- The number of seconds
--- @param nanos number -- The number of nanoseconds
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `secs` or `nanos` is `NaN`
--- @error "[Duration.new()]: Cannot build a Duration from infinities with different signs" -- Thrown if `secs` and `nanos` are infinities with different signs
function Duration.new(secs: number, nanos: number): Duration
    if math.isnan(secs) or math.isnan(nanos) then
        fail("Cannot create a Duration from NaN values")
    end

    local s, n = normalize(secs, nanos)
    return table.freeze(setmetatable({ _secs = s, _nanos = n }, Duration))
end

--- A duration of zero time.
---
--- @prop ZERO Duration
--- @within Duration
--- @readonly
Duration.ZERO = Duration.new(0, 0)

--- A duration of one nanosecond.
---
--- @prop NANOSECOND Duration
--- @within Duration
--- @readonly
Duration.NANOSECOND = Duration.new(0, 1)

--- A duration of one microsecond.
---
--- @prop MICROSECOND Duration
--- @within Duration
--- @readonly
Duration.MICROSECOND = Duration.new(0, NANOS_PER_MICRO)

--- A duration of one millisecond.
---
--- @prop MILLISECOND Duration
--- @within Duration
--- @readonly
Duration.MILLISECOND = Duration.new(0, NANOS_PER_MILLI)

--- A duration of one second.
---
--- @prop SECOND Duration
--- @within Duration
--- @readonly
Duration.SECOND = Duration.new(1, 0)

--- A duration of one minute.
---
--- @prop MINUTE Duration
--- @within Duration
--- @readonly
Duration.MINUTE = Duration.new(SECONDS_PER_MINUTE, 0)

--- A duration of one hour.
---
--- @prop HOUR Duration
--- @within Duration
--- @readonly
Duration.HOUR = Duration.new(SECONDS_PER_HOUR, 0)

--- A duration of one day.
---
--- @prop DAY Duration
--- @within Duration
--- @readonly
Duration.DAY = Duration.new(SECONDS_PER_DAY, 0)

--- A duration of one week.
---
--- @prop WEEK Duration
--- @within Duration
--- @readonly
Duration.WEEK = Duration.new(SECONDS_PER_WEEK, 0)

--- A positive infinite duration.
---
--- For a negative infinite duration, use `-Duration.INFINITE`. Can also be
--- checked for with [Duration:isInf].
---
--- @prop INFINITE Duration
--- @within Duration
--- @readonly
Duration.INFINITE = Duration.new(math.huge, 0)

--- Creates a new `Duration` from the specified number of nanoseconds.
---
--- Fractional nanoseconds are rounded to the nearest nanosecond. Infinite
--- values create an infinite `Duration`.
---
--- @param nanos number -- The number of nanoseconds
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `nanos` is `NaN`
function Duration.fromNanos(nanos: number): Duration
    return Duration.new(0, nanos)
end

--- Creates a new `Duration` from the specified number of microseconds.
---
--- Fractional microseconds are rounded to the nearest nanosecond. Infinite
--- values create an infinite `Duration`.
---
--- @param micros number -- The number of microseconds
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `micros` is `NaN`
function Duration.fromMicros(micros: number): Duration
    return Duration.new(0, micros * NANOS_PER_MICRO)
end

--- Creates a new `Duration` from the specified number of milliseconds.
---
--- Fractional milliseconds are rounded to the nearest nanosecond. Infinite
--- values create an infinite `Duration`.
---
--- @param millis number -- The number of milliseconds
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `millis` is `NaN`
function Duration.fromMillis(millis: number): Duration
    return Duration.new(0, millis * NANOS_PER_MILLI)
end

--- Creates a new `Duration` from the specified number of seconds.
---
--- Fractional seconds are rounded to the nearest nanosecond. Infinite values
--- create an infinite `Duration`.
---
--- @param secs number -- The number of seconds
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `secs` is `NaN`
function Duration.fromSeconds(secs: number): Duration
    return Duration.new(secs, 0)
end

--- Creates a new `Duration` from the specified number of minutes.
---
--- Fractional minutes are rounded to the nearest nanosecond. Infinite values
--- create an infinite `Duration`.
---
--- @param minutes number -- The number of minutes
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `minutes` is `NaN`
function Duration.fromMinutes(minutes: number): Duration
    return Duration.new(minutes * SECONDS_PER_MINUTE, 0)
end

--- Creates a new `Duration` from the specified number of hours.
---
--- Fractional hours are rounded to the nearest nanosecond. Infinite values
--- create an infinite `Duration`.
---
--- @param hours number -- The number of hours
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `hours` is `NaN`
function Duration.fromHours(hours: number): Duration
    return Duration.new(hours * SECONDS_PER_HOUR, 0)
end

--- Creates a new `Duration` from the specified number of days.
---
--- Fractional days are rounded to the nearest nanosecond. Infinite values
--- create an infinite `Duration`.
---
--- @param days number -- The number of days
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `days` is `NaN`
function Duration.fromDays(days: number): Duration
    return Duration.new(days * SECONDS_PER_DAY, 0)
end

--- Creates a new `Duration` from the specified number of weeks.
---
--- Fractional weeks are rounded to the nearest nanosecond. Infinite values
--- create an infinite `Duration`.
---
--- @param weeks number -- The number of weeks
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if `weeks` is `NaN`
function Duration.fromWeeks(weeks: number): Duration
    return Duration.new(weeks * SECONDS_PER_WEEK, 0)
end

--- Creates a new `Duration` from the specified table of parts.
---
--- Missing parts will be treated as zero, and an empty table will return a
--- `Duration` of zero time. Parts may exceed their usual ranges and will carry
--- over, so `{ minutes = 90 }` is the same as `{ hours = 1, minutes = 30 }`.
--- Fractional parts are rounded to the nearest nanosecond.
---
--- `negative = true` negates the sum of all parts, so negative parts with
--- `negative = true` are doubly-negated and become positive.
---
--- ```lua
--- Duration.fromParts({ hours = 1, minutes = 90 }) -- 2 hours 30 minutes
--- Duration.fromParts({ negative = true, minutes = 5 }) -- -5 minutes
--- Duration.fromParts({ negative = true, minutes = -5 }) -- 5 minutes
--- ```
---
--- @param parts TimePartsI -- The table of parts
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if any part is `NaN`, or if infinite parts with different signs are combined
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
--- The result is a single `number`, so it is subject to float64 precision
--- loss beyond ~104 days. Use [Duration:toSecondsAndNanos]
--- for exact values. Returns `math.huge` or `-math.huge` for infinite
--- `Duration`s.
---
--- @method toNanos
--- @within Duration
--- @return number -- The total number of nanoseconds
function Duration.toNanos(self: Duration): number
    return self._secs * NANOS_PER_SECOND + self._nanos
end

--- Returns the total number of microseconds contained by this `Duration`.
---
--- The result may be fractional and is a single `number`, so it is subject to
--- float64 precision loss for very large `Duration`s. Use
--- [Duration:toSecondsAndNanos] for exact values. Returns `math.huge` or
--- `-math.huge` for infinite `Duration`s.
---
--- @method toMicros
--- @within Duration
--- @return number -- The total number of microseconds
function Duration.toMicros(self: Duration): number
    return self:toNanos() / NANOS_PER_MICRO
end

--- Returns the total number of milliseconds contained by this `Duration`.
---
--- The result may be fractional and is a single `number`, so it is subject to
--- float64 precision loss for very large `Duration`s. Use
--- [Duration:toSecondsAndNanos] for exact values. Returns `math.huge` or
--- `-math.huge` for infinite `Duration`s.
---
--- @method toMillis
--- @within Duration
--- @return number -- The total number of milliseconds
function Duration.toMillis(self: Duration): number
    return self:toNanos() / NANOS_PER_MILLI
end

--- Returns the total number of seconds contained by this `Duration`.
---
--- The result may be fractional and is a single `number`, so it is subject to
--- float64 precision loss for very large `Duration`s. Use
--- [Duration:toSecondsAndNanos] for exact values. Returns `math.huge` or
--- `-math.huge` for infinite `Duration`s.
---
--- @method toSeconds
--- @within Duration
--- @return number -- The total number of seconds
function Duration.toSeconds(self: Duration): number
    return self._secs + self._nanos / NANOS_PER_SECOND
end

--- Returns the total number of minutes contained by this `Duration`.
---
--- The result may be fractional and is a single `number`, so it is subject to
--- float64 precision loss for very large `Duration`s. Use
--- [Duration:toSecondsAndNanos] for exact values. Returns `math.huge` or
--- `-math.huge` for infinite `Duration`s.
---
--- @method toMinutes
--- @within Duration
--- @return number -- The total number of minutes
function Duration.toMinutes(self: Duration): number
    return self:toSeconds() / SECONDS_PER_MINUTE
end

--- Returns the total number of hours contained by this `Duration`.
---
--- The result may be fractional and is a single `number`, so it is subject to
--- float64 precision loss for very large `Duration`s. Use
--- [Duration:toSecondsAndNanos] for exact values. Returns `math.huge` or
--- `-math.huge` for infinite `Duration`s.
---
--- @method toHours
--- @within Duration
--- @return number -- The total number of hours
function Duration.toHours(self: Duration): number
    return self:toSeconds() / SECONDS_PER_HOUR
end

--- Returns the total number of days contained by this `Duration`.
---
--- The result may be fractional and is a single `number`, so it is subject to
--- float64 precision loss for very large `Duration`s. Use
--- [Duration:toSecondsAndNanos] for exact values. Returns `math.huge` or
--- `-math.huge` for infinite `Duration`s.
---
--- @method toDays
--- @within Duration
--- @return number -- The total number of days
function Duration.toDays(self: Duration): number
    return self:toSeconds() / SECONDS_PER_DAY
end

--- Returns the total number of whole nanoseconds contained by this `Duration`.
---
--- Like [Duration:toNanos], but truncated toward zero, so `-1.5` becomes `-1`.
--- Returns `math.huge` or `-math.huge` for infinite `Duration`s.
---
--- @method wholeNanos
--- @within Duration
--- @return number -- The total number of whole nanoseconds
function Duration.wholeNanos(self: Duration): number
    return truncateTowardZero(self:toNanos())
end

--- Returns the total number of whole microseconds contained by this `Duration`.
---
--- Like [Duration:toMicros], but truncated toward zero, so `-1.5` becomes `-1`.
--- Returns `math.huge` or `-math.huge` for infinite `Duration`s.
---
--- @method wholeMicros
--- @within Duration
--- @return number -- The total number of whole microseconds
function Duration.wholeMicros(self: Duration): number
    return truncateTowardZero(self:toMicros())
end

--- Returns the total number of whole milliseconds contained by this `Duration`.
---
--- Like [Duration:toMillis], but truncated toward zero, so `-1.5` becomes `-1`.
--- Returns `math.huge` or `-math.huge` for infinite `Duration`s.
---
--- @method wholeMillis
--- @within Duration
--- @return number -- The total number of whole milliseconds
function Duration.wholeMillis(self: Duration): number
    return truncateTowardZero(self:toMillis())
end

--- Returns the total number of whole seconds contained by this `Duration`.
---
--- Like [Duration:toSeconds], but truncated toward zero, so `-1.5` becomes
--- `-1`. Returns `math.huge` or `-math.huge` for infinite `Duration`s.
---
--- @method wholeSeconds
--- @within Duration
--- @return number -- The total number of whole seconds
function Duration.wholeSeconds(self: Duration): number
    return truncateTowardZero(self:toSeconds())
end

--- Returns the total number of whole minutes contained by this `Duration`.
---
--- Like [Duration:toMinutes], but truncated toward zero, so `-1.5` becomes
--- `-1`. Returns `math.huge` or `-math.huge` for infinite `Duration`s.
---
--- @method wholeMinutes
--- @within Duration
--- @return number -- The total number of whole minutes
function Duration.wholeMinutes(self: Duration): number
    return truncateTowardZero(self:toMinutes())
end

--- Returns the total number of whole hours contained by this `Duration`.
---
--- Like [Duration:toHours], but truncated toward zero, so `-1.5` becomes `-1`.
--- Returns `math.huge` or `-math.huge` for infinite `Duration`s.
---
--- @method wholeHours
--- @within Duration
--- @return number -- The total number of whole hours
function Duration.wholeHours(self: Duration): number
    return truncateTowardZero(self:toHours())
end

--- Returns the total number of whole days contained by this `Duration`.
---
--- Like [Duration:toDays], but truncated toward zero, so `-1.5` becomes `-1`.
--- Returns `math.huge` or `-math.huge` for infinite `Duration`s.
---
--- @method wholeDays
--- @within Duration
--- @return number -- The total number of whole days
function Duration.wholeDays(self: Duration): number
    return truncateTowardZero(self:toDays())
end

--- Returns the nanoseconds component of this `Duration`.
---
--- The magnitude is in the range 0-999, and the result has the same sign as the
--- `Duration`, so `-1_500` nanoseconds has a nanoseconds component of `-500`.
--- Returns 0 for infinite `Duration`s.
---
--- @method nanosPart
--- @within Duration
--- @return number -- The nanoseconds
function Duration.nanosPart(self: Duration): number
    if self:isInf() then
        return 0
    end

    local sign, _, nanos = toMagnitude(self)
    return signedPart(sign, nanos % NANOS_PER_MICRO)
end

--- Returns the microseconds component of this `Duration`.
---
--- The magnitude is in the range 0-999, and the result has the same sign as the
--- `Duration`, so `-1_500` microseconds has a microseconds component of `-500`.
--- Returns 0 for infinite `Duration`s.
---
--- @method microsPart
--- @within Duration
--- @return number -- The microseconds
function Duration.microsPart(self: Duration): number
    if self:isInf() then
        return 0
    end

    local sign, _, nanos = toMagnitude(self)
    return signedPart(
        sign,
        math.floor(nanos / NANOS_PER_MICRO) % MICROS_PER_MILLI
    )
end

--- Returns the milliseconds component of this `Duration`.
---
--- The magnitude is in the range 0-999, and the result has the same sign as the
--- `Duration`, so `-1_500` milliseconds has a milliseconds component of `-500`.
--- Returns 0 for infinite `Duration`s.
---
--- @method millisPart
--- @within Duration
--- @return number -- The milliseconds
function Duration.millisPart(self: Duration): number
    if self:isInf() then
        return 0
    end

    local sign, _, nanos = toMagnitude(self)
    return signedPart(sign, math.floor(nanos / NANOS_PER_MILLI))
end

--- Returns the seconds component of this `Duration`.
---
--- The magnitude is in the range 0-59, and the result has the same sign as the
--- `Duration`, so `-90` seconds has a seconds component of `-30`. Returns 0 for
--- infinite `Duration`s.
---
--- @method secondsPart
--- @within Duration
--- @return number -- The seconds
function Duration.secondsPart(self: Duration): number
    if self:isInf() then
        return 0
    end

    local sign, secs = toMagnitude(self)
    return signedPart(sign, secs % SECONDS_PER_MINUTE)
end

--- Returns the minutes component of this `Duration`.
---
--- The magnitude is in the range 0-59, and the result has the same sign as the
--- `Duration`, so `-90` minutes has a minutes component of `-30`. Returns 0 for
--- infinite `Duration`s.
---
--- @method minutesPart
--- @within Duration
--- @return number -- The minutes
function Duration.minutesPart(self: Duration): number
    if self:isInf() then
        return 0
    end

    local sign, secs = toMagnitude(self)
    return signedPart(
        sign,
        math.floor(secs / SECONDS_PER_MINUTE) % MINUTES_PER_HOUR
    )
end

--- Returns the hours component of this `Duration`.
---
--- The magnitude is in the range 0-23, and the result has the same sign as the
--- `Duration`, so `-36` hours has an hours component of `-12`. Returns 0 for
--- infinite `Duration`s.
---
--- @method hoursPart
--- @within Duration
--- @return number -- The hours
function Duration.hoursPart(self: Duration): number
    if self:isInf() then
        return 0
    end

    local sign, secs = toMagnitude(self)
    return signedPart(sign, math.floor(secs / SECONDS_PER_HOUR) % HOURS_PER_DAY)
end

--- Returns the days component of this `Duration`.
---
--- Days are the largest component, so the magnitude is unbounded. The result
--- has the same sign as the `Duration`. Returns `math.huge` or `-math.huge`
--- for infinite `Duration`s.
---
--- @method daysPart
--- @within Duration
--- @return number -- The days
function Duration.daysPart(self: Duration): number
    if self:isInf() then
        return self._secs
    end

    local sign, secs = toMagnitude(self)
    return signedPart(sign, math.floor(secs / SECONDS_PER_DAY))
end

--- Returns each component of this `Duration` as a table.
---
--- Unlike the `*Part` methods, such as [Duration:hoursPart], every part is
--- non-negative and the sign is stored in `negative`. Passing the result to
--- [Duration.fromParts] recreates the same `Duration`.
---
--- ```lua
--- Duration.fromSeconds(-90_061.5):toParts()
--- -- { negative = true, days = 1, hours = 1, minutes = 1, seconds = 1,
--- --   millis = 500, micros = 0, nanos = 0 }
--- ```
---
--- @method toParts
--- @within Duration
--- @return TimePartsO -- The parts
function Duration.toParts(self: Duration): TimePartsO
    return if self:isInf()
        then {
            negative = self:isNegative(),
            days = math.huge,
            hours = 0,
            minutes = 0,
            seconds = 0,
            millis = 0,
            micros = 0,
            nanos = 0,
        }
        else {
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

--- Returns the exact internal seconds and nanoseconds of this `Duration`.
---
--- The nanoseconds are always in [0, 999_999_999], since the sign is stored in
--- the seconds, so `-1.5` seconds returns `-2, 500_000_000`. Infinite
--- `Duration`s return `math.huge` or `-math.huge`, and 0. Passing the results
--- to [Duration.new] recreates the same `Duration`.
---
--- ```lua
--- Duration.fromSeconds(1.5):toSecondsAndNanos() -- 1, 500_000_000
--- Duration.fromSeconds(-1.5):toSecondsAndNanos() -- -2, 500_000_000
--- ```
---
--- @method toSecondsAndNanos
--- @within Duration
--- @return number -- The whole seconds
--- @return number -- The nanosecond adjustment
function Duration.toSecondsAndNanos(self: Duration): (number, number)
    return self._secs, self._nanos
end

--- Creates a new `Duration` spanning from the specified start time to now.
---
--- The result is negative if `start` is after `now`.
---
--- Both parameters passed should use the same clock source:
--- * `os.clock()` for local elapsed time (the default)
--- * `os.time()` for Unix seconds with whole-second precision
--- * `Workspace:GetServerTimeNow()` for ensuring synchronized values between
---   client and server
---
--- ```lua
--- local start = os.clock()
--- doWork()
--- print(Duration.since(start):toHumanString()) -- e.g. "1s 250ms"
--- ```
---
--- @param start number -- The start time
--- @param now number? -- The end time (defaults to `os.clock()`)
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if the difference is `NaN`
function Duration.since(start: number, now: number?): Duration
    return Duration.new((now or os.clock()) - start, 0)
end

--- Creates a new `Duration` spanning from the specified start time to the
--- specified end time.
---
--- The result is negative if `start` is after `stop`.
---
--- Both parameters passed should use the same clock source:
--- * `os.clock()` for local elapsed time (the default)
--- * `os.time()` for Unix seconds with whole-second precision
--- * `Workspace:GetServerTimeNow()` for ensuring synchronized values between
---   client and server
---
--- ```lua
--- Duration.between(10, 12.5) -- 2.5 seconds
--- Duration.between(5, 3) -- -2 seconds
--- ```
---
--- @param start number -- The start time
--- @param stop number -- The end time
--- @return Duration -- The new `Duration`
--- @error "[Duration.new()]: Cannot create a Duration from NaN values" -- Thrown if the difference is `NaN`
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
--- A `Duration` is not negative if it is zero. Use [Duration:isZero] to check
--- for zero.
---
--- @method isNegative
--- @within Duration
--- @return boolean -- Whether this `Duration` is negative
function Duration.isNegative(self: Duration): boolean
    return self._secs < 0
end

--- Returns whether this `Duration` is positive.
---
--- A `Duration` is not positive if it is zero. Use [Duration:isZero] to check
--- for zero.
---
--- @method isPositive
--- @within Duration
--- @return boolean -- Whether this `Duration` is positive
function Duration.isPositive(self: Duration): boolean
    return self._secs > 0 or (self._secs == 0 and self._nanos > 0)
end

--- Returns whether this `Duration` is infinite, either positive or negative.
---
--- Use [Duration:isPositive] or [Duration:isNegative] to check the sign.
---
--- @method isInf
--- @within Duration
--- @return boolean -- Whether this `Duration` is infinite
function Duration.isInf(self: Duration): boolean
    return math.isinf(self._secs)
end

--- Returns whether this `Duration` is finite.
---
--- This is always the opposite of [Duration:isInf].
---
--- @method isFinite
--- @within Duration
--- @return boolean -- Whether this `Duration` is finite
function Duration.isFinite(self: Duration): boolean
    return math.isfinite(self._secs)
end

--- Returns the result of adding this `Duration` and another.
---
--- The result is exact. Adding an infinite `Duration` to a finite one returns
--- the infinite one.
---
--- Also used for the `+` operator.
---
--- @method plus
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The sum
--- @error "[Duration.plus()]: Attempted to perform addition on a non-Duration value: {value}" -- Thrown if `self` or `other` is not a `Duration`
--- @error "[Duration.plus()]: Adding infinities with different signs is undefined" -- Thrown if `self` and `other` are infinities with different signs
function Duration.plus(self: Duration, other: Duration): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "addition", "plus")
    assertDuration(other, "addition", "plus")

    if self:isInf() and other:isInf() and self._secs ~= other._secs then
        fail("Adding infinities with different signs is undefined")
    end

    return Duration.new(self._secs + other._secs, self._nanos + other._nanos)
end
Duration.__add = Duration.plus

--- Returns the result of subtracting another `Duration` from this one.
---
--- The result is exact. Use [Duration:saturatingMinus] to clamp the result at
--- zero.
---
--- Also used for the `-` operator.
---
--- @method minus
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The difference
--- @error "[Duration.minus()]: Attempted to perform subtraction on a non-Duration value: {value}" -- Thrown if `self` or `other` is not a `Duration`
--- @error "[Duration.minus()]: Subtracting infinities with the same sign is undefined" -- Thrown if `self` and `other` are infinities with the same sign
function Duration.minus(self: Duration, other: Duration): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "subtraction", "minus")
    assertDuration(other, "subtraction", "minus")

    if self:isInf() and other:isInf() and self._secs == other._secs then
        fail("Subtracting infinities with the same sign is undefined")
    end

    return Duration.new(self._secs - other._secs, self._nanos - other._nanos)
end
Duration.__sub = Duration.minus

--- Returns the result of multiplying this `Duration` and a scalar.
---
--- The result is exact for integer scalars. Fractional scalars are rounded to
--- the nearest nanosecond. Multiplying an infinite `Duration`, or multiplying
--- by an infinite scalar, returns an infinite `Duration` with the sign of the
--- product.
---
--- Also used for the `*` operator, in either order (`duration * 2` or
--- `2 * duration`).
---
--- ```lua
--- Duration.SECOND * 3 -- 3 seconds
--- 2 * Duration.MINUTE -- 2 minutes
--- Duration.SECOND:times(1.5) -- 1.5 seconds
--- Duration.SECOND * math.huge -- Duration.INFINITE
--- ```
---
--- @method times
--- @within Duration
--- @param scalar number -- The scalar
--- @return Duration -- The product
--- @error "[Duration.times()]: Attempted to perform multiplication on a non-Duration value: {value}" -- Thrown if `self` is not a `Duration`
--- @error "[Duration.times()]: Attempted to multiply a Duration by a non-number" -- Thrown if `scalar` is not a `number`
--- @error "[Duration.times()]: Multiplication by NaN is undefined" -- Thrown if `scalar` is `NaN`
--- @error "[Duration.times()]: Infinity multiplied by 0 is undefined" -- Thrown if an infinite `Duration` is multiplied by 0, or a zero `Duration` is multiplied by an infinity
function Duration.times(self: Duration, scalar: number): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "multiplication", "times")
    if type(scalar) ~= "number" then
        fail("Attempted to multiply a Duration by a non-number")
    end

    if math.isnan(scalar) then
        fail("Multiplication by NaN is undefined")
    end
    if
        (self:isInf() and scalar == 0) or (self:isZero() and math.isinf(scalar))
    then
        fail("Infinity multiplied by 0 is undefined")
    end

    if self:isInf() then
        return if scalar > 0 then self else self:negated()
    elseif math.isinf(scalar) then
        return Duration.new(scalar * if self:isNegative() then -1 else 1, 0)
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
--- For integer scalars, the division is exact before rounding, and halves are
--- rounded away from zero. Fractional scalars are rounded through float
--- arithmetic. Dividing an infinite `Duration` returns an infinite `Duration`
--- with the sign of the quotient, and dividing a finite `Duration` by an
--- infinity returns [Duration.ZERO].
---
--- To divide by another `Duration`, use [Duration:floorDividedBy],
--- [Duration:truncatedDividedBy], or [Duration:ratio].
---
--- Also used for the `/` operator.
---
--- ```lua
--- Duration.SECOND / 3 -- 333_333_333 nanoseconds
--- Duration.NANOSECOND / 2 -- 1 nanosecond; halves round away from zero
--- Duration.SECOND / math.huge -- Duration.ZERO
--- ```
---
--- @method dividedBy
--- @within Duration
--- @param scalar number -- The scalar
--- @return Duration -- The quotient
--- @error "[Duration.dividedBy()]: Attempted to perform division on a non-Duration value: {value}" -- Thrown if `self` is not a `Duration`
--- @error "[Duration.dividedBy()]: Attempted to divide a Duration by a non-number" -- Thrown if `scalar` is not a `number`
--- @error "[Duration.dividedBy()]: Attempted to divide by 0" -- Thrown if `scalar` is 0
--- @error "[Duration.dividedBy()]: Division by NaN is undefined" -- Thrown if `scalar` is `NaN`
--- @error "[Duration.dividedBy()]: Dividing two infinities is undefined" -- Thrown if `self` is infinite and `scalar` is an infinity
function Duration.dividedBy(self: Duration, scalar: number): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "division", "dividedBy")
    if type(scalar) ~= "number" then
        fail("Attempted to divide a Duration by a non-number")
    end
    if scalar == 0 then
        fail("Attempted to divide by 0")
    end

    if math.isnan(scalar) then
        fail("Division by NaN is undefined")
    end
    if self:isInf() and math.isinf(scalar) then
        fail("Dividing two infinities is undefined")
    end

    if self:isInf() then
        return if scalar > 0 then self else self:negated()
    elseif math.isinf(scalar) then
        return Duration.ZERO
    end

    local negateResult = self:isNegative() ~= (scalar < 0)
    local mag = self:abs()

    -- fractional (or huge) scalars can't be exact, so round via normalize()
    if scalar % 1 ~= 0 or math.abs(scalar) >= MAX_SAFE_INT then
        local result = Duration.new(
            mag._secs / math.abs(scalar),
            mag._nanos / math.abs(scalar)
        )
        return if negateResult then result:negated() else result
    end

    local k = math.abs(scalar)
    local kNanos = Duration.new(0, k) -- k nanoseconds, exact for k < 2^53

    -- estimate whole seconds exactly, sub-second part with floats
    local qSecs = mag._secs // k
    local rSecs = mag._secs - qSecs * k -- 0 <= rSecs < k, exact
    local estNanos = math.floor((rSecs * NANOS_PER_SECOND + mag._nanos) / k)
    local q = Duration.new(qSecs, estNanos)

    -- exact residual for the estimate
    local r = mag:minus(q:times(k))

    -- correct the estimate until 0 <= r < k nanoseconds
    while r:isNegative() do
        q = q:minus(Duration.NANOSECOND)
        r = r:plus(kNanos)
    end
    while r:compareTo(kNanos) >= 0 do
        q = q:plus(Duration.NANOSECOND)
        r = r:minus(kNanos)
    end

    -- round half away from zero; the leftover is r / k of a nanosecond
    if r:times(2):compareTo(kNanos) >= 0 then
        q = q:plus(Duration.NANOSECOND)
    end

    return if negateResult then q:negated() else q
end
Duration.__div = Duration.dividedBy

--- Returns how many times another whole `Duration` can fit into this one.
---
--- The quotient is exact and floored toward negative infinity, so
--- `-3s // 2s` is `-2`. Pairs with [Duration:mod], such that
--- `self == other * q + r`. Use [Duration:truncatedDividedBy] to truncate
--- toward zero instead.
---
--- Also used for the `//` operator.
---
--- ```lua
--- local a, b = Duration.fromSeconds(-7), Duration.fromSeconds(2)
--- a // b -- -4
--- a % b -- 1 second, so a == b * -4 + 1 second
--- ```
---
--- @method floorDividedBy
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The quotient
--- @error "[Duration.floorDividedBy()]: Attempted to perform floor division on a non-Duration value: {value}" -- Thrown if `self` or `other` is not a `Duration`
--- @error "[Duration.floorDividedBy()]: Attempted to divide by 0" -- Thrown if `other` is zero
--- @error "[Duration.floorDividedBy()]: Floor division with an infinity is undefined" -- Thrown if `self` or `other` is infinite
--- @error "[Duration.floorDividedBy()]: Quotient is too large to be represented exactly" -- Thrown if the quotient is at least 2^53 in magnitude
function Duration.floorDividedBy(self: Duration, other: Duration): number
    -- type validation for metamethod error handling
    assertDuration(self, "floor division", "floorDividedBy")
    assertDuration(other, "floor division", "floorDividedBy")
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    if self:isInf() or other:isInf() then
        fail("Floor division with an infinity is undefined")
    end

    local q = divModFloor(self, other, "floorDividedBy")
    return q
end
Duration.__idiv = Duration.floorDividedBy

--- Returns the floored remainder of dividing this `Duration` by another, with
--- the sign of `other`.
---
--- The remainder is exact and pairs with [Duration:floorDividedBy], so
--- `-3s % 2s` is `1s`. Use [Duration:remainder] for a remainder with the sign
--- of `self` instead.
---
--- Also used for the `%` operator.
---
--- ```lua
--- local a, b = Duration.fromSeconds(-7), Duration.fromSeconds(2)
--- a % b -- 1 second
--- a // b -- -4, so a == b * -4 + 1 second
--- ```
---
--- @method mod
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The remainder
--- @error "[Duration.mod()]: Attempted to perform modulus on a non-Duration value: {value}" -- Thrown if `self` or `other` is not a `Duration`
--- @error "[Duration.mod()]: Attempted to divide by 0" -- Thrown if `other` is zero
--- @error "[Duration.mod()]: Modulus with an infinity is undefined" -- Thrown if `self` or `other` is infinite
--- @error "[Duration.mod()]: Quotient is too large to be represented exactly" -- Thrown if the quotient is at least 2^53 in magnitude
function Duration.mod(self: Duration, other: Duration): Duration
    -- type validation for metamethod error handling
    assertDuration(self, "modulus", "mod")
    assertDuration(other, "modulus", "mod")
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    if self:isInf() or other:isInf() then
        fail("Modulus with an infinity is undefined")
    end

    local _, r = divModFloor(self, other, "mod")
    return r
end
Duration.__mod = Duration.mod

--- Returns the truncated quotient of dividing this `Duration` by another.
---
--- The quotient is exact and truncated toward zero, so `-3s / 2s` is `-1`.
--- Pairs with [Duration:remainder], such that `self == other * q + r`. Use
--- [Duration:floorDividedBy] to floor toward negative infinity instead.
---
--- ```lua
--- local a, b = Duration.fromSeconds(-7), Duration.fromSeconds(2)
--- a:truncatedDividedBy(b) -- -3
--- a:remainder(b) -- -1 second, so a == b * -3 - 1 second
--- ```
---
--- @method truncatedDividedBy
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The quotient
--- @error "[Duration.truncatedDividedBy()]: Attempted to divide by 0" -- Thrown if `other` is zero
--- @error "[Duration.truncatedDividedBy()]: Truncated division with an infinity is undefined" -- Thrown if `self` or `other` is infinite
--- @error "[Duration.truncatedDividedBy()]: Quotient is too large to be represented exactly" -- Thrown if the quotient is at least 2^53 in magnitude
function Duration.truncatedDividedBy(self: Duration, other: Duration): number
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    if self:isInf() or other:isInf() then
        fail("Truncated division with an infinity is undefined")
    end

    local q = divModTruncated(self, other, "truncatedDividedBy")
    return q
end

--- Returns the truncated remainder of dividing this `Duration` by another, with
--- the sign of `self`.
---
--- The remainder is exact and pairs with [Duration:truncatedDividedBy], so the
--- remainder of `-3s` and `2s` is `-1s`. Use [Duration:mod] for a remainder
--- with the sign of `other` instead.
---
--- ```lua
--- local a, b = Duration.fromSeconds(-7), Duration.fromSeconds(2)
--- a:remainder(b) -- -1 second
--- a:truncatedDividedBy(b) -- -3, so a == b * -3 - 1 second
--- ```
---
--- @method remainder
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The remainder
--- @error "[Duration.remainder()]: Attempted to divide by 0" -- Thrown if `other` is zero
--- @error "[Duration.remainder()]: Remainder with an infinity is undefined" -- Thrown if `self` or `other` is infinite
--- @error "[Duration.remainder()]: Quotient is too large to be represented exactly" -- Thrown if the quotient is at least 2^53 in magnitude
function Duration.remainder(self: Duration, other: Duration): Duration
    if other:isZero() then
        fail("Attempted to divide by 0")
    end

    if self:isInf() or other:isInf() then
        fail("Remainder with an infinity is undefined")
    end

    local _, r = divModTruncated(self, other, "remainder")
    return r
end

--- Returns the ratio between this `Duration` and another, as `self / other`.
---
--- The ratio is computed with float arithmetic, so it may be inexact. Returns
--- `math.huge` or `-math.huge` if only `self` is infinite, and 0 if only
--- `other` is infinite.
---
--- ```lua
--- Duration.MINUTE:ratio(Duration.SECOND) -- 60
--- Duration.SECOND:ratio(Duration.MINUTE) -- 0.01666...
--- ```
---
--- @method ratio
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The ratio
--- @error "[Duration.ratio()]: Attempted to calculate a ratio with a zero Duration" -- Thrown if `other` is zero
--- @error "[Duration.ratio()]: Dividing two infinities is undefined" -- Thrown if `self` and `other` are both infinite
function Duration.ratio(self: Duration, other: Duration): number
    if other:isZero() then
        fail("Attempted to calculate a ratio with a zero Duration")
    end

    if self:isInf() and other:isInf() then
        fail("Dividing two infinities is undefined")
    end

    if self:isInf() then
        return if self:isPositive() == other:isPositive()
            then math.huge
            else -math.huge
    elseif other:isInf() then
        return 0
    end

    return self:toNanos() / other:toNanos()
end

--- Returns the result of subtracting another `Duration` from this one, clamped
--- at zero.
---
--- Returns [Duration.ZERO] if `other` is greater than or equal to `self`, so
--- this never throws for infinite `Duration`s.
---
--- ```lua
--- Duration.MINUTE:saturatingMinus(Duration.SECOND) -- 59 seconds
--- Duration.SECOND:saturatingMinus(Duration.MINUTE) -- Duration.ZERO
--- ```
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

--- Returns a `Duration` with the opposite sign of this one.
---
--- Negating [Duration.ZERO] returns a zero `Duration`.
---
--- Also used for the unary `-` operator.
---
--- @method negated
--- @within Duration
--- @return Duration -- The negated `Duration`
function Duration.negated(self: Duration): Duration
    return Duration.new(-self._secs, -self._nanos)
end
Duration.__unm = Duration.negated

--- Returns the absolute value of this `Duration`.
---
--- Returns `self` if it is not negative.
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
--- as [Duration.SECOND], but any positive, finite `Duration` is valid.
---
--- Infinite `Duration`s are returned unchanged.
---
--- ```lua
--- Duration.fromMillis(1_500):truncatedTo(Duration.SECOND) -- 1 second
--- Duration.fromMillis(-1_500):truncatedTo(Duration.SECOND) -- -1 second
--- local quarterHour = Duration.fromMinutes(15)
--- Duration.fromMinutes(37):truncatedTo(quarterHour) -- 30 minutes
--- ```
---
--- @method truncatedTo
--- @within Duration
--- @param unit Duration -- The unit to truncate to
--- @return Duration -- The truncated `Duration`
--- @error "[Duration.truncatedTo()]: Cannot truncate using a non-positive unit" -- Thrown if `unit` is zero or negative
--- @error "[Duration.truncatedTo()]: Truncating to infinity is undefined" -- Thrown if `unit` is infinite
--- @error "[Duration.truncatedDividedBy()]: Quotient is too large to be represented exactly" -- Thrown if `self` divided by `unit` is at least 2^53 in magnitude
function Duration.truncatedTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot truncate using a non-positive unit")
    end

    if unit:isInf() then
        fail("Truncating to infinity is undefined")
    end

    if self:isInf() then
        return self
    end

    return unit:times(self:truncatedDividedBy(unit))
end

--- Returns the result of flooring this `Duration` to a multiple of `unit`,
--- toward negative infinity.
---
--- It is generally expected to pass a `Duration` unit constant to `unit`, such
--- as [Duration.SECOND], but any positive, finite `Duration` is valid.
---
--- Infinite `Duration`s are returned unchanged.
---
--- ```lua
--- Duration.fromMillis(1_500):flooredTo(Duration.SECOND) -- 1 second
--- Duration.fromMillis(-1_500):flooredTo(Duration.SECOND) -- -2 seconds
--- ```
---
--- @method flooredTo
--- @within Duration
--- @param unit Duration -- The unit to floor to
--- @return Duration -- The floored `Duration`
--- @error "[Duration.flooredTo()]: Cannot floor using a non-positive unit" -- Thrown if `unit` is zero or negative
--- @error "[Duration.flooredTo()]: Flooring to infinity is undefined" -- Thrown if `unit` is infinite
--- @error "[Duration.floorDividedBy()]: Quotient is too large to be represented exactly" -- Thrown if `self` divided by `unit` is at least 2^53 in magnitude
function Duration.flooredTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot floor using a non-positive unit")
    end

    if unit:isInf() then
        fail("Flooring to infinity is undefined")
    end

    if self:isInf() then
        return self
    end

    return unit:times(self:floorDividedBy(unit))
end

--- Returns the result of ceiling this `Duration` to a multiple of `unit`,
--- toward positive infinity.
---
--- It is generally expected to pass a `Duration` unit constant to `unit`, such
--- as [Duration.SECOND], but any positive, finite `Duration` is valid.
---
--- Infinite `Duration`s are returned unchanged.
---
--- ```lua
--- Duration.fromMillis(1_500):ceiledTo(Duration.SECOND) -- 2 seconds
--- Duration.fromMillis(-1_500):ceiledTo(Duration.SECOND) -- -1 second
--- ```
---
--- @method ceiledTo
--- @within Duration
--- @param unit Duration -- The unit to ceil to
--- @return Duration -- The ceiled `Duration`
--- @error "[Duration.ceiledTo()]: Cannot ceil using a non-positive unit" -- Thrown if `unit` is zero or negative
--- @error "[Duration.ceiledTo()]: Ceiling to infinity is undefined" -- Thrown if `unit` is infinite
--- @error "[Duration.floorDividedBy()]: Quotient is too large to be represented exactly" -- Thrown if `self` divided by `unit` is at least 2^53 in magnitude
function Duration.ceiledTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot ceil using a non-positive unit")
    end

    if unit:isInf() then
        fail("Ceiling to infinity is undefined")
    end

    if self:isInf() then
        return self
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
--- as [Duration.SECOND], but any positive, finite `Duration` is valid.
---
--- Infinite `Duration`s are returned unchanged.
---
--- ```lua
--- Duration.fromMillis(1_500):roundedTo(Duration.SECOND) -- 2 seconds
--- Duration.fromMillis(-1_500):roundedTo(Duration.SECOND) -- -2 seconds
--- local quarterHour = Duration.fromMinutes(15)
--- Duration.fromMinutes(37):roundedTo(quarterHour) -- 30 minutes
--- Duration.fromMinutes(38):roundedTo(quarterHour) -- 45 minutes
--- ```
---
--- @method roundedTo
--- @within Duration
--- @param unit Duration -- The unit to round to
--- @return Duration -- The rounded `Duration`
--- @error "[Duration.roundedTo()]: Cannot round using a non-positive unit" -- Thrown if `unit` is zero or negative
--- @error "[Duration.roundedTo()]: Rounding to infinity is undefined" -- Thrown if `unit` is infinite
--- @error "[Duration.truncatedDividedBy()]: Quotient is too large to be represented exactly" -- Thrown if `self` divided by `unit` is at least 2^53 in magnitude
function Duration.roundedTo(self: Duration, unit: Duration): Duration
    if not unit:isPositive() then
        fail("Cannot round using a non-positive unit")
    end

    if unit:isInf() then
        fail("Rounding to infinity is undefined")
    end

    if self:isInf() then
        return self
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
--- Only values created by `Duration` functions are considered `Duration`s;
--- tables with the same fields are not.
---
--- @param value any -- The value to check
--- @return boolean -- Whether the value is a `Duration`
function Duration.is(value: any): boolean
    return getmetatable(value) == Duration
end

--- Returns `true` if both `Duration`s represent the same span of time.
---
--- Returns `false` if `other` is not a `Duration`. Infinities are only equal
--- to infinities with the same sign.
---
--- Also used for the `==` and `~=` operators.
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
--- Negative infinity is less than every finite `Duration`, and positive
--- infinity is greater than every finite `Duration`.
---
--- Also used for the `<`, `<=`, `>`, and `>=` operators.
---
--- ```lua
--- Duration.SECOND:compareTo(Duration.MINUTE) -- -1
--- Duration.SECOND < Duration.MINUTE -- true
--- -Duration.INFINITE < Duration.ZERO -- true
--- ```
---
--- @method compareTo
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return number -- The result of the comparison
--- @error "[Duration.compareTo()]: Attempted to perform comparison on a non-Duration value: {value}" -- Thrown if `self` or `other` is not a `Duration`
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
--- Returns `self` if they are equal.
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
--- Returns `self` if they are equal.
---
--- @method max
--- @within Duration
--- @param other Duration -- The other `Duration`
--- @return Duration -- The larger of `self` and `other`
function Duration.max(self: Duration, other: Duration): Duration
    return if self:compareTo(other) >= 0 then self else other
end

--- Returns the result of clamping `self` between `min` and `max`, inclusive.
---
--- ```lua
--- local maxWait = Duration.MINUTE
--- Duration.fromSeconds(90):clamp(Duration.ZERO, maxWait) -- 1 minute
--- Duration.fromSeconds(-5):clamp(Duration.ZERO, maxWait) -- Duration.ZERO
--- ```
---
--- @method clamp
--- @within Duration
--- @param min Duration -- The minimum `Duration`
--- @param max Duration -- The maximum `Duration`
--- @return Duration -- The clamped `Duration`
--- @error "[Duration.clamp()]: Clamp value min must be less than or equal to max" -- Thrown if `min` is greater than `max`
function Duration.clamp(self: Duration, min: Duration, max: Duration): Duration
    if min:compareTo(max) > 0 then
        fail("Clamp value min must be less than or equal to max")
    end
    return self:min(max):max(min)
end

--- Creates a new `Duration` from an ISO 8601 duration string, such as
--- `"PT1H30M"`.
---
--- The accepted format is `PnWnDTnHnMnS`, where every component is optional
--- but at least one must be present, and components must appear in that
--- order:
--- * An optional leading `-` or `+` sign applies to the whole `Duration`
--- * `W` (weeks) and `D` (days) must come before the `T` separator
--- * `H` (hours), `M` (minutes), and `S` (seconds) must come after it
--- * Only seconds may be fractional, using either `.` or `,` as the decimal
---   separator; digits past nanosecond precision are truncated
--- * Letters are case-insensitive
---
--- Years and months are rejected, since they have no fixed length. The
--- strings `Infinity` and `-Infinity` (also case-insensitive) are accepted for
--- infinite `Duration`s. Every string produced by [Duration:toString] can be
--- parsed back into an equal `Duration`.
---
--- Use [Duration.tryParse] for strings that may be malformed.
---
--- ```lua
--- Duration.parse("PT1H30M") -- 1 hour 30 minutes
--- Duration.parse("p1w2dt3,5s") -- 9 days 3.5 seconds
--- Duration.parse("-PT0.25S") -- -250 milliseconds
--- Duration.parse("-Infinity") -- -Duration.INFINITE
--- ```
---
--- @param s string -- The ISO 8601 duration string
--- @return Duration -- The new `Duration`
--- @error "[Duration.parse()]: Failed to parse duration: {reason}" -- Thrown if the string could not be parsed; `{reason}` is the error from [Duration.tryParse]
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

--- Tries to create a new `Duration` from an ISO 8601 duration string, such as
--- `"PT1H30M"`.
---
--- The accepted format is `PnWnDTnHnMnS`, where every component is optional
--- but at least one must be present, and components must appear in that
--- order:
--- * An optional leading `-` or `+` sign applies to the whole `Duration`
--- * `W` (weeks) and `D` (days) must come before the `T` separator
--- * `H` (hours), `M` (minutes), and `S` (seconds) must come after it
--- * Only seconds may be fractional, using either `.` or `,` as the decimal
---   separator; digits past nanosecond precision are truncated
--- * Letters are case-insensitive
---
--- Years and months are rejected, since they have no fixed length. The
--- strings `Infinity` and `-Infinity` (also case-insensitive) are accepted for
--- infinite `Duration`s. Every string produced by [Duration:toString] can be
--- parsed back into an equal `Duration`.
---
--- Returns an "ok" [Result] holding the `Duration`, or an "err" [Result]
--- holding a message in the form
--- `Invalid ISO-8601 duration: "{input}" ({reason} at position {pos})`.
--- Never throws.
---
--- ```lua
--- Duration.tryParse("PT1H") -- Ok(PT1H)
--- Duration.tryParse("PT1M1H")
--- -- Err('Invalid ISO-8601 duration: "PT1M1H" (H is repeated or out of order
--- -- at position 5)')
--- ```
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
        if string.sub(str, pos) == "INFINITY" then
            return Core.Result.ok(
                if negative
                    then Duration.INFINITE:negated()
                    else Duration.INFINITE
            )
        end
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

--- Converts this `Duration` to an ISO 8601 duration string, such as
--- `"P1DT2H3M4.5S"`.
---
--- Days are the largest unit used, so weeks are never output. Zero-valued
--- components are omitted, fractional seconds have trailing zeros removed, and
--- a zero `Duration` is `"PT0S"`. Negative `Duration`s are prefixed with `-`.
--- Infinite `Duration`s are `"Infinity"` or `"-Infinity"`.
---
--- The result can be parsed back into an equal `Duration` with
--- [Duration.parse].
---
--- Also used by `tostring()`.
---
--- ```lua
--- Duration.fromSeconds(93_784.5):toString() -- "P1DT2H3M4.5S"
--- Duration.WEEK:toString() -- "P7D"
--- Duration.fromMillis(-250):toString() -- "-PT0.25S"
--- Duration.ZERO:toString() -- "PT0S"
--- ```
---
--- @method toString
--- @within Duration
--- @return string -- The ISO 8601 duration string
function Duration.toString(self: Duration): string
    if self:isInf() then
        return (if self:isNegative() then "-" else "") .. "Infinity"
    end

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
--- An optional zero-pad width may follow the '%' (e.g. '%02H'). Values are
--- truncated, not rounded, and are always non-negative; negative `Duration`s
--- are prefixed with a single '-' instead. A trailing '%' with no specifier
--- is kept as-is.
---
--- Infinite `Duration`s ignore `pattern` and return `"∞"` or `"-∞"`.
---
--- ```lua
--- Duration.fromSeconds(3725):format("%H:%02M:%02S") -- "1:02:05"
--- ```
---
--- @method format
--- @within Duration
--- @param pattern string -- The pattern
--- @return string -- The formatted string
--- @error "[Duration.format()]: Unknown specifier '%{spec}'" -- Thrown if `pattern` contains an unknown specifier
function Duration.format(self: Duration, pattern: string): string
    if self:isInf() then
        return (if self:isNegative() then "-" else "") .. "∞"
    end

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
--- Zero-valued components are not included, but still count toward
--- `options.maxUnits` once the largest non-zero unit is reached, so
--- `1d 0h 5m` with `maxUnits = 2` becomes `"1d"`. A `Duration` with no
--- components to show returns zero of the smallest unit, such as `"0ms"`.
--- Negative `Duration`s are prefixed with `-`, and infinite `Duration`s return
--- `"∞"` or `"-∞"`.
---
--- ```lua
--- local d = Duration.fromSeconds(93_784.567)
--- d:toHumanString() -- "1d 2h 3m 4s 567ms"
--- d:toHumanString({ maxUnits = 2 }) -- "1d 2h"
--- d:toHumanString({ smallestUnit = "minutes" }) -- "1d 2h 3m"
--- -- the zero hours still count toward maxUnits
--- Duration.fromSeconds(86_405):toHumanString({ maxUnits = 2 }) -- "1d"
--- local options = { smallestUnit = "seconds" }
--- Duration.fromMillis(5):toHumanString(options) -- "0s"
--- ```
---
--- @method toHumanString
--- @within Duration
--- @param options HumanStringOptions? -- The options to apply (defaults to `{ maxUnits = math.huge, smallestUnit = "millis" }`)
--- @return string -- The human-readable string
--- @error "[Duration.toHumanString()]: Max units should be a positive integer" -- Thrown if `options.maxUnits` is not a positive integer or `math.huge`
function Duration.toHumanString(
    self: Duration,
    options: HumanStringOptions?
): string
    local maxUnits = options and options.maxUnits
    if
        maxUnits ~= nil
        and (maxUnits <= 0 or (maxUnits % 1 ~= 0 and not math.isinf(maxUnits)))
    then
        fail("Max units should be a positive integer")
    end
    maxUnits = maxUnits or math.huge
    local smallestUnit = options and options.smallestUnit or "millis"

    if self:isInf() then
        return (if self:isNegative() then "-" else "") .. "∞"
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
--- are considered "equal" produce identical keys. Equal `Duration`s always
--- produce identical keys, since this returns the same string as
--- [Duration:toString].
---
--- ```lua
--- local seen = {}
--- seen[Duration.fromMillis(1_500):toKey()] = true
--- print(seen[Duration.new(1, 500_000_000):toKey()]) -- true
--- ```
---
--- @method toKey
--- @within Duration
--- @return string -- The key
function Duration.toKey(self: Duration): string
    return self:toString()
end

--- Serializes this `Duration` into a `DataStore`-safe data table.
---
--- Finite `Duration`s serialize to `{ secs = number, nanos = number }`, and
--- infinite `Duration`s serialize to `{ inf = 1 }` or `{ inf = -1 }`, since
--- infinities are not `DataStore`-safe. Use [Duration.deserialize] to convert
--- the data back into a `Duration`.
---
--- ```lua
--- Duration.fromSeconds(-1.5):serialize() -- { secs = -2, nanos = 500_000_000 }
--- Duration.INFINITE:serialize() -- { inf = 1 }
--- ```
---
--- @method serialize
--- @within Duration
--- @return Core.Map<any, any> -- The serialized data
function Duration.serialize(self: Duration): Core.Map<any, any>
    return if self:isInf()
        then { inf = if self:isNegative() then -1 else 1 }
        else { secs = self._secs, nanos = self._nanos }
end

--- Creates a new `Duration` from a serialized data table.
---
--- This function guarantees to always deserialize valid `Duration`s serialized
--- using [Duration:serialize]. Any other method of serialization is not
--- guaranteed to work with deserialization.
---
--- Use [Duration.tryDeserialize] for data that may be malformed.
---
--- @param data Core.Map<any, any> -- The data table
--- @return Duration -- The new `Duration`
--- @error "[Duration.deserialize()]: Failed to deserialize duration: {reason}" -- Thrown if the data could not be deserialized; `{reason}` is the error from [Duration.tryDeserialize]
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
--- using [Duration:serialize]. Any other method of serialization is not
--- guaranteed to work with deserialization.
---
--- Returns an "ok" [Result] holding the `Duration`, or an "err" [Result]
--- holding a message describing the first problem found, such as a missing
--- key, a non-integer value, or `nanos` outside of [0, 999_999_999]. Never
--- throws.
---
--- ```lua
--- Duration.tryDeserialize({ secs = 1, nanos = 0 }) -- Ok(PT1S)
--- Duration.tryDeserialize({ secs = 1 })
--- -- Err("Expected key 'nanos' in data table")
--- ```
---
--- @param data Core.Map<any, any> -- The data table
--- @return Core.Result<Duration, string> -- The result of parsing the data
function Duration.tryDeserialize(
    data: Core.Map<any, any>
): Core.Result<Duration, string>
    if type(data) ~= "table" then
        return Core.Result.err("Expected data to be a table")
    end

    local inf = data.inf
    if inf ~= nil then
        if inf ~= 1 and inf ~= -1 then
            return Core.Result.err(
                "Expected key 'inf' to be 1 or -1 in data table"
            )
        end
        return Core.Result.ok(
            if inf == 1 then Duration.INFINITE else Duration.INFINITE:negated()
        )
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
