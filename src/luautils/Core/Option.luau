--!strict

-- Option type
-- by @vuppyan

-- TODO: eventually make all docs accurate to moonwave doc tags, and add any missing pieces in documentation

local repr = require("../_internal").repr
local types = require("./types")

local fail = require("../_internal").Errors.errorWithScope("Option")

--- An optional value: an `Option` is either "some" and has a value, or "none",
--- and does not.
---
--- Supports `==` and `~=` comparison and `tostring()`.
local Option = {}
Option.__index = Option

type OptionData<T> = {
    read _value: T?,
}

export type Option<T> = typeof(setmetatable({} :: OptionData<T>, Option))

-- Helper for creating a new Option
local function new<T>(value: T?): Option<T>
    return table.freeze(setmetatable({ _value = value }, Option))
end

local NONE = new(nil)

--- Creates a new `Option` that contains a value.
---
--- @param value T -- The value to wrap
--- @return Option<T> -- The new `Option`
function Option.some<T>(value: T): Option<T>
    if value == nil then
        fail(
            "Value cannot be nil "
                .. "(use Option.fromNillable() for nillable values)"
        )
    end
    return new(value)
end

--- Creates a new `Option` that does not contain a value.
---
--- This returns a singleton instance, meaning adding more "none" `Option`s does
--- not allocate more memory.
---
--- @return Option<T> -- The new `Option`
function Option.none<T>(): Option<T>
    return NONE
end

--- Creates a new `Option` from a nillable value.
---
--- Generates a "some" for any non-nil value, and a "none" for nil.
---
--- @param value T? -- The value to wrap
--- @return Option<T> -- The new `Option`
function Option.fromNillable<T>(value: T?): Option<T>
    return if value == nil then Option.none() else new(value)
end

--- Returns the contained value if the `Option` is "some", otherwise returns
--- `nil`.
---
--- Useful for Roblox APIs that expect `nil`, and provides type-checking where
--- `unwrapOr(nil)` wouldn't.
---
--- @return T? -- The contained value, or `nil`
function Option.toNillable<T>(self: Option<T>): T?
    return self._value
end

--- Returns whether the `Option` contains a value.
---
--- @return boolean -- Whether the `Option` contains a value
function Option.isSome<T>(self: Option<T>): boolean
    return self._value ~= nil
end

--- Returns whether the `Option` is "some" and the value inside matches a
--- predicate.
---
--- @param predicate types.Predicate<T> -- The predicate to check the value against
--- @return boolean -- Whether the `Option` is "some" and the value matches the predicate
function Option.isSomeAnd<T>(
    self: Option<T>,
    predicate: types.Predicate<T>
): boolean
    return self:isSome() and predicate(self._value :: T)
end

--- Returns whether the `Option` does not contain a value.
---
--- @return boolean -- Whether the `Option` does not contain a value
function Option.isNone<T>(self: Option<T>): boolean
    return not self:isSome()
end

--- Returns whether the `Option` is "none" or the value inside matches a
--- predicate.
---
--- @param predicate types.Predicate<T> -- The predicate to check the value against
--- @return boolean -- Whether the `Option` is "none" or the value matches the predicate
function Option.isNoneOr<T>(
    self: Option<T>,
    predicate: types.Predicate<T>
): boolean
    return not self:isSome() or predicate(self._value :: T)
end

--- Returns the contained value if the `Option` is "some", otherwise throws with
--- a message.
---
--- @param message string -- The message to throw with if the `Option` is "none"
--- @return T -- The contained value
--- @error message -- Thrown if the `Option` is "none"
function Option.expect<T>(self: Option<T>, message: string): T
    if self:isNone() then
        fail(message)
    end
    return self._value :: T
end

--- Returns the contained value if the `Option` is "some", otherwise throws.
---
--- @return T -- The contained value
--- @error 'Attempted to unwrap an Option that was "none"' -- Thrown if the `Option` is "none"
function Option.unwrap<T>(self: Option<T>): T
    if self:isNone() then
        fail('Attempted to unwrap an Option that was "none"')
    end
    return self._value :: T
end

--- Returns the contained value if the `Option` is "some", or a default.
---
--- @param default T -- The default value to return if the `Option` is "none"
--- @return T -- The contained value, or the default
function Option.unwrapOr<T>(self: Option<T>, default: T): T
    return if self:isSome() then self._value :: T else default
end

--- Returns the contained value if the `Option` is "some", or computes a default
--- from a supplier.
---
--- @param supplier types.Supplier<T> -- The supplier to compute the default value
--- @return T -- The contained value, or the computed default
function Option.unwrapOrElse<T>(self: Option<T>, supplier: types.Supplier<T>): T
    return if self:isSome() then self._value :: T else supplier()
end

--- Returns the contained value if the `Option` is "some", otherwise throws.
---
--- @param errorSupplier types.Supplier<any> -- The supplier to compute the error message
--- @return T -- The contained value
--- @error any -- Thrown if the `Option` is "none"
function Option.unwrapOrThrow<T>(
    self: Option<T>,
    errorSupplier: types.Supplier<any>
): T
    return if self:isSome() then self._value :: T else fail(errorSupplier())
