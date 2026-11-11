--!strict

-- core types
-- by @vuppyan

--[=[
    Shared type aliases for function shapes, containers, iteration, and
    protocols.

    This module has no runtime value. Every type is re-exported by `Core` and
    `Luautils`, so use them as `Luautils.Supplier<T>` or `Core.Map<K, V>`, etc.

    The typing helpers are type functions, which require Luau's new type solver.

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

-- TODO: add union support to existing helpers
-- e.g. Nillable<A | B> -> Nillable<A> | Nillable<B>

--[[ Typing helpers ]]

--[=[
    A type function that removes `nil` from any type.

    `unknown` is converted to `~nil`.
    `any` is left unchanged, since `any` denotes disabling type checking.

    ```lua
    type MaybeData = string | number | nil

    local function expectData(data: MaybeData): NonNil<MaybeData>
        -- handle stuff...
        return data -- now string | number
    end
    ```

    @type NonNil (t: type) -> type
    @within typing
    @since v0.1.0
]=]
export type function NonNil(t: type): type
    if t:is("nil") then
        return types.never -- the type was just `nil`
    elseif t:is("unknown") then
        return types.negationof(types.singleton(nil)) -- any value except `nil`
    elseif not t:is("union") then
        return t
    end

    local kept = {}
    for _, component in t:components() do
        if component:is("unknown") then
            -- unknown absorbs the rest of the union, leaving just ~nil
            return types.negationof(types.singleton(nil))
        elseif component:is("any") then
            -- any absorbs the rest of the union and is left unchanged
            return types.any
        elseif not component:is("nil") then
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

    `read` and `write` modifiers are kept, and metatable is copied unchanged.
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
            if component:is("unknown") then
                -- unknown absorbs the rest of the union, leaving just ~nil
                return types.negationof(types.singleton(nil))
            elseif component:is("any") then
                -- any absorbs the rest of the union and is left unchanged
                return types.any
            elseif not component:is("nil") then
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

    `read` and `write` modifiers are kept, and the metatable is copied
    unchanged.
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
            return types.never -- just nil
        elseif ty:is("unknown") then
            return types.negationof(types.singleton(nil)) -- ~nil
        elseif not ty:is("union") then
            return ty
        end

        local kept = {}
        for _, component in ty:components() do
            if component:is("unknown") then
                -- unknown absorbs the rest of the union, leaving just ~nil
                return types.negationof(types.singleton(nil))
            elseif component:is("any") then
                -- any absorbs the rest of the union and is left unchanged
                return types.any
            elseif not component:is("nil") then
                table.insert(kept, component)
            end
        end

        if #kept == 0 then
            return types.never -- every component was nil
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
    --   read tags: { string } }
    ```

    @type DeepReadOnly (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function DeepReadOnly(t: type): type
    assert(t:is("table"), "DeepReadOnly expects a table type")

    local seen: { { from: type, to: type } } = {}

    local function deep(ty: type): type
        if ty:is("table") and ty:metatable() == nil then
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

--[=[
    A type function that makes every property of a table type readable and
    writable, removing `read` and `write` modifiers.

    Each property keeps its read type (or its write type, if it was
    write-only) and becomes a normal property.

    The indexer and metatable are copied unchanged.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type State = ReadOnly<{ score: number, alive: boolean }>
    -- { read score: number, read alive: boolean }

    type MutableState = Writable<State>
    -- { score: number, alive: boolean }
    ```

    @type Writable (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Writable(t: type): type
    assert(t:is("table"), "Writable expects a table type")

    -- make every named property readable and writable
    local result = types.newtable()
    for key, prop in t:properties() do
        local ty = prop.read or prop.write
        if ty then
            result:setreadproperty(key, ty)
            result:setwriteproperty(key, ty)
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
    A type function that makes every property of a table type readable and
    writable, recursively, removing `read` and `write` modifiers.

    Each property keeps its read type (or its write type, if it was
    write-only) and becomes a normal property.
    Nested table types (including tables inside unions, intersections, and
    indexer values) are made deeply writable as well.

    Metatables are copied unchanged.
    Recursive types are supported.
    Only table types are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type Frozen = DeepReadOnly<{ name: string, window: { width: number } }>
    -- { read name: string, read window: { read width: number } }

    type Editable = DeepWritable<Frozen>
    -- { name: string, window: { width: number } }
    ```

    @type DeepWritable (t: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function DeepWritable(t: type): type
    assert(t:is("table"), "DeepWritable expects a table type")

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
            -- register before recursing so cycles point back at `result`
            table.insert(seen, { from = ty, to = result })

            -- make every named property readable and writable, recursively
            for key, prop in ty:properties() do
                local propType = prop.read or prop.write
                if propType then
                    local converted = deep(propType)
                    result:setreadproperty(key, converted)
                    result:setwriteproperty(key, converted)
                end
            end

            -- recurse into the indexer's values
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
    A type function that builds a table type with keys `K` and values `V`.

    Each string singleton in `K` becomes a named property of type `V`, so
    `Record<"wood" | "stone", number>` is `{ wood: number, stone: number }`.
    Every other key type in `K` (such as `string`, `number`, or `boolean`
    singletons) become part of the indexer, so `Record<string, number>` is
    `{ [string]: number }`.
    Since a table only has one indexer, multiple non-singleton keys are
    combined into one, so `Record<"id" | number, V>` is
    `{ id: V, [number]: V }` and `Record<string | number, V>` is
    `{ [string | number]: V }`.
    `Record<never, V>` is an empty table.

    ```lua
    type Resource = "wood" | "stone" | "gold"

    type Inventory = Record<Resource, number>
    -- { wood: number, stone: number, gold: number }

    local inventory: Inventory = { wood = 0, stone = 0, gold = 0 }
    inventory.iron = 5 -- type error: iron is not a Resource
    ```

    @type Record (k: type, v: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Record(k: type, v: type): type
    local keys = if k:is("union")
        then k:components()
        elseif k:is("never") then {}
        else { k }

    local result = types.newtable()
    local indexKeys = {}

    for _, key in keys do
        if key:is("singleton") and typeof(key:value()) == "string" then
            -- string singletons become named properties
            result:setproperty(key, v)
        else
            -- everything else is collected in the indexer
            table.insert(indexKeys, key)
        end
    end

    -- a table only has one indexer, so combine the non-singleton keys
    if #indexKeys == 1 then
        result:setindexer(indexKeys[1], v)
    elseif #indexKeys > 1 then
        result:setindexer(types.unionof(table.unpack(indexKeys)), v)
    end

    return result
end

--[=[
    A type function that removes the members of a union `T` that match `U`.

    A member matches if it is the same type as a member of `U`, if it is a
    singleton whose primitive type is in `U`, (so `"a"` matches `string`), or
    if `U` contains `unknown` or `any`.
    Tables, functions, and classes only match the exact same type, not
    structurally equal ones.
    If every member is removed, the result is `never`.

    ```lua
    type GameState = "Lobby" | "Playing" | "Ended"

    type ActiveState = Exclude<GameState, "Lobby" | "Ended">
    -- "Playing"

    type NonString = Exclude<"a" | "b" | number | boolean, string>
    -- number | boolean
    ```

    @type Exclude (t: type, u: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Exclude(t: type, u: type): type
    local PRIMITIVES =
        { "nil", "boolean", "number", "string", "thread", "buffer" }

    local function matches(member: type, filter: type): boolean
        if filter:is("unknown") or filter:is("any") then
            return true
        elseif member:is("singleton") then
            if filter:is("singleton") then
                return member:value() == filter:value()
            end
            -- "a" matches string, true matches boolean, etc.
            return filter:is(typeof(member:value()))
        end

        for _, kind in PRIMITIVES do
            if member:is(kind) then
                return filter:is(kind)
            end
        end

        return member == filter
    end

    local members = if t:is("union") then t:components() else { t }
    local filters = if u:is("union") then u:components() else { u }

    local kept = {}
    for _, member in members do
        local excluded = false
        for _, filter in filters do
            if matches(member, filter) then
                excluded = true
                break
            end
        end
        if not excluded then
            table.insert(kept, member)
        end
    end

    if #kept == 0 then
        return types.never -- all members were excluded
    elseif #kept == 1 then
        return kept[1] -- no need for a union
    else
        return types.unionof(table.unpack(kept))
    end
end

--[=[
    A type function that keeps only the members of a union `T` that match `U`.

    A member matches if it is the same type as a member of `U`, if it is a
    singleton whose primitive type is in `U` (so `"a"` matches `string`), or
    if `U` contains `unknown` or `any`.
    Tables, functions, and classes only match the exact same type, not
    structurally equal ones.
    If no member matches, the result is `never`.

    ```lua
    type Input = "Jump" | "Crouch" | number | Vector3

    type InputName = Extract<Input, string>
    -- "Jump" | "Crouch"

    type MovementInput = Extract<Input, "Jump" | "Crouch" | "Sprint">
    -- "Jump" | "Crouch"
    ```

    @type Extract (t: type, u: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Extract(t: type, u: type): type
    local PRIMITIVES =
        { "nil", "boolean", "number", "string", "thread", "buffer" }

    local function matches(member: type, filter: type): boolean
        if filter:is("unknown") or filter:is("any") then
            return true
        elseif member:is("singleton") then
            if filter:is("singleton") then
                return member:value() == filter:value()
            end
            -- `"a"` matches string, true matches boolean
            return filter:is(typeof(member:value()))
        end

        for _, kind in PRIMITIVES do
            if member:is(kind) then
                return filter:is(kind)
            end
        end

        return member == filter
    end

    local members = if t:is("union") then t:components() else { t }
    local filters = if u:is("union") then u:components() else { u }

    local kept = {}
    for _, member in members do
        for _, filter in filters do
            if matches(member, filter) then
                table.insert(kept, member)
                break
            end
        end
    end

    if #kept == 0 then
        return types.never -- no member matched
    elseif #kept == 1 then
        return kept[1] -- no need to keep the union
    else
        return types.unionof(table.unpack(kept))
    end
end

--[=[
    A type function that keeps only the given named properties of a table type.

    `K` is a string singleton or a union of string singletons.
    Every key must be a property of `T`, otherwise it is a type error.

    `read` and `write` modifiers are kept, and the metatable is copied
    unchanged.
    The indexer is dropped, since only named properties are picked.
    Only tables are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type Profile = { name: string, level: number, coins: number }

    type ProfileCard = Pick<Profile, "name" | "level">
    -- { name: string, level: number }
    ```

    @type Pick (t: type, k: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Pick(t: type, k: type): type
    assert(t:is("table"), "Pick expects a table type")

    local keys = if k:is("union")
        then k:components()
        elseif k:is("never") then {}
        else { k }

    local result = types.newtable()
    for _, key in keys do
        assert(
            key:is("singleton") and typeof(key:value()) == "string",
            "Pick expects string singleton keys"
        )

        local read = t:readproperty(key)
        local write = t:writeproperty(key)
        if not read and not write then
            error(`Pick: property "{key:value()}" does not exist`)
        end

        if read then
            result:setreadproperty(key, read)
        end
        if write then
            result:setwriteproperty(key, write)
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
    A type function that removes the given named properties of a table type.

    `K` is a string singleton or a union of string singletons.
    Keys that are not properties of `T` are ignored.

    `read` and `write` modifiers are kept, and the indexer and metatable are
    copied unchanged.
    Only tables are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type Profile = { name: string, level: number, coins: number }

    type PublicProfile = Omit<Profile, "coins">
    -- { name: string, level: number }
    ```

    @type Omit (t: type, k: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Omit(t: type, k: type): type
    assert(t:is("table"), "Omit expects a table type")

    local keys = if k:is("union")
        then k:components()
        elseif k:is("never") then {}
        else { k }

    local omitted: { [string]: boolean } = {}
    for _, key in keys do
        assert(
            key:is("singleton") and typeof(key:value()) == "string",
            "Omit expects string singleton keys"
        )
        omitted[key:value()] = true
    end

    -- copy every named property not in `K`
    local result = types.newtable()
    for key, prop in t:properties() do
        if not omitted[key:value() :: string] then
            if prop.read then
                result:setreadproperty(key, prop.read)
            end
            if prop.write then
                result:setwriteproperty(key, prop.write)
            end
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
    A type function that merges two table types, with `B`'s properties
    replacing `A`'s.

    Properties only in `A` are kept, properties in `B` replace any property of
    `A` with the same name, including its `read` and `write` modifiers.
    Unlike `A & B`, conflicting properties do not become `never`.
    `B`'s indexer and metatable are used if it has them, otherwise `A`'s are
    copied unchanged.

    Only table types are accepted, so unions and intersections of tables are a
    type error.

    ```lua
    type Base = { id: number, name: string, tags: { string } }
    type Patch = { name: string?, id: string }

    type Patched = Merge<Base, Patch>
    -- { id: string, name: string?, tags: { string } }

    type Intersected = Base & Patch
    -- `id` is `number & string`, which is `never`
    ```

    @type Merge (a: type, b: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Merge(a: type, b: type): type
    assert(a:is("table"), "Merge expects a table type for A")
    assert(b:is("table"), "Merge expects a table type for B")

    local result = types.newtable()

    -- collect B's keys so A's conflicting properties are skipped
    local replaced: { [string]: boolean } = {}
    for key in b:properties() do
        replaced[key:value() :: string] = true
    end

    -- copy A's properties that B doesn't replace
    for key, prop in a:properties() do
        if not replaced[key:value() :: string] then
            if prop.read then
                result:setreadproperty(key, prop.read)
            end
            if prop.write then
                result:setwriteproperty(key, prop.write)
            end
        end
    end

    -- copy all of B's properties
    for key, prop in b:properties() do
        if prop.read then
            result:setreadproperty(key, prop.read)
        end
        if prop.write then
            result:setwriteproperty(key, prop.write)
        end
    end

    -- use B's indexer if it has one, otherwise A's
    -- (luau doesn't support separate read/write indexer types yet, so
    -- setreadindexer/setwriteindexer throw)
    local idx = b:indexer() or a:indexer()
    if idx and idx.readresult then
        result:setindexer(idx.index, idx.readresult)
    end

    -- use B's metatable if it has one, otherwise A's
    local mt = b:metatable() or a:metatable()
    if mt then
        result:setmetatable(mt)
    end

    return result
end

--[=[
    A type function that gets a parameter type of a function type by its
    position.

    `I` is a string singleton holding a 1-based index, such as `"1"` or `"2"`,
    since Luau does not have number singleton types.
    If the position falls inside a variadic parameter (`...T`), the result is
    `T`.
    If the function has no parameter at that position, it is a type error.

    Methods count `self` as their first parameter.
    Only function types are accepted, so overloaded functions (intersections
    of functions) are a type error.

    ```lua
    local function spawnEnemy(name: string, level: number): Model
        -- ...
    end

    type EnemyName = Parameter<typeof(spawnEnemy), "1">
    -- string

    type EnemyLevel = Parameter<typeof(spawnEnemy), "2">
    -- number
    ```

    @type Parameter (f: type, i: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function Parameter(f: type, i: type): type
    assert(f:is("function"), "Parameter expects a function type")
    assert(
        i:is("singleton") and typeof(i:value()) == "string",
        `Parameter expects a string index like "1"`
    )

    local index = tonumber(i:value())
    assert(
        index and index >= 1 and index % 1 == 0,
        `Parameter expects a positive integer index like "1"`
    )

    local params = f:parameters()
    local head = params.head or {}

    if index <= #head then
        return head[index]
    elseif params.tail then
        return params.tail -- the position falls inside ...T
    else
        error(`Parameter: function has no parameter {index}`)
    end
end

--[=[
    A type function that gets the first return type of a function type.

    This is the type a caller gets from `local value = f()`.
    If the function returns nothing, the result is `nil`.
    If its first return is variadic (`...T`), the result is `T?`, since it may
    return no values.

    Luau type functions cannot return type packs, so only the first return
    type is available.
    Only function types are accepted, so overloaded functions (intersections
    of functions) are a type error.

    ```lua
    local function spawnEnemy(name: string, level: number): Model
        -- ...
    end

    type Enemy = ReturnType<typeof(spawnEnemy)>
    -- Model
    ```

    @type ReturnType (f: type) -> type
    @within typing
    @since [UNRELEASED]
]=]
export type function ReturnType(f: type): type
    assert(f:is("function"), "ReturnType expects a function type")

    local returns = f:returns()
    local head = returns.head or {}

    if #head > 0 then
        return head[1]
    elseif returns.tail then
        return types.optional(returns.tail) -- ...T may return no values
    else
        return types.singleton(nil) -- the function returns nothing
    end
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
