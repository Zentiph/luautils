--!strict

-- operations on any value (like Java's Objects)
-- author(s): @vuppyan

local fail = require("./Errors").errorWithScope("Values")

--[=[
    Protocol-aware operations that work on any value, similar to Java's
    `Objects` utility class.

    Each function dispatches to the matching protocol method when the value is
    a table that has it (such as [typing.Equatable] or [typing.Comparable]),
    and otherwise falls back to the built-in operator or function. This lets one
    function signature accept both primitives and classes:

    ```lua
    Values.equals(1, 1) -- true, using `==`
    Values.equals(Option.some(1), Option.some(1)) -- true, using `:equals()`

    Values.compare("a", "b") -- -1, using `<`
    Values.compare(Duration.SECOND, Duration.MINUTE) -- negative, using `:compareTo()`
    ```

    Error messages thrown by `Values` functions are prefixed with the function
    that threw them, such as `[Values.compare()]: `, after the usual position
    prefix added by `error()`.

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

    Types are checked with `type()`, not `typeof()`, so ROBLOX types such as
    `Instance` and `CFrame` are all `"userdata"`.

    ```lua
    Values.is(5, "number") -- true
    Values.is("hi", "number", "string") -- true
    Values.is(workspace, "Instance") -- false, since `type(workspace)` is "userdata"
    ```

    @since [UNRELEASED]
    @param v any -- The value to check
    @param t string -- The first type to check against (required)
    @param ... string -- Additional types to check against
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

    A value is primitive if its `type()` is one of:
    * `"string"`
    * `"number"`
    * `"boolean"`
    * `"nil"`

    Tables, functions, threads, userdata, buffers, and vectors are not
    considered primitive.

    Use [Values.isImmutable] to check whether a value can be modified instead.

    ```lua
    Values.isPrimitive("hi") -- true
    Values.isPrimitive(nil) -- true
    Values.isPrimitive(print) -- false
    Values.isPrimitive({}) -- false
    ```

    @since [UNRELEASED]
    @param v any -- The value to check
    @return boolean -- Whether the value is primitive
]=]
function Values.isPrimitive(v: any): boolean
    return Values.is(v, "string", "number", "boolean", "nil")
end

--[=[
    Returns `true` if the value is an immutable type.

    A value is immutable if its `type()` is one of:
    * `"string"`
    * `"number"`
    * `"boolean"`
    * `"nil"`
    * `"vector"` (including ROBLOX's `Vector3`)
    * `"function"`

    Tables, threads, userdata, and buffers are not considered immutable, even
    if they are frozen or have no methods that modify them.

    Immutable values are safe to share instead of copying, which is how
    [Values.clone] treats them.

    ```lua
    Values.isImmutable("hi") -- true
    Values.isImmutable(vector.create(1, 2, 3)) -- true
    Values.isImmutable(print) -- true
    Values.isImmutable(table.freeze({})) -- false, since tables never count
    ```

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
    Returns `true` if the values are of types that can be compared with
    [Values.compare].

    This is `true` if `type(a) == type(b)` and either:
    * `a` and `b` are both tables with a `compareTo` method
    ([typing.Comparable]), or
    * `a` and `b` are both numbers or both strings.

    Only the types are checked: `NaN` counts as comparable here, but the
    comparison functions still throw an error for it.

    ```lua
    Values.isComparable(1, 2) -- true
    Values.isComparable("a", "b") -- true
    Values.isComparable(1, "a") -- false, since the types differ
    Values.isComparable(true, false) -- false, since booleans are not ordered
    Values.isComparable(Duration.SECOND, Duration.MINUTE) -- true
    ```

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return boolean -- Whether the values can be compared
]=]
function Values.isComparable<T>(a: T, b: T): boolean
    return type(a) == type(b)
        and (
            (
                isTableAndHasMethod(a, "compareTo")
                and isTableAndHasMethod(b, "compareTo")
            )
            or (type(a) == "number" or type(a) == "string")
        )
end

--[=[
    Returns `true` if the values are equal.

    Equality is checked in this order:
    1. If `rawequal(a, b)` is `true`, `true` is returned.
    2. If `a` is a table with an `equals` method ([typing.Equatable]),
    `a:equals(b)` is returned.
    3. Otherwise, `a == b` is returned.

    This means [typing.Equatable] classes compare by value even if they do not
    set an `__eq` metamethod. Plain tables still compare by reference.

    Matches the [typing.BiPredicate] signature, so it can be passed wherever an
    equality check is expected.

    ```lua
    Values.equals(1, 1) -- true
    Values.equals(Option.some(1), Option.some(1)) -- true
    Values.equals({}, {}) -- false, since plain tables compare by reference
    ```

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
    Compares two values, returning a negative number if `a < b`, a positive
    number if `a > b`, or `0` if they are equal.

    If `a` and `b` are both [typing.Comparable] tables, `a:compareTo(b)` is
    returned. Otherwise, if they are both numbers or both strings, they are
    compared with `<` and `==`, returning `-1`, `0`, or `1`. Strings are
    compared by byte value, the same as `<`.

    Matches the [typing.Comparator] signature. Use [Values.lessThan] for
    `table.sort`, which expects a `boolean` instead.

    ```lua
    Values.compare(1, 2) -- -1
    Values.compare("b", "a") -- 1
    Values.compare(Duration.MINUTE, Duration.SECOND) -- positive
    Values.compare(1, "a") -- error, since the types differ
    Values.compare(0 / 0, 1) -- error, since NaN is not ordered
    ```

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return number -- Negative if `a < b`, positive if `a > b`, or `0` if they are equal
    @error "[Values.compare()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be compared; see [Values.isComparable]
    @error "[Values.compare()]: Cannot meaningfully compare NaN values" -- Thrown if `a` or `b` is `NaN`
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
    Returns `true` if `a` is less than `b`, using [Values.compare].

    Can be passed directly to `table.sort` to sort an array of numbers, strings,
    or [typing.Comparable] values.

    ```lua
    local durations = { Duration.MINUTE, Duration.SECOND, Duration.HOUR }
    table.sort(durations, Values.lessThan)
    -- { Duration.SECOND, Duration.MINUTE, Duration.HOUR }
    ```

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return boolean -- Whether `a` is less than `b`
    @error "[Values.lessThan()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be compared; see [Values.isComparable]
    @error "[Values.lessThan()]: Cannot meaningfully compare NaN values" -- Thrown if `a` or `b` is `NaN`
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
    Returns the smaller of two values, using [Values.compare].

    If the values are equal, `a` is returned. Unlike `math.min`, this works on
    strings and [typing.Comparable] values as well as numbers.

    ```lua
    Values.min(3, 1) -- 1
    Values.min("b", "a") -- "a"
    Values.min(Duration.MINUTE, Duration.SECOND) -- Duration.SECOND
    ```

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return T -- The smaller value, or `a` if they are equal
    @error "[Values.min()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be compared; see [Values.isComparable]
    @error "[Values.min()]: Cannot meaningfully compare NaN values" -- Thrown if `a` or `b` is `NaN`
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
    Returns the larger of two values, using [Values.compare].

    If the values are equal, `a` is returned. Unlike `math.max`, this works on
    strings and [typing.Comparable] values as well as numbers.

    ```lua
    Values.max(3, 1) -- 3
    Values.max("b", "a") -- "b"
    Values.max(Duration.MINUTE, Duration.SECOND) -- Duration.MINUTE
    ```

    @since [UNRELEASED]
    @param a T -- The first value
    @param b T -- The second value
    @return T -- The larger value, or `a` if they are equal
    @error "[Values.max()]: Cannot meaningfully compare values of type {type(a)} and {type(b)}" -- Thrown if the values cannot be compared; see [Values.isComparable]
    @error "[Values.max()]: Cannot meaningfully compare NaN values" -- Thrown if `a` or `b` is `NaN`
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
    Returns `v` limited to the range from `lo` to `hi`, using [Values.compare].

    If `v` is less than `lo`, `lo` is returned; if `v` is greater than `hi`,
    `hi` is returned; otherwise, `v` is returned. Unlike `math.clamp`, this
    works on strings and [typing.Comparable] values as well as numbers.

    ```lua
    Values.clamp(15, 0, 10) -- 10
    Values.clamp("m", "a", "f") -- "f"
    Values.clamp(Duration.HOUR, Duration.ZERO, Duration.MINUTE) -- Duration.MINUTE
    Values.clamp(5, 10, 0) -- error, since `lo` is greater than `hi`
    ```

    @since [UNRELEASED]
    @param v T -- The value to clamp
    @param lo T -- The lower bound
    @param hi T -- The upper bound
    @return T -- The clamped value
    @error "[Values.clamp()]: Cannot meaningfully compare values of type {type(v)} and {type(lo)}" -- Thrown if `v` and `lo` cannot be compared; see [Values.isComparable]
    @error "[Values.clamp()]: Cannot meaningfully compare values of type {type(v)} and {type(hi)}" -- Thrown if `v` and `hi` cannot be compared; see [Values.isComparable]
    @error "[Values.clamp()]: Cannot meaningfully compare NaN values" -- Thrown if `v`, `lo`, or `hi` is `NaN`
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
    Returns a value that can be used as a table key for `v`.

    If `v` is a table with a `toKey` method ([typing.Keyable]), `v:toKey()` is
    returned, so value-equal objects share a table slot. Otherwise, `v` itself
    is returned, so primitives keep their own value as the key and plain tables
    are keyed by reference.

    Keys from [typing.Keyable] values are strings, so they can collide with
    plain string keys in the same table. `NaN` and `nil` throw an error, since
    they cannot be used as table keys.

    ```lua
    local seen = {}
    for _, v in { 1, "a", 1, someKeyable } do
        seen[Values.toKey(v)] = true
    end
    ```

    @since [UNRELEASED]
    @param v any -- The value to get a key for
    @return any -- The key for the value
    @error "[Values.toKey()]: Cannot use NaN as a table key" -- Thrown if `v` is `NaN`
    @error "[Values.toKey()]: Cannot use nil as a table key" -- Thrown if `v` is `nil`
]=]
function Values.toKey(v: any): any
    if type(v) == "number" and math.isnan(v) then
        fail("Cannot use NaN as a table key")
    elseif v == nil then
        fail("Cannot use nil as a table key")
    end

    return if isTableAndHasMethod(v, "toKey") then (v :: any):toKey() else v
end

--[=[
    Returns a string representation of `v`.

    If `v` is a table with a `toString` method ([typing.Stringable]),
    `v:toString()` is returned. Otherwise, `tostring(v)` is returned, which
    uses a `__tostring` metamethod if `v` has one.

    Matches the [typing.Mapper] signature, so it can be passed directly to
    mapping functions.

    ```lua
    Values.toString(5) -- "5"
    Values.toString(Option.some("hi")) -- 'Some("hi")'
    Values.toString(Duration.WEEK) -- "P7D"
    ```

    @since [UNRELEASED]
    @param v any -- The value to convert
    @return string -- The string representation
]=]
function Values.toString(v: any): string
    return if isTableAndHasMethod(v, "toString")
        then (v :: any):toString()
        else tostring(v)
end

--[=[
    Returns a copy of `v`.

    If `v` is a table with a `clone` method ([typing.Cloneable]), `v:clone()` is
    returned. Otherwise, if `v` is immutable (see [Values.isImmutable]), `v`
    itself is returned, since it cannot be modified. Otherwise, an error is
    thrown: plain tables are not copied, since a shallow and a deep copy are
    both reasonable. Use `table.clone` or [Tables.deepCopy] for those.

    ```lua
    Values.clone(5) -- 5
    Values.clone(vector.create(1, 2, 3)) -- the same vector
    Values.clone(someCloneable) -- someCloneable:clone()
    Values.clone({}) -- error, use table.clone() or Tables.deepCopy()
    ```

    @since [UNRELEASED]
    @param v T -- The value to copy
    @return T -- The copy, or `v` itself if it is immutable
    @error "[Values.clone()]: Cannot clone value of type {type(v)}. (...)" -- Thrown if `v` is not immutable and has no `clone` method. The message continues with a hint to add a `clone` method, or to use `table.clone()` or [Tables.deepCopy]
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
