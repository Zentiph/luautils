--!strict

-- Core exports
-- by @vuppyan

local types = require("@self/types")

-- re-export the types here so users can grab them easier
export type Predicate<T> = types.Predicate<T>
export type Supplier<T> = types.Supplier<T>
export type Consumer<T> = types.Consumer<T>
export type Mapper<T, U> = types.Mapper<T, U>
export type Zipper<T, U, R> = types.Zipper<T, U, R>

return {
    Option = require("@self/Option"),
    Result = require("@self/Result"),
}
