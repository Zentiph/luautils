--!strict

-- Error handling utilities
-- by @vuppyan

--[=[
    A module of error handling utilities.

    @class Errors
    @since v0.1.0
]=]
local Errors = {}

--[=[
    Builds an error thrower that prefixes `"[Module.fn()]: "` to an error message.

    The returned error thrower takes a message, error level (like `error()`'s)
    with a default of `2`, and a function name override (defaults to the
    caller's name).

    Levels are counted starting from the function that calls the thrower, with 0
    meaning no position. Due to Luau's compiler optimizations, local functions
    may be inlined, leading to an unexpected call-frame offset. To avoid this,
    when passing a custom level, the function that calls the thrower should be
    a table field, not a `local function`.

    ```lua
    local fail = Errors.errorWithScope("MyModule")
    function MyModule.thrower()
        fail("Whoops") -- errors with "[MyModule.thrower()]: Whoops"
    end
    ```

    @since v0.1.0
    @param moduleName string -- The name of the module that threw the error
    @return (message: string, level: number?, functionName: string?): never -- The error thrower
]=]
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

return table.freeze(Errors)
