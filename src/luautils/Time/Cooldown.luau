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
    ]=]
    clock: Supplier<number>?,
    --[=[
        The maximum number of charges to give the cooldown (defaults to 1).
    ]=]
    maxCharges: number?,
}

type CooldownData<K> = {
    read _clock: Supplier<number>,
    _length: Duration,
    _maxCharges: number,
    _entries: Map<K, CooldownEntry>,
}

export type Cooldown<K> = typeof(setmetatable({} :: CooldownData<K>, Cooldown))

--[=[
    Creates a new `Cooldown` with the given length and options.

    The clock function should return the current time in seconds, and should
    not go backwards.
    Common choices are:
    * `os.clock` for local elapsed time (the default)
    * `os.time` for Unix seconds with whole-second precision
    * `function() return Workspace:GetServerTimeNow() end` for time
      synchronized between client and server

    Because this constructor does not take an argument of type `K`, it is
    recommended to type your constructed instance with the key type you are
    using (e.g. `local cd: Cooldown<string> = Cooldown.new(...)`).

    @param length Duration -- The length of the cooldown
    @param options CooldownOptions? -- The options to use (defaults to `{ clock = os.clock, maxCharges = 1 }`)
    @return Cooldown -- The new `Cooldown`
]=]
function Cooldown.new<K>(length: Duration, options: CooldownOptions?): Cooldown<K>
    local clock = options and options.clock or os.clock
    local maxCharges = options and options.maxCharges or 1

    if length:isNegative() then
        fail("Length cannot be negative")
    elseif maxCharges < 1 or maxCharges % 1 ~= 0 then
        fail("Max charges must be a positive integer")
    end

    return setmetatable({
        _clock = clock,
        _length = length,
        _maxCharges = maxCharges,
        _entries = {},
    }, Cooldown)
end

return Cooldown
