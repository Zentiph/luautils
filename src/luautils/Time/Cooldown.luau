--!strict

-- Cooldown type
-- by @vuppyan

local Core = require("../Core")
type Map<K, V> = Core.Map<K, V>
type Supplier<T> = Core.Supplier<T>

local Duration = require("./Duration")
type Duration = Duration.Duration

local fail = Core.Errors.errorWithScope("Cooldown")

--[=[
    A mutable cooldown timer for measuring the time between uses of something.

    `Cooldown`s are keyed, as server-side scripts often need one cooldown per
    player or ability.
    Every method takes a `key` parameter, and single global cooldowns can be
    implemented by using a constant key.

    Due to how server-client authority works, client-side cooldowns only affect
    visuals, and `tryUse` on the server-side is the real check to run.

    @tag mutable
    @class Cooldown
    @since [UNRELEASED]
]=]
local Cooldown = {}
Cooldown.__index = Cooldown

type CooldownEntry = {
    -- both are clock readings
    startedAt: number,
    readyAt: number,
    charges: number,
}

--[=[
    Options for `Cooldown.new`.

    @type CooldownOptions { clock: Supplier<number>?, charges: number? }
    @within Cooldown
    @since [UNRELEASED]
]=]
export type CooldownOptions = {
    --[=[
        The clock function to use (defaults to `os.clock`).

        The clock function should return the current time in seconds, and
        should not go backwards.
        Common choices are:
        * `os.clock` for local elapsed time (the default)
        * `os.time` for Unix seconds with whole-second precision
        * `function() return workspace:GetServerTimeNow() end` for time
          synchronized between client and server

        @since [UNRELEASED]
    ]=]
    read clock: Supplier<number>?,
    --[=[
        The maximum number of charges to give the cooldown (defaults to 1).

        @since [UNRELEASED]
    ]=]
    read maxCharges: number?,
}

type CooldownData<K> = {
    read _clock: Supplier<number>,
    _length: number,
    _maxCharges: number,
    _entries: Map<K, CooldownEntry>,
}

export type Cooldown<K> = typeof(setmetatable({} :: CooldownData<K>, Cooldown))

-- Helper to bring `key`'s entry up to date at time `now`, adding every charge
-- that finished recharging since it was last touched. Deletes the entry and
-- returns nil once all charges are back.
local function settle<K>(self: Cooldown<K>, key: K, now: number): CooldownEntry?
    local entry = self._entries[key]
    if entry == nil or now < entry.readyAt then
        return entry
    end

    -- the charge in progress finished at readyAt, and each later charge took
    -- the default length after that
    local interval = self._length
    local recovered = 1
    if interval == 0 then
        recovered = self._maxCharges
    else
        recovered += math.floor((now - entry.readyAt) / interval)
    end

    entry.charges += recovered
    if entry.charges >= self._maxCharges then
        self._entries[key] = nil
        return nil
    end

    -- the next charge began when the last recovered one finished
    -- skip the multiplication when nothing extra was recovered,
    -- since 0 * inf is NaN
    if recovered > 1 then
        entry.startedAt = entry.readyAt + (recovered - 1) * interval
    else
        entry.startedAt = entry.readyAt
    end
    entry.readyAt = entry.startedAt + interval
    return entry
end

--[=[
    Creates a new `Cooldown` with the given length and options.

    The clock function should return the current time in seconds, and should
    not go backwards.
    Common choices are:
    * `os.clock` for local elapsed time (the default)
    * `os.time` for Unix seconds with whole-second precision
    * `function() return workspace:GetServerTimeNow() end` for time
      synchronized between client and server

    Because this constructor cannot be generic due to Luau limitations, it is
    recommended to annotate your cooldowns if you want to use generic type
    checking.

    @since [UNRELEASED]
    @param length Duration -- The length of the cooldown
    @param options CooldownOptions? -- The options to use (defaults to `{ clock = os.clock, maxCharges = 1 }`)
    @return Cooldown<any> -- The new `Cooldown`
    @error "[Cooldown.new()]: Length cannot be negative" -- Thrown if `length` is negative
    @error "[Cooldown.new()]: Max charges must be a positive integer" -- Thrown if `options.maxCharges` is not a positive integer
]=]
function Cooldown.new(
    length: Duration,
    options: CooldownOptions?
): Cooldown<any>
    local clock = options and options.clock or os.clock
    local maxCharges = options and options.maxCharges or 1

    if length:isNegative() then
        fail("Length cannot be negative")
    elseif maxCharges < 1 or maxCharges % 1 ~= 0 then
        fail("Max charges must be a positive integer")
    end

    return setmetatable({
        _clock = clock,
        _length = length:toSeconds(),
        _maxCharges = maxCharges,
        _entries = {},
    }, Cooldown)
