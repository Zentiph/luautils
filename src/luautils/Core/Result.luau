--!strict

-- Result type
-- by @vuppyan

local Option = require("./Option")
local repr = require("../_internal").repr
local types = require("./types")

local fail = require("../_internal").Errors.errorWithScope("Result")

--- A crash-safe error propagation type that represents either success ("ok") or
--- failure ("err").
local Result = {}
Result.__index = Result

type ResultData<T, E> = {
    read _value: T,
    read _error: E?,
}

export type Result<T, E> = typeof(setmetatable({} :: ResultData<T, E>, Result))

-- Helper for creating a new Result
local function new<T, E>(value: T, err: E?): Result<T, E>
    return table.freeze(setmetatable({ _value = value, _error = err }, Result))
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
        fail("Error cannot be nil")
    end
    return new(nil, err)
end

--- Returns the contained value if the `Result` is "ok", otherwise returns
--- `nil`.
---
--- Useful for Roblox APIs that expect `nil`, and provides type-checking where
--- `unwrapOr(nil)` wouldn't.
---
--- @return T? -- The contained value, or `nil`
function Result.toNillable<T, E>(self: Result<T, E>): T?
    return self._value
end

--- Returns the contained error if the `Result` is "err", otherwise returns
--- `nil`.
---
--- Useful for Roblox APIs that expect `nil`, and provides type-checking where
--- `unwrapErrOr(nil)` wouldn't.
---
--- @return E? -- The contained error, or `nil`
function Result.errToNillable<T, E>(self: Result<T, E>): E?
    return self._error
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
--- @param predicate types.Predicate<T> -- The predicate to check the value against
--- @return boolean -- Whether the `Result` is "ok" and the value matches the predicate
function Result.isOkAnd<T, E>(
    self: Result<T, E>,
    predicate: types.Predicate<T>
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
--- @param predicate types.Predicate<E> -- The predicate to check the error against
--- @return boolean -- Whether the `Result` is "err" and the error matches the predicate
function Result.isErrAnd<T, E>(
    self: Result<T, E>,
    predicate: types.Predicate<E>
): boolean
    return self:isErr() and predicate(self._error :: E)
end

--- Converts from `Result<T, E>` to `Option<T>`.
---
--- Converts a `nil` or error into a "none" `Option`.
---
--- @return Option<T> -- The converted `Option`
function Result.asOk<T, E>(self: Result<T, E>): Option.Option<T>
    return if self:isOk()
        then Option.fromNillable(self._value)
        else Option.none()
end

--- Converts from `Result<T, E>` to `Option<E>`.
---
--- @return Option<E> -- The converted `Option`
function Result.asErr<T, E>(self: Result<T, E>): Option.Option<E>
    return if self:isErr() then Option.some(self._error :: E) else Option.none()
end

--- Maps a `Result<T, E>` to `Result<U, E>` by applying a function to a
--- contained "ok" value, leaving an "err" value untouched.
---
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return Result<U, E> -- The mapped `Result`
function Result.map<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, U>
): Result<U, E>
    return if self:isOk() then Result.ok(mapper(self._value)) else self
end

--- Returns the provided default (if "err"), or applies a function to the
--- contained value (if "ok").
---
--- @param default U -- The default value to return if the `Result` is "err"
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The provided default value, or the mapped value
function Result.mapOr<T, E, U>(
    self: Result<T, E>,
    default: U,
    mapper: types.Mapper<T, U>
): U
    return if self:isOk() then mapper(self._value) else default
end

--- Maps a `Result<T, E>` to `U` by applying fallback function `default` to a
--- contained "err" value, or a function `mapper` to a contained "ok" value.
---
--- @param default types.Mapper<E, U> -- The function to apply on an "err"
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return U -- The mapped value
function Result.mapOrElse<T, E, U>(
    self: Result<T, E>,
    default: types.Mapper<E, U>,
    mapper: types.Mapper<T, U>
): U
    return if self:isOk()
        then mapper(self._value)
        else default(self._error :: E)
end

