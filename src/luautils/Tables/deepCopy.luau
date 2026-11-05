--!strict

-- deepCopy function
-- by @vuppyan

local Core = require("../Core")
type Map<K, V> = Core.Map<K, V>

local fail = Core.Errors.errorWithScope("Tables")

-- stop optimizations from inlining helpers that need to track call stack
local Internal = {}

function Internal.deepCopyImpl(
    t: Map<any, any>,
    visited: Map<Map<any, any>, Map<any, any>>,
    level: number
): Map<any, any>
    local copy = {}
    visited[t] = copy

    local mt = getmetatable(t)
    if mt ~= nil and type(mt) ~= "table" then
        fail("Cannot copy a table with a locked metatable", level, "deepCopy")
    end

    -- bypass a table's __iter with using next directly
    for key, value in next, t do
        if type(value) == "table" then
            copy[key] = visited[value]
                or Internal.deepCopyImpl(value, visited, level + 1)
        else
            copy[key] = value
        end
    end

    if type(mt) == "table" then
        setmetatable(copy, mt)
    end
    if table.isfrozen(t) then
        table.freeze(copy)
    end

    return copy :: Map<any, any>
end

--- Returns a deep copy of the given table.
---
--- Table keys are shared with the original, not copied.
--- Copies of frozen tables are also frozen.
--- Metatables are shared with the original, not copied, and `__iter`
--- metamethods are bypassed so every raw key/value pair is copied.
---
--- If a non-table value is passed, it is returned as-is.
---
--- @function deepCopy
--- @within Tables
--- @param tbl T -- The table to copy
--- @return T -- The copied table
--- @error "[Tables.deepCopy()]: Cannot copy a table with a locked metatable" -- Thrown if the table has a locked metatable (note that metatables locked by tables are not detected)
return function<T>(tbl: T): T
    return (
        if type(tbl) ~= "table" then tbl else Internal.deepCopyImpl(tbl, {}, 3)
    ) :: T
end
