--!strict

-- error handling for the library
-- by @vuppyan

local Errors = {}

--- Builds an error thrower that prefixes "[Module.fn()]: " to an error message.
function Errors.errorWithScope(
    moduleName: string
): (message: string, level: number?) -> never
    return function(message: string, level: number?): never
        local functionName = debug.info(2, "n") or "?"
        -- add 1 to level to account for this function's stack frame
        error(`[{moduleName}.{functionName}()]: {message}`, (level or 2) + 1)
    end
end

return Errors
