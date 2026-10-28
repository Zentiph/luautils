--!strict

-- Result type
-- by @vuppyan

local Option = require("./Option")
local repr = require("../_internal").repr
local types = require("./types")

local fail = require("../_internal").Errors.errorWithScope("Result")

--- A value that represents either success ("ok") and holds a value, or failure
--- ("err") and holds an error.
---
--- An "ok" may hold `nil`, but an "err" cannot; a `Result` is "err" exactly
--- when its error is not `nil`. `Result`s are frozen and cannot be modified.
---
--- Supports `==` and `~=` comparison and `tostring()`.
---
--- @class Result
local Result = {}
Result.__index = Result

type ResultData<T, E> = {
    read _value: T,
    read _error: E?,
}

--- A `Result` holding either an "ok" value of type `T` or an "err" value of
--- type `E`.
---
--- @type Result Result<T, E>
--- @within Result
export type Result<T, E> = typeof(setmetatable({} :: ResultData<T, E>, Result))

-- Helper for creating a new Result
local function new<T, E>(value: T, err: E?): Result<T, E>
    return table.freeze(setmetatable({ _value = value, _error = err }, Result))
end

-- Helper for the message thrown when an external function produces a nil error.
local function nilErrorMessage(source: string): string
    return `{source} produced a nil error; "err" Results cannot hold nil`
end

--- Creates a new "ok" `Result` with the specified value.
---
--- The value may be `nil`.
---
--- @param value T -- The value to wrap
--- @return Result<T, E> -- The new `Result`
function Result.ok<T, E>(value: T): Result<T, E>
    return new(value, nil)
end

--- Creates a new "err" `Result` with the specified error.
---
--- @param err E -- The error to wrap
--- @return Result<T, E> -- The new `Result`
--- @error "Error cannot be nil" -- Thrown if `err` is `nil`
function Result.err<T, E>(err: E): Result<T, E>
    if err == nil then
        fail("Error cannot be nil")
    end
    return new(nil, err)
end

--- Returns the contained value if the `Result` is "ok", otherwise returns
--- `nil`.
---
--- Useful for APIs that accept optional values, and provides type-checking
--- where `unwrapOr(nil)` wouldn't.
---
--- An "ok" holding `nil` also returns `nil`, so the result alone cannot tell it
--- apart from an "err". Use [Result:isOk] if the difference matters.
---
--- @method toNillable
--- @within Result
--- @return T? -- The contained value, or `nil`
function Result.toNillable<T, E>(self: Result<T, E>): T?
    return self._value
end

--- Returns the contained error if the `Result` is "err", otherwise returns
--- `nil`.
---
--- Useful for APIs that accept optional values.
---
--- @method errToNillable
--- @within Result
--- @return E? -- The contained error, or `nil`
function Result.errToNillable<T, E>(self: Result<T, E>): E?
    return self._error
end

--- Returns `true` if the `Result` is "ok".
---
--- @method isOk
--- @within Result
--- @return boolean -- Whether the `Result` is "ok"
function Result.isOk<T, E>(self: Result<T, E>): boolean
    return self._error == nil
end

--- Returns `true` if the `Result` is "ok" and the contained value matches a
--- predicate.
---
--- `predicate` is only called if the `Result` is "ok".
---
--- @method isOkAnd
--- @within Result
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
--- @method isErr
--- @within Result
--- @return boolean -- Whether the `Result` is "err"
function Result.isErr<T, E>(self: Result<T, E>): boolean
    return self._error ~= nil
end

--- Returns `true` if the `Result` is "err" and the contained error matches a
--- predicate.
---
--- `predicate` is only called if the `Result` is "err".
---
--- @method isErrAnd
--- @within Result
--- @param predicate types.Predicate<E> -- The predicate to check the error against
--- @return boolean -- Whether the `Result` is "err" and the error matches the predicate
function Result.isErrAnd<T, E>(
    self: Result<T, E>,
    predicate: types.Predicate<E>
): boolean
    return self:isErr() and predicate(self._error :: E)
end

--- Converts an [Option] into a `Result<T, E>`, mapping "some" to "ok" and
--- "none" to "err".
---
--- `err` is evaluated even if the `Option` is "some"; use
--- [Result.fromOptionElse] if the error is expensive to create.
---
--- @param option Option.Option<T> -- The `Option` to convert
--- @param err E -- The error to provide if the `Option` is "none"
--- @return Result<T, E> -- The converted `Result`
--- @error "Given error produced a nil error" -- Thrown if the `Option` is "none" and `err` is `nil`
function Result.fromOption<T, E>(option: Option.Option<T>, err: E): Result<T, E>
    if option:isSome() then
        return Result.ok(option:unwrap())
    end
    if err == nil then
        fail(nilErrorMessage("Given error"))
    end
    return new(nil, err)
