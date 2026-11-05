--!strict

-- Option type
-- by @vuppyan

local typing = require("./typing")
type Action = typing.Action
type Array<T> = typing.Array<T>
type BiMapper<T, U, R> = typing.BiMapper<T, U, R>
type Consumer<T> = typing.Consumer<T>
type Map<K, V> = typing.Map<K, V>
type Mapper<T, U> = typing.Mapper<T, U>
type Predicate<T> = typing.Predicate<T>
type Supplier<T> = typing.Supplier<T>

local repr = require("../_internal").repr
local fail = require("./Errors").errorWithScope("Option")

--- An optional value: an `Option` is either "some" and holds a value, or
--- "none" and does not.
---
--- A "some" cannot hold `nil`; an `Option` is "none" exactly when its value is
--- `nil`. `Option`s are frozen and cannot be modified.
---
--- Supports `==` and `~=` comparison and `tostring()`.
---
--- Error messages thrown by `Option` functions are prefixed with the function
--- that threw them, such as `[Option.unwrap()]: `, after the usual position
--- prefix added by `error()`. Errors from [Option:unwrapOrThrow] are thrown
--- as-is and are not prefixed.
---
--- @class Option
local Option = {}
Option.__index = Option

type OptionData<T> = {
    read _value: T?,
}

--- An `Option` that may hold a value of type `T`.
---
--- @type Option Option<T>
--- @within Option
export type Option<T> = typeof(setmetatable({} :: OptionData<T>, Option))

-- Helper for creating a new Option
local function new<T>(value: T?): Option<T>
    return table.freeze(setmetatable({ _value = value }, Option))
end

local NONE = new(nil)

--- Creates a new "some" `Option` with the specified value.
---
--- @param value T -- The value to wrap
--- @return Option<T> -- The new `Option`
--- @error "[Option.some()]: Value cannot be nil" -- Thrown if `value` is `nil`; use [Option.fromNillable] for nillable values
function Option.some<T>(value: T): Option<T>
    if value == nil then
        fail(
            "Value cannot be nil "
                .. "(use Option.fromNillable() for nillable values)"
        )
    end
    return new(value)
end

--- Creates a new "none" `Option`.
---
--- This returns a singleton instance, meaning creating more "none" `Option`s
--- does not allocate more memory.
---
--- @return Option<T> -- The "none" `Option`
function Option.none<T>(): Option<T>
    return NONE
end

--- Creates a new `Option` from a nillable value.
---
--- Creates a "some" for any non-nil value, and a "none" for `nil`.
---
--- ```lua
--- Option.fromNillable(5) -- Some(5)
--- Option.fromNillable(false) -- Some(false), since only `nil` is "none"
--- Option.fromNillable(nil) -- None
--- ```
---
--- @param value T? -- The value to wrap
--- @return Option<T> -- The new `Option`
function Option.fromNillable<T>(value: T?): Option<T>
    return if value == nil then Option.none() else new(value)
end

--- Returns the contained value if the `Option` is "some", otherwise returns
--- `nil`.
---
--- Useful for APIs that accept optional values, and provides type-checking
--- where `unwrapOr(nil)` wouldn't.
---
--- @method toNillable
--- @within Option
--- @return T? -- The contained value, or `nil`
function Option.toNillable<T>(self: Option<T>): T?
    return self._value
end

--- Returns `true` if the `Option` is "some".
---
--- @method isSome
--- @within Option
--- @return boolean -- Whether the `Option` is "some"
function Option.isSome<T>(self: Option<T>): boolean
    return self._value ~= nil
end

--- Returns `true` if the `Option` is "some" and the contained value matches a
--- predicate.
---
--- `predicate` is only called if the `Option` is "some".
---
--- @method isSomeAnd
--- @within Option
--- @param predicate Predicate<T> -- The predicate to check the value against
--- @return boolean -- Whether the `Option` is "some" and the value matches the predicate
function Option.isSomeAnd<T>(self: Option<T>, predicate: Predicate<T>): boolean
    return self:isSome() and predicate(self._value :: T)
end

--- Returns `true` if the `Option` is "none".
---
--- @method isNone
--- @within Option
--- @return boolean -- Whether the `Option` is "none"
function Option.isNone<T>(self: Option<T>): boolean
    return not self:isSome()
