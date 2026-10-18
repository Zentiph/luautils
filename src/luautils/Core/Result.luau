--!strict

-- Result type
-- by @vuppyan

local Option = require("./Option")
local repr = require("../_internal").repr

--- A crash-safe error propagation type that represents either success (Ok) or
--- failure (Err).
local Result = {}
Result.__index = Result

type ResultData<T, E> = {
    read _value: T,
    read _error: E?,
}

export type Result<T, E> = typeof(setmetatable(
    {} :: ResultData<T, E>,
    Result
))

type Predicate<T> = (value: T) -> boolean
type Mapper<T, U> = (T) -> U
type PackedTable = { n: number, [number]: any }

-- Helper for creating a new Result
local function new<T, E>(value: T, err: E?): Result<T, E>
    return table.freeze(
        setmetatable({ _value = value, _error = err }, Result)
    )
end

--- Creates a new `Result` with the specified value.
---
--- @param value T -- The value to wrap
--- @return Result<T, E> -- The new `Result`
function Result.ok<T, E>(value: T): Result<T, E>
    return new(value, nil)
end

--- Creates a new `Result` with the specified error.
---
--- @param err E -- The error to wrap
--- @return Result<T, E> -- The new `Result`
function Result.err<T, E>(err: E): Result<T, E>
    if err == nil then
        error("[Result.err()]: Error cannot be nil", 2)
    end
    return new(nil, err)
end

--- Returns `true` if the `Result` is "ok".
---
--- @return boolean -- Whether the `Result` is "ok"
function Result.isOk<T, E>(self: Result<T, E>): boolean
    return self._error == nil
end

--- Returns `true` if the `Result` is "ok" and the value inside of it matches a
--- predicate.
---
--- @param predicate Predicate<T> -- The predicate to check the value against
--- @return boolean -- Whether the `Result` is "ok" and the value matches the predicate
function Result.isOkAnd<T, E>(
    self: Result<T, E>,
    predicate: Predicate<T>
): boolean
    return self:isOk() and predicate(self._value)
end

--- Returns `true` if the `Result` is "err".
---
--- @return boolean -- Whether the `Result` is "err"
function Result.isErr<T, E>(self: Result<T, E>): boolean
    return self._error ~= nil
end

--- Returns `true` if the `Result` is "err" and the error inside of it matches a
--- predicate.
---
--- @param predicate Predicate<E> -- The predicate to check the error against
--- @return boolean -- Whether the `Result` is "err" and the error matches the predicate
function Result.isErrAnd<T, E>(
    self: Result<T, E>,
    predicate: Predicate<E>
): boolean
    return self:isErr() and predicate(self._error :: E)
end

--- Converts from `Result<T, E>` to `Option<T>`.
---
--- Converts a `nil` or error into a "none" `Option`.
---
--- @return Option<T> -- The converted `Option`
function Result.getOk<T, E>(self: Result<T, E>): Option.Option<T>
    return if self:isOk() then Option.from(self._value) else Option.none()
end

--- Converts from `Result<T, E>` to `Option<E>`.
---
--- @return Option<E> -- The converted `Option`
function Result.getErr<T, E>(self: Result<T, E>): Option.Option<E>
    return if self:isErr()
        then Option.some(self._error :: E)
        else Option.none()
end

--- Maps a `Result<T, E>` to `Result<U, E>` by applying a function to a
--- contained "ok" value, leaving an "err" value untouched.
---
--- @param mapper Mapper<T, U> -- The function to apply to the contained value
--- @return Result<U, E> -- The mapped `Result`
function Result.map<T, E, U>(
    self: Result<T, E>,
    mapper: Mapper<T, U>
): Result<U, E>
    return if self:isOk() then Result.ok(mapper(self._value)) else self
end

--- Returns the provided default (if "err"), or applies a function to the
--- contained value (if "ok").
---
--- @param default U -- The default value to return if the `Result` is "err"
--- @param mapper Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The provided default value, or the mapped value
function Result.mapOr<T, E, U>(
    self: Result<T, E>,
    default: U,
    mapper: Mapper<T, U>
): U
    return if self:isOk() then mapper(self._value) else default
end

--- Maps a `Result<T, E>` to `U` by applying fallback function `default` to a
--- contained "err" value, or a function `mapper` to a contained "ok" value.
---
--- @param default (E) -> U -- The function to apply on an "err"
--- @param mapper Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The mapped value
function Result.mapOrElse<T, E, U>(
    self: Result<T, E>,
    default: (E) -> U,
    mapper: Mapper<T, U>
): U
    return if self:isOk()
        then mapper(self._value)
        else default(self._error :: E)