--- Like `map`, except this method returns an "err" `Result` if `mapper` throws,
--- with the error's content as the "err" value.
---
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return Result<U, E> -- The mapped `Result`
function Result.tryMap<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, U>
): Result<U, E>
    return if self:isOk() then Result.try(mapper, self._value) else self
end

--- Maps a `Result<T, E>` to `Result<T, F>` by applying a function to a
--- contained "err" value, leaving an "ok" value untouched.
---
--- @param mapper types.Mapper<E, F> -- The function to apply to the contained error
--- @return Result<T, F> -- The mapped `Result`
function Result.mapErr<T, E, F>(
    self: Result<T, E>,
    mapper: types.Mapper<E, F>
): Result<T, F>
    if self:isOk() then
        return self
    end
    local mapped = mapper(self._error :: E)
    if mapped == nil then
        fail('Mapper gave a nil error; "err" Results cannot hold nil')
    end
    return Result.err(mapped)
end

--- Tests the contained value of the `Result` if "ok", and returns a `Result`
--- containing either the verified value or a validation error.
---
--- If the `Result` is "err", returns the original `Result`.
---
--- @param predicate types.Predicate<T> -- The predicate to check the value against
--- @param errorFactory types.Factory<E, T> -- The function to create a validation error
--- @return Result<T, E> -- The validated `Result`
function Result.filterOrElse<T, E>(
    self: Result<T, E>,
    predicate: types.Predicate<T>,
    errorFactory: types.Factory<E, T>
): Result<T, E>
    if self:isOk() then
        return if predicate(self._value)
            then self
            else Result.err(errorFactory(self._value))
    else
        return self
    end
end

--- Calls a function with the contained value if "ok".
---
--- Returns the original `Result`.
---
--- @param consumer types.Consumer<T> -- The function to call with the contained value
--- @return Result<T, E> -- The original `Result`
function Result.inspect<T, E>(
    self: Result<T, E>,
    consumer: types.Consumer<T>
): Result<T, E>
    if self:isOk() then
        consumer(self._value)
    end
    return self
end

--- Calls a function with the contained error if "err".
---
--- Returns the original `Result`.
---
--- @param consumer types.Consumer<E> -- The function to call with the contained error
--- @return Result<T, E> -- The original `Result`
function Result.inspectErr<T, E>(
    self: Result<T, E>,
    consumer: types.Consumer<E>
): Result<T, E>
    if self:isErr() then
        consumer(self._error :: E)
    end
    return self
end

--- Returns the contained "ok" value, or throws with the provided message and
--- the content of the inner error if the `Result` is "err".
---
--- @param message string -- The error message
--- @return T -- The contained value
function Result.expect<T, E>(self: Result<T, E>, message: string): T
    if self:isErr() then
        fail(`{message}: {repr(self._error)}`)
    end
    return self._value
end

--- Returns the contained "ok" value, or throws if the `Result` is "err" with an
--- error message provided by the "err" value.
---
--- If the "err" is a table or userdata, a raw error is raised instead, in order
--- to preserve table data.
---
--- @return T -- The contained value
function Result.unwrap<T, E>(self: Result<T, E>): T
    if self:isErr() then
        local err = self._error
        if type(err) == "table" or type(err) == "userdata" then
            error(err, 2)
        end
        fail(tostring(err))
    end
    return self._value
end

--- Returns the contained "err" value, or throws if the `Result` is "ok", with
--- an error message including the passed message, and the content of the "ok".
---
--- @param message string -- The error message
--- @return E -- The contained error
function Result.expectErr<T, E>(self: Result<T, E>, message: string): E
    if self:isOk() then
        fail(`{message}: {repr(self._value)}`)
    end
    return self._error :: E
end

--- Returns the contained "err" value, or throws if the `Result` is "ok", with
--- an error message provided by the "ok" value.
---
--- @return E -- The contained error
function Result.unwrapErr<T, E>(self: Result<T, E>): E
    if self:isOk() then
        fail(`Called on an ok value: {repr(self._value)}`)
    end
    return self._error :: E
end

