--!strict

-- Duration datatype
-- by @vuppyan

-- TODO: replace errors with results
-- TODO: remove as many casts as possible
-- TODO: make as functional as possible (like rust)
-- TODO: make official testing suite to work with roblox codebase
--       (maybe with testing on roblox cloud, add to CI eventually too)

-- TODO: change lib structure to simply reflect use cases for code instead of
--       types (e.g. math/, tables/, etc. instead of datatypes/, functions/, etc.)
--       it can be explained in the README that camelCase files are functions
--       and PascalCase files are datatypes/classes/etc.

type UnitInfo = { rank: number, secs: number }

local NANOS_PER_MICRO = 1_000
local NANOS_PER_MILLI = 1_000_000
local NANOS_PER_SEC = 1_000_000_000
local SECS_PER_MIN = 60
local SECS_PER_HOUR = 3_600
local SECS_PER_DAY = 86_400

-- units allowed before 'T' in ISO-8601
local DATE_UNITS: { [string]: UnitInfo } = {
    W = { rank = 1, secs = 7 * SECS_PER_DAY },
    D = { rank = 2, secs = SECS_PER_DAY },
}

-- units allowed after 'T' in ISO-8601
local TIME_UNITS: { [string]: UnitInfo } = {
    H = { rank = 3, secs = SECS_PER_HOUR },
    M = { rank = 4, secs = SECS_PER_MIN },
    S = { rank = 5, secs = 1 },
}

--[=[
    A fixed-length span of time with nanosecond precision and no upper bound.

    Internally, a `Duration` is represented by two `number` fields.
    The first represents whole seconds with any sign, unbounded.
    The second represents a nanosecond adjustment in [0, 999_999_999], which is
    always non-negative, since the sign of the `Duration` lives in the seconds
    field.
    This avoids float64 mantissa loss, as a single `number` storing nanoseconds
    loses precision beyond ~104 days.
    Splitting into seconds and nanoseconds gives exact time arithmetic at both
    scales without any practical upper limit.
]=]
local Duration = {}
Duration.__index = Duration

type DurationData = {
    read _secs: number,
    read _nanos: number,
}

export type Duration = typeof(setmetatable({} :: DurationData, Duration))

-- Normalize the given seconds and nanoseconds
local function normalize(secs: number, nanos: number): (number, number)
    local fracSecs = secs % 1
    secs -= fracSecs
    nanos = math.round(nanos + fracSecs * NANOS_PER_SEC)

    local carry = math.floor(nanos / NANOS_PER_SEC)
    return secs + carry, nanos - carry * NANOS_PER_SEC
end

-- Quick helper to make a new Duration
local function new(secs: number, nanos: number): Duration
    assert(secs == secs and nanos == nanos, "[Duration]: NaN component")
    assert(math.abs(secs) ~= math.huge, "[Duration]: Infinite duration")

    local s, n = normalize(secs, nanos)
    return table.freeze(setmetatable({ _secs = s, _nanos = n }, Duration))
end

-- Returns the sign of the duration
local function sign(duration: Duration): number
    if duration._secs >= 0 then
        return 1
    else
        return -1
    end
end

-- Applies the duration's sign to a non-negative magnitude to avoid producing -0
local function signed(value: number, duration: Duration): number
    if value == 0 or sign(duration) > 0 then
        return value
    end
    return -value
end

local function parseError(input: string, reason: string): string
    return `[Duration.parse()]: Invalid ISO-8601 duration: "{input}" ({reason})`
end

--[=[
    Creates a `Duration` of length zero.
]=]
function Duration.zero(): Duration
    return new(0, 0)
end

--[=[
    Creates a `Duration` with the specified number of nanoseconds.
]=]
function Duration.ofNanos(nanos: number): Duration
    return new(0, nanos)
end

--[=[
    Creates a `Duration` with the specified number of microseconds.
]=]
function Duration.ofMicros(micros: number): Duration
    return new(0, micros * NANOS_PER_MICRO)
