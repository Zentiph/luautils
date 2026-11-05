--!strict

-- core types
-- by @vuppyan

--- Shared type aliases for function shapes, containers, iteration, and
--- protocols.
---
--- This module has no runtime value. Every type is re-exported by `Core`, so
--- use them as `Core.Supplier<T>`, `Core.Map<K, V>`, and so on.
---
--- @class typing

--[[ Function shapes ]]

--- A function that runs with no arguments or return value.
---
--- @type Action () -> ()
--- @within typing
export type Action = () -> ()

--- A function that takes any arguments and returns nothing.
---
--- @type Callback (A...) -> ()
--- @within typing
export type Callback<A...> = (A...) -> ()

--- A function that takes no arguments and returns a value.
---
--- @type Supplier () -> T
--- @within typing
export type Supplier<T> = () -> T

--- A function that builds a value from arguments.
---
--- @type Factory (A...) -> T
--- @within typing
export type Factory<T, A...> = (A...) -> T

--- A function that builds a tuple from arguments.
---
--- @type TupleFactory (A...) -> T...
--- @within typing
export type TupleFactory<T..., A...> = (A...) -> T...

--- A function that takes one value and returns nothing.
---
--- @type Consumer (value: T) -> ()
--- @within typing
export type Consumer<T> = (value: T) -> ()

--- A function that takes two values and returns nothing.
---
--- @type BiConsumer (a: T, b: U) -> ()
--- @within typing
export type BiConsumer<T, U> = (a: T, b: U) -> ()

--- A function that tests one value.
---
--- @type Predicate (value: T) -> boolean
--- @within typing
export type Predicate<T> = (value: T) -> boolean

--- A function that tests two values.
---
--- @type BiPredicate (a: T, b: U) -> boolean
--- @within typing
export type BiPredicate<T, U> = (a: T, b: U) -> boolean

--- A function that transforms one value.
---
--- @type Mapper (value: T) -> U
--- @within typing
export type Mapper<T, U> = (value: T) -> U

--- A function that combines two values.
---
--- @type BiMapper (a: T, b: U) -> R
--- @within typing
export type BiMapper<T, U, R> = (a: T, b: U) -> R

--- A function that transforms a value into the same type.
---
--- @type UnaryOperator (value: T) -> T
--- @within typing
export type UnaryOperator<T> = (value: T) -> T

--- A function that combines two values of the same type.
---
--- @type BinaryOperator (a: T, b: T) -> T
--- @within typing
export type BinaryOperator<T> = (a: T, b: T) -> T

--- A function that folds a value into an accumulator.
---
--- @type Reducer (accumulator: A, value: T) -> A
--- @within typing
export type Reducer<T, A> = (accumulator: A, value: T) -> A

--- A function that orders two values.
---
--- Returns a negative `number` if `a < b`, zero if `a == b`, and a positive
--- `number` if `a > b`.
---
--- @type Comparator (a: T, b: T) -> number
--- @within typing
export type Comparator<T> = (a: T, b: T) -> number

--[[ Containers ]]

--- A sequential, 1-indexed table.
---
--- @type Array { T }
--- @within typing
export type Array<T> = { T }

--- A keyed table.
---
--- @type Map { [K]: V }
--- @within typing
export type Map<K, V> = { [K]: V }

--- A membership table.
---
--- @type Set { [T]: true }
--- @within typing
export type Set<T> = { [T]: true }

--- The result of `table.pack`.
---
--- @type PackedTable { n: number, [number]: any }
--- @within typing
export type PackedTable = { n: number, [number]: any }

--[[ Iteration ]]

--- A stateful iterator that can be called until it returns `nil`.
---
--- Usable as `for v in gen do`.
---
--- @type Generator () -> T?
--- @within typing
export type Generator<T> = () -> T?

--- A step function of a generic-for iterator triple `(fn, state, control)`.
---
--- Iteration stops when the returned control value is `nil`.
---
--- @type Iterator (state: S, control: C?) -> (C?, V...)
--- @within typing
export type Iterator<S, C, V...> = (state: S, control: C?) -> (C?, V...)

--[[ Protocols/"traits" ]]

--- A type that supports value equality.
---
--- @type Equatable { equals: (self: Self, other: Self) -> boolean }
--- @within typing
export type Equatable<Self> = { equals: (self: Self, other: Self) -> boolean }

--- A type that supports total ordering.
---
--- Its ordering function should return a negative `number` if `a < b`, zero if
--- `a == b`, and a positive `number` if `a > b`.
---
--- @type Comparable { compareTo: (self: Self, other: Self) -> number }
--- @within typing
export type Comparable<Self> =
    { compareTo: (self: Self, other: Self) -> number }

--- A type that can be converted to a string.
---
--- @type Stringable { toString: (self: Self) -> string }
--- @within typing
export type Stringable<Self> = { toString: (self: Self) -> string }

--- A type that can produce a stable key, allowing for value-equal objects
--- to share a table slot.
---
--- @type Keyable { toKey: (self: Self) -> string }
--- @within typing
export type Keyable<Self> = { toKey: (self: Self) -> string }

--- A type that can make an independent copy of itself.
---
--- @type Cloneable { clone: (self: Self) -> Self }
--- @within typing
export type Cloneable<Self> = { clone: (self: Self) -> Self }

--- A type that can convert itself to plain, DataStore-safe data.
---
--- @type Serializable { serialize: (self: Self) -> D }
--- @within typing
export type Serializable<Self, D> = { serialize: (self: Self) -> D }

--- A type that can be statically converted from plain, DataStore-safe data.
---
--- @type Deserializable { deserialize: (data: D) -> Self }
--- @within typing
export type Deserializable<Self, D> = { deserialize: (data: D) -> Self }

--- A type that can be iterated with a `for ... in obj:iter()` loop.
---
--- @type Iterable { iter: (self: Self) -> (Iterator<Self, C, V...>, Self, C?) }
--- @within typing
export type Iterable<Self, C, V...> = {
    iter: (self: Self) -> (Iterator<Self, C, V...>, Self, C?),
}

--[[ ROBLOX-compatible protocols ]]

--- A type that can be disconnected (like `RBXScriptConnection`).
---
--- @type Disconnectable { Disconnect: (self: any) -> () }
--- @within typing
export type Disconnectable = { Disconnect: (self: any) -> () }

--- A type that can be destroyed (like `Instance`s).
---
--- @type Destroyable { Destroy: (self: any) -> () }
--- @within typing
export type Destroyable = { Destroy: (self: any) -> () }

return nil
