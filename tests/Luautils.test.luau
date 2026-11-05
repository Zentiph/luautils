--!strict

-- Root test file
-- Tests the root module, which is what the pesde package loads
-- by @vuppyan

local test = require("@std/test")

test.case("luautils can be required without ROBLOX globals", function(_)
    -- throws if any module uses a ROBLOX global (game, task, ...) at load time
    require("../src/luautils")
end)

test.case("luautils root contains VERSION", function(asserts)
    local luautils = require("../src/luautils")
    asserts.eq("string", type(luautils.VERSION))
end)