--- Returns `other` if the `Result` is "ok", otherwise returns the "err" value
--- of `self`.
---
--- @param other Result<U, E> -- The `Result` to return if the `Result` is "ok"
--- @return Result<U, E> -- The provided `Result`, or the "err" value of `self`
function Result.andResult<T, E, U>(self: Result<T, E>, other: Result<U, E>): Result<U, E>
    return if self:isOk() then other else self
end

--- Calls `mapper` if the `Result` is "ok", otherwise returns the "err" value
--- of `self`.
---
--- @param mapper types.Mapper<T, Result<U, E>> -- The function to call if the `Result` is "ok"
--- @return Result<U, E> -- The provided `Result`, or the "err" value of `self`
function Result.andThen<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, Result<U, E>>
): Result<U, E>
    return if self:isOk() then mapper(self._value) else self
end

--- Like `andThen`, except this method returns an "err" `Result` if `mapper`
--- throws, with the error's content as the "err" value.
---
--- @param mapper types.Mapper<T, Result<U, E>> -- The function to call if the `Result` is "ok"
--- @return Result<U, E> -- The provided `Result`, or the "err" value of `self`
function Result.tryAndThen<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, Result<U, E>>
): Result<U, E>
    return if self:isOk()
        then Result.try(mapper, self._value):flatten()
        else self
end

--- Returns `other` if the `Result` is "err", otherwise returns the "ok" value
--- of `self`.
---
--- @param other Result<T, F> -- The `Result` to return if the `Result` is "err"
--- @return Result<T, F> -- The provided `Result`, or the "ok" value of `self`
function Result.orResult<T, E, F>(self: Result<T, E>, other: Result<T, F>): Result<T, F>
    return if self:isOk() then self else other
end

