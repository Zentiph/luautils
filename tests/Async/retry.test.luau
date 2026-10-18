--!strict

-- retry tests
-- by @vuppyan

local test = require("@std/test")
local retry = require("../../src/luautils/Async/retry")

test.suite("retry", function(suite)
    suite:case("returns true and result on success", function(asserts)
        local success, result = retry(function()
            return "done"
        end, 1)

        asserts.eq(true, success)
        asserts.eq("done", result)
    end)

    suite:case("returns false and error on failure", function(asserts)
        local success, result = retry(function()
            error("failed")
        end, 1)

        asserts.eq(false, success)
        asserts.strContains(result, "failed")
    end)

    suite:case("retries on failure", function(asserts)
        local count = 0
        local success, result = retry(function()
            count += 1
            error("failed")
        end, 5)

        asserts.eq(false, success)
        asserts.strContains(result, "failed")
        asserts.eq(5, count)
    end)

    suite:case(
        "does not attempt on less than 1 retries",
        function(asserts)
            local count = 0
            local success, result = retry(function()
                count += 1
                error("failed")
            end, 0)

            asserts.eq(false, success)
            asserts.eq(nil, result)
            asserts.eq(0, count)
        end
    )
end)