end

--- Like [Result.fromOption], but computes the error from a supplier instead.
---
--- `err` is only called if the [Option] is "none".
---
--- @param option Option.Option<T> -- The `Option` to convert
--- @param err types.Supplier<E> -- The function that supplies the error if the `Option` is "none"
--- @return Result<T, E> -- The converted `Result`
--- @error "Error supplier produced a nil error" -- Thrown if the `Option` is "none" and `err` returns `nil`
function Result.fromOptionElse<T, E>(
    option: Option.Option<T>,
    err: types.Supplier<E>
): Result<T, E>
    if option:isSome() then
        return Result.ok(option:unwrap())
    end
    local supplied = err()
    if supplied == nil then
        fail(nilErrorMessage("Error supplier"))
    end
    return new(nil, supplied)
end

--- Converts from `Result<T, E>` to an [Option] of the "ok" value.
---
--- An "err", or an "ok" holding `nil`, becomes a "none" `Option`.
---
--- @method asOk
--- @within Result
--- @return Option.Option<T> -- The converted `Option`
function Result.asOk<T, E>(self: Result<T, E>): Option.Option<T>
    return if self:isOk()
        then Option.fromNillable(self._value)
        else Option.none()
end

--- Converts from `Result<T, E>` to an [Option] of the "err" value.
---
--- An "ok" becomes a "none" `Option`.
---
--- @method asErr
--- @within Result
--- @return Option.Option<E> -- The converted `Option`
function Result.asErr<T, E>(self: Result<T, E>): Option.Option<E>
    return if self:isErr() then Option.some(self._error :: E) else Option.none()
end

--- Maps a `Result<T, E>` to `Result<U, E>` by applying a function to a
--- contained "ok" value, leaving an "err" value untouched.
---
--- @method map
--- @within Result
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return Result<U, E> -- The mapped `Result`
function Result.map<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, U>
): Result<U, E>
    return if self:isOk() then Result.ok(mapper(self._value)) else self
end

--- Maps a `Result<T, E>` to `U` by applying a function to a contained "ok"
--- value, or returning the provided default if "err".
---
--- `default` is evaluated even if the `Result` is "ok"; use [Result:mapOrElse]
--- if the default is expensive to create.
---
--- @method mapOr
--- @within Result
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

--- Maps a `Result<T, E>` to `U` by applying `mapper` to a contained "ok"
--- value, or the fallback function `default` to a contained "err" value.
---
--- @method mapOrElse
--- @within Result
--- @param default types.Mapper<E, U> -- The function to apply to the contained error
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

--- Like [Result:map], except this method returns an "err" `Result` if `mapper`
--- throws, with the thrown value as the "err" value.
---
--- As with [Result.try], a thrown `nil` is replaced with a descriptive string,
--- and the error is typed as `unknown`, since it may be either the original
--- error or a thrown value.
---
--- @method tryMap
--- @within Result
--- @param mapper types.Mapper<T, U> -- The function to apply to the contained value
--- @return Result<U, unknown> -- The mapped `Result`
function Result.tryMap<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, U>
): Result<U, unknown>
    return if self:isOk() then Result.try(mapper, self._value) else self
end

--- Maps a `Result<T, E>` to `Result<T, F>` by applying a function to a
--- contained "err" value, leaving an "ok" value untouched.
---
--- @method mapErr
--- @within Result
--- @param mapper types.Mapper<E, F> -- The function to apply to the contained error
--- @return Result<T, F> -- The mapped `Result`
--- @error "Mapper produced a nil error" -- Thrown if `mapper` returns `nil`
function Result.mapErr<T, E, F>(
    self: Result<T, E>,
    mapper: types.Mapper<E, F>
): Result<T, F>
    if self:isOk() then
        return self
    end
    local mapped = mapper(self._error :: E)
    if mapped == nil then
        fail(nilErrorMessage("Mapper"))
    end
    return new(nil, mapped)
end

