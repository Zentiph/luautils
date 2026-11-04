--!strict

-- retry function
-- by @vuppyan

local Core = require("../Core")
type Result<T, E> = Core.Result<T, E>

return function<T>(
    callback: () -> T,
    retries: number,
    waitSeconds: number?
): Core.Result<T, string>
    local success = false
    local result: T? = nil
    local tried = false

    for retry = 1, retries do
        tried = true
        success, result = pcall(callback)
        if success then
            return Core.Result.ok(result)
        end

        if retry == retries then
            break -- don't wait for the last retry
        end

        if waitSeconds then
            task.wait(waitSeconds)
        end
    end
    return Core.Result.err("Exceeded maximum number of retries " .. if tried
        -- check if the function was tried at all, rather than
        -- assuming a nil result means it didn't.
        -- callers may return nil as an error.
        then `(retried function errored with {tostring(result)})`
        else "")
end
