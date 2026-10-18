--!strict

-- Core exports
-- by @vuppyan

local Option = require("@self/Option")
local Result = require("@self/Result")
local types = require("@self/types")

-- re-export the types here so users can grab them easier
export type Action = types.Action
export type Predicate<T> = types.Predicate<T>
export type Supplier<T> = types.Supplier<T>
export type Consumer<T> = types.Consumer<T>
export type Mapper<T, U> = types.Mapper<T, U>
export type Zipper<T, U, R> = types.Zipper<T, U, R>
export type Iterator<T> = types.Iterator<T>
export type Iterable<T> = types.Iterable<T>

-- same with the modules themselves
export type Option<T> = Option.Option<T>
export type Result<T, E> = Result.Result<T, E>

return {
    Option = Option,
    Result = Result,
}
