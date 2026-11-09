--!strict

-- Time exports
-- by @vuppyan

local Duration = require("@self/Duration")
export type Duration = Duration.Duration

local Stopwatch = require("@self/Stopwatch")
export type Stopwatch = Stopwatch.Stopwatch

--[=[
    Utilities for measuring and representing time.

    @class Time
]=]
return table.freeze({
    Duration = Duration,
    Stopwatch = Stopwatch,
})
