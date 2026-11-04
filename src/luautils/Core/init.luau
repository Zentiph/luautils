--!strict

-- Core exports
-- by @vuppyan

local Option = require("@self/Option")
local Result = require("@self/Result")
local types = require("@self/types")

-- re-export the types here so users can grab them easier
export type Action = types.Action
export type Callback<A...> = types.Callback<A...>
export type Supplier<T> = types.Supplier<T>
export type Factory<T, A...> = types.Factory<T, A...>
export type TupleFactory<T..., A...> = types.TupleFactory<T..., A...>
export type Consumer<T> = types.Consumer<T>
export type BiConsumer<T, U> = types.BiConsumer<T, U>
export type Predicate<T> = types.Predicate<T>
export type BiPredicate<T, U> = types.BiPredicate<T, U>
export type Mapper<T, U> = types.Mapper<T, U>
export type BiMapper<T, U, R> = types.BiMapper<T, U, R>
export type UnaryOperator<T> = types.UnaryOperator<T>
export type BinaryOperator<T> = types.BinaryOperator<T>
export type Reducer<T, A> = types.Reducer<T, A>
export type Comparator<T> = types.Comparator<T>

export type Array<T> = types.Array<T>
export type Map<K, V> = types.Map<K, V>
export type Set<T> = types.Set<T>
export type PackedTable = types.PackedTable

export type Generator<T> = types.Generator<T>
export type Iterator<S, C, V...> = types.Iterator<S, C, V...>

export type Equatable<Self> = types.Equatable<Self>
export type Comparable<Self> = types.Comparable<Self>
export type Stringable<Self> = types.Stringable<Self>
export type Keyable<Self> = types.Keyable<Self>
export type Cloneable<Self> = types.Cloneable<Self>
export type Serializable<Self, D> = types.Serializable<Self, D>
export type Deserializable<Self, D> = types.Deserializable<Self, D>
export type Iterable<Self, C, V...> = types.Iterable<Self, C, V...>

export type Disconnectable = types.Disconnectable
export type Destroyable = types.Destroyable

-- same with the module types themselves
export type Option<T> = Option.Option<T>
export type Result<T, E> = Result.Result<T, E>

return {
    Option = Option,
    Result = Result,
}
