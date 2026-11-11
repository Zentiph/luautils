--!strict

-- core types
-- by @vuppyan

--[=[
    Shared type aliases for function shapes, containers, iteration, and
    protocols.

    This module has no runtime value. Every type is re-exported by `Core` and
    `Luautils`, so use them as `Luautils.Supplier<T>` or `Core.Map<K, V>`, etc.

    The typing helpers ([typing.Partial], [typing.Required], and
    [typing.ReadOnly]) are type functions, which need Luau's new type solver.

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

--[[ Typing helpers ]]

--[=[
    A type function that makes every property of a table type optional.

    `read` and `write` modifiers are kept, and the indexer and metatable are
    copied unchanged.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type Profile = { name: string, read level: number }

    type ProfilePatch = Partial<Profile>
    -- { name: string?, read level: number? }

    local function applyPatch(profile: Profile, patch: ProfilePatch)
        profile.name = patch.name or profile.name
    end
    ```

    @type Partial (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Partial(t: type): type
    assert(t:is("table"), "Partial expects a table type")

    -- make all named properties optional
    local result = types.newtable()
    for key, prop in t:properties() do
        if prop.read then
            result:setreadproperty(key, types.optional(prop.read))
        end
        if prop.write then
            result:setwriteproperty(key, types.optional(prop.write))
        end
    end

    -- copy indexer unchanged
    -- (luau doesn't support separate read/write indexer types yet, so
    -- setreadindexer/setwriteindexer throw)
    local idx = t:indexer()
    if idx and idx.readresult then
        result:setindexer(idx.index, idx.readresult)
    end

    -- copy metatable unchanged
    local mt = t:metatable()
    if mt then
        result:setmetatable(mt)
    end

    return result
end

--[=[
    A type function that makes every property of a table type optional,
    recursively.

    Every named property becomes optional, and nested table types (including
    tables inside unions and intersections) are made deeply partial as well.
    Indexer values are recursed into but not made optional, so `{ T }` stays
    an array of non-nil values while each `T` becomes deeply partial.

    `read` and `write` modifiers are kept, and the indexer and metatable are
    copied unchanged.
    Recursive types are supported.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type Settings = {
        audio: { volume: number, muted: boolean },
        ui: { scale: number }
    }

    type SettingsOverrides = DeepPartial<Settings>
    -- { audio: { volume: number?, muted: boolean? }, ui: { scale: number? } }

    local function configure(overrides: SettingsOverrides)
        -- ...
    end

    configure({ audio = { volume = 0.2 } }) -- everything else falls back
    ```

    @type DeepPartial (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function DeepPartial(t: type): type
    assert(t:is("table"), "DeepPartial expects a table type")

    -- tables already being converted, so recursive types terminate
    local seen: { { from: type, to: type } } = {}

    local function deep(ty: type): type
        if ty:is("table") then
            for _, entry in seen do
                if entry.from == ty then
                    return entry.to
                end
            end

            local result = types.newtable()
            -- register before recursing so cycles point back at result
            table.insert(seen, { from = ty, to = result })

            -- make all named properties optional, recursively
            for key, prop in ty:properties() do
                if prop.read then
                    result:setreadproperty(key, types.optional(deep(prop.read)))
                end
                if prop.write then
                    result:setwriteproperty(
                        key,
                        types.optional(deep(prop.write))
                    )
                end
            end

            -- recurse into the indexer's values without making them optional
            -- (luau doesn't support separate read/write indexer types yet,
            --  so setreadindexer/setwriteindexer throw)
            local idx = ty:indexer()
            if idx and idx.readresult then
                result:setindexer(idx.index, deep(idx.readresult))
            end

            -- copy metatable unchanged
            local mt = ty:metatable()
            if mt then
                result:setmetatable(mt)
            end

            return result
        elseif ty:is("union") or ty:is("intersection") then
            local parts = {}
            for _, component in ty:components() do
                table.insert(parts, deep(component))
            end
            return if ty:is("union")
                then types.unionof(table.unpack(parts))
                else types.intersectionof(table.unpack(parts))
        else
            -- primitives, functions, classes, etc. are left as-is
            return ty
        end
    end

    return deep(t)
end

--[=[
    A type function that removes `nil` from every property of a table type,
    recursively.

    Optional properties lose their `nil`, so `number?` becomes `number`, and a
    property typed as just `nil` becomes `never`.
    `unknown` is converted to `~nil`.
    `any` is left unchanged, since `any` denotes disabling type checking.

    Nested table types (including tables inside unions and intersections) are
    made deeply required as well.
    Indexer values are recursed into but keep their `nil`, so `{ [string]: T? }`
    still allows missing keys while each `T` becomes deeply required.

    `read` and `write` modifiers are kept, and the indexer and metatable are
    copied unchanged.
    Recursive types are supported.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type PartialSettings = {
        audio: { volume: number?, muted: boolean? }?,
        ui: { scale: number? }?,
    }

    type ResolvedSettings = DeepRequired<PartialSettings>
    -- { audio: { volume: number, muted: boolean }, ui: { scale: number } }
    ```

    @type DeepRequired (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function DeepRequired(t: type): type
    assert(t:is("table"), "DeepRequired expects a table type")

    local function stripNil(ty: type): type
        if ty:is("nil") then
            return types.never -- just `nil`
        elseif ty:is("unknown") then
            return types.negationof(types.singleton(nil)) -- ~nil
        elseif not ty:is("union") then
            return ty
        end

        local kept = {}
        for _, component in ty:components() do
            if not component:is("nil") then
                table.insert(kept, component)
            end
        end

        if #kept == 0 then
            return types.never -- every component was `nil`
        elseif #kept == 1 then
            return kept[1] -- no need to keep the union
        else
            return types.unionof(table.unpack(kept))
        end
    end

    -- tables already being converted, so recursive types terminate
    local seen: { { from: type, to: type } } = {}

    local function deep(ty: type): type
        if ty:is("table") then
            for _, entry in seen do
                if entry.from == ty then
                    return entry.to
                end
            end

            local result = types.newtable()
            -- register before recursing so cycles point back at result
            table.insert(seen, { from = ty, to = result })

            -- make all named properties required, recursively
            -- (strip nil first so tables inside T? are reached)
            for key, prop in ty:properties() do
                if prop.read then
                    result:setreadproperty(key, deep(stripNil(prop.read)))
                end
                if prop.write then
                    result:setwriteproperty(key, deep(stripNil(prop.write)))
                end
            end

            -- recurse into the indexer's values without removing their nil
            -- (luau doesn't support separate read/write indexer types yet, so
            -- setreadindexer/setwriteindexer throw)
            local idx = ty:indexer()
            if idx and idx.readresult then
                result:setindexer(idx.index, deep(idx.readresult))
            end

            -- copy metatable unchanged
            local mt = ty:metatable()
            if mt then
                result:setmetatable(mt)
            end

            return result
        elseif ty:is("union") or ty:is("intersection") then
            local parts = {}
            for _, component in ty:components() do
                table.insert(parts, deep(component))
            end
            return if ty:is("union")
                then types.unionof(table.unpack(parts))
                else types.intersectionof(table.unpack(parts))
        else
            -- primitives, functions, classes, etc. are left as-is
            return ty
        end
    end

    return deep(t)
end

--[=[
    A type function that removes `nil` from every property of a table type.

    Optional properties lose their `nil`, so `number?` becomes `number`, and a
    property typed as just `nil` becomes `never`.
    `unknown` is converted to `~nil`.
    `any` is left unchanged, since `any` denotes disabling type checking.
    `read` and `write` modifiers are kept, and the indexer and metatable are
    copied unchanged.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type Settings = { volume: number?, muted: boolean? }

    type ResolvedSettings = Required<Settings>
    -- { volume: number, muted: boolean }

    local DEFAULTS: ResolvedSettings = { volume = 0.5, muted = false }

    local function resolve(settings: Settings): ResolvedSettings
        return {
            volume = settings.volume or DEFAULTS.volume,
            muted = if settings.muted == nil
                then DEFAULTS.muted
                else settings.muted,
        }
    end
    ```

    @type Required (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Required(t: type): type
    assert(t:is("table"), "Required expects a table type")

    local function stripNil(ty: type): type
        if ty:is("nil") then
            return types.never -- the type was just `nil`
        elseif ty:is("unknown") then
            return types.negationof(types.singleton(nil)) -- ~nil
        elseif not ty:is("union") then
            return ty
        end

        local kept = {}
        for _, component in ty:components() do
            if not component:is("nil") then
                table.insert(kept, component)
            end
        end

        if #kept == 0 then
            return types.never -- every component was `nil`
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
    -- (luau doesn't support separate read/write indexer types yet, so
    -- setreadindexer/setwriteindexer throw)
    local idx = t:indexer()
    if idx and idx.readresult then
        result:setindexer(idx.index, idx.readresult)
    end

    -- copy metatable unchanged
    local mt = t:metatable()
    if mt then
        result:setmetatable(mt)
    end

    return result
end

--[=[
    A type function that makes every property of a table type read-only.

    This is shallow, so tables inside the properties can still be modified.
    Write-only properties are dropped, since they cannot be read.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    Luau does not yet support read-only indexers, so the indexer is copied
    unchanged and stays writable.
    Luau also does not report writes to read-only properties of a table with a
    writable indexer, so only tables without an indexer are fully protected.

    This only affects type checking.
    To prevent writes at runtime, freeze the table with `table.freeze`.

    ```lua
    type Config = { maxPlayers: number, mode: string }

    local CONFIG: ReadOnly<Config> = table.freeze({
        maxPlayers = 10,
        mode = "classic",
    })
    CONFIG.maxPlayers = 20 -- type error: maxPlayers is read-only
    ```

    @type ReadOnly (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function ReadOnly(t: type): type
    assert(t:is("table"), "ReadOnly expects a table type")

    -- only keep read properties
    local result = types.newtable()
    for key, prop in t:properties() do
        if prop.read then
            result:setreadproperty(key, prop.read)
        end
    end

    -- copy the indexer's read type
    -- (luau doesn't support read-only indexers yet, so setreadindexer throws)
    local idx = t:indexer()
    if idx and idx.readresult then
        result:setindexer(idx.index, idx.readresult)
    end

    -- preserve metatable
    local mt = t:metatable()
    if mt then
        result:setmetatable(mt)
    end

    return result
end

--[=[
    A type function that makes every property of a table type read-only,
    recursively.

    This is deep, so tables inside the properties cannot be modified.
    Primitives, functions, and classes (tables with a metatable) are left as-is.
    Write-only properties are dropped, since they cannot be read.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    Luau does not yet support read-only indexers, so the indexer is copied
    unchanged and stays writable.
    Luau also does not report writes to read-only properties of a table with a
    writable indexer, so only tables without an indexer are fully protected.

    This only affects type checking.
    To prevent writes at runtime, freeze the table recursively with
    `table.freeze`.

    ```lua
    type Config = {
        name: string,
        window: { width: number, height: number },
        tags: { string },
    }

    type FrozenConfig = DeepReadOnly<Config>
    -- { read name: string,
    --   read window: { read width: number, read height: number },
    --   read tags: { read string } }
    ```

    @type DeepReadOnly (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function DeepReadOnly(t: type): type
    assert(t:is("table"), "DeepReadOnly expects a table type")

    local seen: { { from: type, to: type } } = {}

    local function deep(ty: type): type
        if ty:is("table") then
            for _, entry in seen do
                if entry.from == ty then
                    return entry.to
                end
            end

            local result = types.newtable()
            -- register before recursing so cycles point back at result
            table.insert(seen, { from = ty, to = result })

            -- only keep read properties, made deep read-only
            for key, prop in ty:properties() do
                if prop.read then
                    result:setreadproperty(key, deep(prop.read))
                end
            end

            -- copy the indexer's read type, made deep read-only
            -- (luau doesn't support read-only indexers yet,
            --  so setreadindexer throws)
            local idx = ty:indexer()
            if idx and idx.readresult then
                result:setindexer(idx.index, deep(idx.readresult))
            end

            -- preserve metatable
            local mt = ty:metatable()
            if mt then
                result:setmetatable(mt)
            end

            return result
        elseif ty:is("union") then
            local parts = {}
            for _, component in ty:components() do
                table.insert(parts, deep(component))
            end
            return types.unionof(table.unpack(parts))
        elseif ty:is("intersection") then
            local parts = {}
            for _, component in ty:components() do
                table.insert(parts, deep(component))
            end
            return types.intersectionof(table.unpack(parts))
        else
            -- primitives, functions, classes, etc. are left as-is
            return ty
        end
    end

    return deep(t)
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