end

--- Returns `true` if the `Option` is "none" or the contained value matches a
--- predicate.
---
--- `predicate` is only called if the `Option` is "some".
---
--- @method isNoneOr
--- @within Option
--- @param predicate Predicate<T> -- The predicate to check the value against
--- @return boolean -- Whether the `Option` is "none" or the value matches the predicate
function Option.isNoneOr<T>(self: Option<T>, predicate: Predicate<T>): boolean
    return not self:isSome() or predicate(self._value :: T)
end

--- Returns the contained value, or throws with the provided message if the
--- `Option` is "none".
---
--- @method expect
--- @within Option
--- @param message string -- The error message
--- @return T -- The contained value
--- @error "[Option.expect()]: {message}" -- Thrown if the `Option` is "none"
function Option.expect<T>(self: Option<T>, message: string): T
    if self:isNone() then
        fail(message)
    end
    return self._value :: T
end

--- Returns the contained value, or throws if the `Option` is "none".
---
--- @method unwrap
--- @within Option
--- @return T -- The contained value
--- @error '[Option.unwrap()]: Attempted to unwrap an Option that was "none"' -- Thrown if the `Option` is "none"
function Option.unwrap<T>(self: Option<T>): T
    if self:isNone() then
        fail('Attempted to unwrap an Option that was "none"')
    end
    return self._value :: T
end

--- Returns the contained value or a provided default.
---
--- `default` is evaluated even if the `Option` is "some"; use
--- [Option:unwrapOrElse] if the default is expensive to create.
---
--- @method unwrapOr
--- @within Option
--- @param default T -- The default value to return if the `Option` is "none"
--- @return T -- The contained value, or the provided default
function Option.unwrapOr<T>(self: Option<T>, default: T): T
    return if self:isSome() then self._value :: T else default
end

--- Returns the contained value or computes one using `supplier`.
---
--- `supplier` is only called if the `Option` is "none".
---
--- @method unwrapOrElse
--- @within Option
--- @param supplier Supplier<T> -- The function to call if the `Option` is "none"
--- @return T -- The contained value, or the computed value
function Option.unwrapOrElse<T>(self: Option<T>, supplier: Supplier<T>): T
    return if self:isSome() then self._value :: T else supplier()
end

--- Returns the contained value, or throws the error computed by
--- `errorSupplier` if the `Option` is "none".
---
--- `errorSupplier` is only called if the `Option` is "none". Its return value
--- is thrown as-is, so tables and other values keep their data. String errors
--- are prefixed with the caller's position, as with `error()`.
---
--- ```lua
--- local value = Option.none():unwrapOrThrow(function()
---     return { code = 404 } -- thrown as a table, so `code` is kept
--- end)
--- ```
---
--- @method unwrapOrThrow
--- @within Option
--- @param errorSupplier Supplier<any> -- The function that supplies the error
--- @return T -- The contained value
--- @error any -- Thrown if the `Option` is "none"
function Option.unwrapOrThrow<T>(self: Option<T>, errorSupplier: Supplier<any>): T
    return if self:isSome() then self._value :: T else error(errorSupplier(), 2)
end

--- Returns `true` if the `Option` is "some" and the contained value is equal
--- to `value`.
---
--- Values are compared with `==`.
---
--- ```lua
--- Option.some(1):contains(1) -- true
--- Option.some({}):contains({}) -- false, since the tables are different
--- ```
---
--- @method contains
--- @within Option
--- @param value T -- The value to compare against
--- @return boolean -- Whether the `Option` holds `value`
function Option.contains<T>(self: Option<T>, value: T): boolean
    return self:isSome() and self._value == value
end

--- Creates a "some" holding `value` if `condition` is `true`, otherwise
--- returns "none".
---
--- `value` is evaluated even if `condition` is `false`; use [Option.whenThen]
--- if the value is expensive to create.
---
--- ```lua
--- Option.when(true, 1) -- Some(1)
--- Option.when(false, 1) -- None
--- ```
---
--- @param condition boolean -- The condition to check
--- @param value T -- The value to wrap if `condition` is `true`
--- @return Option<T> -- A "some" holding `value`, or "none"
--- @error "[Option.some()]: Value cannot be nil" -- Thrown if `condition` is `true` and `value` is `nil`
function Option.when<T>(condition: boolean, value: T): Option<T>
    return if condition then Option.some(value) else Option.none()
