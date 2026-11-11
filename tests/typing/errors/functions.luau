--!strict

-- typing function type function tests that must fail to type check
-- by @vuppyan

-- Checked by `.lute/typing.luau`: each `-- error: <text>` comment expects an
-- error containing `<text>` on the next line of code, and any other error
-- fails the check.

local typing = require("../../../src/luautils/Core/typing")

type F = (name: string, level: number) -> number
type Pack = <T...>(T...) -> T...

--[[ Parameter ]]

-- error: Parameter expects function types
local _paramFunction: typing.Parameter<string, "1"> = nil :: any

-- error: Parameter expects a string index like "1"
local _paramIndexType: typing.Parameter<F, string> = nil :: any

-- error: Parameter expects a positive integer index like "1"
local _paramZero: typing.Parameter<F, "0"> = nil :: any

-- error: Parameter expects a positive integer index like "1"
local _paramFraction: typing.Parameter<F, "1.5"> = nil :: any

-- error: Parameter expects a positive integer index like "1"
local _paramWord: typing.Parameter<F, "first"> = nil :: any

-- error: Parameter: function has no parameter 3
local _paramMissing: typing.Parameter<F, "3"> = nil :: any

-- error: Parameter: function has no parameter 2
local _paramUnion: typing.Parameter<F | ((string) -> ()), "2"> = nil :: any

-- error: Parameter: function has no parameter 3
local _paramOverloads: typing.Parameter<F & ((string) -> ()), "3"> = nil :: any

-- error: Parameter: parameter 1 falls inside a generic type pack
local _paramPack: typing.Parameter<Pack, "1"> = nil :: any

--[[ ReturnType ]]

-- error: ReturnType expects function types
local _returnFunction: typing.ReturnType<string> = nil :: any

-- error: ReturnType: first return falls inside a generic type pack
local _returnPack: typing.ReturnType<Pack> = nil :: any

--[[ OmitSelf ]]

-- error: OmitSelf expects function types
local _omitSelfFunction: typing.OmitSelf<string> = nil :: any

-- error: OmitSelf expects functions with at least one parameter
local _omitSelfEmpty: typing.OmitSelf<() -> ()> = nil :: any

-- error: OmitSelf expects functions with at least one parameter
local _omitSelfOverloads: typing.OmitSelf<F & (() -> ())> = nil :: any

return nil
