--!strict

-- retry function
-- by @vuppyan

--[=[
	Attempts to execute a callback function and retries if it fails.

	@param callback () -> T -- The function to execute
	@param retries number -- The number of retries
	@param waitSeconds number? -- The delay between retries (defaults to 0)
	@return (boolean, T?) -- Returns a boolean indicating success and the result of the callback
]=]
return function<T>(
    callback: () -> T,
    retries: number,
    waitSeconds: number?
): (boolean, T?) -- TODO: MAKE THIS RETURN A RESULT TYPE
    local success = false
    local result: T? = nil

    for retry = 1, retries do
        success, result = pcall(callback)
        if success then
            return true, result
        end

        if retry == retries then
            break -- don't wait for the last retry
        end

        if waitSeconds then
            task.wait(waitSeconds)
        end
    end
    return false, result
end