--- Tests the contained value of the `Result` if "ok". Returns the original
--- `Result` if the value matches `predicate`, otherwise returns an "err"
--- holding the error created by `errorFactory` from the value.
---
--- If the `Result` is "err", returns the original `Result` without calling
--- either function.
---
--- @method filterOrElse
--- @within Result
--- @param predicate types.Predicate<T> -- The predicate to check the value against
--- @param errorFactory types.Factory<E, T> -- The function that creates the error from the value
--- @return Result<T, E> -- The original `Result`, or the new "err"
--- @error "Error factory produced a nil error" -- Thrown if `errorFactory` returns `nil`
function Result.filterOrElse<T, E>(
    self: Result<T, E>,
    predicate: types.Predicate<T>,
    errorFactory: types.Factory<E, T>
): Result<T, E>
    if self:isErr() or predicate(self._value) then
        return self
    end
    local err = errorFactory(self._value)
    if err == nil then
        fail(nilErrorMessage("Error factory"))
    end
    return new(nil, err)
end

--- Calls a function with the contained value if "ok".
---
--- Returns the original `Result`.
---
--- @method inspect
--- @within Result
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
--- @method inspectErr
--- @within Result
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

--- Returns the contained "ok" value, or throws if the `Result` is "err", with
--- an error message made of the provided message and the contained error.
---
--- @method expect
--- @within Result
--- @param message string -- The error message
--- @return T -- The contained value
--- @error "{message}: {error}" -- Thrown if the `Result` is "err"
function Result.expect<T, E>(self: Result<T, E>, message: string): T
    if self:isErr() then
        fail(`{message}: {repr(self._error)}`)
    end
    return self._value
end

--- Returns the contained "ok" value, or throws the contained error if the
--- `Result` is "err".
---
--- If the error is a table or userdata, it is thrown as-is, in order to
--- preserve its data. Otherwise, it is converted with `tostring()` and thrown
--- as a message, prefixed with `[Result.unwrap()]: `.
---
--- @method unwrap
--- @within Result
--- @return T -- The contained value
--- @error unknown -- Thrown if the `Result` is "err"
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
--- an error message made of the provided message and the contained value.
---
--- @method expectErr
--- @within Result
--- @param message string -- The error message
--- @return E -- The contained error
--- @error "{message}: {value}" -- Thrown if the `Result` is "ok"
function Result.expectErr<T, E>(self: Result<T, E>, message: string): E
    if self:isOk() then
        fail(`{message}: {repr(self._value)}`)
    end
    return self._error :: E
end

--- Returns the contained "err" value, or throws if the `Result` is "ok", with
--- an error message containing the contained value.
---
--- Unlike [Result:unwrap], the contained value is always included in a message,
--- never thrown as-is.
---
--- @method unwrapErr
--- @within Result
--- @return E -- The contained error
--- @error "Called on an ok value: {value}" -- Thrown if the `Result` is "ok"
function Result.unwrapErr<T, E>(self: Result<T, E>): E
    if self:isOk() then
        fail(`Called on an ok value: {repr(self._value)}`)
    end
    return self._error :: E
end

--- Returns `other` if the `Result` is "ok", otherwise returns `self`.
---
--- `other` is evaluated even if the `Result` is "err"; use [Result:andThen] if
--- it is expensive to create.
---
--- @method andResult
--- @within Result
--- @param other Result<U, E> -- The `Result` to return if the `Result` is "ok"
--- @return Result<U, E> -- `other`, or the original "err" `Result`
function Result.andResult<T, E, U>(self: Result<T, E>, other: Result<U, E>): Result<U, E>
    return if self:isOk() then other else self
end

--- Calls `mapper` with the contained value if the `Result` is "ok", otherwise
--- returns `self`.
---
--- @method andThen
--- @within Result
--- @param mapper types.Mapper<T, Result<U, E>> -- The function to call if the `Result` is "ok"
--- @return Result<U, E> -- The `Result` returned by `mapper`, or the original "err" `Result`
function Result.andThen<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, Result<U, E>>
): Result<U, E>
    return if self:isOk() then mapper(self._value) else self
end

--- Returns `other` if the `Result` is "err", otherwise returns `self`.
---
--- `other` is evaluated even if the `Result` is "ok"; use [Result:orElse] if it
--- is expensive to create.
---
--- @method orResult
--- @within Result
--- @param other Result<T, F> -- The `Result` to return if the `Result` is "err"
--- @return Result<T, F> -- `other`, or the original "ok" `Result`
function Result.orResult<T, E, F>(self: Result<T, E>, other: Result<T, F>): Result<T, F>
    return if self:isOk() then self else other
end

--- Calls `mapper` with the contained error if the `Result` is "err", otherwise
--- returns `self`.
---
--- @method orElse
--- @within Result
--- @param mapper types.Mapper<E, Result<T, F>> -- The function to call if the `Result` is "err"
--- @return Result<T, F> -- The `Result` returned by `mapper`, or the original "ok" `Result`
function Result.orElse<T, E, F>(
    self: Result<T, E>,
    mapper: types.Mapper<E, Result<T, F>>
): Result<T, F>
    return if self:isOk() then self else mapper(self._error :: E)