--- Calls `mapper` if the `Result` is "err", otherwise returns the "ok" value
--- of `self`.
---
--- @param mapper types.Mapper<E, Result<T, F>> -- The function to call if the `Result` is "err"
--- @return Result<T, F> -- The provided `Result`, or the "ok" value of `self`
function Result.orElse<T, E, F>(
    self: Result<T, E>,
    mapper: types.Mapper<E, Result<T, F>>
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

--- Returns the contained "ok" value or computes one from the error using
--- `mapper`.
---
--- @param mapper types.Mapper<E, T> -- The function to call if the `Result` is "err"
--- @return T -- The contained value, or the provided default
function Result.unwrapOrElse<T, E>(self: Result<T, E>, mapper: types.Mapper<E, T>): T
    return if self:isOk() then self._value else mapper(self._error :: E)
end

--- Calls `ifOk` with the contained value if the `Result` is "ok", otherwise
--- calls `ifErr` with the contained error.
---
--- @param ifOk types.Consumer<T> -- The function to call with the contained value
--- @param ifErr types.Consumer<E> -- The function to call with the contained error
function Result.match<T, E>(
    self: Result<T, E>,
    ifOk: types.Consumer<T>,
    ifErr: types.Consumer<E>
): ()
    if self:isOk() then
        ifOk(self._value)
    else
        ifErr(self._error :: E)
    end
end

--- Calls `factory` with the given arguments in protected mode, returning "ok"
--- with its first return value, or "err" with the thrown value.
---
--- It is recommended to use `Result.tryPack()` for functions that may return
--- multiple values.
---
--- If `factory` throws `nil`, then the error is replaced with a descriptive
--- string, since an "err" cannot hold `nil`.
---
--- Since `pcall` cannot check error types, the error is typed as `unknown`.
--- Cast this `Result` to one with the desired error type if desired.
---
--- @param factory types.Factory<T, A...> -- The function to call in protected mode
--- @return Result<T, unknown> -- The `Result`
function Result.try<T, A...>(
    factory: types.Factory<T, A...>,
    ...: A...
): Result<T, unknown>
    local ok, result = pcall(factory, ...)
    return if ok
        then Result.ok(result)
        else Result.err(
            if result == nil then "error(nil) was called" else result
        )
end

-- TODO: eventually rework to use xpcall (or add a variant) since pcall discards
--        the traceback

--- Like `Result.try`, but packs all return values of `factory` into a table.
---
--- Use `table.unpack(packed, 1, packed.n)` to get the values back.
---
--- @param factory types.TupleFactory<...any, A...> -- The function to call in protected mode
--- @return Result<types.PackedTable, unknown> -- The `Result`
function Result.tryPack<A...>(
    factory: types.TupleFactory<...any, A...>,
    ...: A...
): Result<types.PackedTable, unknown>
    local results = table.pack(pcall(factory, ...))
    if results[1] then
        return Result.ok(table.pack(table.unpack(results, 2, results.n)))
    else
        local err = results[2]
        return Result.err(
                if err == nil then "error(nil) was called" else err
            ) :: Result<types.PackedTable, unknown>
    end
end

--- Wraps a function that may throw an error into one that returns a `Result`.
---
--- @param factory types.Factory<T, A...> -- The function to wrap
--- @return Result<T, unknown>
function Result.wrap<T, A...>(
    factory: types.Factory<T, A...>
): types.Factory<Result<T, unknown>, A...>
    return function(...: A...)
        return Result.try(factory, ...)
    end
end

--- Transposes a `Result` of an `Option` into an `Option` of a `Result`.
---
--- An "ok" with a "none" is mapped to "none". An "ok" with a "some" is mapped
--- to a "some" with the "ok". An "err" is mapped to a "some" with the "err".
---
--- @return Option<Result<T, E>> -- The transposed `Option`
function Result.transpose<T, E>(
    self: Result<Option.Option<T>, E>
): Option.Option<Result<T, E>>
    if self:isErr() then
        return Option.some(Result.err(self._error :: E))
    end
    local inner = self._value
    if not Option.is(inner) then
        fail("Called transpose on a Result that does not contain an Option")
    end
    return if inner:isSome()
        then Option.some(Result.ok(inner:unwrap()))
        else Option.none() :: Option.Option<Result<T, E>>
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
        fail("Called flatten on a Result that does not contain a Result")
    end
    return inner
end

--- Converts a `Map<K, Result<T, E>>` to a `Result<Map<K, T>, E>`.
---
--- Returns "ok" if all values in the table are "ok", otherwise returns the
--- first "err".
---
--- Keys are preserved, so array input produces arrays with gaps.
---
--- @param results types.Map<K, Result<T, E>> -- The table of `Result`s
--- @return Result<Map<K, T>, E> -- The converted `Result`
function Result.all<T, E, K>(
    results: types.Map<K, Result<T, E>>
): Result<types.Map<K, T>, E>
    local result = {}
    for key, value in results do
        if not Result.is(value) then
            fail("Called all on a table containing a non-Result value")
        end
        if value:isErr() then
            return value
        end
        result[key] = value:unwrap()
    end
    return Result.ok(result)
end

--- Splits a table of `Result`s into two tables: one of unwrapped "ok" values,
--- and the other of unwrapped "err" values.
---
--- Unlike `all`, this never short-circuits and always returns both tables
--- fully. "Ok" values of `nil` are omitted, since tables cannot hold `nil`.
---
--- Keys are preserved, so array input produces arrays with gaps.
---
--- @param results types.Map<K, Result<T, E>> -- The table of `Result`s
--- @return types.Map<K, T>, types.Map<K, E> -- A tuple of unwrapped "ok" and "err" values
function Result.partition<T, E, K>(
    results: types.Map<K, Result<T, E>>
): (types.Map<K, T>, types.Map<K, E>)
    local oks, errs = {}, {}
    for key, value in results do
        if not Result.is(value) then
            fail("Called partition on a table containing a non-Result value")
        end
        if value:isOk() then
            oks[key] = value._value
        else
            errs[key] = value._error
        end
    end
    return oks, errs
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
function Result.equals<T, E>(self: Result<T, E>, other: Result<T, E>): boolean
    return Result.is(other)
        and self._value == other._value
        and self._error == other._error
end
Result.__eq = Result.equals

--- Returns a string representation of the `Result`.
---
--- @return string -- A string representation of the `Result`
function Result.toString<T, E>(self: Result<T, E>): string
    return if self:isOk()
        then `Ok({repr(self._value)})`
        else `Err({repr(self._error)})`
end
Result.__tostring = Result.toString

return Result
