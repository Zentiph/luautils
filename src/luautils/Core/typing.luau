--!strict

-- core types
-- by @vuppyan

--[=[
    Shared type aliases for function shapes, containers, iteration, and
    protocols.

    This module has no runtime value. Every type is re-exported by `Core` and
    `Luautils`, so use them as `Luautils.Supplier<T>` or `Core.Map<K, V>`, etc.

    @class typing
    @since v0.1.0
]=]

--[[ Function shapes ]]

--[=[
    A function that runs with no arguments or return value.

    @type Action () -> ()
    @within typing
    @since v0.1.0
]=]
export type Action = () -> ()

--[=[
    A function that takes any arguments and returns nothing.

    @type Callback (A...) -> ()
    @within typing
    @since v0.1.0
]=]
export type Callback<A...> = (A...) -> ()

--[=[
    A function that takes no arguments and returns a value.

    @type Supplier () -> T
    @within typing
    @since v0.1.0
]=]
export type Supplier<T> = () -> T

--[=[
    A function that builds a value from arguments.

    @type Factory (A...) -> T
    @within typing
    @since v0.1.0
]=]
export type Factory<T, A...> = (A...) -> T

--[=[
    A function that builds a tuple from arguments.

    @type TupleFactory (A...) -> T...
    @within typing
    @since v0.1.0
]=]
export type TupleFactory<T..., A...> = (A...) -> T...

--[=[
    A function that takes one value and returns nothing.

    @type Consumer (value: T) -> ()
    @within typing
    @since v0.1.0
]=]
export type Consumer<T> = (value: T) -> ()

--[=[
    A function that takes two values and returns nothing.

    @type BiConsumer (a: T, b: U) -> ()
    @within typing
    @since v0.1.0
]=]
export type BiConsumer<T, U> = (a: T, b: U) -> ()

--[=[
    A function that tests one value.

    @type Predicate (value: T) -> boolean
    @within typing
    @since v0.1.0
]=]
export type Predicate<T> = (value: T) -> boolean

--[=[
    A function that tests two values.

    @type BiPredicate (a: T, b: U) -> boolean
    @within typing
    @since v0.1.0
]=]
export type BiPredicate<T, U> = (a: T, b: U) -> boolean

--[=[
    A function that transforms one value.

    @type Mapper (value: T) -> U
    @within typing
    @since v0.1.0
]=]
export type Mapper<T, U> = (value: T) -> U

--[=[
    A function that combines two values.

    @type BiMapper (a: T, b: U) -> R
    @within typing
    @since v0.1.0
]=]
export type BiMapper<T, U, R> = (a: T, b: U) -> R

--[=[
    A function that transforms a value into the same type.

    @type UnaryOperator (value: T) -> T
    @within typing
    @since v0.1.0
]=]
export type UnaryOperator<T> = (value: T) -> T

--[=[
    A function that combines two values of the same type.

    @type BinaryOperator (a: T, b: T) -> T
    @within typing
    @since v0.1.0
]=]
export type BinaryOperator<T> = (a: T, b: T) -> T

--[=[
    A function that folds a value into an accumulator.

    @type Reducer (accumulator: A, value: T) -> A
    @within typing
    @since v0.1.0
]=]
export type Reducer<T, A> = (accumulator: A, value: T) -> A

--[=[
    A function that orders two values.

    Returns a negative `number` if `a < b`, zero if `a == b`, and a positive
    `number` if `a > b`.

    @type Comparator (a: T, b: T) -> number
    @within typing
    @since v0.1.0
]=]
export type Comparator<T> = (a: T, b: T) -> number

--[[ Containers ]]

--[=[
    A sequential, 1-indexed table.

    @type Array { T }
    @within typing
    @since v0.1.0
]=]
export type Array<T> = { T }

--[=[
    A keyed table.

    @type Map { [K]: V }
    @within typing
    @since v0.1.0
]=]
export type Map<K, V> = { [K]: V }

--[=[
    A membership table.

    @type Set { [T]: true }
    @within typing
    @since v0.1.0
]=]
export type Set<T> = { [T]: true }

--[=[
    The result of `table.pack`.

    @type PackedTable { n: number, [number]: any }
    @within typing
    @since v0.1.0
]=]
export type PackedTable = { n: number, [number]: any }

--[[ Iteration ]]

--[=[
    A stateful iterator that can be called until it returns `nil`.

    Usable as `for v in gen do`.

    @type Generator () -> T?
    @within typing
    @since v0.1.0
]=]
export type Generator<T> = () -> T?

--[=[
    A step function of a generic-for iterator triple `(fn, state, control)`.

    Iteration stops when the returned control value is `nil`.

    @type Iterator (state: S, control: C?) -> (C?, V...)
    @within typing
    @since v0.1.0
]=]
export type Iterator<S, C, V...> = (state: S, control: C?) -> (C?, V...)

--[[ Protocols/"traits" ]]

--[=[
    A type that supports value equality.

    @type Equatable { equals: (self: Self, other: Self) -> boolean }
    @within typing
    @since v0.1.0
]=]
export type Equatable<Self> = { equals: (self: Self, other: Self) -> boolean }