end

--- Returns the contained "ok" value or a provided default.
---
--- `default` is evaluated even if the `Result` is "ok"; use
--- [Result:unwrapOrElse] if the default is expensive to create.
---
--- @method unwrapOr
--- @within Result
--- @param default T -- The default value to return if the `Result` is "err"
--- @return T -- The contained value, or the provided default
function Result.unwrapOr<T, E>(self: Result<T, E>, default: T): T
    return if self:isOk() then self._value else default
end

--- Returns the contained "ok" value or computes one from the error using
--- `mapper`.
---
--- @method unwrapOrElse
--- @within Result
--- @param mapper types.Mapper<E, T> -- The function to call if the `Result` is "err"
--- @return T -- The contained value, or the computed value
function Result.unwrapOrElse<T, E>(self: Result<T, E>, mapper: types.Mapper<E, T>): T
    return if self:isOk() then self._value else mapper(self._error :: E)
end

--- Calls `ifOk` with the contained value if the `Result` is "ok", otherwise
--- calls `ifErr` with the contained error.
---
--- Returns nothing; the return values of `ifOk` and `ifErr` are discarded. Use
--- [Result:mapOrElse] to produce a value instead.
---
--- @method match
--- @within Result
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
--- Any additional return values are discarded; use [Result.tryPack] for
--- functions that return multiple values.
---
--- If `factory` throws `nil`, then the error is replaced with a descriptive
--- string, since an "err" cannot hold `nil`.
---
--- Since `pcall` cannot check error types, the error is typed as `unknown`.
--- Cast this `Result` to one with the expected error type if needed.
---
--- The traceback of the error is lost; use [Result.tryTrace] to capture it.
---
--- @param factory types.Factory<T, A...> -- The function to call in protected mode
--- @param ... A... -- The arguments to pass to `factory`
--- @return Result<T, unknown> -- The `Result` of running the function
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

--- Like [Result.try], but runs the function in extended protected mode with an
--- error handler.
---
--- This is recommended when you want to inspect the traceback of an error that
--- occurs in `factory`, which is done by calling `debug.traceback()` in
--- `onErr`.
---
--- `onErr` is called with the thrown value before the stack unwinds, and its
--- return value becomes the "err" value. If `onErr` returns `nil`, the error is
--- replaced with a descriptive string, since an "err" cannot hold `nil`.
---
--- Unlike [Result.try], a thrown `nil` is passed to `onErr` as-is, so `onErr`
--- decides what it becomes.
---
--- Note that `onErr` comes before the arguments to `factory`.
---
--- @param factory types.Factory<T, A...> -- The function to call in extended protected mode
--- @param onErr types.Mapper<unknown, E?> -- The error handler to call if the function fails
--- @param ... A... -- The arguments to pass to `factory`
--- @return Result<T, E> -- The `Result` of running the function
function Result.tryTrace<T, E, A...>(
    factory: types.Factory<T, A...>,
    onErr: types.Mapper<unknown, E?>,
    ...: A...
): Result<T, E>
    local ok, result = xpcall(factory, onErr, ...)
    return if ok
        then Result.ok(result)
        else Result.err(
            if result == nil then "error handler returned nil" else result
        )
end

--- Like [Result.try], but packs all return values of `factory` into a table.
---
--- Use `table.unpack(packed, 1, packed.n)` to get the values back.
---
--- As with [Result.try], a thrown `nil` is replaced with a descriptive string.
---
--- @param factory types.TupleFactory<...any, A...> -- The function to call in protected mode
--- @param ... A... -- The arguments to pass to `factory`
--- @return Result<types.PackedTable, unknown> -- The `Result` of running the function, holding the packed return values if "ok"
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

--- Like [Result:andThen], except this method returns an "err" `Result` if
--- `mapper` throws, with the thrown value as the "err" value.
---
--- As with [Result.try], a thrown `nil` is replaced with a descriptive string,
--- and the error is typed as `unknown`, since it may be either the original
--- error, an error returned by `mapper`, or a thrown value.
---
--- @method tryAndThen
--- @within Result
--- @param mapper types.Mapper<T, Result<U, E>> -- The function to call if the `Result` is "ok"
--- @return Result<U, unknown> -- The `Result` returned by `mapper`, the thrown error, or the original "err" `Result`
--- @error "Called flatten on a Result that does not contain a Result" -- Thrown if `mapper` returns a non-`Result` value without throwing
function Result.tryAndThen<T, E, U>(
    self: Result<T, E>,
    mapper: types.Mapper<T, Result<U, E>>
): Result<U, unknown>
    return if self:isOk()
        then Result.try(mapper, self._value):flatten()
        else self
