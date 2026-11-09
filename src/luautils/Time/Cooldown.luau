--!strict

-- Cooldown type
-- by @vuppyan

local Core = require("../Core")

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

type CooldownData = {
    -- TODO:
}

export type Cooldown = typeof(setmetatable({} :: CooldownData, Cooldown))

return Cooldown