--[=[
    A type that supports total ordering.

    Its ordering function should return a negative `number` if `a < b`, zero if
    `a == b`, and a positive `number` if `a > b`.

    @type Comparable { compareTo: (self: Self, other: Self) -> number }
    @within typing
    @since v0.1.0
]=]
export type Comparable<Self> =
    { compareTo: (self: Self, other: Self) -> number }

--[=[
    A type that can be converted to a string.

    @type Stringable { toString: (self: Self) -> string }
    @within typing
    @since v0.1.0
]=]
export type Stringable<Self> = { toString: (self: Self) -> string }

--[=[
    A type that can produce a stable key, allowing for value-equal objects
    to share a table slot.

    @type Keyable { toKey: (self: Self) -> string }
    @within typing
    @since v0.1.0
]=]
export type Keyable<Self> = { toKey: (self: Self) -> string }

--[=[
    A type that can make an independent copy of itself.

    @type Cloneable { clone: (self: Self) -> Self }
    @within typing
    @since v0.1.0
]=]
export type Cloneable<Self> = { clone: (self: Self) -> Self }

--[=[
    A type that can convert itself to plain, DataStore-safe data.

    @type Serializable { serialize: (self: Self) -> D }
    @within typing
    @since v0.1.0
]=]
export type Serializable<Self, D> = { serialize: (self: Self) -> D }

--[=[
    A type that can be statically converted from plain, DataStore-safe data.

    @type Deserializable { deserialize: (data: D) -> Self }
    @within typing
    @since v0.1.0
]=]
export type Deserializable<Self, D> = { deserialize: (data: D) -> Self }

--[=[
    A type that can be iterated with a `for ... in obj:iter()` loop.

    @type Iterable { iter: (self: Self) -> (Iterator<Self, C, V...>, Self, C?) }
    @within typing
    @since v0.1.0
]=]
export type Iterable<Self, C, V...> = {
    iter: (self: Self) -> (Iterator<Self, C, V...>, Self, C?),
}

-- [[ Typing helpers ]]

--[=[
    A type that makes all of the properties of the wrapped type optional.

    ```lua
    type Data = { -- full data schema
        name: string,
        age: number,
    }
    local function getDataFor(name: string): Nillable<Data> -- each prop may be nil
    ```

    @type Nillable (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Nillable(t: type): type
    assert(t:is("table"), "Nillable expects a table type")
    local result = types.newtable()

    -- make all named properties optional
    for key, prop in t:properties() do
        if prop.read then
            result:setreadproperty(key, types.optional(prop.read))
        end
        if prop.write then
            result:setwriteproperty(key, types.optional(prop.write))
        end
    end

    -- copy indexer unchanged
    local idx = t:indexer()
    if idx then
        if idx.readresult then
            result:setreadindexer(idx.index, idx.readresult)
        end
        if idx.writeresult then
            result:setwriteindexer(idx.index, idx.writeresult)
        end
    end

    -- copy metatable unchanged
    local mt = t:metatable()
    if mt then
        result:setmetatable(mt)
    end

    return result
end

--[=[
    A type that makes all of the properties of the wrapped type required.

    `unknown` and `any` remain unchanged.
    A property typed exactly as `nil` becomes `never`.

    ```lua
    type Data = { -- data schema with optional props
        name: string?,
        age: number?,
    }
    local function fillData(data: Data): Required<Data> -- each prop is required
    ```

    @type Required (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Required(t: type): type
    assert(t:is("table"), "Required expects a table type")

    local function stripNil(ty: type): type
        if not ty:is("union") then
            return ty
        end

        local kept = {}
        for _, component in ty:components() do
            if not component:is("nil") then
                table.insert(kept, component)
            end
        end

        if #kept == 0 then
            return types.never -- the type was just `nil`
        elseif #kept == 1 then
            return kept[1] -- no need to keep the union
        else
            return types.unionof(table.unpack(kept))
        end
    end

    -- make all named properties required
    local result = types.newtable()
    for key, prop in t:properties() do
        if prop.read then
            result:setreadproperty(key, stripNil(prop.read))
        end
        if prop.write then
            result:setwriteproperty(key, stripNil(prop.write))
        end
    end

    -- copy indexer unchanged
    local idx = t:indexer()
    if idx then
        if idx.readresult then
            result:setreadindexer(idx.index, idx.readresult)
        end
        if idx.writeresult then
            result:setwriteindexer(idx.index, idx.writeresult)
        end
    end

    -- copy metatable unchanged
    local mt = t:metatable()
    if mt then
        result:setmetatable(mt)
    end

    return result
end

--[[ ROBLOX-compatible protocols ]]

--[=[
    A type that can be disconnected (like `RBXScriptConnection`).

    @type Disconnectable { Disconnect: (self: any) -> () }
    @within typing
    @since v0.1.0
]=]
export type Disconnectable = { Disconnect: (self: any) -> () }

--[=[
    A type that can be destroyed (like `Instance`s).

    @type Destroyable { Destroy: (self: any) -> () }
    @within typing
    @since v0.1.0
]=]
export type Destroyable = { Destroy: (self: any) -> () }

return nil
