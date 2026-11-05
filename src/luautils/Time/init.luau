--!strict

-- Time exports
-- by @vuppyan

local Duration = require("@self/Duration")
export type Duration = Duration.Duration

--[=[
    Utilities for measuring and representing time.

    @class Time
    @since v0.1.0
]=]
return table.freeze({
    Duration = Duration,
})
