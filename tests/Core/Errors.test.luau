--!strict

-- Errors tests
-- by @vuppyan

local test = require("@std/test")
local types = require("@std/test/types")
local Errors = require("../../src/luautils/Core/Errors")

local fail = Errors.errorWithScope("Mod")

-- calls `fn` and returns the thrown error as a string
local function catch(fn: () -> ()): string
    local ok, err = pcall(fn)
    assert(not ok, "expected function to throw")
    return tostring(err)
end

-- asserts that `err` ends with `suffix`
local function endsWith(asserts: types.Asserts, suffix: string, err: string)
    asserts.eq(suffix, string.sub(err, -#suffix))
end

test.suite("errorWithScope()", function(suite)
    suite:case("returns a function", function(asserts)
        asserts.eq("function", type(Errors.errorWithScope("Mod")))
    end)

    suite:case("prefixes the module and caller name", function(asserts)
        local function doThing()
            fail("bad input")
        end

        endsWith(asserts, "[Mod.doThing()]: bad input", catch(doThing))
    end)

    suite:case("uses the module name it was built with", function(asserts)
        local otherFail = Errors.errorWithScope("Other")
        local function doThing()
            otherFail("bad input")
        end

        endsWith(asserts, "[Other.doThing()]: bad input", catch(doThing))
    end)

    suite:case("uses the function name override", function(asserts)
        local function doThing()
            fail("bad input", nil, "override")
        end

        endsWith(asserts, "[Mod.override()]: bad input", catch(doThing))
    end)

    suite:case("uses ? for an anonymous caller", function(asserts)
        local err = catch(function()
            fail("bad input")
        end)

        endsWith(asserts, "[Mod.?()]: bad input", err)
    end)

    suite:case("uses ? for an empty function name override", function(asserts)
        local function doThing()
            fail("bad input", nil, "")
        end

        endsWith(asserts, "[Mod.?()]: bad input", catch(doThing))
    end)

    suite:case(
        "defaults to blaming the caller of the throwing function",
        function(asserts)
            local function doThing()
                fail("bad input")
            end

            local line
            local err = catch(function()
                line = debug.info(1, "l") + 1
                doThing()
            end)

            asserts.strContains(err, `:{line}: [Mod.doThing()]: bad input`)
        end
    )

    suite:case("level 1 blames the throwing function", function(asserts)
        local line
        local function doThing()
            line = debug.info(1, "l") + 1
            fail("bad input", 1)
        end

        asserts.strContains(
            catch(doThing),
            `:{line}: [Mod.doThing()]: bad input`
        )
    end)

    suite:case("level 0 adds no position", function(asserts)
        local function doThing()
            fail("bad input", 0)
        end

        asserts.eq("[Mod.doThing()]: bad input", catch(doThing))
    end)
end)
