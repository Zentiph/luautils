--!strict

-- typing type function tests that must type check
-- by @vuppyan

-- These tests only run at type-check time, through `.lute/typing.luau`.
-- Cases that must fail to type check live in `errors/`.
-- Each case checks that `actual` and `expected` are assignable to each other,
-- which means they are the same type, and that `actual` is not `any`, which
-- would pass every assignment.
-- (`==` on types ignores property names, and `tostring` treats `{ a: T }` and
-- `{ read a: T, write a: T }` as different, so neither is used here.
-- See https://github.com/luau-lang/luau/issues/3116)

local typing = require("../../src/luautils/Core/typing")

-- `assert` errors are suppressed when a type function is given `any`, so this
-- returns a singleton that the cases assign to `false` instead
type function IsAny(t: type): type
    return types.singleton(t:is("any"))
end

local Door = {}
Door.__index = Door
type Door = typeof(setmetatable({} :: { open: boolean }, Door))

type A = { a: number, s: string }
type B = { b: boolean, s: string }

--[[ NonNil ]]

do -- removes nil from a union
    local actual: typing.NonNil<string | number | nil> = nil :: any
    local expected: string | number = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- nil becomes never
    local actual: typing.NonNil<nil> = nil :: any
    local expected: never = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Partial ]]

do -- makes properties optional and keeps modifiers
    local actual: typing.Partial<{ name: string, read level: number }> =
        nil :: any
    local expected: { name: string?, read level: number? } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- copies the indexer unchanged
    local actual: typing.Partial<{ a: number, [string]: boolean }> = nil :: any
    local expected: { a: number?, [string]: boolean } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts union members and keeps nil
    local actual: typing.Partial<A | B | nil> = nil :: any
    local expected: { a: number?, s: string? } | { b: boolean?, s: string? } | nil =
        actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts intersection members
    local actual: typing.Partial<{ a: number } & { b: boolean }> = nil :: any
    local expected: { a: number? } & { b: boolean? } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ DeepPartial ]]

type Settings = {
    audio: { volume: number, muted: boolean },
    ui: { scale: number },
}

do -- makes nested properties optional
    local actual: typing.DeepPartial<Settings> = nil :: any
    local expected: {
        audio: { volume: number?, muted: boolean? }?,
        ui: { scale: number? }?,
    } =
        actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- recurses into indexer values without making them optional
    local actual: typing.DeepPartial<{ items: { { x: number } } }> = nil :: any
    local expected: { items: { { x: number? } }? } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- leaves nested classes as-is
    local actual: typing.DeepPartial<{ door: Door, inner: { y: number } }> =
        nil :: any
    local expected: { door: Door?, inner: { y: number? }? } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- keeps sibling tables with different property names apart
    local actual: typing.DeepPartial<{ p: { y: number }, q: { z: number } }> =
        nil :: any
    local expected: { p: { y: number? }?, q: { z: number? }? } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

type Node = { value: number, next: Node? }
type PartialNode = { value: number?, next: PartialNode? }

do -- supports recursive types
    local actual: typing.DeepPartial<Node> = nil :: any
    local expected: PartialNode = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Required ]]

do -- removes nil from properties
    local actual: typing.Required<{ volume: number?, muted: boolean }> =
        nil :: any
    local expected: { volume: number, muted: boolean } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- keeps nil in a union
    local actual: typing.Required<{ a: number? }?> = nil :: any
    local expected: { a: number }? = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ DeepRequired ]]

do -- removes nil from nested properties
    local actual: typing.DeepRequired<{
        audio: { volume: number?, muted: boolean? }?,
        ui: { scale: number? }?,
    }> =
        nil :: any
    local expected: {
        audio: { volume: number, muted: boolean },
        ui: { scale: number },
    } =
        actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- recurses into indexer values without removing their nil
    local actual: typing.DeepRequired<{ [string]: { y: number? }? }> =
        nil :: any
    local expected: { [string]: { y: number }? } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- keeps sibling tables with different property names apart
    local actual: typing.DeepRequired<{ p: { y: number? }, q: { z: number? } }> =
        nil :: any
    local expected: { p: { y: number }, q: { z: number } } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts union members
    local actual: typing.DeepRequired<{ x: { y: number? }? } | { z: number? }> =
        nil :: any
    local expected: { x: { y: number } } | { z: number } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ ReadOnly ]]

do -- makes properties read-only
    local actual: typing.ReadOnly<{ maxPlayers: number, mode: string }> =
        nil :: any
    local expected: { read maxPlayers: number, read mode: string } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- drops write-only properties
    local actual: typing.ReadOnly<{ write w: number, r: number }> = nil :: any
    local expected: { read r: number } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts intersection members
    local actual: typing.ReadOnly<A & B> = nil :: any
    local expected: { read a: number, read s: string } & { read b: boolean, read s: string } =
        actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ DeepReadOnly ]]

do -- makes nested properties read-only
    local actual: typing.DeepReadOnly<{
        name: string,
        window: { width: number },
        tags: { string },
    }> =
        nil :: any
    local expected: {
        read name: string,
        read window: { read width: number },
        read tags: { string },
    } =
        actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts the top-level table even if it has a metatable
    local actual: typing.DeepReadOnly<Door> = nil :: any
    local expected: typing.ReadOnly<Door> = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- keeps nil in a union
    local actual: typing.DeepReadOnly<A?> = nil :: any
    local expected: { read a: number, read s: string }? = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Writable ]]

do -- removes read and write modifiers
    local actual: typing.Writable<{ read a: number, write b: string }> =
        nil :: any
    local expected: { a: number, b: string } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts union members
    local actual: typing.Writable<typing.ReadOnly<A> | typing.ReadOnly<B>> =
        nil :: any
    local expected: A | B = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ DeepWritable ]]