end

--[=[
    Attempts to activate the cooldown for the given key, returning `true` if it
    was ready and activated, or `false` if it was not and nothing happened.

    An optional `length` parameter can be given to override the cooldown's
    length for this one use.
    This may be useful for special cases like a longer cooldown after a charged
    attack.
    An override only applies if it starts a recharge.
    If a charge is already recharging, the use only spends a charge, and the
    timer already running isn't changed.

    Zero-length uses are free and don't spend a charge.

    @method tryUse
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @param length Duration? -- The custom length to use (defaults to the cooldown's normal length)
    @return boolean -- Whether the cooldown was activated
    @error "[Cooldown.tryUse()]: Length cannot be negative" -- Thrown if `length` is negative
]=]
function Cooldown.tryUse<K>(self: Cooldown<K>, key: K, length: Duration?): boolean
    if length and length:isNegative() then
        fail("Length cannot be negative")
    end

    local now = self._clock()
    local entry = settle(self, key, now)
    local available = if entry then entry.charges else self._maxCharges
    if available < 1 then
        return false
    end

    local seconds = if length then length:toSeconds() else self._length
    if seconds == 0 then
        return true -- zero-length uses never start a cooldown
    end

    if entry == nil then
        -- first use from full: this charge starts recharging now
        self._entries[key] = {
            charges = self._maxCharges - 1,
            startedAt = now,
            readyAt = now + seconds,
        }
    else
        -- a charge is already recharging: spend one and leave the timer alone
        entry.charges -= 1
    end
    return true
end

--[=[
    Starts the cooldown for the given key without checking, setting the
    available charges to 0, and thereby overriding any existing cooldown for the
    key.

    This method may be useful for effects like silences or stuns.

    An optional `length` parameter can be given to override the cooldown's
    length for this one use.
    This may be useful for special cases like a longer cooldown after a charged
    attack.

    @method start
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @param length Duration? -- The custom length to use (defaults to the cooldown's normal length)
]=]
function Cooldown.start<K>(self: Cooldown<K>, key: K, length: Duration?): ()
    if length and length:isNegative() then
        fail("Length cannot be negative")
    end
    local seconds = if length then length:toSeconds() else self._length
    if seconds == 0 then
        self._entries[key] = nil
        return
    end
    local now = self._clock()
    self._entries[key] = {
        charges = 0,
        startedAt = now,
        readyAt = now + seconds,
    }
end

--[=[
    Shifts the ready time of a cooldown by a signed `Duration`, doing nothing if
    the key is ready.

    Negative `Duration`s reduce the cooldown, while positive `Duration`s
    increase it.

    @method adjust
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @param delta Duration -- The amount to adjust
]=]
function Cooldown.adjust<K>(self: Cooldown<K>, key: K, delta: Duration): ()
    local now = self._clock()
    local entry = settle(self, key, now)
    if entry == nil then
        return
    end

    local newReadyAt = entry.readyAt + delta:toSeconds()
    if newReadyAt <= now then
        self._entries[key] = nil
    else
        self._entries[key].readyAt = newReadyAt
    end
end

--[=[
    Resets the cooldown for the given key, making it ready.

    @method reset
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
]=]
function Cooldown.reset<K>(self: Cooldown<K>, key: K): ()
    self._entries[key] = nil
end

--[=[
    Resets all cooldowns, making them ready.

    @method resetAll
    @within Cooldown
    @since [UNRELEASED]
]=]
function Cooldown.resetAll<K>(self: Cooldown<K>): ()
    self._entries = {}
end

--[=[
    Removes all expired (ready) entries from the `Cooldown`'s table.

    @method prune
    @within Cooldown
    @since [UNRELEASED]
]=]
function Cooldown.prune<K>(self: Cooldown<K>): ()
    local now = self._clock()
    for key, entry in self._entries do
        if entry.readyAt <= now then
            self._entries[key] = nil
        end
    end
end

--[=[
    Returns whether the cooldown is ready for the given key.

    This method should be used for display or branching.
    To check and use a cooldown in one step, use [Cooldown.tryUse].

    @method isReady
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @return boolean -- Whether the cooldown is ready
]=]
function Cooldown.isReady<K>(self: Cooldown<K>, key: K): boolean
    local now = self._clock()
    local entry = settle(self, key, now)
    return entry == nil or entry.charges > 0
end

--[=[
    Returns the remaining time on the charge cooldown for the given key.

    A return value of [Duration.ZERO] may not be the only indication that the
    cooldown is ready, as in the case of a cooldown with multiple charges.
    Use [Cooldown.isReady] to check readiness, or [Cooldown.remainingUntilFull]
    to check all charges at once.

    @method remaining
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @return Duration -- The remaining time
]=]
function Cooldown.remaining<K>(self: Cooldown<K>, key: K): Duration
    local now = self._clock()
    local entry = settle(self, key, now)
    return if entry
        then Duration.fromSeconds(entry.readyAt - now)
        else Duration.ZERO
end

--[=[
    Returns the progress on the charge cooldown for the given key in a range
    from 0.0 to 1.0.

    A return value of 1.0 may not be the only indication that the cooldown is
    ready, as in the case of a cooldown with multiple charges.
    Use [Cooldown.isReady] to check readiness, or [Cooldown.progressUntilFull]
    to check all charges at once.
]=]
function Cooldown.progress<K>(self: Cooldown<K>, key: K): number
    local now = self._clock()
    local entry = settle(self, key, now)
    if entry == nil then
        return 1
    end
    local interval = entry.readyAt - entry.startedAt
    return math.clamp((now - entry.startedAt) / interval, 0, 1)
end

--[=[
    Returns the remaining time on all charges for the given key.

    A return value of [Duration.ZERO] indicates that all charges are ready.
    To check for the time remaining of the next single charge, use
    [Cooldown.remaining].

    @method remainingUntilFull
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @return Duration -- The remaining time
]=]
function Cooldown.remainingUntilFull<K>(self: Cooldown<K>, key: K): Duration
    local now = self._clock()
    local entry = settle(self, key, now)
    if entry == nil then
        return Duration.ZERO
    end
    local missing = self._maxCharges - entry.charges
    local seconds = entry.readyAt - now
    if missing > 1 then
        seconds += (missing - 1) * self._length
    end
    return Duration.fromSeconds(seconds):max(Duration.ZERO)
end

--[=[
    Returns the progress on all charges for the given key in a range from 0.0
    to 1.0.

    A return value of 1.0 indicates that all charges are ready.
    To check the progress of the next single charge, use [Cooldown.progress].

    @method progressUntilFull
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @return number -- The progress
]=]
function Cooldown.progressUntilFull<K>(self: Cooldown<K>, key: K): number
    local now = self._clock()
    local entry = settle(self, key, now)
    if entry == nil then
        return 1
    end
    local interval = entry.readyAt - entry.startedAt
    local partial = math.clamp((now - entry.startedAt) / interval, 0, 1)
    return (entry.charges + partial) / self._maxCharges
end

--[=[
    Returns the length of the cooldown.

    @method getLength
    @within Cooldown
    @since [UNRELEASED]
    @return Duration -- The length
]=]
function Cooldown.getLength<K>(self: Cooldown<K>): Duration
    return Duration.fromSeconds(self._length)
end

--[=[
    Sets the length of the cooldown.

    @method setLength
    @within Cooldown
    @since [UNRELEASED]
    @param length Duration -- The length
    @error "Length cannot be negative" -- Thrown if `length` is negative
]=]
function Cooldown.setLength<K>(self: Cooldown<K>, length: Duration): ()
    if length:isNegative() then
        fail("Length cannot be negative")
    end
    self._length = length:toSeconds()
end

--[=[
    Returns the number of charges available for the given key.

    @method charges
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the cooldown
    @return number -- The number of charges
]=]
function Cooldown.charges<K>(self: Cooldown<K>, key: K): number
    local now = self._clock()
    local entry = settle(self, key, now)
    return if entry then entry.charges else self._maxCharges
end

--[=[
    Returns the maximum number of charges for the cooldown.

    @method maxCharges
    @within Cooldown
    @since [UNRELEASED]
    @return number -- The maximum number of charges
]=]
function Cooldown.maxCharges<K>(self: Cooldown<K>): number
    return self._maxCharges
end

--[=[
    Returns whether the given value is a `Cooldown`.

    Only values created by `Cooldown` functions are considered `Cooldown`s;
    tables with the same fields are not.

    @since [UNRELEASED]
    @param value any -- The value to check
    @return boolean -- Whether `value` is a `Cooldown`
]=]
function Cooldown.is(value: any): boolean
    return getmetatable(value) == Cooldown
end

return table.freeze(Cooldown)
