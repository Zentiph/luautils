--!strict

-- Error handling utilities
-- by @vuppyan

--- A module of error handling utilities.
local Errors = {}

--- Builds an error thrower that prefixes "[Module.fn()]: " to an error message.
---
--- The returned error thrower takes a message, error level (like `error()`'s)
--- with a default of `2`, and a function name override (defaults to the
--- caller's name.
---
--- @param moduleName string -- The name of the module that threw the error
--- @return (message: string, level: number?, functionName: string?): never -- The error thrower
function Errors.errorWithScope(moduleName: string): (
    message: string,
    level: number?,
    functionName: string?
) -> never
    return function(
        message: string,
        level: number?,
        functionName: string?
    ): never
        functionName = functionName or debug.info(2, "n")
        if functionName == nil or functionName == "" then
            functionName = "?"
        end
        -- add 1 to level to account for this function's stack frame
        local errorLevel = if level == 0 then 0 else (level or 2) + 1
        error(`[{moduleName}.{functionName}()]: {message}`, errorLevel)
    end
end

return Errors