end

--- Maps a `Result<T, E>` to `Result<T, F>` by applying a function to a
--- contained "err" value, leaving an "ok" value untouched.
---
--- @param mapper Mapper<E, F> -- The function to apply to the contained error
--- @return Result<T, F> -- The mapped `Result`
function Result.mapErr<T, E, F>(
    self: Result<T, E>,
    mapper: Mapper<E, F>
): Result<T, F>
    return if self:isOk()
        then self
        else Result.err(mapper(self._error :: E))
end

--- Calls a function with the contained value if "ok".
---
--- Returns the original `Result`.
---
--- @param callback (T) -> () -- The function to call with the contained value
--- @return Result<T, E> -- The original `Result`
function Result.inspect<T, E>(
    self: Result<T, E>,
    callback: (T) -> ()
): Result<T, E>
    if self:isOk() then
        callback(self._value)
    end
    return self
end

--- Calls a function with the contained error if "err".
---
--- Returns the original `Result`.
---
--- @param callback (E) -> () -- The function to call with the contained error
--- @return Result<T, E> -- The original `Result`
function Result.inspectErr<T, E>(
    self: Result<T, E>,
    callback: (E) -> ()
): Result<T, E>
    if self:isErr() then
        callback(self._error :: E)
    end
    return self
end

--- Returns the contained "ok" value, or errors with the provided message and
--- the content of the inner error if the `Result` is "err".
---
--- @param message string -- The error message
--- @return T -- The contained value
function Result.expect<T, E>(self: Result<T, E>, message: string): T
    if self:isOk() then
        return self._value
    else
        error(`{message}: {repr(self._error)}`, 2)
    end
end

--- Returns the contained "ok" value, or errors if the `Result` is "err" with an
--- error message provided by the "err" value.
---
--- @return T -- The contained value
function Result.unwrap<T, E>(self: Result<T, E>): T
    if self:isOk() then
        return self._value
    else
        error(self._error, 2)
    end
end

--- Returns the contained "err" value, or errors if the `Result` is "ok", with
--- an error message including the passed message, and the content of the "ok".
---
--- @param message string -- The error message
--- @return E -- The contained error
function Result.expectErr<T, E>(self: Result<T, E>, message: string): E
    if self:isOk() then
        error(`{message}: {repr(self._value)}`, 2)
    else
        return self._error :: E
    end
end

--- Returns the contained "err" value, or errors if the `Result` is "ok", with
--- an error message provided by the "ok" value.
---
--- @return E -- The contained error
function Result.unwrapErr<T, E>(self: Result<T, E>): E
    if self:isOk() then
        error(tostring(self._value), 2)
    else
        return self._error :: E
    end
end

--- Returns `other` if the `Result` is "ok", otherwise returns the "err" value
--- of `self`.
---
--- @param other Result<U, E> -- The `Result` to return if the `Result` is "ok"
--- @return Result<U, E> -- The provided `Result`, or the "err" value of `self`
function Result.andResult<T, E, U>(
    self: Result<T, E>,
    other: Result<U, E>
): Result<U, E>
    return if self:isOk() then other else self
end

---  Calls `mapper` if the `Result` is "ok", otherwise returns the "err" value
--- of `self`.
---
--- @param mapper Mapper<T, Result<U, E>> -- The function to call if the `Result` is "ok"
--- @return Result<U, E> -- The provided `Result`, or the "err" value of `self`
function Result.andThen<T, E, U>(
    self: Result<T, E>,
    mapper: Mapper<T, Result<U, E>>
): Result<U, E>
    return if self:isOk() then mapper(self._value) else self
end

--- Returns `other` if the `Result` is "err", otherwise returns the "ok" value
--- of `self`.
---
--- @param other Result<T, F> -- The `Result` to return if the `Result` is "err"
--- @return Result<T, F> -- The provided `Result`, or the "ok" value of `self`
function Result.orResult<T, E, F>(
    self: Result<T, E>,
    other: Result<T, F>
): Result<T, F>
    return if self:isOk() then self else other
end

--- Calls `mapper` if the `Result` is "err", otherwise returns the "ok" value
--- of `self`.
---
--- @param mapper Mapper<E, Result<T, F>> -- The function to call if the `Result` is "err"
--- @return Result<T, F> -- The provided `Result`, or the "ok" value of `self`
function Result.orElse<T, E, F>(
    self: Result<T, E>,
    mapper: Mapper<E, Result<T, F>>
): Result<T, F>
    return if self:isOk() then self else mapper(self._error :: E)
