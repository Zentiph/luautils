--!strict

-- core types
-- by @vuppyan

--[[ Function shapes ]]

--- A function that runs with no arguments or return value.
export type Action = () -> ()
--- A function that takes any arguments and returns nothing.
export type Callback<A...> = (A...) -> ()

--- A function that takes no arguments and returns a value.
export type Supplier<T> = () -> T
--- A function that builds a value from arguments.
export type Factory<T, A...> = (A...) -> T
--- A function that builds a tuple from arguments.
export type TupleFactory<T..., A...> = (A...) -> T...

--- A function that takes one value and returns nothing.
export type Consumer<T> = (value: T) -> ()
--- A function that takes two values and returns nothing.
export type BiConsumer<T, U> = (a: T, b: U) -> ()

--- A function that tests one value.
export type Predicate<T> = (value: T) -> boolean
--- A function that tests two values.
export type BiPredicate<T, U> = (a: T, b: U) -> boolean

--- A function that transforms one value.
export type Mapper<T, U> = (value: T) -> U
--- A function that combines two values.
export type BiMapper<T, U, R> = (a: T, b: U) -> R

--- A function that transforms a value into the same type.
export type UnaryOperator<T> = (value: T) -> T
--- A function that combines two values of the same type.
export type BinaryOperator<T> = (a: T, b: T) -> T

--- A function that folds a value into an accumulator.
export type Reducer<T, A> = (accumulator: A, value: T) -> A

--- A function that orders two values.
---
--- Returns a negative `number` if `a < b`, zero if `a == b`, and a positive
--- `number` if `a > b`.
export type Comparator<T> = (a: T, b: T) -> number

--[[ Containers ]]

--- A sequential, 1-indexed table.
export type Array<T> = { T }
--- A keyed table.
export type Map<K, V> = { [K]: V }
--- A membership table.
export type Set<T> = { [T]: true }
--- The result of `table.pack`.
export type PackedTable = { n: number, [number]: any }

--[[ Iteration ]]

--- A stateful iterator that can be called until it returns `nil`.
---
--- Usable as `for v in gen do`.
export type Generator<T> = () -> T?
--- A step function of a generic-for iterator triple `(fn, state, control)`.
---
--- Iteration stops when the returned control value is `nil`.
export type Iterator<S, C, V...> = (state: S, control: C?) -> (C?, V...)

--[[ protocols/"traits" ]]

--- A type that supports value equality.
export type Equatable<Self> = { equals: (self: Self, other: Self) -> boolean }

--- A type that supports total ordering.
---
--- Its ordering function should return a negative `number` if `a < b`, zero if
--- `a == b`, and a positive `number` if `a > b`.
export type Comparable<Self> =
    { compareTo: (self: Self, other: Self) -> number }

--- A type that can be converted to a string.
export type Stringable<Self> = { toString: (self: Self) -> string }

--- A type that can produce a stable key, allowing for value-equal objects
--- to share a table slot.
export type Keyable<Self> = { toKey: (self: Self) -> string }

--- A type that can make an independent copy of itself.
export type Cloneable<Self> = { clone: (self: Self) -> Self }

--- A type that can convert itself to plain, DataStore-safe data.
export type Serializable<Self, D> = { serialize: (self: Self) -> D }
--- A type that can be statically converted from plain, DataStore-safe data.
export type Deserializable<Self, D> = { deserialize: (data: D) -> Self }

--- A type that can be iterated with a `for ... in obj:iter()` loop.
export type Iterable<Self, C, V...> = {
    iter: (self: Self) -> (Iterator<Self, C, V...>, Self, C?),
}

--[[ Roblox-compatible protocols ]]

--- A type that can be disconnected (like `RBXScriptConnection`).
export type Disconnectable = { Disconnect: (self: any) -> () }

--- A type that can be destroyed (like `Instance`s).
export type Destroyable = { Destroy: (self: any) -> () }

return nil
