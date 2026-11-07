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

-- prevent function inlining for helpers that require call stack consistency
local Internal = {}

function Internal.compareFail<T>(a: T, b: T, functionName: string): never
    return fail(
        `Cannot meaningfully compare values of type {type(a)} and {type(b)}`,
        3,
        functionName
    )
end

function Internal.nanFail(functionName: string): never
    return fail("Cannot meaningfully compare NaN values", 3, functionName)
end

local function isTableAndHasMethod(v: any, method: string): boolean
    return type(v) == "table" and type(v[method]) == "function"
end

--[=[
    Returns `true` if the value is one of the given types.

    @since [UNRELEASED]
    @param v any -- The value to check
    @param t string -- The first type to check (required)
    @param ... string -- Additional types to check
    @return boolean -- Whether the value is one of the types
]=]
function Values.is(v: any, t: string, ...: string): boolean
    if type(v) == t then
        return true
    end

    for i = 1, select("#", ...) do
        if type(v) == select(i, ...) then
            return true
        end
    end

    return false
end

--[=[
    Returns `true` if the value is a primitive type.

    A value is a primitive type if it is a:
    * string
    * number
    * boolean
    * nil

    Tables, functions, threads, and userdata are not considered primitive types.

    @since [UNRELEASED]
    @param v any -- The value to check
    @return boolean -- Whether the value is primitive
]=]
function Values.isPrimitive(v: any): boolean
    return Values.is(v, "string", "number", "boolean", "nil")
end

--[=[
    Returns `true` if the value is an immutable type.

    A value is an immutable type if it is a:
    * string
    * number
    * boolean
    * nil
    * vector
    * function

    Tables, threads, and userdata are not considered immutable types.

    @since [UNRELEASED]
    @param v any -- The value to check
    @return boolean -- Whether the value is immutable
]=]
function Values.isImmutable(v: any): boolean
    return Values.is(
        v,
        "string",
        "number",
        "boolean",
        "nil",
        "vector",
        "function"
    )
end

--[=[
    Returns `true` if the arguments can be meaningfully compared.

    If `a` and `b` are tables and match the [Comparable] protocol, then `true`
    is returned.
    Otherwise, if `a` and `b` are the same type and support total ordering, then
    `true` is returned.
    Otherwise, `false` is returned.

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return boolean -- Whether the values can be meaningfully compared
]=]
function Values.isComparable<T>(a: T, b: T): boolean
    return (
        isTableAndHasMethod(a, "compareTo")
        and isTableAndHasMethod(b, "compareTo")
    )
        or (type(a) == type(b) and (type(a) == "number" or type(a) == "string"))
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

    If `a` and `b` are tables and match the [Comparable] protocol, then the
    result of `a:compareTo(b)` is returned.
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
    if not Values.isComparable(a, b) then
        Internal.compareFail(a, b, "compare")
    elseif
        (type(a) == "number" and math.isnan(a))
        or (type(b) == "number" and math.isnan(b))
    then
        Internal.nanFail("compare")
    end

    if isTableAndHasMethod(a, "compareTo") then
        return (a :: any):compareTo(b)
    else
        return if (a :: any) < b then -1 elseif a == b then 0 else 1
    end
end

--[=[
    Returns `true` if `a` < `b`.

    If `a` and `b` are tables and match the [Comparable] protocol, then the
    result of `a:compareTo(b) < 0` is returned.
    Otherwise, if `a` and `b` are the same type and support total ordering, then
    the result of comparing `a` and `b` with `<` is returned.
    Otherwise, an error is thrown.

    Can be passed to `table.sort` to sort a table of values that support total
    ordering.

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return boolean -- Whether `a` < `b`
    @error "[Values.lessThan()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be meaningfully compared
]=]
function Values.lessThan<T>(a: T, b: T): boolean
    if not Values.isComparable(a, b) then
        Internal.compareFail(a, b, "lessThan")
    elseif
        (type(a) == "number" and math.isnan(a))
        or (type(b) == "number" and math.isnan(b))
    then
        Internal.nanFail("lessThan")
    end

    return Values.compare(a, b) < 0
end

