--!strict

-- Class helpers library
-- author(s): @vuppyan

local fail = require("./Errors").errorWithScope("Class")

--[=[
    Helpers for writing classes in Luau: inheritance with [Class.extends],
    instance creation with [Class.new], immutability with [Class.sealed], and
    instance checks with [Class.isA] and [Class.cast].

    A class is a plain table of methods owned by the class. Subclasses are
    created with `setmetatable({}, Class.extends(Base))`, and instances with
    `Class.new(Class, fields)`, which sets up the class's `__index` and
    inherited metamethods the first time it is used, so neither has to be
    written by hand.

    Each class builds its fields in a `fields` function, which its subclasses
    reuse in their own constructors, so a base class's constructor logic is
    written once:

    ```lua
    local Animal = {}

    export type AnimalFields = { name: string, health: number }

    function Animal.fields(name: string): AnimalFields
        return { name = name, health = 10 }
    end

    function Animal.new(name: string)
        return Class.new(Animal, Animal.fields(name))
    end

    function Animal.speak(_self): string
        return "..."
    end

    function Animal.hurt(self: AnimalFields, amount: number)
        self.health -= amount
    end

    local Dog = setmetatable({}, Class.extends(Animal))

    export type DogFields = AnimalFields & { breed: string }

    function Dog.fields(name: string, breed: string): DogFields
        return Class.merge(Animal.fields(name), { breed = breed })
    end

    function Dog.new(name: string, breed: string)
        return Class.new(Dog, Dog.fields(name, breed))
    end

    function Dog.speak(self): string
        return `Woof! {Animal.speak(self)}`
    end

    local dog = Dog.new("Rex", "Labrador")
    dog:speak() -- "Woof! ..."
    dog:hurt(3) -- inherited from Animal
    dog.health -- 7
    ```

    Everything above is fully type checked in `--!strict` mode: fields, the
    subclass's own methods, overrides, and inherited methods all have their real
    types.

    > **Tip: Type `self` with the fields type in methods that use fields**
    >
    > Methods that read or write fields, such as `Animal.hurt`, should type
    > `self` as the class's fields type (`self: AnimalFields`). Subclass
    > instances fit it, since they have every field of their base classes.
    > Leaving `self` unannotated works for methods that only call other methods,
    > but arithmetic on its fields fails to type check, and typing it as the
    > instance type (`self: Animal`) rejects subclass instances.

    To accept instances of a class or any of its subclasses, type the parameter
    with [Class.IsA] and pass subclass instances through [Class.cast], which
    checks them at runtime:

    ```lua
    type AnyAnimal = Luautils.IsA<typeof(Animal)>

    local function greet(animal: AnyAnimal): string
        return `{animal.name} says {animal:speak()}`
    end

    greet(Animal.new("Generic")) -- base class instances can be passed directly
    greet(Class.cast(dog, Animal)) -- subclass instances need a cast
    ```

    > **Caution: Subclass instances are not their base class's type**
    >
    > Passing `dog` directly to a parameter typed as an `Animal` instance is a
    > type error, even when typed with [Class.IsA]. Luau only follows `__index`
    > to plain tables when comparing types, and every subclass is a
    > `setmetatable` type. This is a limit of Luau's type system and applies to
    > hand-written classes too, which is why [Class.cast] exists.

    > **Caution: Operator metamethods are not typed**
    >
    > Metamethods such as `__tostring`, `__eq`, and `__add` work at runtime and
    > are inherited, but Luau does not see operator metamethods on instances
    > created with `Class.new`, so `a + b` on two instances is a type error.
    > Give operators a named method too, such as `Vector.add(a, b)`, and call
    > that in typed code.

    Error messages thrown by `Class` functions are prefixed with the function
    that threw them, such as `[Class.new()]: `, after the usual position prefix
    added by `error()`.

    @class Class
    @since [UNRELEASED]
]=]
local Class = {}

-- runtime implementations which are given typed signatures later on
local Untyped = {}

-- prevent function inlining for helpers that require call stack consistency
local Internal = {}

-- classes whose `__index` and inherited metamethods have been set up
local setUp: { [any]: true } = setmetatable({}, { __mode = "k" })

-- classes sealed with `Class.sealed`
local sealed: { [any]: true } = setmetatable({}, { __mode = "k" })

