--!strict

-- retry tests
-- by @vuppyan

local test = require("@std/test")
local retry = require("../../src/luautils/Async/retry")

test.suite("retry", function(suite)
    suite:case("returns true and result on success", function(asserts)
        local result = retry(function()
            return "done"
        end, 1)

        asserts.eq(true, result:isOk())
        asserts.eq("done", result:unwrap())
    end)

    suite:case("returns false and error on failure", function(asserts)
        local result = retry(
            function()
                error("failed")
            end :: () -> never,
            1
        )

        asserts.eq(false, result:isOk())
        asserts.strContains(result:unwrapErr(), "failed")
    end)

    suite:case("retries on failure", function(asserts)
        local count = 0
        local result = retry(
            function()
                count += 1
                error("failed")
            end :: () -> never,
            5
        )

        asserts.eq(false, result:isOk())
        asserts.strContains(result:unwrapErr(), "failed")
        asserts.eq(5, count)
    end)

    suite:case(
        "does not attempt on less than 1 retries",
        function(asserts)
            local count = 0
            local result = retry(
                function()
                    count += 1
                    error("failed")
                end :: () -> never,
                0
            )

            asserts.eq(false, result:isOk())
            asserts.strContains(
                result:unwrapErr(),
                "Exceeded maximum number of retries"
            )
            asserts.eq(0, count)
        end
    )
end)