--[=[
    Returns the smaller of two values.

    If `a` and `b` are tables and match the [Comparable] protocol, then the
    result of comparison using `a:compareTo(b)` is returned.
    Otherwise, if `a` and `b` are the same type and support total ordering, then
    the result of comparing `a` and `b` with `<` and `==` is returned.
    Otherwise, an error is thrown.

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return T -- The smaller value
    @error "[Values.min()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be meaningfully compared
]=]
function Values.min<T>(a: T, b: T): T
    if not Values.isComparable(a, b) then
        Internal.compareFail(a, b, "min")
    elseif
        (type(a) == "number" and math.isnan(a))
        or (type(b) == "number" and math.isnan(b))
    then
        Internal.nanFail("min")
    end

    return if Values.compare(a, b) <= 0 then a else b
end

--[=[
    Returns the larger of the values.

    If `a` and `b` are tables and match the [Comparable] protocol, then the
    result of comparison using `a:compareTo(b)` is returned.
    Otherwise, if `a` and `b` are the same type and support total ordering, then
    the result of comparing `a` and `b` with `<` and `==` is returned.
    Otherwise, an error is thrown.

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return T -- The larger value
    @error "[Values.max()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be meaningfully compared
]=]
function Values.max<T>(a: T, b: T): T
    if not Values.isComparable(a, b) then
        Internal.compareFail(a, b, "max")
    elseif
        (type(a) == "number" and math.isnan(a))
        or (type(b) == "number" and math.isnan(b))
    then
        Internal.nanFail("max")
    end

    return if Values.compare(a, b) >= 0 then a else b
end

--[=[
    Returns the value clamped between `lo` and `hi`.

    If `v`, `lo`, and `hi` are tables and match the [Comparable] protocol, then
    the result of comparison using `v:compareTo(lo)` and `v:compareTo(hi)` is
    returned.
    Otherwise, if `v` and `lo`/`hi` are the same type and support total ordering, then
    the result of comparing `v` and `lo`/`hi` with `<` and `==` is returned.
    Otherwise, an error is thrown.

    @since [UNRELEASED]
    @param v T -- The value to clamp
    @param lo T -- The lower bound
    @param hi T -- The upper bound
    @return T -- The clamped value
    @error "[Values.clamp()]: Cannot meaningfully compare values of type {type(v)} and {type(lo|hi)}" -- Thrown if the values cannot be meaningfully compared
    @error "[Values.clamp()]: lo must be less than or equal to hi" -- Thrown if `lo` is greater than `hi`
]=]
function Values.clamp<T>(v: T, lo: T, hi: T): T
    if not Values.isComparable(v, lo) then
        Internal.compareFail(v, lo, "clamp")
    elseif not Values.isComparable(v, hi) then
        Internal.compareFail(v, hi, "clamp")
    elseif
        (type(v) == "number" and math.isnan(v))
        or (type(lo) == "number" and math.isnan(lo))
        or (type(hi) == "number" and math.isnan(hi))
    then
        Internal.nanFail("clamp")
    elseif Values.compare(lo, hi) > 0 then
        fail("lo must be less than or equal to hi")
    end

    return Values.min(Values.max(v, lo), hi)
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
    return if isTableAndHasMethod(v, "toKey") then (v :: any):toKey() else v
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
        then (v :: any):toString()
        else tostring(v)
end

--[=[
    Returns a copy of the value.

    If `v` is a table and matches the [Cloneable] protocol, then the result of
    `v:clone()` is returned.
    Otherwise, if `v` is a primitive type, then `v` itself is returned.
    Otherwise, an error is thrown.

    @since [UNRELEASED]
    @param v T -- The value to clone
    @return T -- The cloned value
    @error "[Values.clone()]: Cannot clone value of type {type(v)}." -- Thrown if the value cannot be cloned
]=]
function Values.clone<T>(v: T): T
    return if isTableAndHasMethod(v, "clone")
        then (v :: any):clone()
        elseif Values.isImmutable(v) then v
        else fail(
            `Cannot clone value of type {type(v)}. `
                .. "(If you are trying to clone a class, "
                .. "give it a .clone() method to match the Cloneable protocol. "
                .. "If you are trying to clone a table, "
                .. "use table.clone() for shallow copies or "
                .. "Tables.deepCopy() for deep copies.)"
        )
end

return table.freeze(Values)
