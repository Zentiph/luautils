--!strict

-- typing string type function tests that must fail to type check
-- by @vuppyan

-- Checked by `.lute/typing.luau`: each `-- error: <text>` comment expects an
-- error containing `<text>` on the next line of code, and any other error
-- fails the check.

local typing = require("../../../src/luautils/Core/typing")

-- error: Uppercase expects a string singleton or string
local _upper: typing.Uppercase<number> = nil :: any

-- error: Uppercase expects a string singleton or string
local _upperUnion: typing.Uppercase<"a" | number> = nil :: any

-- error: Lowercase expects a string singleton or string
local _lower: typing.Lowercase<boolean> = nil :: any

-- error: Capitalize expects a string singleton or string
local _capitalize: typing.Capitalize<{ a: string }> = nil :: any

-- error: Uncapitalize expects a string singleton or string
local _uncapitalize: typing.Uncapitalize<number> = nil :: any

return nil
