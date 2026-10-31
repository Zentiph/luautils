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

--- A set of parts in a `Duration`.
---
--- @type TimeParts
--- @within Duration
export type TimeParts = {
    weeks: number?,
    days: number?,
    hours: number?,
    minutes: number?,
    seconds: number?,
    millis: number?,
    micros: number?,
    nanos: number?,
}

-- TODO: maybe extract these to a separate time constants file where it makes sense?
local NANOS_PER_MICRO = 1_000
local NANOS_PER_MILLI = 1_000_000
local NANOS_PER_SECOND = 1_000_000_000
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3_600
local SECONDS_PER_DAY = 86_400
local SECONDS_PER_WEEK = 604_800

local DATE_UNITS: { [string]: { rank: number, secs: number } } = {
    W = { rank = 1, secs = SECONDS_PER_WEEK },
    D = { rank = 2, secs = SECONDS_PER_DAY },
}
local TIME_UNITS: { [string]: { rank: number, secs: number } } = {
    H = { rank = 3, secs = SECONDS_PER_HOUR },
    M = { rank = 4, secs = SECONDS_PER_MINUTE },
    S = { rank = 5, secs = 1 },
}

-- Helper for normalizing seconds and nanoseconds to their expected ranges
local function normalize(secs: number, nanos: number): (number, number)
    local fracSecs = secs % 1
    secs -= fracSecs
    nanos = math.round(nanos + fracSecs * NANOS_PER_SECOND)

    local carry = math.floor(nanos / NANOS_PER_SECOND)
    return secs + carry, nanos - carry * NANOS_PER_SECOND
end

-- Helper for generating Duration.parse() error messages
local function parseErrMsg(input: string, pos: number, reason: string): string
    return `[Duration.parse()]: Invalid ISO-8601 duration: "{input} ({reason} at position {pos})`
end

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
--- @param parts TimeParts -- The table of parts
--- @return Duration -- The new `Duration`
function Duration.fromParts(parts: TimeParts): Duration
    local secs = (parts.weeks or 0) * SECONDS_PER_WEEK
        + (parts.days or 0) * SECONDS_PER_DAY
        + (parts.hours or 0) * SECONDS_PER_HOUR
        + (parts.minutes or 0) * SECONDS_PER_MINUTE
        + (parts.seconds or 0)
    local nanos = (parts.millis or 0) * NANOS_PER_MILLI
        + (parts.micros or 0) * NANOS_PER_MICRO
        + (parts.nanos or 0)
    return Duration.new(secs, nanos)
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

--- Creates a new `Duration` from an ISO 8601 duration string.
---
--- @param s string -- The ISO 8601 duration string
--- @return Duration -- The new `Duration`
--- @error "Failed to parse duration" -- If the string could not be parsed
function Duration.parse(s: string): Duration
    return Duration.tryParse(s):expect(
        "Failed to parse duration. "
            .. "If you are working with potentially malformed input, "
            .. "use Duration.tryParse() instead."
    )
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
        return Core.Result.err(parseErrMsg(str, pos, "missing 'P' prefix"))
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
                    parseErrMsg(str, pos, "repeated 'T' prefix")
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
                parseErrMsg(str, pos, "expected a number and unit")
            )
        end

        local info = (if inTime then TIME_UNITS else DATE_UNITS)[unit]
        if not info then
            if not inTime and (unit == "Y" or unit == "M") then
                return Core.Result.err(
                    parseErrMsg(
                        str,
                        pos,
                        "years and months have no fixed length"
                    )
                )
            end
            local where = if inTime then "after" else "before"
            return Core.Result.err(
                parseErrMsg(str, pos, `'{unit}' is not valid {where} 'T'`)
            )
        end

        if info.rank <= lastRank then
            return Core.Result.err(
                parseErrMsg(str, pos, `{unit} is repeated or out of order`)
            )
        end
        if sep ~= "" then
            if unit ~= "S" then
                return Core.Result.err(
                    parseErrMsg(str, pos, "only seconds may be fractional")
                )
            elseif frac == "" then
                return Core.Result.err(
                    parseErrMsg(
                        str,
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
        return Core.Result.err(parseErrMsg(str, pos, "no components"))
    end
    if inTime and lastRank < TIME_UNITS.H.rank then
        return Core.Result.err(
            parseErrMsg(str, pos, "'T' must be followed by a time component")
        )
    end

    local duration = if negative
        then Duration.new(-secs, -nanos)
        else Duration.new(secs, nanos)
    return Core.Result.ok(duration)
end

return Duration
