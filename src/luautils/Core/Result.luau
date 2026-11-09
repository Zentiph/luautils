--!strict

-- Result type
-- by @vuppyan

local Option = require("./Option")
type Option<T> = Option.Option<T>

local typing = require("./typing")
type Consumer<T> = typing.Consumer<T>
type Factory<T, A...> = typing.Factory<T, A...>
type Map<K, V> = typing.Map<K, V>
type Mapper<T, U> = typing.Mapper<T, U>
type PackedTable = typing.PackedTable
type Predicate<T> = typing.Predicate<T>
type Supplier<T> = typing.Supplier<T>
type TupleFactory<T..., A...> = typing.TupleFactory<T..., A...>

local repr = require("../_internal").repr
local fail = require("./Errors").errorWithScope("Result")

--[=[
    A value that represents either success ("ok") and holds a value, or failure
    ("err") and holds an error.

    An "ok" may hold `nil`, but an "err" cannot; a `Result` is "err" exactly
    when its error is not `nil`. `Result`s are frozen and cannot be modified.

    Supports `==` and `~=` comparison and `tostring()`.

    Error messages thrown by `Result` functions are prefixed with the function
    that threw them, such as `[Result.unwrap()]: `, after the usual position
    prefix added by `error()`. Errors that are thrown as-is, such as table
    errors from [Result:unwrap], are not prefixed.

    @class Result
    @since v0.1.0
]=]
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

-- Helper for the message thrown when an external function produces a nil error.
local function nilErrorMessage(source: string): string
    return `{source} produced a nil error; "err" Results cannot hold nil`
end

--[=[
    Creates a new "ok" `Result` with the specified value.

    The value may be `nil`.

    While the return type is typed as `Result<T, never>`, the `Result` created
    by this function can still be used generically as a `Result<T, E>`. This is
    done to prevent false positives from the type checker.

    ```lua
    Result.ok(5) -- Ok(5)
    Result.ok(nil) -- Ok(nil), which is still "ok"
    ```

    @since v0.1.0
    @param value T -- The value to wrap
    @return Result<T, E> -- The new `Result`
]=]
function Result.ok<T, E>(value: T): Result<T, never>
    return new(value, nil :: any)
end

--[=[
    Creates a new "err" `Result` with the specified error.

    While the return type is typed as `Result<never, E>`, the `Result` created
    by this function can still be used generically as a `Result<T, E>`. This is
    done to prevent false positives from the type checker.

    @since v0.1.0
    @param err E -- The error to wrap
    @return Result<T, E> -- The new `Result`
    @error "[Result.err()]: Error cannot be nil" -- Thrown if `err` is `nil`
]=]
function Result.err<T, E>(err: E): Result<never, E>
    if err == nil then
        fail("Error cannot be nil")
    end
    return new(nil :: any, err)
end

--[=[
    Returns the contained value if the `Result` is "ok", otherwise returns
    `nil`.

    Useful for APIs that accept optional values, and provides type-checking
    where `unwrapOr(nil)` wouldn't.

    An "ok" holding `nil` also returns `nil`, so the result alone cannot tell it
    apart from an "err". Use [Result:isOk] if the difference matters.

    ```lua
    Result.ok(1):toNillable() -- 1
    Result.ok(nil):toNillable() -- nil
    Result.err("x"):toNillable() -- nil
    ```

    @method toNillable
    @within Result
    @since v0.1.0
    @return T? -- The contained value, or `nil`
]=]
function Result.toNillable<T, E>(self: Result<T, E>): T?
    return self._value
end

--[=[
    Returns the contained error if the `Result` is "err", otherwise returns
    `nil`.

    Useful for APIs that accept optional values.

    @method errToNillable
    @within Result
    @since v0.1.0
    @return E? -- The contained error, or `nil`
]=]
function Result.errToNillable<T, E>(self: Result<T, E>): E?
    return self._error
end

--[=[
    Returns `true` if the `Result` is "ok".

    @method isOk
    @within Result
    @since v0.1.0
    @return boolean -- Whether the `Result` is "ok"
]=]
function Result.isOk<T, E>(self: Result<T, E>): boolean
    return self._error == nil
end

