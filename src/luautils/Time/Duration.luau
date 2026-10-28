--!strict

-- Duration type
-- by @vuppyan

local Core = require("../Core")
local repr = require("../_internal").repr

-- TODO: add enum creators with type support
-- TODO: other oop tools like "final class" metatable locking, easy interface checking, etc

--- A fixed-length span of time with nanosecond precision and no upper bound.
---
--- Internally, a `Duration` is represented by two `number` fields. The first
--- represents whole seconds with any sign, unbounded. The second represents a
--- nanosecond adjustment in [0, 999_999_999], which is always non-negative,
--- since the sign of the `Duration` lives in the seconds field. This avoids
--- float64 mantissa loss, as a single `number` storing nanoseconds closes
--- precision beyond ~104 days. Splitting into seconds and nanoseconds gives
--- exact time arithmetic at both scales without any practical upper limit.
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

-- TODO: maybe extract these to a separate time constants file where it makes sense?
local NANOS_PER_MICRO = 1_000
local NANOS_PER_MILLI = 1_000_000
local NANOS_PER_SECOND = 1_000_000_000
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3_600
local SECONDS_PER_DAY = 86_400
local SECONDS_PER_WEEK = 604_800

-- Helper for normalizing seconds and nanoseconds to their expected ranges
local function normalize(secs: number, nanos: number): (number, number)
    local fracSecs = secs % 1
    secs -= fracSecs
    nanos = math.round(nanos + fracSecs * NANOS_PER_SECOND)

    local carry = math.floor(nanos / NANOS_PER_SECOND)
    return secs + carry, nanos - carry * NANOS_PER_SECOND
end

-- Helper for constructing a new Duration
local function new(secs: number, nanos: number): Duration
    local s, n = normalize(secs, nanos)
    return table.freeze(setmetatable({ _secs = s, _nanos = n }, Duration))
end

--- A duration of zero time.
---
--- @prop ZERO Duration
--- @within Duration
Duration.ZERO = new(0, 0)

--- A duration of one nanosecond.
---
--- @prop NANOSECOND Duration
--- @within Duration
Duration.NANOSECOND = new(0, 1)

--- A duration of one microsecond.
---
--- @prop MICROSECOND Duration
--- @within Duration
Duration.MICROSECOND = new(0, NANOS_PER_MICRO)

--- A duration of one millisecond.
---
--- @prop MILLISECOND Duration
--- @within Duration
Duration.MILLISECOND = new(0, NANOS_PER_MILLI)

--- A duration of one second.
---
--- @prop SECOND Duration
--- @within Duration
Duration.SECOND = new(1, 0)

--- A duration of one minute.
---
--- @prop MINUTE Duration
--- @within Duration
Duration.MINUTE = new(SECONDS_PER_MINUTE, 0)

--- A duration of one hour.
---
--- @prop HOUR Duration
--- @within Duration
Duration.HOUR = new(SECONDS_PER_HOUR, 0)

--- A duration of one day.
---
--- @prop DAY Duration
--- @within Duration
Duration.DAY = new(SECONDS_PER_DAY, 0)

--- A duration of one week.
---
--- @prop WEEK Duration
--- @within Duration
Duration.WEEK = new(SECONDS_PER_WEEK, 0)

-- TODO: ofNanos ... ofDays

return Duration