end

--- Like [Option.when], but returns the result of calling `supplier` instead.
---
--- `supplier` is only called if `condition` is `true`.
---
--- ```lua
--- Option.whenThen(true, createValue) -- Some(createValue())
--- Option.whenThen(false, createValue) -- None; `createValue` is never called
--- ```
---
--- @param condition boolean -- The condition to check
--- @param supplier Supplier<T> -- The function to call if `condition` is `true`
--- @return Option<T> -- The result of calling `supplier`, or "none"
--- @error "[Option.some()]: Value cannot be nil" -- Thrown if `condition` is `true` and `supplier` returns `nil`
function Option.whenThen<T>(condition: boolean, supplier: Supplier<T>): Option<T>
    return if condition then Option.some(supplier()) else Option.none()
end

--- Maps an `Option<T>` to `Option<U>` by applying a function to a contained
--- value, leaving a "none" untouched.
---
--- If `mapper` returns `nil`, the result is "none".
---
--- ```lua
--- Option.some(5):map(function(x)
---     return x * 2
--- end) -- Some(10)
--- Option.some(5):map(function()
---     return nil
--- end) -- None
--- ```
---
--- @method map
--- @within Option
--- @param mapper Mapper<T, U?> -- The function to apply to the contained value
--- @return Option<U> -- The mapped `Option`
function Option.map<T, U>(self: Option<T>, mapper: Mapper<T, U?>): Option<U>
    return if self:isSome()
        then Option.fromNillable(mapper(self._value :: T))
        else Option.none()
end

--- Maps an `Option<T>` to `U` by applying a function to a contained value, or
--- returning the provided default if "none".
---
--- `default` is evaluated even if the `Option` is "some"; use
--- [Option:mapOrElse] if the default is expensive to create.
---
--- ```lua
--- local function double(x: number): number
---     return x * 2
--- end
--- Option.some(5):mapOr(0, double) -- 10
--- Option.none():mapOr(0, double) -- 0
--- ```
---
--- @method mapOr
--- @within Option
--- @param default U -- The default value to return if the `Option` is "none"
--- @param mapper Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The provided default value, or the mapped value
function Option.mapOr<T, U>(self: Option<T>, default: U, mapper: Mapper<T, U>): U
    return if self:isSome() then mapper(self._value :: T) else default
end

--- Maps an `Option<T>` to `U` by applying `mapper` to a contained value, or
--- calling the fallback function `supplier` if "none".
---
--- ```lua
--- local function double(x: number): number
---     return x * 2
--- end
--- local function fallback(): number
---     return -1
--- end
--- Option.some(5):mapOrElse(fallback, double) -- 10
--- Option.none():mapOrElse(fallback, double) -- -1
--- ```
---
--- @method mapOrElse
--- @within Option
--- @param supplier Supplier<U> -- The function to call if the `Option` is "none"
--- @param mapper Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The computed default value, or the mapped value
function Option.mapOrElse<T, U>(
    self: Option<T>,
    supplier: Supplier<U>,
    mapper: Mapper<T, U>
): U
    return if self:isSome() then mapper(self._value :: T) else supplier()
end

--- Calls a function with the contained value if "some".
---
--- Returns the original `Option`.
---
--- @method inspect
--- @within Option
--- @param consumer Consumer<T> -- The function to call with the contained value
--- @return Option<T> -- The original `Option`
function Option.inspect<T>(self: Option<T>, consumer: Consumer<T>): Option<T>
    if self:isSome() then
        consumer(self._value :: T)
    end
    return self
end