-- a value no class can be, for walking a whole chain
local NOTHING = table.freeze({})

-- the class `class` extends: the `__index` of its metatable
local function parentOf(class: any): any
    local mt = getmetatable(class)
    return if type(mt) == "table" then rawget(mt, "__index") else nil
end

-- metamethods and other `__` keys are copied to subclasses, since Luau looks
-- metamethods up on the metatable itself, not through `__index`
local function isInheritedKey(k: any): boolean
    return type(k) == "string"
        and string.sub(k, 1, 2) == "__"
        and k ~= "__index"
        and k ~= "__metatable"
end

-- returns whether `target` is `start` or one of the classes `start` extends,
-- throwing at `level` if the chain loops (Floyd's tortoise and hare)
function Internal.hasAncestor(
    start: any,
    target: any,
    level: number,
    functionName: string
): boolean
    local slow, fast = start, start
    while type(slow) == "table" do
        if rawequal(slow, target) then
            return true
        end
        slow = parentOf(slow)
        fast = parentOf(parentOf(fast))
        if fast ~= nil and rawequal(slow, fast) then
            fail("Circular inheritance detected", level, functionName)
        end
    end
    return false
end

-- sets up `class` and the classes it extends, root first
-- each gets `__index` set to itself and copies of its base class's inherited
-- keys
function Internal.setUp(class: any, functionName: string)
    if setUp[class] then
        return
    end
    Internal.hasAncestor(class, NOTHING, 4, functionName)

    local chain = {}
    local current = class
    while type(current) == "table" and not setUp[current] do
        table.insert(chain, current)
        current = parentOf(current)
    end

    for i = #chain, 1, -1 do
        current = chain[i]
        local index = rawget(current, "__index")
        if index ~= nil and not rawequal(index, current) then
            fail(
                "Class must not have an __index other than itself",
                3,
                functionName
            )
        end

        -- find everything to write first, so a frozen class fails cleanly
        local parent = parentOf(current)
        local inherited = {}
        if type(parent) == "table" then
            for k, v in pairs(parent) do
                if isInheritedKey(k) and rawget(current, k) == nil then
                    inherited[k] = v
                end
            end
        end

        if index == nil or next(inherited) ~= nil then
            if table.isfrozen(current) then
                fail(
                    "Cannot set up a class frozen with table.freeze(); "
                        .. "use Class.sealed() instead",
                    3,
                    functionName
                )
            end
            for k, v in pairs(inherited) do
                rawset(current, k, v)
            end
            rawset(current, "__index", current)
        end

        setUp[current] = true
    end
end

-- whether setting up a frozen, not yet set up class would need to write to it
-- set up classes hold their base classes' inherited keys, so checking every
-- base class covers the ones not yet set up too
function Internal.needsWrites(class: any): boolean
    if rawget(class, "__index") == nil then
        return true
    end
    local current = parentOf(class)
    while type(current) == "table" do
        for k in pairs(current) do
            if isInheritedKey(k) and rawget(class, k) == nil then
                return true
            end
        end
        current = parentOf(current)
    end
    return false
end

-- checks a table that will become an instance, throwing at the caller of
-- the public function that called this
function Internal.checkFields(fields: any, what: string, functionName: string)
    if type(fields) ~= "table" then
        fail(
            `Expected {what} to be a table, got {type(fields)}`,
            3,
            functionName
        )
    elseif table.isfrozen(fields) then
        fail(`Cannot use frozen {what}`, 3, functionName)
    elseif getmetatable(fields) ~= nil then
        fail(`Cannot use {what} that already have a metatable`, 3, functionName)
    end
end

-- checks a table to merge, throwing at the caller of `Class.merge`
function Internal.checkMerged(t: any, what: string)
    if type(t) ~= "table" then
        fail(`Expected {what} to be a table, got {type(t)}`, 3, "merge")
    elseif getmetatable(t) ~= nil then
        fail(`Cannot merge {what} that has a metatable`, 3, "merge")
    end
end

--[[ creating classes ]]

function Untyped.extends(base: any): any
    if type(base) ~= "table" then
        fail(`Expected a base class table, got {type(base)}`)
    elseif sealed[base] then
        fail("Cannot extend a sealed class")
    end

    local index = rawget(base, "__index")
    if index ~= nil and not rawequal(index, base) then
        fail("Base class must not have an __index other than itself")
    end

    -- walks the whole chain, so loops throw here
    Internal.hasAncestor(base, NOTHING, 3, "extends")

    if
        table.isfrozen(base)
        and not setUp[base]
        and Internal.needsWrites(base)
    then
        fail(
            "Cannot extend a class frozen with table.freeze() "
                .. "before being set up; use Class.sealed() instead"
        )
    end

    return table.freeze({ __index = base })
end

function Untyped.sealed(class: any): any
    if type(class) ~= "table" then
        fail(`Expected a class table, got {type(class)}`)
    elseif table.isfrozen(class) then
        fail("Cannot seal a frozen table")
    end

    Internal.setUp(class, "sealed")
    sealed[class] = true
    return table.freeze(class)
end

function Untyped.isSealed(class: any): boolean
    return sealed[class] == true
end

--[[ creating instances ]]

function Untyped.new(class: any, ...: any): any
    if type(class) ~= "table" then
        fail(`Expected a class table, got {type(class)}`)
    end

    local instance
    if select("#", ...) >= 2 then
        local inherited, fields = ...
        Internal.checkFields(inherited, "inherited fields", "new")
        if fields ~= nil and type(fields) ~= "table" then
            fail(`Expected a fields table or nil, got {type(fields)}`)
        end
        Internal.setUp(class, "new")
        if fields ~= nil then
            for k, v in next, fields do
                rawset(inherited, k, v)
            end
        end
        instance = inherited
    else
        local fields = ...
        if fields == nil then
            fields = {}
        elseif type(fields) ~= "table" then
            fail(`Expected a fields table or nil, got {type(fields)}`)
        else
            Internal.checkFields(fields, "fields", "new")
        end
        Internal.setUp(class, "new")
        instance = fields
    end

    return setmetatable(instance, class)
end

function Untyped.merge(base: any, fields: any): any
    Internal.checkMerged(base, "base")
    Internal.checkMerged(fields, "fields")

    local merged = table.clone(base)
    for k, v in next, fields do
        merged[k] = v
    end
    return merged
end

--[[ inspecting ]]

function Untyped.isA(value: any, class: any): boolean
    if type(value) ~= "table" or type(class) ~= "table" then
        return false
    end
    return Internal.hasAncestor(getmetatable(value), class, 3, "isA")
end

function Untyped.isSubclassOf(class: any, base: any): boolean
    if type(class) ~= "table" or type(base) ~= "table" then
        return false
    end
    return Internal.hasAncestor(parentOf(class), base, 3, "isSubclassOf")
end

function Untyped.parentOf(class: any): any
    return if type(class) == "table" then parentOf(class) else nil
end

function Untyped.classOf(value: any): any
    return if type(value) == "table" then getmetatable(value) else nil
end

function Untyped.cast(value: any, class: any): any
    if type(class) ~= "table" then
        fail(`Expected a class table, got {type(class)}`)
    elseif
        type(value) ~= "table"
        or not Internal.hasAncestor(getmetatable(value), class, 3, "cast")
    then
        fail("Value is not an instance of the class")
    end
    return value
end

function Untyped.tryCast(value: any, class: any): any
    if type(class) ~= "table" then
        fail(`Expected a class table, got {type(class)}`)
    elseif
        type(value) ~= "table"
        or not Internal.hasAncestor(getmetatable(value), class, 3, "tryCast")
    then
        return nil
    end
    return value
end

--[[ types ]]

--[=[
    @interface Metatable<C>
    @within Class
    @since [UNRELEASED]
    @field __index C -- The class, which instances look up their methods in

    The metatable of an instance of the class `C`, as seen by the type checker.
    Instances created with [Class.new] are typed
    `setmetatable<Fields, Metatable<C>>`.
]=]
export type Metatable<C> = { __index: C }

--[=[
    @type IsA<C> { [string]: any }
    @within Class
    @since [UNRELEASED]

    The type of an instance of the class `C` or any of its subclasses, viewed as
    an instance of `C`. `C` is the class's type, such as `typeof(Animal)`.

    The type is built from `C` and its base classes, and contains:
    * The fields of the instance returned by `C.new`, if `C` has a `new`
      constructor. Fields can be read and written.
    * Every method of `C` and its base classes, with `self` typed as `any` so
      subclass overrides fit. Methods can only be read.
    * Every other value stored on `C` and its base classes, such as constants.
      These can only be read.

    Left out, since they are not called on instances or subclasses usually
    change them:
    * Constructors (`new`).
    * Keys starting with `__`, such as metamethods.
    * Static functions, recognized by their first parameter being a string,
      number, boolean, or other non-table type, such as `fields(name: string)`.
      Functions with no parameters are left out too.

    Base class instances can be passed directly where an `IsA<C>` is expected,
    but subclass instances must go through [Class.cast] or [Class.tryCast]; see
    the caution in [Class] for why.

    ```lua
    type AnyAnimal = Luautils.IsA<typeof(Animal)>

    local zoo: { AnyAnimal } = {
        Animal.new("Generic"),
        Class.cast(Dog.new("Rex", "Labrador"), Animal),
    }
    for _, animal in zoo do
        print(animal.name, animal:speak())
    end
    ```

    > **Caution: A class cannot use `IsA` of itself**
    >
    > Using `IsA<typeof(Animal)>` in the definition of `Animal` itself, such as
    > to type the `other` parameter of `Animal.equals`, makes the class's type
    > refer to itself, which Luau's type functions cannot resolve, and breaks
    > every type involving `Animal`. Use the class's fields type instead, such
    > as `other: AnimalFields`, and use `IsA` only outside the class.

    The type only checks the shape of a value, not its class, so a table with
    the same fields and methods also fits. [Class.cast] checks the class at
    runtime.
]=]
export type function IsA(class: type): type
    local result = types.newtable()

    -- widens a method's `self` parameter to `any`, so overrides that type
    -- `self` as a subclass still fit
    local function widenSelf(method: type): type
        local params = method:parameters()
        local head = params.head or {}
        if #head > 0 then
            head[1] = types.any
        end
        return types.newfunction(
            { head = head, tail = params.tail },
            method:returns(),
            method:generics()
        )
    end

    -- static functions take no `self` (no fixed parameters), or a first
    -- parameter that cannot be an instance
    local NOT_SELF = {
        "nil",
        "boolean",
        "number",
        "string",
        "singleton",
        "thread",
        "buffer",
        "vector",
    }
    local function isStatic(fn: type): boolean
        local params = fn:parameters()
        local first = params.head and params.head[1]
        if first == nil then
            return true
        end
        for _, tag in NOT_SELF do
            if first:is(tag) then
                return true
            end
        end
        return false
    end

    local function isIncluded(key: type): boolean
        local name = key:value()
        return type(name) ~= "string"
            or (name ~= "new" and string.sub(name, 1, 2) ~= "__")
    end

    -- fields from the instance type returned by the constructor
    local constructor = if class:is("table")
        then class:readproperty(types.singleton("new"))
        else nil
    if constructor and constructor:is("function") then
        local returned = constructor:returns().head
        local instance = returned and returned[1]
        if instance and instance:is("table") then
            for key, prop in instance:properties() do
                if prop.read and isIncluded(key) then
                    result:setproperty(key, prop.read)
                end
            end
        end
    end

    -- members from the class and its base classes, using the nearest first so
    -- overrides win
    local current: type? = class
    local depth = 0
    while current and current:is("table") and depth < 1024 do
        depth += 1
        for key, prop in current:properties() do
            local value = prop.read
            if
                value
                and isIncluded(key)
                and result:readproperty(key) == nil
            then
                if not value:is("function") then
                    result:setreadproperty(key, value)
                elseif not isStatic(value) then
                    result:setreadproperty(key, widenSelf(value))
                end
            end
        end
        local link = current:metatable()
        current = if link and link:is("table")
            then link:readproperty(types.singleton("__index"))
            else nil
    end

    return result
end

--[[ public API ]]

--[=[
    @function extends
    @within Class
    @since [UNRELEASED]

    Returns the metatable to create a subclass of `base` with:

    ```lua
    local Dog = setmetatable({}, Class.extends(Animal))
    ```

    The returned metatable is `{ __index = base }`, frozen, so anything the
    subclass does not define is looked up on the base class: methods, static
    functions, and constructors alike. Since constructors are inherited too,
    give each subclass its own `new`, or `Dog.new` will create `Animal`s.

    Metamethods such as `__tostring` and `__eq` are not looked up through
    `__index`, so [Class.new] and [Class.sealed] copy the base class's
    metamethods into the subclass instead, unless the subclass defines its own.
    Every key starting with `__` is copied, except `__index` and `__metatable`,
    so non-metamethod fields such as `__name` are copied too.

    > **Note: Why `setmetatable` is called by hand**
    >
    > Luau only lets a table type gain new fields after it is created if the
    > table came from a table literal, or from `setmetatable` called on one.
    > Calling `setmetatable` yourself keeps the subclass open, so methods can be
    > added to it afterward with full types. A table returned by `Class.extends`
    > itself could not be added to.

    @param base B -- The base class to extend
    @return { read __index: B } -- The frozen metatable to create the subclass with
    @error "[Class.extends()]: Expected a base class table, got {type(base)}" -- Thrown if `base` is not a table
    @error "[Class.extends()]: Cannot extend a sealed class" -- Thrown if `base` was sealed with [Class.sealed]
    @error "[Class.extends()]: Base class must not have an __index other than itself" -- Thrown if `base.__index` is set to anything other than `base`
    @error "[Class.extends()]: Cannot extend a class frozen with table.freeze() before being set up; use Class.sealed() instead" -- Thrown if `base` was frozen with `table.freeze()` before [Class.new] or [Class.sealed] could set it up
    @error "[Class.extends()]: Circular inheritance detected" -- Thrown if `base`'s inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.extends = Untyped.extends :: <B>(base: B) -> { read __index: B }

--[=[
    @function sealed
    @within Class
    @since [UNRELEASED]

    Seals a class, making it immutable and final. The class is set up as
    described in [Class.new], then frozen. The class is modified in place and
    returned.

    Sealing has two effects:
    * The class is frozen, so no fields or methods can be added, changed, or
      removed. The freeze is shallow, like `table.freeze()`, so tables stored in
      the class can still be modified.
    * The class cannot be extended with [Class.extends].

    Instances are not affected: they can still be changed, or frozen with
    `table.freeze()` to make immutable values:

    ```lua
    local Vector = {}

    function Vector.new(x: number, y: number)
        return table.freeze(Class.new(Vector, { x = x, y = y }))
    end

    -- define constants, functions, and methods...

    return Class.sealed(Vector)
    ```

    Define everything on the class before sealing it, since it cannot be changed
    afterward. Freezing a class with `table.freeze()` instead of sealing it is
    an error once the class needs setting up, since setting up writes to the
    class.

    Subclasses can be sealed too, as long as nothing needs to extend them.

    @param class T -- The class to seal
    @return T -- The same class, now sealed
    @error "[Class.sealed()]: Expected a class table, got {type(class)}" -- Thrown if `class` is not a table
    @error "[Class.sealed()]: Cannot seal a frozen table" -- Thrown if `class` is already frozen, including if it is already sealed
    @error "[Class.sealed()]: Class must not have an __index other than itself" -- Thrown if `class` or one of its base classes has an `__index` set to anything other than itself
    @error "[Class.sealed()]: Cannot set up a class frozen with table.freeze(); use Class.sealed() instead" -- Thrown if one of `class`'s base classes was frozen with `table.freeze()` before being set up
    @error "[Class.sealed()]: Circular inheritance detected" -- Thrown if `class`'s inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.sealed = Untyped.sealed :: <T>(class: T) -> T

--[=[
    @function isSealed
    @within Class
    @since [UNRELEASED]

    Returns `true` if the class was sealed with [Class.sealed]. Values that are
    not sealed classes, including tables frozen with `table.freeze()`, return
    `false`.

    ```lua
    local Person = {}
    Class.isSealed(Person) -- false
    Class.sealed(Person)
    Class.isSealed(Person) -- true
    Class.isSealed(table.freeze({})) -- false, since freezing is not sealing
    ```

    @param class any -- The class to check
    @return boolean -- Whether the class was sealed
]=]
Class.isSealed = Untyped.isSealed :: (class: any) -> boolean

--[=[
    @function new
    @within Class
    @since [UNRELEASED]

    Creates an instance of `class`.

    With one table, `fields` becomes the instance itself, not a copy, by setting
    its metatable to `class`. It defaults to a new, empty table.

    ```lua
    function Animal.new(name: string)
        return Class.new(Animal, { name = name })
    end
    ```

    With two tables, `fields` is copied into `inherited`, which becomes the
    instance. `inherited` is usually built by a base class's fields function,
    which keeps the base class's constructor logic in one place:

    ```lua
    function Dog.new(name: string, breed: string)
        return Class.new(Dog, Animal.fields(name), { breed = breed })
    end
    ```

    This is the same as `Class.new(Dog, Class.merge(Animal.fields(name), {
    breed = breed }))`; use [Class.merge] in a subclass's own fields function,
    so its subclasses can build on it in turn.

    The first time a class is used with `Class.new` or [Class.sealed], it is set
    up: its `__index` is set to itself, and its base class's metamethods are
    copied into it, as described in [Class.extends]. Its base classes are set up
    first, if they have not been already. This means:
    * Classes do not need `Class.__index = Class`, though setting it by hand is
      allowed.
    * Metamethods must be defined before the class's first instance is created.
      Ones added to a base class afterward are not inherited.
    * Instances created with `setmetatable` directly skip this setup, so they
      will not find the class's methods unless the class was already set up.

    The returned instance is typed with its fields and every method of `class`
    and its base classes.

    @param class C -- The class to create an instance of
    @param inherited I? -- Fields built by a base class, which become the instance (only when `fields` is also passed)
    @param fields F? -- The instance's own fields (defaults to a new, empty table)
    @return setmetatable<I & F, Metatable<C>> -- The new instance of `class`
    @error "[Class.new()]: Expected a class table, got {type(class)}" -- Thrown if `class` is not a table
    @error "[Class.new()]: Expected a fields table or nil, got {type(fields)}" -- Thrown if `fields` is neither a table nor `nil`
    @error "[Class.new()]: Expected inherited fields to be a table, got {type(inherited)}" -- Thrown if `inherited` is not a table
    @error "[Class.new()]: Cannot use frozen fields" -- Thrown if the table that becomes the instance is frozen (`"inherited fields"` when `inherited` is passed)
    @error "[Class.new()]: Cannot use fields that already have a metatable" -- Thrown if the table that becomes the instance already has a metatable, such as an instance of another class (`"inherited fields"` when `inherited` is passed)
    @error "[Class.new()]: Class must not have an __index other than itself" -- Thrown if `class` or one of its base classes has an `__index` set to anything other than itself
    @error "[Class.new()]: Cannot set up a class frozen with table.freeze(); use Class.sealed() instead" -- Thrown if `class` or one of its base classes was frozen with `table.freeze()` before being set up
    @error "[Class.new()]: Circular inheritance detected" -- Thrown if `class`'s inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.new = Untyped.new :: (<C>(class: C) -> setmetatable<{}, Metatable<C>>) & (
    <C, F>(class: C, fields: F) -> setmetatable<F, Metatable<C>>
) & (<C, I, F>(
    class: C,
    inherited: I,
    fields: F
) -> setmetatable<I & F, Metatable<C>>)

--[=[
    @function merge
    @within Class
    @since [UNRELEASED]

    Returns a new table with every field of `base`, then every field of
    `fields`, so `fields` wins where both have a key. Neither table is changed.

    Subclasses use it in their fields functions to build on their base class's
    fields, typed as both fields types:

    ```lua
    export type DogFields = AnimalFields & { breed: string }

    function Dog.fields(name: string, breed: string): DogFields
        return Class.merge(Animal.fields(name), { breed = breed })
    end

    function Dog.new(name: string, breed: string)
        return Class.new(Dog, Dog.fields(name, breed))
    end

    -- Puppy can now build on Dog's fields the same way
    function Puppy.new(name: string)
        return Class.new(Puppy, Dog.fields(name, "mutt"), { age = 0 })
    end
    ```

    A field in `fields` that replaces one in `base` with a different type makes
    the merged type of that field `never`, so keep shared fields' types the
    same.

    @param base A -- The fields to start from, such as a base class's fields
    @param fields B -- The fields to add or replace
    @return A & B -- A new table with the fields of both
    @error "[Class.merge()]: Expected base to be a table, got {type(base)}" -- Thrown if `base` is not a table
    @error "[Class.merge()]: Expected fields to be a table, got {type(fields)}" -- Thrown if `fields` is not a table
    @error "[Class.merge()]: Cannot merge base that has a metatable" -- Thrown if `base` has a metatable, such as an instance; merge fields tables, not instances
    @error "[Class.merge()]: Cannot merge fields that has a metatable" -- Thrown if `fields` has a metatable
]=]
Class.merge = Untyped.merge :: <A, B>(base: A, fields: B) -> A & B

--[=[
    @function isA
    @within Class
    @since [UNRELEASED]

    Returns `true` if `value` is an instance of `class` or one of its
    subclasses.

    The value's class is found with `getmetatable(value)`, then each base class
    is found through the `__index` of the previous class's metatable, as set up
    by [Class.extends]. Hierarchies built by hand the same way also work.

    `false` is returned if:
    * `value` or `class` is not a table,
    * `value` has no metatable,
    * `value`'s metatable is locked with a `__metatable` field that is not its
      class, or
    * `value` is a class rather than an instance: `Class.isA(Dog, Animal)` is
      `false`. Use [Class.isSubclassOf] to compare classes.

    ROBLOX `Instance`s always return `false`, since their metatables are locked.
    Use `Instance:IsA()` for those.

    ```lua
    local dog = Dog.new("Rex", "Labrador")
    Class.isA(dog, Dog) -- true
    Class.isA(dog, Animal) -- true, since Dog extends Animal
    Class.isA(Animal.new("Generic"), Dog) -- false
    Class.isA(Dog, Animal) -- false, since Dog is a class, not an instance
    Class.isA({}, Animal) -- false
    ```

    > **Note: `isA` does not narrow types**
    >
    > Luau has no way for a function to narrow its argument's type, so `value`
    > keeps its type after `if Class.isA(value, Dog) then`. To check a value and
    > get it typed as an instance of the class in one step, use [Class.tryCast]:
    >
    > ```lua
    > local dog = Class.tryCast(value, Dog)
    > if dog then
    >     dog:fetch() -- typed as a Dog
    > end
    > ```

    > **Note: `isA` vs `isSubclassOf`**
    >
    > `isA` takes an instance and checks its class, counting the class itself:
    > `Class.isA(dog, Dog)` is `true`. [Class.isSubclassOf] takes a class and
    > checks the classes it extends, not counting itself:
    > `Class.isSubclassOf(Dog, Dog)` is `false`.

    @param value any -- The value to check
    @param class any -- The class to check against
    @return boolean -- Whether `value` is an instance of `class` or one of its subclasses
    @error "[Class.isA()]: Circular inheritance detected" -- Thrown if the value's inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.isA = Untyped.isA :: (value: any, class: any) -> boolean

--[=[
    @function isSubclassOf
    @within Class
    @since [UNRELEASED]

    Returns `true` if `class` extends `base`, directly or through other classes.
    A class is not a subclass of itself.

    ```lua
    local Dog = setmetatable({}, Class.extends(Animal))
    local Puppy = setmetatable({}, Class.extends(Dog))

    Class.isSubclassOf(Dog, Animal) -- true
    Class.isSubclassOf(Puppy, Animal) -- true, through Dog
    Class.isSubclassOf(Dog, Dog) -- false, since a class does not extend itself
    Class.isSubclassOf(Animal, Dog) -- false
    ```

    `false` is returned if either argument is not a table.

    > **Note: `isSubclassOf` vs `isA`**
    >
    > `isSubclassOf` takes a class and checks the classes it extends, not
    > counting itself: `Class.isSubclassOf(Dog, Dog)` is `false`. [Class.isA]
    > takes an instance and checks its class, counting the class itself:
    > `Class.isA(dog, Dog)` is `true`. To check whether a class is `base` or
    > extends it, use `class == base or Class.isSubclassOf(class, base)`.

    @param class any -- The class to check
    @param base any -- The base class to check against
    @return boolean -- Whether `class` extends `base`
    @error "[Class.isSubclassOf()]: Circular inheritance detected" -- Thrown if the class's inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.isSubclassOf = Untyped.isSubclassOf :: (class: any, base: any) -> boolean

--[=[
    @function parentOf
    @within Class
    @since [UNRELEASED]

    Returns the class that `class` directly extends: the `__index` of its
    metatable. Returns `nil` for classes that extend nothing, and for values
    that are not tables.

    ```lua
    Class.parentOf(Puppy) -- Dog
    Class.parentOf(Dog) -- Animal
    Class.parentOf(Animal) -- nil
    ```

    To find an instance's class, use [Class.classOf]: `parentOf(instance)` is
    the instance's class only because instances' metatables are their classes,
    and is the wrong function to read that way.

    @param class any -- The class to find the base class of
    @return any -- The class's base class, or `nil`
]=]
Class.parentOf = Untyped.parentOf :: (class: any) -> any

--[=[
    @function classOf
    @within Class
    @since [UNRELEASED]

    Returns the class of an instance: its metatable. Returns `nil` for values
    that are not tables, and for tables with no metatable.

    ```lua
    local puppy = Puppy.new("Bit")
    Class.classOf(puppy) -- Puppy, not Dog or Animal
    Class.classOf(puppy) == Puppy -- an exact class check, unlike Class.isA
    Class.classOf({}) -- nil
    ```

    If the metatable is locked with a `__metatable` field, that field is
    returned instead, as with `getmetatable`.

    @param value any -- The instance to find the class of
    @return any -- The instance's class, or `nil`
]=]
Class.classOf = Untyped.classOf :: (value: any) -> any

--[=[
    @function cast
    @within Class
    @since [UNRELEASED]

    Returns `value` typed as an instance of `class`, after checking at runtime
    that it is an instance of `class` or one of its subclasses with [Class.isA].
    Throws an error if it is not.

    This is how subclass instances are passed where a [Class.IsA] of a base
    class is expected, since Luau does not accept them directly; see the caution
    in [Class]. It can also cast to a class between the value's class and the
    base class, keeping that class's fields and methods:

    ```lua
    local puppy = Puppy.new("Bit") -- Puppy extends Dog, which extends Animal
    greet(Class.cast(puppy, Animal)) -- greet takes a Luautils.IsA<typeof(Animal)>
    Class.cast(puppy, Dog):fetch() -- Dog's methods are kept
    Class.cast(puppy, Animal):fetch() -- type error, since Animals cannot fetch
    Class.cast(Animal.new("Generic"), Dog) -- error, since it is not a Dog
    ```

    Unlike `value :: any`, the value is checked, so the cast cannot be wrong
    about the class, and is only as loose as [Class.IsA]'s shape. Use
    [Class.tryCast] when the value might not be an instance of the class.

    @param value any -- The value to cast
    @param class C -- The class to cast to
    @return IsA<C> -- `value`, typed as an instance of `class`
    @error "[Class.cast()]: Expected a class table, got {type(class)}" -- Thrown if `class` is not a table
    @error "[Class.cast()]: Value is not an instance of the class" -- Thrown if `value` is not an instance of `class` or one of its subclasses
    @error "[Class.cast()]: Circular inheritance detected" -- Thrown if the value's inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.cast = Untyped.cast :: <C>(value: any, class: C) -> IsA<C>

--[=[
    @function tryCast
    @within Class
    @since [UNRELEASED]

    Returns `value` typed as an instance of `class` if it is an instance of
    `class` or one of its subclasses, or `nil` if it is not. This is [Class.isA]
    and [Class.cast] in one step, for checking values whose class is not known,
    since `isA` cannot narrow types:

    ```lua
    local function onHit(target: unknown)
        local enemy = Class.tryCast(target, Enemy)
        if enemy then
            enemy:hurt(10) -- typed as an Enemy
        end
    end
    ```

    @param value any -- The value to check and cast
    @param class C -- The class to cast to
    @return IsA<C>? -- `value`, typed as an instance of `class`, or `nil`
    @error "[Class.tryCast()]: Expected a class table, got {type(class)}" -- Thrown if `class` is not a table
    @error "[Class.tryCast()]: Circular inheritance detected" -- Thrown if the value's inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.tryCast = Untyped.tryCast :: <C>(value: any, class: C) -> IsA<C>?

return table.freeze(Class)