--[=[
    Returns `true` if the `Result` is "ok" and the contained value matches a
    predicate.

    `predicate` is only called if the `Result` is "ok".

    @method isOkAnd
    @within Result
    @since v0.1.0
    @param predicate Predicate<T> -- The predicate to check the value against
    @return boolean -- Whether the `Result` is "ok" and the value matches the predicate
]=]
function Result.isOkAnd<T, E>(self: Result<T, E>, predicate: Predicate<T>): boolean
    return self:isOk() and predicate(self._value)
end

--[=[
    Returns `true` if the `Result` is "err".

    @method isErr
    @within Result
    @since v0.1.0
    @return boolean -- Whether the `Result` is "err"
]=]
function Result.isErr<T, E>(self: Result<T, E>): boolean
    return self._error ~= nil
end

--[=[
    Returns `true` if the `Result` is "err" and the contained error matches a
    predicate.

    `predicate` is only called if the `Result` is "err".

    @method isErrAnd
    @within Result
    @since v0.1.0
    @param predicate Predicate<E> -- The predicate to check the error against
    @return boolean -- Whether the `Result` is "err" and the error matches the predicate
]=]
function Result.isErrAnd<T, E>(self: Result<T, E>, predicate: Predicate<E>): boolean
    return self:isErr() and predicate(self._error :: E)
end

--[=[
    Converts an [Option] into a `Result<T, E>`, mapping "some" to "ok" and
    "none" to "err".

    `err` is evaluated even if the `Option` is "some"; use
    [Result.fromOptionElse] if the error is expensive to create.

    ```lua
    Result.fromOption(Option.some(1), "missing") -- Ok(1)
    Result.fromOption(Option.none(), "missing") -- Err("missing")
    ```

    @since v0.1.0
    @param option Option<T> -- The `Option` to convert
    @param err E -- The error to provide if the `Option` is "none"
    @return Result<T, E> -- The converted `Result`
    @error '[Result.fromOption()]: Given error produced a nil error; "err" Results cannot hold nil' -- Thrown if the `Option` is "none" and `err` is `nil`
]=]
function Result.fromOption<T, E>(option: Option<T>, err: E): Result<T, E>
    if option:isSome() then
        return Result.ok(option:unwrap())
    end
    if err == nil then
        fail(nilErrorMessage("Given error"))
    end
    return new(nil, err)
end

