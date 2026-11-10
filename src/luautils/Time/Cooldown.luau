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
    A mutable, keyed cooldown timer for measuring the time between uses of
    something.

    A `Cooldown` holds one entry per key, as server-side scripts often need a
    separate timer per player or ability.
    Every method that takes a `key` parameter acts on that key's entry, and a
    single global timer can be implemented by using a constant key.
    Keys cannot be `nil` or NaN.

    Each entry has up to the `Cooldown`'s maximum number of charges.
    A use spends a charge, and spent charges recharge one at a time, each
    taking the `Cooldown`'s length.
    A key with no entry has all of its charges available: an entry is created
    when a charge is spent, and removed once all of its charges have
    recharged.

    Due to how server-client authority works, client-side `Cooldown`s only
    affect visuals, and `tryUse` on the server-side is the real check to run.

    Unlike `Duration`s, `Cooldown`s are not frozen, and their methods modify
    them in place.

    Supports `tostring()`.

    Error messages thrown by `Cooldown` functions are prefixed with the
    function that threw them, such as `[Cooldown.tryUse()]: `, after the usual
    position prefix added by `error()`.

    ```lua
    local fireballCd = Cooldown.new(Duration.fromSeconds(5))

    castRemote.OnServerEvent:Connect(function(player)
        if fireballCd:tryUse(player) then
            castFireball(player)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        fireballCd:reset(player) -- free the player's entry
    end)
    ```

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

    @type CooldownOptions { clock: Supplier<number>?, maxCharges: number? }
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
        The maximum number of charges each entry can hold (defaults to 1).

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
    recommended to annotate your `Cooldown`s if you want to use generic type
    checking.

    ```lua
    local dashCd: Cooldown<Player> = Cooldown.new(
        Duration.fromSeconds(3),
        { maxCharges = 2 }
    )
    local synced = Cooldown.new(Duration.SECOND, {
        clock = function()
            return workspace:GetServerTimeNow()
        end,
    })
    ```

    @since [UNRELEASED]
    @param length Duration -- The time each charge takes to recharge
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
    Attempts to spend a charge from the given key's entry, returning `true` if
    a charge was available and spent, or `false` if none were and nothing
    happened.

    An optional `length` parameter can be given to override the `Cooldown`'s
    length for this one use.
    This may be useful for special cases like a longer cooldown after a charged
    attack.
    An override only applies if this use starts a recharge, which happens when
    the entry had all of its charges.
    If a charge is already recharging, the use only spends a charge, and the
    timer already running isn't changed.

    Zero-length uses still require a charge to be available, but succeed
    without spending it.

    ```lua
    local dashCd = Cooldown.new(Duration.fromSeconds(3), { maxCharges = 2 })
    dashCd:tryUse(player) -- true, 1 charge left, and a charge starts recharging
    dashCd:tryUse(player) -- true, 0 charges left
    dashCd:tryUse(player) -- false
    -- 3 seconds later
    dashCd:tryUse(player) -- true, the first charge recharged

    local attack = Cooldown.new(Duration.SECOND)
    attack:tryUse(player, Duration.fromSeconds(4)) -- true, ready in 4 seconds
    ```

    @method tryUse
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
    @param length Duration? -- The custom length to use (defaults to the `Cooldown`'s length)
    @return boolean -- Whether a charge was available
    @error "[Cooldown.tryUse()]: Key cannot be nil or NaN" -- Thrown if `key` is `nil` or NaN
    @error "[Cooldown.tryUse()]: Length cannot be negative" -- Thrown if `length` is negative
]=]
function Cooldown.tryUse<K>(self: Cooldown<K>, key: K, length: Duration?): boolean
    if key == nil or key ~= key then
        fail("Key cannot be nil or NaN")
    elseif length and length:isNegative() then
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
    Starts a recharge for the given key's entry without checking, setting its
    available charges to 0 and replacing any recharge already in progress.

    This method may be useful for effects like silences or stuns.

    An optional `length` parameter can be given to override the `Cooldown`'s
    length for the first charge.
    This may be useful for special cases like a longer cooldown after a charged
    attack.
    Any later charges recharge with the `Cooldown`'s length.

    A length of zero removes the entry instead, restoring all of its charges
    like [Cooldown.reset].

    ```lua
    local abilityCd = Cooldown.new(Duration.fromSeconds(5), { maxCharges = 3 })
    abilityCd:start(player, Duration.fromSeconds(2)) -- stunned, 0 charges
    -- 2 seconds later
    abilityCd:charges(player) -- 1
    -- 5 seconds later
    abilityCd:charges(player) -- 2
    ```

    @method start
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
    @param length Duration? -- The custom length to use (defaults to the `Cooldown`'s length)
    @error "[Cooldown.start()]: Key cannot be nil or NaN" -- Thrown if `key` is `nil` or NaN
    @error "[Cooldown.start()]: Length cannot be negative" -- Thrown if `length` is negative
]=]
function Cooldown.start<K>(self: Cooldown<K>, key: K, length: Duration?): ()
    if key == nil or key ~= key then
        fail("Key cannot be nil or NaN")
    elseif length and length:isNegative() then
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
    Shifts the time the given key's charge in progress finishes by a signed
    `Duration`, doing nothing if the key has no entry (all of its charges are
    available).

    Negative `Duration`s shorten the recharge, while positive `Duration`s
    lengthen it.
    If a negative `Duration` is larger than the time remaining, the charge
    finishes, and the leftover time carries over to the following charges.

    ```lua
    local abilityCd = Cooldown.new(Duration.fromSeconds(10), { maxCharges = 2 })
    abilityCd:tryUse(player)
    abilityCd:tryUse(player) -- 0 charges, next charge in 10 seconds
    abilityCd:adjust(player, Duration.fromSeconds(-4)) -- next charge in 6 seconds
    abilityCd:adjust(player, Duration.fromSeconds(-8))
    -- 1 charge, and the next charge is 2 seconds in, so it's ready in 8 seconds
    ```

    @method adjust
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
    @param delta Duration -- The amount to adjust
    @error "[Cooldown.adjust()]: Key cannot be nil or NaN" -- Thrown if `key` is `nil` or NaN
]=]
function Cooldown.adjust<K>(self: Cooldown<K>, key: K, delta: Duration): ()
    if key == nil or key ~= key then
        fail("Key cannot be nil or NaN")
    end

    local now = self._clock()
    local entry = settle(self, key, now)
    if entry == nil then
        return
    end

    entry.readyAt += delta:toSeconds()
    settle(self, key, now)