end

--[=[
    Creates a `Duration` with the specified number of milliseconds.
]=]
function Duration.ofMillis(millis: number): Duration
    return new(0, millis * NANOS_PER_MILLI)
end

--[=[
    Creates a `Duration` with the specified number of seconds.
]=]
function Duration.ofSeconds(secs: number): Duration
    return new(secs, 0)
end

--[=[
    Creates a `Duration` with the specified number of minutes.
]=]
function Duration.ofMinutes(mins: number): Duration
    return new(mins * SECS_PER_MIN, 0)
end

--[=[
    Creates a `Duration` with the specified number of hours.
]=]
function Duration.ofHours(hours: number): Duration
    return new(hours * SECS_PER_HOUR, 0)
end

--[=[
    Creates a `Duration` with the specified number of days.
]=]
function Duration.ofDays(days: number): Duration
    return new(days * SECS_PER_DAY, 0)
end

--[=[
    Creates a `Duration` with the specified number of days, hours, minutes,
    seconds, milliseconds, microseconds, and nanoseconds.
]=]
function Duration.of(
    days: number?,
    hours: number?,
    minutes: number?,
    seconds: number?,
    millis: number?,
    micros: number?,
    nanos: number?
): Duration
    local sec = 0
    local nano = 0
    local s = seconds or 0

    sec += (days or 0) * SECS_PER_DAY
    sec += (hours or 0) * SECS_PER_HOUR
    sec += (minutes or 0) * SECS_PER_MIN
    sec += math.floor(s)
    nano += math.round((s - math.floor(s)) * NANOS_PER_SEC)
    nano += (millis or 0) * NANOS_PER_MILLI
    nano += (micros or 0) * NANOS_PER_MICRO
    nano += (nanos or 0)

    return new(sec, nano)
end

--[=[
    Creates a `Duration` from the specified ISO-8601 duration string.
]=]
function Duration.parse(s: string): Duration
    local str = string.upper(s)
    local pos = 1
    local negative = false

    local first = string.sub(str, 1, 1)
    if first == "-" or first == "+" then
        negative = first == "-"
        pos += 1
    end
    if string.sub(str, pos, pos) ~= "P" then
        error(parseError(s, "missing 'P' prefix"), 2)
    end
    pos += 1

    local secs = 0
    local nanos = 0
    local inTime = false
    local lastRank = 0

    while pos <= #str do
        if string.sub(str, pos, pos) == "T" then
            if inTime then
                error(parseError(s, "repeated 'T' prefix"), 2)
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
            -- TODO: this above check makes me want to implement a regex library
            error(
                parseError(s, `expected a number and unit at position {pos}`),
                2
            )
        end

        local info = (if inTime then TIME_UNITS else DATE_UNITS)[unit]
        if not info then
            if not inTime and (unit == "Y" or unit == "M") then
                error(parseError(s, "years and months have no fixed length"), 2)
            end
            local where = if inTime then "after" else "before"
            error(parseError(s, `'{unit}' is not valid {where} 'T'`), 2)
        end

        if info.rank <= lastRank then
            error(parseError(s, `'{unit}' is repeated or out of order`), 2)
        end
        if sep ~= "" then
            if unit ~= "S" then
                error(parseError(s, "only seconds may be fractional"), 2)
            elseif frac == "" then
                error(
                    parseError(s, "missing digits after decimal separator"),
                    2
                )
            end
        end

        lastRank = info.rank
        secs += (tonumber(whole) :: number) * info.secs
        if frac ~= "" then
            -- pad/truncate to 9 digits so the fraction parses as exact nanos
            nanos = tonumber(string.sub(frac .. "000000000", 1, 9)) :: number
        end
        pos = nextPos
    end

    if lastRank == 0 then
        error(parseError(s, "no components"), 2)
    end
    if inTime and lastRank < TIME_UNITS.H.rank then
        error(parseError(s, "'T' must be followed by a time component"), 2)
    end

    return if negative then new(-secs, -nanos) else new(secs, nanos)
