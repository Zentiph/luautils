--!strict

-- deepCopy function
-- by @vuppyan

local Core = require("../Core")
type Map<K, V> = Core.Map<K, V>

local function deepCopyImpl(
    t: Map<any, any>,
    visited: Map<Map<any, any>, Map<any, any>>
): Map<any, any>
    local copy = {}
    visited[t] = copy

    for key, value in t do
        if type(value) == "table" then
            copy[key] = visited[value] or deepCopyImpl(value, visited)
        else
            copy[key] = value
        end
    end

    local mt = getmetatable(t)
    assert(
        mt == nil or type(mt) == "table",
        "[deepCopy]: cannot copy a table with a locked metatable"
    )
    if type(mt) == "table" then
        setmetatable(copy, mt)
    end

    return copy
end

--- Returns a deep copy of the given table.
---
--- @param tbl T -- The table to copy
--- @return T -- The copied table
return function<T>(tbl: T): T
    return deepCopyImpl(tbl, {})
end
