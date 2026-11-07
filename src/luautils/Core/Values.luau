--!strict

-- operations on any value (like Java's Objects)
-- author(s): @vuppyan

--[=[
    Protocol-aware operations on any value.

    Each function dispatches to the protocol method when the value has it, and
    otherwise falls back to the built-in operator.

    @class Values
    @since [UNRELEASED]
]=]
local Values = {}

--[=[
    Returns `true` if the arguments are equal to each other.

    If `rawequal(a, b)` is `true`, `true` is returned.
    Otherwise, if `a` is a table, and matches the [Equatable] protocol, then
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
        elseif type(a) == "table" and type(a.equals) == "function" then (
            a :: any
        ):equals(b)
        else a == b
end

return Values