end

--[=[
    Removes the given key's entry, restoring all of its charges.

    @method reset
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
    @error "[Cooldown.reset()]: Key cannot be nil or NaN" -- Thrown if `key` is `nil` or NaN
]=]
function Cooldown.reset<K>(self: Cooldown<K>, key: K): ()
    if key == nil or key ~= key then
        fail("Key cannot be nil or NaN")
    end
    self._entries[key] = nil
end

--[=[
    Removes every entry, restoring all charges for every key.

    @method resetAll
    @within Cooldown
    @since [UNRELEASED]
]=]
function Cooldown.resetAll<K>(self: Cooldown<K>): ()
    self._entries = {}
end

--[=[
    Brings every entry up to date, removing the entries whose charges have all
    recharged.

    Entries are otherwise only removed when their key is accessed, so this
    method may be useful for freeing memory from keys that are no longer used.

    @method prune
    @within Cooldown
    @since [UNRELEASED]
    @return number -- The number of entries remaining after pruning
]=]
function Cooldown.prune<K>(self: Cooldown<K>): number
    local now = self._clock()
    local total = 0
    for key in self._entries do
        local entry = settle(self, key, now)
        if entry ~= nil then
            total += 1
        end
    end
    return total
end

--[=[
    Returns whether the given key has at least one charge available.

    This method should be used for display or branching.
    To check and spend a charge in one step, use [Cooldown.tryUse].

    @method isReady
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
    @return boolean -- Whether a charge is available
]=]
function Cooldown.isReady<K>(self: Cooldown<K>, key: K): boolean
    local now = self._clock()
    local entry = settle(self, key, now)
    return entry == nil or entry.charges > 0
end