end

--[=[
    Returns the `Duration` since the specified `os.clock()` timestamp.
]=]
function Duration.since(timestamp: number): Duration
    return new(os.clock() - timestamp, 0)
end

--[=[
    Returns the `Duration` between the two specified `os.clock()` timestamps.
]=]
function Duration.between(start: number, stop: number): Duration
    return new(stop - start, 0)
end

--[=[
    Returns the total length of the `Duration` in days.
]=]
function Duration:toDays(): number
    return (self :: Duration):toSeconds() / SECS_PER_DAY
end

--[=[
    Returns the total length of the `Duration` in hours.
]=]
function Duration:toHours(): number
    return (self :: Duration):toSeconds() / SECS_PER_HOUR
end

--[=[
    Returns the total length of the `Duration` in minutes.
]=]
function Duration:toMinutes(): number
    return (self :: Duration):toSeconds() / SECS_PER_MIN
end

--[=[
    Returns the total length of the `Duration` in seconds.
]=]
function Duration:toSeconds(): number
    return (self :: Duration)._secs + (self :: Duration)._nanos / NANOS_PER_SEC
end

--[=[
    Returns the total length of the `Duration` in milliseconds.
]=]
function Duration:toMillis(): number
    return (self :: Duration)._secs * 1_000
        + (self :: Duration)._nanos / NANOS_PER_MILLI
end

--[=[
    Returns the total length of the `Duration` in microseconds.
]=]
function Duration:toMicros(): number
    return (self :: Duration)._secs * 1_000_000
        + (self :: Duration)._nanos / NANOS_PER_MICRO
end

--[=[
    Returns the total length of the `Duration` in nanoseconds.

    NOTE: This operation loses precision for durations > ~104 days at nanosecond
    scale. Use `Duration:toSecondsAndNanoOffset()` for lossless work at that
    scale.
]=]
function Duration:toNanos(): number
    return (self :: Duration)._secs * NANOS_PER_SEC + (self :: Duration)._nanos
end

--[=[
    Returns the size of the seconds component and the nanosecond offset in the
    `Duration`.
]=]
function Duration:toSecondsAndNanoOffset(): (number, number)
    return self._secs, self._nanos
end

--[=[
    Returns the size of the days component in the `Duration`.
]=]
function Duration:daysPart(): number
    return signed(
        math.floor((self :: Duration):abs()._secs / SECS_PER_DAY),
        self
    )
end

--[=[
    Returns the size of the hours component in the `Duration`.
]=]
function Duration:hoursPart(): number
    return signed(
        math.floor(
            (self :: Duration):abs()._secs % SECS_PER_DAY / SECS_PER_HOUR
        ),
        self
    )
end

--[=[
    Returns the size of the minutes component in the `Duration`.
]=]
function Duration:minutesPart(): number
    return signed(
        math.floor(
            (self :: Duration):abs()._secs % SECS_PER_HOUR / SECS_PER_MIN
        ),
        self
    )
end

--[=[
    Returns the size of the seconds component in the `Duration`.
]=]
function Duration:secondsPart(): number
    return signed((self :: Duration):abs()._secs % SECS_PER_MIN, self)
end

--[=[
    Returns the size of the milliseconds component in the `Duration`.
]=]
function Duration:millisPart(): number
    return signed(
        math.floor((self :: Duration):abs()._nanos / NANOS_PER_MILLI),
        self
    )
end

--[=[
    Returns the size of the microseconds component in the `Duration`.
]=]
function Duration:microsPart(): number
    return signed(
        math.floor((self :: Duration):abs()._nanos / NANOS_PER_MICRO) % 1_000,
        self
    )
end

