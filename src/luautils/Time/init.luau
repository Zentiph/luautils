--!strict

-- Time exports
-- by @vuppyan

local Cooldown = require("@self/Cooldown")
export type Cooldown<K> = Cooldown.Cooldown<K>

local Duration = require("@self/Duration")
export type Duration = Duration.Duration

local Stopwatch = require("@self/Stopwatch")
export type Stopwatch = Stopwatch.Stopwatch

--[=[
    Utilities for measuring and representing time.

    @class Time
    @since v0.1.0
]=]
return table.freeze({
    Cooldown = Cooldown,
    Duration = Duration,
    Stopwatch = Stopwatch,
})
