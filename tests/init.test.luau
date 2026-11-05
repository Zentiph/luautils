--!strict

-- Root test file
-- by @vuppyan

local test = require("@std/test")

test.case("luautils can be required without loading ROBLOX globals", function(_)
    -- will throw if ROBLOX globals are loaded at load time
    require("src/luautils")
end)

test.case("luautils root contains VERSION", function(asserts)
    local luautils = require("src/luautils")
    asserts.eq("string", type(luautils.VERSION))
end)