--[=[
    Returns the size of the nanoseconds component in the `Duration`.
]=]
function Duration:nanosPart(): number
    return signed((self :: Duration):abs()._nanos % NANOS_PER_MICRO, self)
end

--[=[
	Adds the two `Duration`s and returns the result.
]=]
function Duration:plus(other: Duration): Duration
    return new(
        (self :: Duration)._secs + other._secs,
        (self :: Duration)._nanos + other._nanos
    )
end

--[=[
	Subtracts the given `Duration` from this one and returns the result.
]=]
function Duration:minus(other: Duration): Duration
    return new(
        (self :: Duration)._secs - other._secs,
        (self :: Duration)._nanos - other._nanos
    )
end

--[=[
	Multiplies the `Duration` by the given scalar and returns the result.
]=]
function Duration:times(scalar: number): Duration
    return new(
        (self :: Duration)._secs * scalar,
        (self :: Duration)._nanos * scalar
    )
end

--[=[
	Divides the `Duration` by the given scalar and returns the result.
]=]
function Duration:dividedBy(scalar: number): Duration
    assert(scalar ~= 0, "[Duration:dividedBy()]: Cannot divide by zero")

    local magnitude = self:abs() :: Duration
    local q = math.floor(magnitude._secs / math.abs(scalar))
    local rem = (magnitude._secs - q * math.abs(scalar)) * NANOS_PER_SEC
        + magnitude._nanos
    local result = new(q, rem / math.abs(scalar))
    return if self:isNegative() ~= (scalar < 0) then result:negate() else result
end

--[=[
    Divides the `Duration` by the given scalar and returns the result, rounding
    down.
]=]
function Duration:floorDividedBy(scalar: number): Duration
    assert(scalar ~= 0, "[Duration:floorDividedBy()]: Cannot divide by zero")
    return new(self:dividedBy(scalar)._secs, 0)
end

--[=[
    Returns the remainder of division between two `Duration`s.
]=]
function Duration:mod(other: Duration): Duration
    assert(
        not other:isZero(),
        "[Duration:mod()]: Modulo by zero-length duration"
    )

    -- float estimate of the quotient, then fix any off-by-ones from rounding
    local selfF = (self :: Duration)._secs
        + (self :: Duration)._nanos / NANOS_PER_SEC
    local otherF = other._secs + other._nanos / NANOS_PER_SEC
    local r = self:minus(other:times(math.floor(selfF / otherF)))

    -- floor-mod: result has the sign of b, like luau's %
    if other:isPositive() then
        while r:isNegative() do
            r = r:plus(other)
        end
        while r:compareTo(other) >= 0 do
            r = r:minus(other)
        end
    else
        while r:isPositive() do
            r = r:plus(other)
        end
        while r:compareTo(other) <= 0 do
            r = r:minus(other)
        end
    end
    return r
end

--[=[
	Returns a `Duration` with the opposite sign.
]=]
function Duration:negate(): Duration
    return new(-(self :: Duration)._secs, -(self :: Duration)._nanos)
end

--[=[
	Returns the absolute value of the `Duration`.
]=]
function Duration:abs(): Duration
    if sign(self) >= 0 then
        return self
    end
    return self:negate()
end

--[=[
    Returns the smaller of the two `Duration`s.
]=]
function Duration:min(other: Duration): Duration
    return self:compareTo(other) <= 0 and (self :: Duration) or other
end

--[=[
    Returns the larger of the two `Duration`s.
]=]
function Duration:max(other: Duration): Duration
    return self:compareTo(other) >= 0 and (self :: Duration) or other
end

--[=[
    Returns the `Duration` clamped between the two given `Duration`s.
]=]
function Duration:clamp(min: Duration, max: Duration): Duration
    return self:min(max):max(min)
end

--[=[
	Returns whether this `Duration` equals another `Duration`.
]=]
function Duration:equals(other: Duration): boolean
    return self._secs == other._secs and self._nanos == other._nanos
