--!strict

-- retry function
-- by @vuppyan

local Core = require("../Core")
type Result<T, E> = Core.Result<T, E>

local types = require("../Core/types")
type Supplier<T> = types.Supplier<T>

local fail = Core.Errors.errorWithScope("retry")

--- Options for `retry`.
---
--- @type RetryOptions { attempts: number, delay: number?, sleep: ((seconds: number) -> ())? }
export type RetryOptions = {
    --- The total number of attempts, including the first.
    read attempts: number,
    --- The seconds to wait between attempts (defaults to not waiting).
    read delay: number?,
    --- The function used to wait between attempts (defaults to `task.wait`).
    read sleep: ((seconds: number) -> ())?,
}

--- Calls `attempt` until it returns "ok" or `options.attempts` is reached,
--- returning the first "ok" or the last "err".
---
--- Wrap functions that throw with `Result.try` (one return value) or
--- `Result.tryPack` (all return values).
---
--- There is no wait after the last attempt.
---
--- ```lua
--- -- a throwing function with one return value
--- local data = retry(function()
---     return Result.try(store.GetAsync, store, key)
--- end, { attempts = 3, delay = 1 })
--- -- multiple return values
--- local res = retry(function()
---     return Result.tryPack(getPair, a, b)
--- end, { attempts = 3 })
--- local packed = res:unwrap()
--- local x, y = table.unpack(packed, 1, packed.n)
--- -- a function that already returns a Result
--- local parsed = retry(function()
---     return Duration.tryParse(readSetting())
--- end, { attempts = 5 })
--- ```
---
--- @param attempt types.Supplier<Result<T, E>> -- The function to call
--- @param options RetryOptions -- The retry options
--- @return Result<T, E> -- The result of `attempt`
return function<T, E>(
    attempt: Supplier<Result<T, E>>,
    options: RetryOptions
): Result<T, E>
    local attempts = options.attempts
    if attempts < 1 or attempts % 1 ~= 0 then
        fail("attempts must be a positive integer", nil, "retry")
    end

    local result = attempt()
    for _ = 2, attempts do
        if result:isOk() then
            break
        end
        if options.delay then
            (options.sleep or task.wait)(options.delay)
        end
        result = attempt()
    end
    return result
end