end

--- Wraps a function that may throw an error into one that returns a `Result`.
---
--- The returned function passes its arguments to `factory` and behaves like
--- [Result.try], so only the first return value is kept.
---
--- @param factory types.Factory<T, A...> -- The function to wrap
--- @return types.Factory<Result<T, unknown>, A...> -- The wrapped function
function Result.wrap<T, A...>(
    factory: types.Factory<T, A...>
): types.Factory<Result<T, unknown>, A...>
    return function(...: A...)
        return Result.try(factory, ...)
    end
end

--- Transposes a `Result` of an [Option] into an `Option` of a `Result`.
---
--- An "ok" with a "none" is mapped to "none". An "ok" with a "some" is mapped
--- to a "some" with the "ok". An "err" is mapped to a "some" with the "err".
---
--- @method transpose
--- @within Result
--- @return Option.Option<Result<T, E>> -- The transposed `Option`
--- @error "Called transpose on a Result that does not contain an Option" -- Thrown if the `Result` is "ok" and does not hold an `Option`
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

--- Transposes an [Option] of a `Result` into a `Result` of an [Option].
---
--- A "some" with an "ok" is mapped to a "ok" with the "some". A "some" with
--- an "err" is mapped to an "err". A "none" is mapped to a "ok" with a "none".
---
--- @method transposeOption
--- @within Result
--- @param option Option.Option<Result<T, E>> -- The `Option` to transpose
--- @return Result<Option.Option<T>, E> -- The transposed `Result`
function Result.transposeOption<T, E>(
    option: Option.Option<Result<T, E>>
): Result<Option.Option<T>, E>
    if option:isNone() then
        return Result.ok(Option.none())
    end
    local inner = option:unwrap()
    if not Result.is(inner) then
        fail(
            "Called transposeOption on an Option that does not contain a Result"
        )
    end
    return if inner:isOk()
        then Result.ok(Option.fromNillable(inner._value))
        else inner
end

--- Converts from `Result<Result<T, E>, E>` to `Result<T, E>`.
---
--- Only one level of nesting is removed.
---
--- @method flatten
--- @within Result
--- @return Result<T, E> -- The flattened `Result`
--- @error "Called flatten on a Result that does not contain a Result" -- Thrown if the `Result` is "ok" and does not hold a `Result`
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
--- first "err" found. Iteration order is only guaranteed for arrays, so with
--- other tables, which "err" is returned may vary.
---
--- "ok" values of `nil` are omitted, since tables cannot hold `nil`. Keys are
--- preserved, so array input containing them produces arrays with gaps.
---
--- @param results types.Map<K, Result<T, E>> -- The table of `Result`s
--- @return Result<types.Map<K, T>, E> -- The converted `Result`
--- @error "Called all on a table containing a non-Result value" -- Thrown if a non-`Result` value is found before any "err"
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
--- Unlike [Result.all], this never short-circuits and always returns both
--- tables fully.
---
--- "ok" values of `nil` are omitted, since tables cannot hold `nil`. Keys are
--- preserved, so array input produces arrays with gaps.
---
--- @param results types.Map<K, Result<T, E>> -- The table of `Result`s
--- @return types.Map<K, T> -- The unwrapped "ok" values
--- @return types.Map<K, E> -- The unwrapped "err" values
--- @error "Called partition on a table containing a non-Result value" -- Thrown if any value is not a `Result`
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
--- Wrapped values are compared with `==`. Returns `false` if `other` is not a
--- `Result`.
---
--- Also used for the `==` and `~=` operators.
---
--- @method equals
--- @within Result
--- @param other Result<T, E> -- The `Result` to compare with the current `Result`
--- @return boolean -- Whether the two `Result`s are equal
function Result.equals<T, E>(self: Result<T, E>, other: Result<T, E>): boolean
    return Result.is(other)
        and self._value == other._value
        and self._error == other._error
end
Result.__eq = Result.equals

--- Returns a string representation of the `Result`, in the form `Ok(value)` or
--- `Err(error)`.
---
--- Also used by `tostring()`.
---
--- @method toString
--- @within Result
--- @return string -- A string representation of the `Result`
function Result.toString<T, E>(self: Result<T, E>): string
    return if self:isOk()
        then `Ok({repr(self._value)})`
        else `Err({repr(self._error)})`
end
Result.__tostring = Result.toString

return Result