do -- undoes DeepReadOnly
    local actual: typing.DeepWritable<typing.DeepReadOnly<Settings>> =
        nil :: any
    local expected: Settings = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- supports recursive types
    local actual: typing.DeepWritable<typing.DeepReadOnly<Node>> = nil :: any
    local expected: Node = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Record ]]

do -- string singletons become properties
    local actual: typing.Record<"wood" | "stone", number> = nil :: any
    local expected: { wood: number, stone: number } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- other keys become the indexer
    local actual: typing.Record<string, number> = nil :: any
    local expected: { [string]: number } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- mixes properties and the indexer
    local actual: typing.Record<"id" | number, string> = nil :: any
    local expected: { id: string, [number]: string } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Exclude ]]

do -- removes singletons
    local actual: typing.Exclude<"Lobby" | "Playing" | "Ended", "Lobby" | "Ended"> =
        nil :: any
    local expected: "Playing" = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- removes singletons of a primitive
    local actual: typing.Exclude<"a" | "b" | number | boolean, string> =
        nil :: any
    local expected: number | boolean = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- splits boolean into true | false
    local actual: typing.Exclude<boolean, true> = nil :: any
    local expected: false = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- matches tables by property names
    local actual: typing.Exclude<{ y: number } | { z: number }, { y: number }> =
        nil :: any
    local expected: { z: number } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Extract ]]

do -- keeps singletons of a primitive
    local actual: typing.Extract<"Jump" | "Crouch" | number, string> =
        nil :: any
    local expected: "Jump" | "Crouch" = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- splits boolean into true | false
    local actual: typing.Extract<boolean | number, true> = nil :: any
    local expected: true = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- rejoins true | false into boolean
    local actual: typing.Extract<boolean | number, boolean> = nil :: any
    local expected: boolean = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Pick ]]

do -- keeps the given properties
    local actual: typing.Pick<A, "a"> = nil :: any
    local expected: { a: number } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts union members
    local actual: typing.Pick<A | B, "s"> = nil :: any
    local expected: { s: string } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- finds keys in any intersection member
    local actual: typing.Pick<A & B, "a" | "b"> = nil :: any
    local expected: { a: number } & { b: boolean } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Omit ]]

do -- removes the given properties and ignores missing ones
    local actual: typing.Omit<A, "s" | "missing"> = nil :: any
    local expected: { a: number } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts union members
    local actual: typing.Omit<A | B, "s"> = nil :: any
    local expected: { a: number } | { b: boolean } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Merge ]]

do -- B's properties replace A's
    local actual: typing.Merge<{ id: number, name: string }, { name: string?, id: string }> =
        nil :: any
    local expected: { id: string, name: string? } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts union members of A and B
    local actual: typing.Merge<A, { s: number } | { a: string }> = nil :: any
    local expected: { a: number, s: number } | { a: string, s: string } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- intersects with intersection members of B
    local actual: typing.Merge<A, { s: number } & { z: boolean }> = nil :: any
    local expected: { a: number } & { s: number } & { z: boolean } = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ Parameter ]]

type Spawn = (name: string, level: number, ...boolean) -> number

do -- gets a parameter by position
    local actual: typing.Parameter<Spawn, "2"> = nil :: any
    local expected: number = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- gets the variadic type past the fixed parameters
    local actual: typing.Parameter<Spawn, "4"> = nil :: any
    local expected: boolean = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- intersects the parameters of a union of functions
    local actual: typing.Parameter<((string?) -> ()) | ((string) -> ()), "1"> =
        nil :: any
    local expected: string = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- unions the parameters of overloads, skipping ones without it
    local actual: typing.Parameter<((string) -> ()) & ((number) -> ()) & (() -> ()), "1"> =
        nil :: any
    local expected: string | number = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ ReturnType ]]

do -- gets the first return type
    local actual: typing.ReturnType<Spawn> = nil :: any
    local expected: number = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- returning nothing is nil
    local actual: typing.ReturnType<() -> ()> = nil :: any
    local expected: nil = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- a variadic return may be missing
    local actual: typing.ReturnType<() -> ...number> = nil :: any
    local expected: number? = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- unions the returns of overloads
    local actual: typing.ReturnType<((string) -> number) & ((number) -> string)> =
        nil :: any
    local expected: number | string = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ OmitSelf ]]

do -- removes the first parameter
    local actual: typing.OmitSelf<(self: Door, speed: number) -> boolean> =
        nil :: any
    local expected: (number) -> boolean = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- converts each overload
    local actual: typing.OmitSelf<
        ((self: Door, number) -> ()) & ((self: Door, string) -> ())
    > =
        nil :: any
    local expected: ((number) -> ()) & ((string) -> ()) = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

--[[ String case ]]

do -- Uppercase converts each union member
    local actual: typing.Uppercase<"north" | "south"> = nil :: any
    local expected: "NORTH" | "SOUTH" = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- Lowercase converts each union member
    local actual: typing.Lowercase<"Common" | "Rare"> = nil :: any
    local expected: "common" | "rare" = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- Capitalize converts the first character
    local actual: typing.Capitalize<"jump" | ""> = nil :: any
    local expected: "Jump" | "" = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- Uncapitalize converts the first character
    local actual: typing.Uncapitalize<"Players"> = nil :: any
    local expected: "players" = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

do -- string stays string
    local actual: typing.Uppercase<string> = nil :: any
    local expected: string = actual
    local _: typeof(actual) = expected
    local isAny: IsAny<typeof(actual)> = nil :: any
    local _notAny: false = isAny
end

return nil
