--!strict

-- Luautils central imports
-- by @vuppyan

--- Luautils: A Luau utilities library
---
--- Luautils strives to act as an extension of Luau's standard library.
---
--- @class Luautils
local Luautils = {}

--- The version of luautils, following semantic versioning.
---
--- @prop VERSION string
--- @within Luautils
Luautils.VERSION = "0.1.0"

local Core = require("@self/Core")
Luautils.Core = Core
export type Option<T> = Core.Option<T>
export type Result<T, E> = Core.Result<T, E>
export type Action = Core.Action
export type Callback<A...> = Core.Callback<A...>
export type Supplier<T> = Core.Supplier<T>
export type Factory<T, A...> = Core.Factory<T, A...>
export type TupleFactory<T..., A...> = Core.TupleFactory<T..., A...>
export type Consumer<T> = Core.Consumer<T>
export type BiConsumer<T, U> = Core.BiConsumer<T, U>
export type Predicate<T> = Core.Predicate<T>
export type BiPredicate<T, U> = Core.BiPredicate<T, U>
export type Mapper<T, U> = Core.Mapper<T, U>
export type BiMapper<T, U, R> = Core.BiMapper<T, U, R>
export type UnaryOperator<T> = Core.UnaryOperator<T>
export type BinaryOperator<T> = Core.BinaryOperator<T>
export type Reducer<T, A> = Core.Reducer<T, A>
export type Comparator<T> = Core.Comparator<T>
export type Array<T> = Core.Array<T>
export type Map<K, V> = Core.Map<K, V>
export type Set<T> = Core.Set<T>
export type PackedTable = Core.PackedTable
export type Generator<T> = Core.Generator<T>
export type Iterator<S, C, V...> = Core.Iterator<S, C, V...>
export type Equatable<Self> = Core.Equatable<Self>
export type Comparable<Self> = Core.Comparable<Self>
export type Stringable<Self> = Core.Stringable<Self>
export type Keyable<Self> = Core.Keyable<Self>
export type Cloneable<Self> = Core.Cloneable<Self>
export type Serializable<Self, D> = Core.Serializable<Self, D>
export type Deserializable<Self, D> = Core.Deserializable<Self, D>
export type Iterable<Self, C, V...> = Core.Iterable<Self, C, V...>
export type Disconnectable = Core.Disconnectable
export type Destroyable = Core.Destroyable

local Collections = require("@self/Collections")
Luautils.Collections = Collections

local Math = require("@self/Math")
Luautils.Math = Math

local Strings = require("@self/Strings")
Luautils.Strings = Strings

local Tables = require("@self/Tables")
Luautils.Tables = Tables

local Time = require("@self/Time")
Luautils.Time = Time
export type Duration = Time.Duration

local Validation = require("@self/Validation")
Luautils.Validation = Validation

local Async = require("@self/Async")
Luautils.Async = Async

local Events = require("@self/Events")
Luautils.Events = Events

local Roblox = require("@self/Roblox")
Luautils.Roblox = Roblox

return table.freeze(Luautils)