--- Returns `other` if the `Option` is "some", otherwise returns "none".
---
--- `other` is evaluated even if the `Option` is "none"; use [Option:andThen] if
--- it is expensive to create.
---
--- ```lua
--- Option.some(1):andOption(Option.some("a")) -- Some("a")
--- Option.some(1):andOption(Option.none()) -- None
--- Option.none():andOption(Option.some("a")) -- None
--- ```
---
--- @method andOption
--- @within Option
--- @param other Option<U> -- The `Option` to return if the `Option` is "some"
--- @return Option<U> -- `other`, or "none"
function Option.andOption<T, U>(self: Option<T>, other: Option<U>): Option<U>
    return if self:isSome() then other else Option.none()
end

--- Calls `mapper` with the contained value if the `Option` is "some",
--- otherwise returns "none".
---
--- This operation is also known as "flatmap".
---
--- ```lua
--- local function parseNumber(s: string): Option<number>
---     return Option.fromNillable(tonumber(s))
--- end
--- Option.some("42"):andThen(parseNumber) -- Some(42)
--- Option.some("abc"):andThen(parseNumber) -- None
--- Option.none():andThen(parseNumber) -- None
--- ```
---
--- @method andThen
--- @within Option
--- @param mapper Mapper<T, Option<U>> -- The function to call if the `Option` is "some"
--- @return Option<U> -- The `Option` returned by `mapper`, or "none"
function Option.andThen<T, U>(
    self: Option<T>,
    mapper: Mapper<T, Option<U>>
): Option<U>
    return if self:isSome() then mapper(self._value :: T) else Option.none()
end

--- Returns the original `Option` if it is "some" and the contained value
--- matches `predicate`, otherwise returns "none".
---
--- `predicate` is only called if the `Option` is "some".
---
--- ```lua
--- local function isEven(x: number): boolean
---     return x % 2 == 0
--- end
--- Option.some(4):filter(isEven) -- Some(4)
--- Option.some(3):filter(isEven) -- None
--- ```
---
--- @method filter
--- @within Option
--- @param predicate Predicate<T> -- The predicate to check the value against
--- @return Option<T> -- The original `Option`, or "none"
function Option.filter<T>(self: Option<T>, predicate: Predicate<T>): Option<T>
    return if self:isSome() and predicate(self._value :: T)
        then self
        else Option.none()
end

--- Returns `other` if the `Option` is "none", otherwise returns `self`.
---
--- `other` is evaluated even if the `Option` is "some"; use [Option:orElse] if
--- it is expensive to create.
---
--- ```lua
--- Option.some(1):orOption(Option.some(2)) -- Some(1)
--- Option.none():orOption(Option.some(2)) -- Some(2)
--- ```
---
--- @method orOption
--- @within Option
--- @param other Option<T> -- The `Option` to return if the `Option` is "none"
--- @return Option<T> -- `other`, or the original "some" `Option`
function Option.orOption<T>(self: Option<T>, other: Option<T>): Option<T>
    return if self:isSome() then self else other
end

--- Calls `supplier` if the `Option` is "none", otherwise returns `self`.
---
--- @method orElse
--- @within Option
--- @param supplier Supplier<Option<T>> -- The function to call if the `Option` is "none"
--- @return Option<T> -- The `Option` returned by `supplier`, or the original "some" `Option`
function Option.orElse<T>(
    self: Option<T>,
    supplier: Supplier<Option<T>>
): Option<T>
    return if self:isSome() then self else supplier()
end

--- Calls `ifSome` with the contained value if the `Option` is "some",
--- otherwise calls `ifNone`.
---
--- Returns nothing; the return values of `ifSome` and `ifNone` are discarded.
--- Use [Option:mapOrElse] to produce a value instead.
---
--- @method match
--- @within Option
--- @param ifSome Consumer<T> -- The function to call with the contained value
--- @param ifNone Action -- The function to call if the `Option` is "none"
function Option.match<T>(self: Option<T>, ifSome: Consumer<T>, ifNone: Action): ()
    if self:isSome() then
        ifSome(self._value :: T)
    else
        ifNone()
    end
end

--- Returns "some" if exactly one of `self` and `other` is "some", otherwise
--- returns "none".
---
--- ```lua
--- Option.some(1):xor(Option.none()) -- Some(1)
--- Option.none():xor(Option.some(2)) -- Some(2)
--- Option.some(1):xor(Option.some(2)) -- None
--- Option.none():xor(Option.none()) -- None
--- ```
---
--- @method xor
--- @within Option
--- @param other Option<T> -- The `Option` to compare with the current `Option`
--- @return Option<T> -- The single "some" `Option`, or "none"
function Option.xor<T>(self: Option<T>, other: Option<T>): Option<T>
    return if self:isSome() ~= other:isSome()
        then if self:isSome() then self else other
        else Option.none()
