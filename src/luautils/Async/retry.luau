--!strict

-- retry function
-- by @vuppyan

local Core = require("../Core")

-- TODO: support packing/unpacking results
--[=[
	Attempts to execute a callback function and retries if it fails.

	@param callback () -> T -- The function to execute
	@param retries number -- The number of retries
	@param waitSeconds number? -- The delay between retries (defaults to 0)
	@return Core.Result<T, string> -- The result of the retry
]=]
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
            return Core.Result.ok(result) -- TODO: see what can be done so people don't have to cast every "ok" construction
        end

        if retry == retries then
            break -- don't wait for the last retry
        end

        if waitSeconds then
            task.wait(waitSeconds)
        end
    end
    return Core.Result.err(
        "Exceeded maximum number of retries "
            .. if tried
                -- check if the function was tried at all, rather than
                -- assuming a nil result means it didn't.
                -- callers may return nil as an error.
                then `(retried function errored with {tostring(result)})`
                else ""
    )
end