--[=[
    Returns the time remaining until the given key's charge in progress
    finishes, or [Duration.ZERO] if the key has no entry.

    With multiple charges, a nonzero return value does not mean the key is
    unready, as other charges may still be available.
    Use [Cooldown.isReady] to check readiness, or [Cooldown.remainingUntilFull]
    to check all charges at once.

    ```lua
    local abilityCd = Cooldown.new(Duration.fromSeconds(10), { maxCharges = 3 })
    abilityCd:tryUse(player)
    abilityCd:tryUse(player)
    -- 4 seconds later
    abilityCd:remaining(player) -- 6 seconds
    abilityCd:remainingUntilFull(player) -- 16 seconds
    abilityCd:isReady(player) -- true, since 1 charge is available
    ```

    @method remaining
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
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
    Returns the progress of the given key's charge in progress in a range from
    0.0 to 1.0, or 1.0 if the key has no entry.

    With multiple charges, a return value below 1.0 does not mean the key is
    unready, as other charges may still be available.
    Use [Cooldown.isReady] to check readiness, or [Cooldown.progressUntilFull]
    to check all charges at once.

    ```lua
    local abilityCd = Cooldown.new(Duration.fromSeconds(10), { maxCharges = 3 })
    abilityCd:tryUse(player)
    abilityCd:tryUse(player)
    -- 4 seconds later
    abilityCd:progress(player) -- 0.4
    abilityCd:progressUntilFull(player) -- 0.4666..., (1 + 0.4) / 3 charges
    ```

    @method progress
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
    @return number -- The progress
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
    Returns the time remaining until all of the given key's charges have
    recharged.

    A return value of [Duration.ZERO] indicates that all charges are available.
    Charges after the one in progress are assumed to take the `Cooldown`'s
    current length.
    To check the time remaining on the charge in progress, use
    [Cooldown.remaining].

    @method remainingUntilFull
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
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
    Returns the progress towards all of the given key's charges being
    available in a range from 0.0 to 1.0, counting the charge in progress as a
    fraction.

    A return value of 1.0 indicates that all charges are available.
    To check the progress of the charge in progress, use [Cooldown.progress].

    @method progressUntilFull
    @within Cooldown
    @since [UNRELEASED]
    @param key K -- The key of the entry
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
    Returns the `Cooldown`'s length, the time each charge takes to recharge.

    @method getLength
    @within Cooldown
    @since [UNRELEASED]
    @return Duration -- The length
]=]
function Cooldown.getLength<K>(self: Cooldown<K>): Duration
    return Duration.fromSeconds(self._length)
end

--[=[
    Sets the `Cooldown`'s length, the time each charge takes to recharge.

    Charges already in progress keep their current timers, and the new length
    applies to every charge that starts recharging afterwards.

    ```lua
    local abilityCd = Cooldown.new(Duration.fromSeconds(10), { maxCharges = 2 })
    abilityCd:tryUse(player)
    abilityCd:tryUse(player)
    abilityCd:setLength(Duration.fromSeconds(4))
    abilityCd:remaining(player) -- 10 seconds, the charge in progress is unchanged
    -- 10 seconds later
    abilityCd:remaining(player) -- 4 seconds, the next charge uses the new length
    ```

    @method setLength
    @within Cooldown
    @since [UNRELEASED]
    @param length Duration -- The length
    @error "[Cooldown.setLength()]: Length cannot be negative" -- Thrown if `length` is negative
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
    @param key K -- The key of the entry
    @return number -- The number of charges
]=]
function Cooldown.charges<K>(self: Cooldown<K>, key: K): number
    local now = self._clock()
    local entry = settle(self, key, now)
    return if entry then entry.charges else self._maxCharges
end

--[=[
    Returns the maximum number of charges each entry can hold.

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

--[=[
    Returns a string representation of the `Cooldown`, including its length
    and number of entries.

    This method prunes the `Cooldown` (see [Cooldown.prune]) to count only the
    entries with charges still recharging.

    Also used by `tostring()`.

    ```lua
    local fireballCd = Cooldown.new(Duration.fromSeconds(5))
    fireballCd:tryUse("a")
    fireballCd:tryUse("b")
    fireballCd:toString() -- "Cooldown(5s, 2 active)"
    -- 5 seconds later
    tostring(fireballCd) -- "Cooldown(5s, 0 active)"
    ```

    @method toString
    @within Cooldown
    @since [UNRELEASED]
    @return string -- The string representation
]=]
function Cooldown.toString<K>(self: Cooldown<K>): string
    local active = self:prune()
    return string.format(
        "Cooldown(%s, %d active)",
        Duration.fromSeconds(self._length):toHumanString(),
        active
    )
end
Cooldown.__tostring = Cooldown.toString

return table.freeze(Cooldown)