end

--- Combines the contained values of `self` and `other` using `biMapper`.
---
--- If both `self` and `other` are "some", returns the result of calling
--- `biMapper` with both contained values, or "none" if `biMapper` returns
--- `nil`. Otherwise, returns "none".
---
--- `biMapper` is only called if both `Option`s are "some".
---
--- ```lua
--- local function add(a: number, b: number): number
---     return a + b
--- end
--- Option.some(2):zip(Option.some(3), add) -- Some(5)
--- Option.some(2):zip(Option.none(), add) -- None
--- ```
---
--- @method zip
--- @within Option
--- @param other Option<U> -- The `Option` to combine with the current `Option`
--- @param biMapper BiMapper<T, U, R?> -- The function to call with both contained values
--- @return Option<R> -- The result of calling `biMapper`, or "none"
function Option.zip<T, U, R>(
    self: Option<T>,
    other: Option<U>,
    biMapper: BiMapper<T, U, R?>
): Option<R>
    return if self:isSome() and other:isSome()
        then Option.fromNillable(biMapper(self._value :: T, other._value :: U))
        else Option.none()
end

--- Reduces two `Option`s into one, using `reducer` if both are "some".
---
--- If both `self` and `other` are "some", returns the result of calling
--- `reducer` with both contained values, or "none" if `reducer` returns `nil`.
--- If only one is "some", that one is returned. If both are "none", returns
--- "none".
---
--- `reducer` is only called if both `Option`s are "some".
---
--- ```lua
--- Option.some(2):reduce(Option.some(3), math.max) -- Some(3)
--- Option.some(2):reduce(Option.none(), math.max) -- Some(2)
--- Option.none():reduce(Option.none(), math.max) -- None
--- ```
---
--- @method reduce
--- @within Option
--- @param other Option<T> -- The `Option` to reduce with the current `Option`
--- @param reducer BiMapper<T, T, T?> -- The function to call with both contained values
--- @return Option<T> -- The reduced `Option`
function Option.reduce<T>(
    self: Option<T>,
    other: Option<T>,
    reducer: BiMapper<T, T, T?>
): Option<T>
    return if self:isSome() and other:isSome()
        then Option.fromNillable(reducer(self._value :: T, other._value :: T))
        else if self:isSome() then self else other
end

--- Converts from `Option<Option<T>>` to `Option<T>`.
---
--- Only one level of nesting is removed.
---
--- ```lua
--- Option.some(Option.some(1)):flatten() -- Some(1)
--- Option.some(Option.none()):flatten() -- None
--- Option.some(Option.some(Option.some(1))):flatten() -- Some(Some(1))
--- ```
---
--- @method flatten
--- @within Option
--- @return Option<T> -- The flattened `Option`
--- @error "[Option.flatten()]: Called flatten on an Option that does not contain an Option" -- Thrown if the `Option` is "some" and does not hold an `Option`
function Option.flatten<T>(self: Option<Option<T>>): Option<T>
    if self:isNone() then
        return Option.none()
    end
    local inner = self._value
    if not Option.is(inner) then
        fail("Called flatten on an Option that does not contain an Option")
    end
    return inner :: Option<T>
end

--- Converts a `Map<K, Option<T>>` to an `Option<Map<K, T>>`.
---
--- Returns "some" if all values in the table are "some", otherwise returns
--- "none". Keys are preserved.
---
--- ```lua
--- local options = { x = Option.some(1), y = Option.some(2) }
--- Option.all(options) -- Some({ x = 1, y = 2 })
--- Option.all({ Option.some(1), Option.none() }) -- None
--- ```
---
--- @param options Map<K, Option<T>> -- The table of `Option`s
--- @return Option<Map<K, T>> -- The converted `Option`
--- @error "[Option.all()]: Called all on a table containing a non-Option value" -- Thrown if a non-`Option` value is found before any "none"
function Option.all<T, K>(options: Map<K, Option<T>>): Option<Map<K, T>>
    local result = {}
    for key, value in options do
        if not Option.is(value) then
            fail("Called all on a table containing a non-Option value")
        end
        if value:isNone() then
            return Option.none() :: Option<Map<K, T>>
        end
        result[key] = value._value
    end
    return Option.some(result)
