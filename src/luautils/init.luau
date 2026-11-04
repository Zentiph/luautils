--!strict

-- Luautils central imports
-- by @vuppyan

--- Luautils -- A Luau utilities library
---
--- Contains tools for general use when coding in Luau, with a heavy focus on
--- functional programming, inspired by the Rust standard library.
local Luautils = {}

Luautils.Core = require("@self/Core")

Luautils.Collections = require("@self/Collections")
Luautils.Math = require("@self/Math")
Luautils.Strings = require("@self/Strings")
Luautils.Tables = require("@self/Tables")
Luautils.Time = require("@self/Time")
Luautils.Validation = require("@self/Validation")

Luautils.Async = require("@self/Async")
Luautils.Events = require("@self/Events")

Luautils.Roblox = require("@self/Roblox")

return Luautils