end
Duration.__eq = Duration.equals

--[=[
	Compare this `Duration` to another, returning -1, 0, or 1 if this is less
    than, equal to, or greater than the other `Duration`, respectively.
]=]
function Duration:compareTo(other: Duration): number
    if self._secs ~= other._secs then
        return self._secs < other._secs and -1 or 1
    end
    if self._nanos ~= other._nanos then
        return self._nanos < other._nanos and -1 or 1
    end
    return 0
end
-- include comparison for table sorts
Duration.__lt = function(a: Duration, b: Duration)
    return a:compareTo(b) < 0
end
Duration.__le = function(a: Duration, b: Duration)
    return a:compareTo(b) <= 0
end

--[=[
	Returns whether this `Duration` has no length.
]=]
function Duration:isZero(): boolean
    return self._secs == 0 and self._nanos == 0
end

--[=[
	Returns whether this `Duration` is negative.
]=]
function Duration:isNegative(): boolean
    return self._secs < 0
end

--[=[
	Returns whether this `Duration` is positive.
]=]
function Duration:isPositive(): boolean
    return self._secs > 0 or (self._secs == 0 and self._nanos > 0)
end

-- TODO: consider writing a protocol for all datatypes to implement certain
--       methods like equals, is, etc. for standard library compatibility
-- TODO: also consider making a trait system like rust for things like
--       "Serializable", if possible
--[=[
    Returns whether the given value is a `Duration`.
]=]
function Duration.is(other: any): boolean
    return getmetatable(other) == Duration
end

--[=[
	Convert this `Duration` to an ISO `string`.
]=]
function Duration:toString(): string
    self = self :: Duration -- for the type checker

    if self:isZero() then
        return "PT0S"
    end

    local negative = self:isNegative()
    local mag = self:abs()
    local secs = mag._secs
    local nanos = mag._nanos

    local d = math.floor(secs / SECS_PER_DAY)
    secs %= SECS_PER_DAY
    local h = math.floor(secs / SECS_PER_HOUR)
    secs %= SECS_PER_HOUR
    local m = math.floor(secs / SECS_PER_MIN)
    secs %= SECS_PER_MIN

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

--[=[
    Formats the `Duration` using strftime-style specifiers:
    - %d: total days
    - %H: hours (0-23)
    - %M: minutes (0-59)
    - %S: seconds (0-59)
    - %f: milliseconds (0-999)
    - %%: literal %

    An optional zero-pad width may follow the '%', e.g. '%02H'.
    Negative durations are prefixed with a single '-'.
]=]
function Duration:format(fmt: string): string
    local magnitude = self:abs() :: Duration
    local values = {
        d = math.floor(magnitude._secs / SECS_PER_DAY),
        H = math.floor(magnitude._secs % SECS_PER_DAY / SECS_PER_HOUR),
        M = math.floor(magnitude._secs % SECS_PER_HOUR / SECS_PER_MIN),
        S = magnitude._secs % SECS_PER_MIN,
        f = math.floor(magnitude._nanos / NANOS_PER_MILLI),
    }

    local result = string.gsub(fmt, "%%(%d*.)", function(token: string): string
        local spec = string.sub(token, -1)
        local width = string.sub(token, 1, -2)

        if spec == "%" then
            return "%"
        end
        local value = values[spec]
        if value == nil then
            error(`[Duration:format()]: Unknown specifier '%{spec}'`)
        end
        return string.format(`%0{width}.0f`, value)
    end)

    return if self:isNegative() then "-" .. result else result
end

--[=[
    Returns a serialized version of this `Duration`.
]=]
function Duration:serialize(): { secs: number, nanos: number }
    return { secs = self._secs, nanos = self._nanos }
end

--[=[
    Creates a new `Duration` from a serialized version.
]=]
function Duration.deserialize(obj: { secs: number, nanos: number }): Duration
    return new(obj.secs, obj.nanos)
end

return Duration