end

--- Returns the contained "ok" value or a provided default.
---
--- @param default T -- The default value to return if the `Result` is "err"
--- @return T -- The contained value, or the provided default
function Result.unwrapOr<T, E>(self: Result<T, E>, default: T): T
    return if self:isOk() then self._value else default
end

--- Returns the contained "ok" value or computes it from a default from a
--- callback.
---
--- @param mapper Mapper<E, T> -- The function to call if the `Result` is "err"
--- @return T -- The contained value, or the provided default
function Result.unwrapOrElse<T, E>(self: Result<T, E>, mapper: Mapper<E, T>): T
    return if self:isOk() then self._value else mapper(self._error :: E)
end

--- Calls `callback` with the given arguments in protected mode, returning "ok"
--- with its first return value, or "err" with the thrown value.
---
--- If `callback` throws `nil`, then the error is replaced with a descriptive
--- string, since an "err" cannot hold `nil`.
---
--- @param callback (A...) -> T -- The function to call in protected mode
--- @return Result<T, unknown> -- The `Result`
function Result.try<T, A...>(callback: (A...) -> T, ...: A...): Result<T, unknown>
    local ok, result = pcall(callback, ...)
    return if ok
        then Result.ok(result)
        else Result.err(
            if result == nil then "error(nil) was called" else result
        )
end

-- TODO: eventually rework to use xpcall (or add a variant) since pcall discards
--        the traceback

--- Like `Result.try`, but packs all return values of `callback` into a table.
---
--- Use `table.unpack(packed, 1, packed.n)` to get the values back.
---
--- @param callback (A...) -> ...any -- The function to call in protected mode
--- @return Result<PackedTable, unknown> -- The `Result`
function Result.tryPack<A...>(
    callback: (A...) -> ...any,
    ...: A...
): Result<PackedTable, unknown>
    local results = table.pack(pcall(callback, ...))
    if results[1] then
        return Result.ok(table.pack(table.unpack(results, 2, results.n)))
    else
        local err = results[2]
        return Result.err(
            if err == nil then "error(nil) was called" else err
        ) :: Result<PackedTable, unknown>
    end
end

-- TODO: add these variants to Option also:

--- Transposes a `Result` of an `Option` into an `Option` of a `Result`.
---
--- An "ok" with a "none" is mapped to "none". An "ok" with a "some" is mapped
--- to a "some" with the "ok". An "err" is mapped to a "some" with the "err".
---
--- @return Option<Result<T, E>> -- The transposed `Option`
function Result.transpose<T, E>(
    self: Result<Option.Option<T>, E>
): Option.Option<Result<T, E>>
    return if self:isOk()
        then if self._value:isSome()
            then Option.some(Result.ok(self._value:unwrap()))
            else Option.none() :: Option.Option<Result<T, E>>
        else Option.some(Result.err(self._error :: E))
end

--- Converts from `Result<Result<T, E>, E>` to `Result<T, E>`.
---
--- @return Result<T, E> -- The flattened `Result`
function Result.flatten<T, E>(self: Result<Result<T, E>, E>): Result<T, E>
    if self:isErr() then
        return self
    end
    local inner = self._value
    if not Result.is(inner) then
        error(
            "[Result:flatten()]: Called flatten on a Result "
                .. "that does not contain a Result",
            2
        )
    end
    return inner
end

--- Returns whether the given value is a `Result`.
---
--- @param value any -- The value to check
--- @return boolean -- Whether the value is a `Result`
function Result.is(value: any): boolean
    return getmetatable(value) == Result
end

--- Returns `true` if both `self` and `other` are "ok" and their wrapped values
--- are equal, returns `true` if both are "err" and their wrapped errors are
--- equal, and returns `false` otherwise.
---
--- Wrapped values are compared with `==`.
---
--- @param other Result<T, E> -- The `Result` to compare with the current `Result`
--- @return boolean -- Whether the two `Result`s are equal
function Result.__eq<T, E>(self: Result<T, E>, other: Result<T, E>): boolean
    return Result.is(other)
        and self._value == other._value
        and self._error == other._error
end

--- Returns a string representation of the `Result`.
---
--- @return string -- A string representation of the `Result`
function Result.__tostring<T, E>(self: Result<T, E>): string
    return if self:isOk()
        then `Ok({repr(self._value)})`
        else `Err({repr(self._error)})`
end

return Result