end

--- Returns whether the `Option` contains a value equal to the provided value.
---
--- Equality is checked using `==`.
---
--- @param value T -- The value to check against
--- @return boolean -- Whether the `Option` contains the value
function Option.contains<T>(self: Option<T>, value: T): boolean
    return self:isSome() and self._value == value
end

--- Returns the provided value if `condition` is true, otherwise returns "none".
---
--- @param condition boolean -- The condition to check
--- @param value T -- The value to return if the condition is true
--- @return Option<T> -- The provided value, or "none"
function Option.when<T>(condition: boolean, value: T): Option<T>
    return if condition then Option.some(value) else Option.none()
end

--- Returns the result of calling `supplier` if `condition` is true, otherwise
--- returns "none".
---
--- @param condition boolean -- The condition to check
--- @param supplier types.Supplier<T> -- The function to call if the condition is true
--- @return Option<T> -- The result of calling `supplier`, or "none"
function Option.whenThen<T>(
    condition: boolean,
    supplier: types.Supplier<T>
): Option<T>
    return if condition then supplier() else Option.none()
end

--- Maps an `Option<T>` to `Option<U>` by applying a function to the contained
--- value (if "some") or returns "none" (if "none").
---
--- If `mapper` returns `nil`, the result is "none".
---
--- @param mapper types.Mapper<T, U?> -- The function to apply to the contained value
--- @return Option<U> -- The mapped `Option`
function Option.map<T, U>(self: Option<T>, mapper: types.Mapper<T, U?>): Option<U>
    return if self:isSome()
        then Option.fromNillable(mapper(self._value :: T))
        else Option.none()
end

--- Returns the provided default result (if "none"), or applies a function to
--- the contained value (if "some").
---
--- @param default U -- The default value to return if the `Option` is "none"
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The provided default value, or the mapped value
function Option.mapOr<T, U>(
    self: Option<T>,
    default: U,
    mapper: types.Mapper<T, U>
): U
    return if self:isSome() then mapper(self._value :: T) else default
end

--- Computes a default function result (if "none"), or applies a different
--- function to the contained value (if "some").
---
--- @param supplier types.Supplier<U> -- The function to compute the default value
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The computed default value, or the mapped value
function Option.mapOrElse<T, U>(
    self: Option<T>,
    supplier: types.Supplier<U>,
    mapper: types.Mapper<T, U>
): U
    return if self:isSome() then mapper(self._value :: T) else supplier()
end

--- Calls a function with the contained value if "some", then returns the
--- original option.
---
--- @param consumer types.Consumer<T> -- The function to call with the contained value
--- @return Option<T> -- The original `Option`
function Option.inspect<T>(self: Option<T>, consumer: types.Consumer<T>): Option<T>
    if self:isSome() then
        consumer(self._value :: T)
    end
    return self
end

--- Returns "none" if the `Option` is "none", otherwise returns `other`.
---
--- @param other Option<U> -- The `Option` to return if the current `Option` is "some"
--- @return Option<U> -- The provided `Option`, or "none"
function Option.andOption<T, U>(self: Option<T>, other: Option<U>): Option<U>
    return if self:isSome() then other else Option.none()
end

--- Returns "none" if the `Option` is "none", otherwise calls `mapper` with the
--- wrapped value and returns the result.
---
--- This operation is also known as "flatmap".
---
--- @param mapper types.Mapper<T, Option<U>> -- The function to call with the contained value
--- @return Option<U> -- The result of calling `mapper`, or "none"
function Option.andThen<T, U>(
    self: Option<T>,
    mapper: types.Mapper<T, Option<U>>
): Option<U>
    return if self:isSome() then mapper(self._value :: T) else Option.none()
end

--- Returns "none" if the option is "none", otherwise calls `predicate` with the
--- wrapped value and returns "some" with the wrapped value if the predicate
--- returns true, and "none" otherwise.
---
--- @param predicate types.Predicate<T> -- The predicate to check the value against
--- @return Option<T> -- The result of calling `predicate`, or "none"
function Option.filter<T>(
    self: Option<T>,
    predicate: types.Predicate<T>
): Option<T>
    return if self:isSome() and predicate(self._value :: T)
        then self
        else Option.none()
end

--- Returns the option if it contains a value, otherwise returns `other`.
---
--- @param other Option<T> -- The `Option` to return if the current `Option` is "none"
--- @return Option<T> -- The provided `Option`, or the current `Option`
function Option.orOption<T>(self: Option<T>, other: Option<T>): Option<T>
    return if self:isSome() then self else other
end

