--!strict

-- operations on any value (like Java's Objects)
-- author(s): @vuppyan

local fail = require("./Errors").errorWithScope("Values")

--[=[
    Protocol-aware operations on any value.

    Each function dispatches to the protocol method when the value has it, and
    otherwise falls back to the built-in operator.

    @class Values
    @since [UNRELEASED]
]=]
local Values = {}

local function isTableAndHasMethod(v: any, method: string): boolean
    return type(v) == "table" and type(v[method]) == "function"
end

--[=[
    Returns `true` if the value is a primitive type (not a table or userdata).

    @since [UNRELEASED]
    @param v any -- The value to check
    @return boolean -- Whether the value is primitive
]=]
function Values.isPrimitive(v: any): boolean
    return type(v) ~= "table" and type(v) ~= "userdata"
end

--[=[
    Returns `true` if the arguments are equal to each other.

    If `rawequal(a, b)` is `true`, `true` is returned.
    Otherwise, if `a` is a table and matches the [Equatable] protocol, then
    the result of `a:equals(b)` is returned.
    Otherwise, `a == b` is returned.

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return boolean -- Whether the values are equal
]=]
function Values.equals<T>(a: T, b: T): boolean
    return if rawequal(a, b)
        then true
        elseif isTableAndHasMethod(a, "equals") then (a :: any):equals(b)
        else a == b
end

--[=[
    Compares two values, returning a negative number if `a` < `b`, a positive
    number if `a` > `b`, or `0` if `a` == `b`.

    If `a` is a table and matches the [Comparable] protocol, then the result of
    `a:compareTo(b)` is returned.
    Otherwise, if `a` and `b` are the same type and support total ordering, then
    the result of comparing `a` and `b` with `<` and `==` is returned.
    Otherwise, an error is thrown.

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return number -- The comparison result
    @error "[Values.compare()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be meaningfully compared
]=]
function Values.compare<T>(a: T, b: T): number
    if isTableAndHasMethod(a, "compareTo") then
        return (a :: any):compareTo(b)
    elseif
        type(a) == type(b) and (type(a) == "number" or type(a) == "string")
    then
        return if a < b then -1 elseif a == b then 0 else 1
    else
        fail(
            `Cannot meaningfully compare values of type {type(a)} and {type(b)}`
        )
        return 0 -- unreachable, just to make the type checker happy
    end
end

--[=[
    Returns the value as a key for a table.

    If `v` is a table and matches the [Keyable] protocol, then the result of
    `v:toKey()` is returned.
    Otherwise, `v` itself is returned

    @since [UNRELEASED]
    @param v any -- The value to convert to a key
    @return any -- The value as a key
]=]
function Values.toKey(v: any): any
    return if isTableAndHasMethod(v, "toKey") then (v :: any).toKey() else v
end

--[=[
    Returns the value as a string.

    If `v` is a table and matches the [Stringable] protocol, then the result of
    `v:toString()` is returned.
    Otherwise, `tostring(v)` is returned.

    @since [UNRELEASED]
    @param v any -- The value to convert to a string
    @return string -- The value as a string
]=]
function Values.toString(v: any): string
    return if isTableAndHasMethod(v, "toString")
        then (v :: any).toString()
        else tostring(v)
end

return Values