end

--- Returns the first "some" `Option` in an array, or "none" if there aren't
--- any.
---
--- Iteration uses `ipairs`, so it stops at the first `nil` in the array.
---
--- ```lua
--- local options = { Option.none(), Option.some(2), Option.some(3) }
--- Option.firstSome(options) -- Some(2)
--- Option.firstSome({ Option.none() }) -- None
--- ```
---
--- @param options Array<Option<T>> -- The array of `Option`s
--- @return Option<T> -- The first "some" `Option`, or "none"
--- @error "[Option.firstSome()]: Called firstSome on a table containing a non-Option value" -- Thrown if a non-`Option` value is found before any "some"
function Option.firstSome<T>(options: Array<Option<T>>): Option<T>
    for _, value in ipairs(options) do
        if not Option.is(value) then
            fail("Called firstSome on a table containing a non-Option value")
        end
        if value:isSome() then
            return value
        end
    end
    return Option.none()
end

--- Returns the contained values of all "some" `Option`s in an array, in order.
---
--- "none" values are skipped, so the result has no gaps. Iteration uses
--- `ipairs`, so it stops at the first `nil` in the array.
---
--- ```lua
--- Option.somes({ Option.some(1), Option.none(), Option.some(3) }) -- { 1, 3 }
--- ```
---
--- @param options Array<Option<T>> -- The array of `Option`s
--- @return Array<T> -- The contained values
--- @error "[Option.somes()]: Called somes on a table containing a non-Option value" -- Thrown if any value is not an `Option`
function Option.somes<T>(options: Array<Option<T>>): Array<T>
    local result = {}
    for _, value in ipairs(options) do
        if not Option.is(value) then
            fail("Called somes on a table containing a non-Option value")
        end
        if value:isSome() then
            table.insert(result, value._value)
        end
    end
    return result
end

--- Returns an array holding the contained value if the `Option` is "some",
--- otherwise returns an empty array.
---
--- @method toArray
--- @within Option
--- @return Array<T> -- The contained value as an array
function Option.toArray<T>(self: Option<T>): Array<T>
    return if self:isSome() then { self._value } else {}
end

--- Returns whether the given value is an `Option`.
---
--- @param value any -- The value to check
--- @return boolean -- Whether the value is an `Option`
function Option.is(value: any): boolean
    return getmetatable(value) == Option
end

--- Returns `true` if both `self` and `other` are "some" and their wrapped
--- values are equal, returns `true` if both are "none", and returns `false`
--- otherwise.
---
--- Wrapped values are compared with `==`. Returns `false` if `other` is not an
--- `Option`.
---
--- Also used for the `==` and `~=` operators.
---
--- ```lua
--- Option.some(1) == Option.some(1) -- true
--- Option.some({}) == Option.some({}) -- false, since the tables are different
--- Option.none() == Option.none() -- true
--- ```
---
--- @method equals
--- @within Option
--- @param other Option<T> -- The `Option` to compare with the current `Option`
--- @return boolean -- Whether the two `Option`s are equal
function Option.equals<T>(self: Option<T>, other: Option<T>): boolean
    return Option.is(other) and self._value == other._value
end
Option.__eq = Option.equals

--- Returns a string representation of the `Option`, in the form `Some(value)`
--- or `None`.
---
--- Also used by `tostring()`.
---
--- ```lua
--- tostring(Option.some("hi")) -- 'Some("hi")'
--- tostring(Option.some(1)) -- "Some(1)"
--- tostring(Option.none()) -- "None"
--- ```
---
--- @method toString
--- @within Option
--- @return string -- A string representation of the `Option`
function Option.toString<T>(self: Option<T>): string
    return if self:isSome() then `Some({repr(self._value)})` else "None"
end
Option.__tostring = Option.toString

return Option
