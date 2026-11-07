--!strict

-- Core exports
-- by @vuppyan

local Option = require("@self/Option")
export type Option<T> = Option.Option<T>

local Result = require("@self/Result")
export type Result<T, E> = Result.Result<T, E>

local typing = require("@self/typing")
export type Action = typing.Action
export type Callback<A...> = typing.Callback<A...>
export type Supplier<T> = typing.Supplier<T>
export type Factory<T, A...> = typing.Factory<T, A...>
export type TupleFactory<T..., A...> = typing.TupleFactory<T..., A...>
export type Consumer<T> = typing.Consumer<T>
export type BiConsumer<T, U> = typing.BiConsumer<T, U>
export type Predicate<T> = typing.Predicate<T>
export type BiPredicate<T, U> = typing.BiPredicate<T, U>
export type Mapper<T, U> = typing.Mapper<T, U>
export type BiMapper<T, U, R> = typing.BiMapper<T, U, R>
export type UnaryOperator<T> = typing.UnaryOperator<T>
export type BinaryOperator<T> = typing.BinaryOperator<T>
export type Reducer<T, A> = typing.Reducer<T, A>
export type Comparator<T> = typing.Comparator<T>
export type Array<T> = typing.Array<T>
export type Map<K, V> = typing.Map<K, V>
export type Set<T> = typing.Set<T>
export type PackedTable = typing.PackedTable
export type Generator<T> = typing.Generator<T>
export type Iterator<S, C, V...> = typing.Iterator<S, C, V...>
export type Equatable<Self> = typing.Equatable<Self>
export type Comparable<Self> = typing.Comparable<Self>
export type Stringable<Self> = typing.Stringable<Self>
export type Keyable<Self> = typing.Keyable<Self>
export type Cloneable<Self> = typing.Cloneable<Self>
export type Serializable<Self, D> = typing.Serializable<Self, D>
export type Deserializable<Self, D> = typing.Deserializable<Self, D>
export type Iterable<Self, C, V...> = typing.Iterable<Self, C, V...>
export type Disconnectable = typing.Disconnectable
export type Destroyable = typing.Destroyable

--[=[
    The foundation of the library: `Option` and `Result` for explicit absence
    and failure, error handling utilities, and shared type aliases.

    @class Core
    @since v0.1.0
]=]
return table.freeze({
    Errors = require("@self/Errors"),
    Option = Option,
    Result = Result,
    Values = require("@self/Values"),
})
