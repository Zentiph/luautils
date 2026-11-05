--!strict

-- Time exports
-- by @vuppyan

local Duration = require("@self/Duration")
export type Duration = Duration.Duration

--[=[
    Utilities for measuring and representing time.

    @class Time
]=]
return table.freeze({
    Duration = Duration,
})