--- Returns the option if it contains a value, otherwise calls `supplier` and
--- returns the result.
---
--- @param supplier types.Supplier<Option<T>> -- The function to call if the current `Option` is "none"
--- @return Option<T> -- The current `Option`, or the result of calling `supplier`
function Option.orElse<T>(
    self: Option<T>,
    supplier: types.Supplier<Option<T>>
): Option<T>
    return if self:isSome() then self else supplier()
end

--- Calls `ifSome` with the contained value if the option is "some", otherwise
--- calls `ifNone`.
---
--- @param ifSome types.Consumer<T> -- The function to call with the contained value
--- @param ifNone types.Action -- The function to call if the option is "none"
function Option.match<T>(
    self: Option<T>,
    ifSome: types.Consumer<T>,
    ifNone: types.Action
): ()
    if self:isSome() then
        ifSome(self._value :: T)
    else
        ifNone()
    end
end

--- Returns "some" if exactly one of `self` and `other` is "some", otherwise
--- returns "none".
---
--- @param other Option<T> -- The `Option` to compare with the current `Option`
--- @return Option<T> -- The single "some" `Option`, or "none"
function Option.xor<T>(self: Option<T>, other: Option<T>): Option<T>
    return if self:isSome() ~= other:isSome()
        then if self:isSome() then self else other
        else Option.none()
end

--- Combines the value in `self` with the value in another `Option`, using
--- `biMapper`.
---
--- If both `self` and `other` are "some", this method returns the result of
--- calling `biMapper` with the wrapped values, or "none" if `biMapper` returns
--- `nil`. Otherwise, it returns "none".
---
--- @param other Option<U> -- The `Option` to combine with the current `Option`
--- @param biMapper types.BiMapper<T, U, R?> -- The function to call with the wrapped values
--- @return Option<R> -- The result of calling `biMapper`, or "none"
function Option.zip<T, U, R>(
    self: Option<T>,
    other: Option<U>,
    biMapper: types.BiMapper<T, U, R?>
): Option<R>
    return if self:isSome() and other:isSome()
        then Option.fromNillable(biMapper(self._value :: T, other._value :: U))
        else Option.none()
end

--- Reduces two options into one, using the provided reducer function if both
--- are "some".
---
--- If `self` is "some" and `other` is "some", this method returns the result of
--- calling `reducer` with the wrapped values. Otherwise, if only one option is
--- "some", that one is returned. If both `self` and `other` are "none", "none"
--- is returned.
---
--- If `reducer` returns `nil`, the result is "none".
---
--- @param other Option<T> -- The `Option` to reduce with the current `Option`
--- @param reducer types.BiMapper<T, T, T?> -- The function to call with the wrapped values
--- @return Option<T> -- The result of calling `reducer`, or "none"
function Option.reduce<T>(
    self: Option<T>,
    other: Option<T>,
    reducer: types.BiMapper<T, T, T?>
): Option<T>
    return if self:isSome() and other:isSome()
        then Option.fromNillable(reducer(self._value :: T, other._value :: T))
        else if self:isSome() then self else other
end

--- Converts from `Option<Option<T>>` to `Option<T>`.
---
--- @return Option<T> -- The flattened `Option`
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
--- "none".
---
--- @param options types.Map<K, Option<T>> -- The table of `Option`s
--- @return Option<types.Map<K, T>> -- The transposed `Option`
function Option.all<T, K>(options: types.Map<K, Option<T>>): Option<types.Map<K, T>>
    local result = {}
    for key, value in options do
        if not Option.is(value) then
            fail("Called all on a table containing a non-Option value")
        end
        if value:isNone() then
            return Option.none() :: Option<types.Map<K, T>>
        end
        result[key] = value._value
    end
    return Option.some(result)
end

--- Returns the first non-"none" result from an ordered table, or "none" if
--- there aren't any.
---
--- @param options types.Array<Option<T>> -- The table of `Option`s
--- @return Option<T> -- The first non-"none" result
function Option.firstSome<T>(options: types.Array<Option<T>>): Option<T>
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

--- Returns all non-"none" results from an ordered table.
---
--- @param options types.Array<Option<T>> -- The table of `Option`s
--- @return types.Array<T> -- The non-"none" results
function Option.somes<T>(options: types.Array<Option<T>>): types.Array<T>
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

--- Returns the wrapped value as an array.
---
--- @return types.Array<T> -- The wrapped value as an array
function Option.toArray<T>(self: Option<T>): { T } | {}
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
--- values are equal, returns `true` if both are "none", and otherwise returns
--- `false`.
---
--- Wrapped values are compared with `==`.
---
--- @param other Option<T> -- The `Option` to compare with the current `Option`
--- @return boolean -- Whether the `Option`s are equal
function Option.equals<T>(self: Option<T>, other: Option<T>): boolean
    return Option.is(other) and self._value == other._value
end
Option.__eq = Option.equals

--- Returns a string representation of the `Option`.
---
--- @return string -- A string representation of the `Option`
function Option.toString<T>(self: Option<T>): string
    return if self:isSome() then `Some({repr(self._value)})` else "None"
end
Option.__tostring = Option.toString

return Option
