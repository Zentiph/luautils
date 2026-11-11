--!strict

-- typing table type function tests that must fail to type check
-- by @vuppyan

-- Checked by `.lute/typing.luau`: each `-- error: <text>` comment expects an
-- error containing `<text>` on the next line of code, and any other error
-- fails the check.

local typing = require("../../../src/luautils/Core/typing")

type A = { a: number, s: string }
type B = { b: boolean, s: string }

--[[ non-table types ]]

-- error: Partial expects table types
local _partial: typing.Partial<string> = nil :: any

-- error: Partial expects table types
local _partialUnion: typing.Partial<A | string> = nil :: any

-- error: DeepPartial expects table types
local _deepPartial: typing.DeepPartial<number> = nil :: any

-- error: Required expects table types
local _required: typing.Required<string> = nil :: any

-- error: DeepRequired expects table types
local _deepRequired: typing.DeepRequired<boolean> = nil :: any

-- error: ReadOnly expects table types
local _readOnly: typing.ReadOnly<string> = nil :: any

-- error: DeepReadOnly expects table types
local _deepReadOnly: typing.DeepReadOnly<string> = nil :: any

-- error: Writable expects table types
local _writable: typing.Writable<string> = nil :: any

-- error: DeepWritable expects table types
local _deepWritable: typing.DeepWritable<string> = nil :: any

--[[ Pick ]]

-- error: Pick: property "missing" does not exist
local _pickMissing: typing.Pick<A, "missing"> = nil :: any

-- error: Pick: property "a" does not exist
local _pickUnion: typing.Pick<A | B, "a"> = nil :: any

-- error: Pick: property "zz" does not exist
local _pickIntersection: typing.Pick<A & B, "zz"> = nil :: any

-- error: Pick expects string singleton keys
local _pickKey: typing.Pick<A, string> = nil :: any

-- error: Pick expects table types
local _pickTable: typing.Pick<string, "a"> = nil :: any

--[[ Omit ]]

-- error: Omit expects string singleton keys
local _omitKey: typing.Omit<A, string> = nil :: any

-- error: Omit expects table types
local _omitTable: typing.Omit<string, "a"> = nil :: any

--[[ Merge ]]

-- error: Merge expects table types for A
local _mergeA: typing.Merge<string, A> = nil :: any

-- error: Merge expects table types for B
local _mergeB: typing.Merge<A, string> = nil :: any

-- error: Merge expects table types for B
local _mergeBUnion: typing.Merge<A, B | string> = nil :: any

return nil