--[=[
    Like [Result.fromOption], but computes the error from a supplier instead.

    `err` is only called if the [Option] is "none".

    @since v0.1.0
    @param option Option<T> -- The `Option` to convert
    @param err Supplier<E> -- The function that supplies the error if the `Option` is "none"
    @return Result<T, E> -- The converted `Result`
    @error '[Result.fromOptionElse()]: Error supplier produced a nil error; "err" Results cannot hold nil' -- Thrown if the `Option` is "none" and `err` returns `nil`
]=]
function Result.fromOptionElse<T, E>(
    option: Option<T>,
    err: Supplier<E>
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

--[=[
    Converts from `Result<T, E>` to an [Option] of the "ok" value.

    An "err", or an "ok" holding `nil`, becomes a "none" `Option`.

    ```lua
    Result.ok(1):asOk() -- Some(1)
    Result.ok(nil):asOk() -- None
    Result.err("x"):asOk() -- None
    ```

    @method asOk
    @within Result
    @since v0.1.0
    @return Option<T> -- The converted `Option`
]=]
function Result.asOk<T, E>(self: Result<T, E>): Option<T>
    return if self:isOk()
        then Option.fromNillable(self._value)
        else Option.none()
end

--[=[
    Converts from `Result<T, E>` to an [Option] of the "err" value.

    An "ok" becomes a "none" `Option`.

    @method asErr
    @within Result
    @since v0.1.0
    @return Option<E> -- The converted `Option`
]=]
function Result.asErr<T, E>(self: Result<T, E>): Option<E>
    return if self:isErr() then Option.some(self._error :: E) else Option.none()
end

--[=[
    Maps a `Result<T, E>` to `Result<U, E>` by applying a function to a
    contained "ok" value, leaving an "err" value untouched.

    @method map
    @within Result
    @since v0.1.0
    @param mapper Mapper<T, U> -- The function to apply to the contained value
    @return Result<U, E> -- The mapped `Result`
]=]
function Result.map<T, E, U>(self: Result<T, E>, mapper: Mapper<T, U>): Result<U, E>
    return if self:isOk() then Result.ok(mapper(self._value)) else self
end

--[=[
    Maps a `Result<T, E>` to `U` by applying a function to a contained "ok"
    value, or returning the provided default if "err".

    `default` is evaluated even if the `Result` is "ok"; use [Result:mapOrElse]
    if the default is expensive to create.

    @method mapOr
    @within Result
    @since v0.1.0
    @param default U -- The default value to return if the `Result` is "err"
    @param mapper Mapper<T, U> -- The function to apply to the contained value
    @return U -- The provided default value, or the mapped value
]=]
function Result.mapOr<T, E, U>(self: Result<T, E>, default: U, mapper: Mapper<T, U>): U
    return if self:isOk() then mapper(self._value) else default
end

--[=[
    Maps a `Result<T, E>` to `U` by applying `mapper` to a contained "ok"
    value, or the fallback function `default` to a contained "err" value.

    ```lua
    local function double(x: number): number
        return x * 2
    end
    local function length(e: string): number
        return #e
    end
    Result.ok(2):mapOrElse(length, double) -- 4
    Result.err("abc"):mapOrElse(length, double) -- 3
    ```

    @method mapOrElse
    @within Result
    @since v0.1.0
    @param default Mapper<E, U> -- The function to apply to the contained error
    @param mapper Mapper<T, U> -- The function to apply to the contained value
    @return U -- The mapped value
]=]
function Result.mapOrElse<T, E, U>(
    self: Result<T, E>,
    default: Mapper<E, U>,
    mapper: Mapper<T, U>
): U
    return if self:isOk()
        then mapper(self._value)
        else default(self._error :: E)
end

--[=[
    Like [Result:map], except this method returns an "err" `Result` if `mapper`
    throws, with the thrown value as the "err" value.

    As with [Result.try], a thrown `nil` is replaced with a descriptive string,
    and the error is typed as `unknown`, since it may be either the original
    error or a thrown value.

    ```lua
    Result.ok(2):tryMap(function(x)
        return x + 1
    end) -- Ok(3)
    Result.ok(2):tryMap(function(x)
        error("boom", 0)
    end) -- Err("boom")
    ```

    @method tryMap
    @within Result
    @since v0.1.0
    @param mapper Mapper<T, U> -- The function to apply to the contained value
    @return Result<U, unknown> -- The mapped `Result`
]=]
function Result.tryMap<T, E, U>(
    self: Result<T, E>,
    mapper: Mapper<T, U>
): Result<U, unknown>
    return if self:isOk() then Result.try(mapper, self._value) else self
end

--[=[
    Maps a `Result<T, E>` to `Result<T, F>` by applying a function to a
    contained "err" value, leaving an "ok" value untouched.

    @method mapErr
    @within Result
    @since v0.1.0
    @param mapper Mapper<E, F> -- The function to apply to the contained error
    @return Result<T, F> -- The mapped `Result`
    @error '[Result.mapErr()]: Mapper produced a nil error; "err" Results cannot hold nil' -- Thrown if `mapper` returns `nil`
]=]
function Result.mapErr<T, E, F>(self: Result<T, E>, mapper: Mapper<E, F>): Result<T, F>
    if self:isOk() then
        return self
    end
    local mapped = mapper(self._error :: E)
    if mapped == nil then
        fail(nilErrorMessage("Mapper"))
    end
    return new(nil, mapped)
end

--[=[
    Tests the contained value of the `Result` if "ok". Returns the original
    `Result` if the value matches `predicate`, otherwise returns an "err"
    holding the error created by `errorFactory` from the value.

    If the `Result` is "err", returns the original `Result` without calling
    either function.

    ```lua
    local function isPositive(x: number): boolean
        return x > 0
    end
    local function notPositive(x: number): string
        return `{x} is not positive`
    end
    Result.ok(5):filterOrElse(isPositive, notPositive) -- Ok(5)
    Result.ok(-5):filterOrElse(isPositive, notPositive)
    -- Err("-5 is not positive")
    ```

    @method filterOrElse
    @within Result
    @since v0.1.0
    @param predicate Predicate<T> -- The predicate to check the value against
    @param errorFactory Factory<E, T> -- The function that creates the error from the value
    @return Result<T, E> -- The original `Result`, or the new "err"
    @error '[Result.filterOrElse()]: Error factory produced a nil error; "err" Results cannot hold nil' -- Thrown if `errorFactory` returns `nil`
]=]
function Result.filterOrElse<T, E>(
    self: Result<T, E>,
    predicate: Predicate<T>,
    errorFactory: Factory<E, T>
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

--[=[
    Calls a function with the contained value if "ok".

    Returns the original `Result`.

    @method inspect
    @within Result
    @since v0.1.0
    @param consumer Consumer<T> -- The function to call with the contained value
    @return Result<T, E> -- The original `Result`
]=]
function Result.inspect<T, E>(self: Result<T, E>, consumer: Consumer<T>): Result<T, E>
    if self:isOk() then
        consumer(self._value)
    end
    return self
end

--[=[
    Calls a function with the contained error if "err".

    Returns the original `Result`.

    @method inspectErr
    @within Result
    @since v0.1.0
    @param consumer Consumer<E> -- The function to call with the contained error
    @return Result<T, E> -- The original `Result`
]=]
function Result.inspectErr<T, E>(
    self: Result<T, E>,
    consumer: Consumer<E>
): Result<T, E>
    if self:isErr() then
        consumer(self._error :: E)
    end
    return self
end

--[=[
    Returns the contained "ok" value, or throws if the `Result` is "err", with
    an error message made of the provided message and the contained error.

    ```lua
    Result.ok(1):expect("Failed to load") -- 1
    Result.err("timeout"):expect("Failed to load")
    -- throws '[Result.expect()]: Failed to load: "timeout"'
    ```

    @method expect
    @within Result
    @since v0.1.0
    @param message string -- The error message
    @return T -- The contained value
    @error "[Result.expect()]: {message}: {error}" -- Thrown if the `Result` is "err"
]=]
function Result.expect<T, E>(self: Result<T, E>, message: string): T
    if self:isErr() then
        fail(`{message}: {repr(self._error)}`)
    end
    return self._value
end

--[=[
    Returns the contained "ok" value, or throws the contained error if the
    `Result` is "err".

    If the error is a table or userdata, it is thrown as-is, in order to
    preserve its data. Otherwise, it is converted with `tostring()` and thrown
    as a message, prefixed with `[Result.unwrap()]: `.

    ```lua
    Result.ok(1):unwrap() -- 1
    Result.err("timeout"):unwrap() -- throws "[Result.unwrap()]: timeout"
    Result.err({ code = 1 }):unwrap() -- throws the table itself
    ```

    @method unwrap
    @within Result
    @since v0.1.0
    @return T -- The contained value
    @error unknown -- Thrown if the `Result` is "err"; `"[Result.unwrap()]: {error}"` unless the error is a table or userdata
]=]
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

--[=[
    Returns the contained "err" value, or throws if the `Result` is "ok", with
    an error message made of the provided message and the contained value.

    @method expectErr
    @within Result
    @since v0.1.0
    @param message string -- The error message
    @return E -- The contained error
    @error "[Result.expectErr()]: {message}: {value}" -- Thrown if the `Result` is "ok"
]=]
function Result.expectErr<T, E>(self: Result<T, E>, message: string): E
    if self:isOk() then
        fail(`{message}: {repr(self._value)}`)
    end
    return self._error :: E
end

--[=[
    Returns the contained "err" value, or throws if the `Result` is "ok", with
    an error message containing the contained value.

    Unlike [Result:unwrap], the contained value is always included in a message,
    never thrown as-is.

    @method unwrapErr
    @within Result
    @since v0.1.0
    @return E -- The contained error
    @error "[Result.unwrapErr()]: Called on an ok value: {value}" -- Thrown if the `Result` is "ok"
]=]
function Result.unwrapErr<T, E>(self: Result<T, E>): E
    if self:isOk() then
        fail(`Called on an ok value: {repr(self._value)}`)
    end
    return self._error :: E
end

--[=[
    Returns `other` if the `Result` is "ok", otherwise returns `self`.

    `other` is evaluated even if the `Result` is "err"; use [Result:andThen] if
    it is expensive to create.

    ```lua
    Result.ok(1):andResult(Result.ok(2)) -- Ok(2)
    Result.ok(1):andResult(Result.err("b")) -- Err("b")
    Result.err("a"):andResult(Result.ok(2)) -- Err("a")
    ```

    @method andResult
    @within Result
    @since v0.1.0
    @param other Result<U, E> -- The `Result` to return if the `Result` is "ok"
    @return Result<U, E> -- `other`, or the original "err" `Result`
]=]
function Result.andResult<T, E, U>(self: Result<T, E>, other: Result<U, E>): Result<U, E>
    return if self:isOk() then other else self
end

--[=[
    Calls `mapper` with the contained value if the `Result` is "ok", otherwise
    returns `self`.

    ```lua
    local function safeDivide(x: number): Result<number, string>
        if x == 0 then
            return Result.err("divide by zero")
        end
        return Result.ok(10 / x)
    end
    Result.ok(2):andThen(safeDivide) -- Ok(5)
    Result.ok(0):andThen(safeDivide) -- Err("divide by zero")
    Result.err("e"):andThen(safeDivide) -- Err("e")
    ```

    @method andThen
    @within Result
    @since v0.1.0
    @param mapper Mapper<T, Result<U, E>> -- The function to call if the `Result` is "ok"
    @return Result<U, E> -- The `Result` returned by `mapper`, or the original "err" `Result`
]=]
function Result.andThen<T, E, U>(
    self: Result<T, E>,
    mapper: Mapper<T, Result<U, E>>
): Result<U, E>
    return if self:isOk() then mapper(self._value) else self
end

--[=[
    Returns `other` if the `Result` is "err", otherwise returns `self`.

    `other` is evaluated even if the `Result` is "ok"; use [Result:orElse] if it
    is expensive to create.

    ```lua
    Result.ok(1):orResult(Result.ok(2)) -- Ok(1)
    Result.err("a"):orResult(Result.ok(2)) -- Ok(2)
    ```

    @method orResult
    @within Result
    @since v0.1.0
    @param other Result<T, F> -- The `Result` to return if the `Result` is "err"
    @return Result<T, F> -- `other`, or the original "ok" `Result`
]=]
function Result.orResult<T, E, F>(self: Result<T, E>, other: Result<T, F>): Result<T, F>
    return if self:isOk() then self else other
end

--[=[
    Calls `mapper` with the contained error if the `Result` is "err", otherwise
    returns `self`.

    ```lua
    Result.ok(1):orElse(function(e)
        return Result.ok(#e)
    end) -- Ok(1)
    Result.err("abc"):orElse(function(e)
        return Result.ok(#e)
    end) -- Ok(3)
    ```

    @method orElse
    @within Result
    @since v0.1.0
    @param mapper Mapper<E, Result<T, F>> -- The function to call if the `Result` is "err"
    @return Result<T, F> -- The `Result` returned by `mapper`, or the original "ok" `Result`
]=]
function Result.orElse<T, E, F>(
    self: Result<T, E>,
    mapper: Mapper<E, Result<T, F>>
): Result<T, F>
    return if self:isOk() then self else mapper(self._error :: E)
end

--[=[
    Returns the contained "ok" value or a provided default.

    `default` is evaluated even if the `Result` is "ok"; use
    [Result:unwrapOrElse] if the default is expensive to create.

    @method unwrapOr
    @within Result
    @since v0.1.0
    @param default T -- The default value to return if the `Result` is "err"
    @return T -- The contained value, or the provided default
]=]
function Result.unwrapOr<T, E>(self: Result<T, E>, default: T): T
    return if self:isOk() then self._value else default
end

--[=[
    Returns the contained "ok" value or computes one from the error using
    `mapper`.

    @method unwrapOrElse
    @within Result
    @since v0.1.0
    @param mapper Mapper<E, T> -- The function to call if the `Result` is "err"
    @return T -- The contained value, or the computed value
]=]
function Result.unwrapOrElse<T, E>(self: Result<T, E>, mapper: Mapper<E, T>): T
    return if self:isOk() then self._value else mapper(self._error :: E)
end

--[=[
    Calls `ifOk` with the contained value if the `Result` is "ok", otherwise
    calls `ifErr` with the contained error.

    Returns nothing; the return values of `ifOk` and `ifErr` are discarded. Use
    [Result:mapOrElse] to produce a value instead.

    @method match
    @within Result
    @since v0.1.0
    @param ifOk Consumer<T> -- The function to call with the contained value
    @param ifErr Consumer<E> -- The function to call with the contained error
]=]
function Result.match<T, E>(
    self: Result<T, E>,
    ifOk: Consumer<T>,
    ifErr: Consumer<E>
): ()
    if self:isOk() then
        ifOk(self._value)
    else
        ifErr(self._error :: E)
    end
end

--[=[
    Calls `factory` with the given arguments in protected mode, returning "ok"
    with its first return value, or "err" with the thrown value.

    Any additional return values are discarded; use [Result.tryPack] for
    functions that return multiple values.

    If `factory` throws `nil`, then the error is replaced with a descriptive
    string, since an "err" cannot hold `nil`.

    Since `pcall` cannot check error types, the error is typed as `unknown`.
    Cast this `Result` to one with the expected error type if needed.

    The traceback of the error is lost; use [Result.tryTrace] to capture it.

    ```lua
    Result.try(tonumber, "12") -- Ok(12)
    Result.try(error, "bad", 0) -- Err("bad")
    Result.try(function()
        return 1, 2
    end) -- Ok(1), since extra return values are discarded
    Result.try(function()
        error(nil)
    end) -- Err("error(nil) was called")
    ```

    @since v0.1.0
    @param factory Factory<T, A...> -- The function to call in protected mode
    @param ... A... -- The arguments to pass to `factory`
    @return Result<T, unknown> -- The `Result` of running the function
]=]
function Result.try<T, A...>(factory: Factory<T, A...>, ...: A...): Result<T, unknown>
    local ok, result = pcall(factory, ...)
    return if ok
        then Result.ok(result)
        else Result.err(
            if result == nil then "error(nil) was called" else result
        )
end

--[=[
    Like [Result.try], but runs the function in extended protected mode with an
    error handler.

    This is recommended when you want to inspect the traceback of an error that
    occurs in `factory`, which is done by calling `debug.traceback()` in
    `onErr`.

    `onErr` is called with the thrown value before the stack unwinds, and its
    return value becomes the "err" value. If `onErr` returns `nil`, the error is
    replaced with a descriptive string, since an "err" cannot hold `nil`.

    Unlike [Result.try], a thrown `nil` is passed to `onErr` as-is, so `onErr`
    decides what it becomes.

    Note that `onErr` comes before the arguments to `factory`.

    ```lua
    -- `onErr` comes before the arguments to `factory`
    Result.tryTrace(loadData, function(err)
        return debug.traceback(tostring(err))
    end, "player123") -- Err(<the error with its traceback>) if `loadData` fails
    ```

    @since v0.1.0
    @param factory Factory<T, A...> -- The function to call in extended protected mode
    @param onErr Mapper<unknown, E?> -- The error handler to call if the function fails
    @param ... A... -- The arguments to pass to `factory`
    @return Result<T, E> -- The `Result` of running the function
]=]
function Result.tryTrace<T, E, A...>(
    factory: Factory<T, A...>,
    onErr: Mapper<unknown, E?>,
    ...: A...
): Result<T, E>
    local ok, result = xpcall(factory, onErr, ...)
    return if ok
        then Result.ok(result)
        else Result.err(
            if result == nil then "error handler returned nil" else result
        )
end

--[=[
    Like [Result.try], but packs all return values of `factory` into a table.

    Use `table.unpack(packed, 1, packed.n)` to get the values back.

    As with [Result.try], a thrown `nil` is replaced with a descriptive string.

    ```lua
    local packed = Result.tryPack(function()
        return 1, nil, 3
    end):unwrap()
    print(packed.n) -- 3
    print(table.unpack(packed, 1, packed.n)) -- 1 nil 3
    ```

    @since v0.1.0
    @param factory TupleFactory<...any, A...> -- The function to call in protected mode
    @param ... A... -- The arguments to pass to `factory`
    @return Result<PackedTable, unknown> -- The `Result` of running the function, holding the packed return values if "ok"
]=]
function Result.tryPack<A...>(
    factory: TupleFactory<...any, A...>,
    ...: A...
): Result<PackedTable, unknown>
    local results = table.pack(pcall(factory, ...))
    if results[1] then
        return Result.ok(table.pack(table.unpack(results, 2, results.n)))
    else
        local err = results[2]
        return Result.err(
                if err == nil then "error(nil) was called" else err
            ) :: Result<PackedTable, unknown>
    end
end

--[=[
    Like [Result:andThen], except this method returns an "err" `Result` if
    `mapper` throws, with the thrown value as the "err" value.

    As with [Result.try], a thrown `nil` is replaced with a descriptive string,
    and the error is typed as `unknown`, since it may be either the original
    error, an error returned by `mapper`, or a thrown value.

    ```lua
    Result.ok(2):tryAndThen(function(x)
        return Result.ok(x + 1)
    end) -- Ok(3)
    Result.ok(2):tryAndThen(function(x)
        error("boom", 0)
    end) -- Err("boom")
    ```

    @method tryAndThen
    @within Result
    @since v0.1.0
    @param mapper Mapper<T, Result<U, E>> -- The function to call if the `Result` is "ok"
    @return Result<U, unknown> -- The `Result` returned by `mapper`, the thrown error, or the original "err" `Result`
    @error "[Result.flatten()]: Called flatten on a Result that does not contain a Result" -- Thrown if `mapper` returns a non-`Result` value without throwing
]=]
function Result.tryAndThen<T, E, U>(
    self: Result<T, E>,
    mapper: Mapper<T, Result<U, E>>
): Result<U, unknown>
    return if self:isOk()
        then Result.try(mapper, self._value):flatten()
        else self
end

--[=[
    Wraps a function that may throw an error into one that returns a `Result`.

    The returned function passes its arguments to `factory` and behaves like
    [Result.try], so only the first return value is kept.

    ```lua
    local function parse(s: string): number
        return tonumber(s) or error(`not a number: {s}`, 0)
    end
    local tryParse = Result.wrap(parse)
    tryParse("5") -- Ok(5)
    tryParse("x") -- Err("not a number: x")
    ```

    @since v0.1.0
    @param factory Factory<T, A...> -- The function to wrap
    @return Factory<Result<T, unknown>, A...> -- The wrapped function
]=]
function Result.wrap<T, A...>(
    factory: Factory<T, A...>
): Factory<Result<T, unknown>, A...>
    return function(...: A...)
        return Result.try(factory, ...)
    end
end

--[=[
    Transposes a `Result` of an [Option] into an `Option` of a `Result`.

    An "ok" with a "none" is mapped to "none". An "ok" with a "some" is mapped
    to a "some" with the "ok". An "err" is mapped to a "some" with the "err".

    ```lua
    Result.ok(Option.some(1)):transpose() -- Some(Ok(1))
    Result.ok(Option.none()):transpose() -- None
    Result.err("e"):transpose() -- Some(Err("e"))
    ```

    @method transpose
    @within Result
    @since v0.1.0
    @return Option<Result<T, E>> -- The transposed `Option`
    @error "[Result.transpose()]: Called transpose on a Result that does not contain an Option" -- Thrown if the `Result` is "ok" and does not hold an `Option`
]=]
function Result.transpose<T, E>(self: Result<Option<T>, E>): Option<Result<T, E>>
    if self:isErr() then
        return Option.some(Result.err(self._error :: E))
    end
    local inner = self._value
    if not Option.is(inner) then
        fail("Called transpose on a Result that does not contain an Option")
    end
    return if inner:isSome()
        then Option.some(Result.ok(inner:unwrap()))
        else Option.none() :: Option<Result<T, E>>
end

--[=[
    Transposes an [Option] of a `Result` into a `Result` of an [Option].

    A "some" with an "ok" is mapped to an "ok" with the "some". A "some" with
    an "err" is mapped to an "err". A "none" is mapped to an "ok" with a
    "none".

    ```lua
    Result.transposeOption(Option.some(Result.ok(1))) -- Ok(Some(1))
    Result.transposeOption(Option.some(Result.err("e"))) -- Err("e")
    Result.transposeOption(Option.none()) -- Ok(None)
    ```

    @since v0.1.0
    @param option Option<Result<T, E>> -- The `Option` to transpose
    @return Result<Option<T>, E> -- The transposed `Result`
    @error "[Result.transposeOption()]: Called transposeOption on an Option that does not contain a Result" -- Thrown if the `Option` is "some" and does not hold a `Result`
]=]
function Result.transposeOption<T, E>(
    option: Option<Result<T, E>>
): Result<Option<T>, E>
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

--[=[
    Converts from `Result<Result<T, E>, E>` to `Result<T, E>`.

    Only one level of nesting is removed.

    ```lua
    Result.ok(Result.ok(1)):flatten() -- Ok(1)
    Result.ok(Result.err("e")):flatten() -- Err("e")
    Result.err("e"):flatten() -- Err("e")
    ```

    @method flatten
    @within Result
    @since v0.1.0
    @return Result<T, E> -- The flattened `Result`
    @error "[Result.flatten()]: Called flatten on a Result that does not contain a Result" -- Thrown if the `Result` is "ok" and does not hold a `Result`
]=]
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

--[=[
    Converts a `Map<K, Result<T, E>>` to a `Result<Map<K, T>, E>`.

    Returns "ok" if all values in the table are "ok", otherwise returns the
    first "err" found. Iteration order is only guaranteed for arrays, so with
    other tables, which "err" is returned may vary.

    "ok" values of `nil` are omitted, since tables cannot hold `nil`. Keys are
    preserved, so array input containing them produces arrays with gaps.

    ```lua
    Result.all({ Result.ok(1), Result.ok(2) }) -- Ok({ 1, 2 })
    Result.all({ Result.ok(1), Result.err("a"), Result.err("b") }) -- Err("a")
    ```

    @since v0.1.0
    @param results Map<K, Result<T, E>> -- The table of `Result`s
    @return Result<Map<K, T>, E> -- The converted `Result`
    @error "[Result.all()]: Called all on a table containing a non-Result value" -- Thrown if a non-`Result` value is found before any "err"
]=]
function Result.all<T, E, K>(results: Map<K, Result<T, E>>): Result<Map<K, T>, E>
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

--[=[
    Splits a table of `Result`s into two tables: one of unwrapped "ok" values,
    and the other of unwrapped "err" values.

    Unlike [Result.all], this never short-circuits and always returns both
    tables fully.

    "ok" values of `nil` are omitted, since tables cannot hold `nil`. Keys are
    preserved, so an array that mixes "ok" and "err" values produces arrays with
    gaps.

    ```lua
    local oks, errs = Result.partition({
        Result.ok(1),
        Result.err("a"),
        Result.ok(3),
    })
    -- oks is { [1] = 1, [3] = 3 }, and errs is { [2] = "a" }
    ```

    @since v0.1.0
    @param results Map<K, Result<T, E>> -- The table of `Result`s
    @return Map<K, T> -- The unwrapped "ok" values
    @return Map<K, E> -- The unwrapped "err" values
    @error "[Result.partition()]: Called partition on a table containing a non-Result value" -- Thrown if any value is not a `Result`
]=]
function Result.partition<T, E, K>(results: Map<K, Result<T, E>>): (Map<K, T>, Map<K, E>)
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

--[=[
    Returns whether the given value is a `Result`.

    @since v0.1.0
    @param value any -- The value to check
    @return boolean -- Whether the value is a `Result`
]=]
function Result.is(value: any): boolean
    return getmetatable(value) == Result
end

--[=[
    Returns `true` if both `self` and `other` are "ok" and their wrapped values
    are equal, returns `true` if both are "err" and their wrapped errors are
    equal, and returns `false` otherwise.

    Wrapped values are compared with `==`. Returns `false` if `other` is not a
    `Result`.

    Also used for the `==` and `~=` operators.

    ```lua
    Result.ok(1) == Result.ok(1) -- true
    Result.ok(1) == Result.err(1) -- false
    Result.ok({}) == Result.ok({}) -- false, since the tables are different
    ```

    @method equals
    @within Result
    @since v0.1.0
    @param other Result<T, E> -- The `Result` to compare with the current `Result`
    @return boolean -- Whether the two `Result`s are equal
]=]
function Result.equals<T, E>(self: Result<T, E>, other: Result<T, E>): boolean
    return Result.is(other)
        and self._value == other._value
        and self._error == other._error
end
Result.__eq = Result.equals

--[=[
    Returns a string representation of the `Result`, in the form `Ok(value)` or
    `Err(error)`.

    Also used by `tostring()`.

    ```lua
    tostring(Result.ok("hi")) -- 'Ok("hi")'
    tostring(Result.ok(nil)) -- "Ok(nil)"
    tostring(Result.err("bad")) -- 'Err("bad")'
    ```

    @method toString
    @within Result
    @since v0.1.0
    @return string -- A string representation of the `Result`
]=]
function Result.toString<T, E>(self: Result<T, E>): string
    return if self:isOk()
        then `Ok({repr(self._value)})`
        else `Err({repr(self._error)})`
end
Result.__tostring = Result.toString

return table.freeze(Result)
