--!strict

-- error handling for the library
-- by @vuppyan

local Errors = {}

--- Builds an error thrower that prefixes "[Module.fn()]: " to an error message.
---
--- @param moduleName string -- The name of the module to prefix the error message with
--- @return (message: string, level: number?) -> never -- The error thrower
function Errors.errorWithScope(
    moduleName: string
): (message: string, level: number?) -> never
    return function(message: string, level: number?): never
        local functionName = debug.info(2, "n") or "?"
        -- add 1 to level to account for this function's stack frame
        error(
            `[{moduleName}.{functionName}()]: {message}`,
            (level or 2) + 1
        )
    end
end

return Errors
