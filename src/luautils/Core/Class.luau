--!strict

-- Class helpers library
-- author(s): @vuppyan

local fail = require("./Errors").errorWithScope("Class")

--[=[
    Helpers for writing classes in Luau: inheritance with [Class.extends],
    instance creation with [Class.new], immutability with [Class.sealed], and
    instance checks with [Class.isA].

    A class is a plain table of methods. Subclasses are created with
    `setmetatable({}, Class.extends(Base))`, and instances with
    `Class.new(Class, fields)`, which sets up the class's `__index` and
    inherited metamethods the first time it is used, so neither has to be
    written by hand:

    ```lua
    local Animal = {}

    function Animal.new(name: string)
        return Class.new(Animal, { name = name })
    end

    function Animal.speak(self): string
        return "..."
    end

    local Dog = setmetatable({}, Class.extends(Animal))

    function Dog.new(name: string, breed: string)
        return Class.new(Dog, { name = name, breed = breed })
    end

    function Dog.speak(self): string
        return "Woof!"
    end

    function Dog.fetch(self): string
        return `{self.name} fetches the ball`
    end

    local dog = Dog.new("Rex", "Labrador")
    dog:speak() -- "Woof!"
    dog:fetch() -- "Rex fetches the ball"
    dog.breed -- "Labrador"
    ```

    Everything above is fully type checked in `--!strict` mode: fields, the
    subclass's own methods, overrides, and inherited methods all have their
    real types.

    To accept instances of a class or any of its subclasses, type the
    parameter with [Class.IsA] and pass subclass instances through
    [Class.cast], which checks them at runtime:

    ```lua
    type AnyAnimal = Luautils.IsA<typeof(Animal)>

    local function greet(animal: AnyAnimal): string
        return `{animal.name} says {animal:speak()}`
    end

    greet(Animal.new("Generic")) -- base class instances can be passed directly
    greet(Class.cast(dog, Animal)) -- subclass instances need a cast
    ```

    :::caution Subclass instances are not their base class's type
    Passing `dog` directly to a parameter typed as an `Animal` instance is a
    type error, even when typed with [Class.IsA]. Luau only follows `__index`
    to plain tables when comparing types, and every subclass is a
    `setmetatable` type. This is a limit of Luau's type system and applies to
    hand-written classes too, which is why [Class.cast] exists.
    :::

    Error messages thrown by `Class` functions are prefixed with the function
    that threw them, such as `[Class.new()]: `, after the usual position prefix
    added by `error()`.

    @class Class
    @since [UNRELEASED]
]=]
local Class = {}

--[=[
    @type IsA<C> { [string]: any }
    @within Class
    @since [UNRELEASED]

    The type of an instance of the class `C` or any of its subclasses, viewed
    as an instance of `C`. `C` is the class's type, such as `typeof(Animal)`.

    The type is built from `C` and its base classes, and contains:
    * The fields of the instance returned by `C.new`, if `C` has a `new`
    constructor. Fields can be read and written.
    * Every method of `C` and its base classes, with `self` typed as `any` so
    subclass overrides fit. Methods can only be read.

    Constructors (`new`) and keys starting with `__`, such as metamethods, are
    left out, since subclasses usually change them.

    Base class instances can be passed directly where an `IsA<C>` is expected,
    but subclass instances must go through [Class.cast]; see the caution in
    [Class] for why.

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

    :::caution A class cannot use `IsA` of itself
    Using `IsA<typeof(Animal)>` in the definition of `Animal` itself, such as
    to type the `other` parameter of `Animal.equals`, makes the class's type
    refer to itself, which Luau's type functions cannot resolve, and breaks
    every type involving `Animal`. Leave such parameters unannotated, and use
    `IsA` only outside the class.
    :::

    The type only checks the shape of a value, not its class, so a table with
    the same fields and methods also fits. [Class.cast] checks the class at
    runtime.
]=]
export type function IsA(class: type): type
    local result = types.newtable()

    -- widens a method's `self` parameter to `any`, so overrides that type
    -- `self` as a subclass still fit
    local function widenSelf(method: type): type
        if not method:is("function") then
            return method
        end
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

    local function isIncluded(key: type): boolean
        local name = key:value()
        return type(name) ~= "string"
            or (name ~= "new" and string.sub(name, 1, 2) ~= "__")
    end

    -- fields, from the instance type returned by the constructor
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

    -- methods, from the class and its base classes, nearest first so
    -- overrides win
    local current: type? = class
    local depth = 0
    while current and current:is("table") and depth < 1024 do
        depth += 1
        for key, prop in current:properties() do
            if
                prop.read
                and isIncluded(key)
                and result:readproperty(key) == nil
            then
                result:setreadproperty(key, widenSelf(prop.read))
            end
        end
        local link = current:metatable()
        current = if link and link:is("table")
            then link:readproperty(types.singleton("__index"))
            else nil
    end

    return result
end

-- `new` has two signatures, since the fields type cannot be inferred when
-- `fields` is omitted
type New =
    (<C>(class: C) -> setmetatable<{}, { __index: C }>)
    & (<C, F>(class: C, fields: F) -> setmetatable<F, { __index: C }>)

-- classes whose __index and inherited metamethods have been set up
local prepared: { [any]: true } = setmetatable({}, { __mode = "k" }) :: any

local function parentOf(class: any): any
    local link = getmetatable(class)
    return if type(link) == "table" then rawget(link, "__index") else nil
end

local function isInheritedKey(k: any): boolean
    return type(k) == "string"
        and string.sub(k, 1, 2) == "__"
        and k ~= "__index"
        and k ~= "__metatable"
end

-- prevent function inlining for helpers that require call stack consistency
local Internal = {}

-- sets up `class` and its base classes, root first, so each class has
-- `__index` set to itself and a copy of its base class's metamethods
function Internal.prepare(class: any, functionName: string)
    if prepared[class] then
        return
    end

    -- collect the classes that still need setting up, from `class` to the
    -- root, using Floyd's tortoise and hare cycle checking
    local chain = {}
    local slow, fast = class, class
    while type(slow) == "table" and not prepared[slow] do
        table.insert(chain, slow)
        slow = parentOf(slow)
        fast = parentOf(parentOf(fast))
        if fast ~= nil and rawequal(slow, fast) then
            fail("Circular inheritance detected", 3, functionName)
        end
    end

    for i = #chain, 1, -1 do
        local current = chain[i]
        local index = rawget(current, "__index")
        if index ~= nil and not rawequal(index, current) then
            fail(
                "Class must not have an __index other than itself",
                3,
                functionName
            )
        end

        -- find everything to write before writing, so a frozen class fails
        -- cleanly instead of being half set up
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
                    "Cannot set up a frozen class; "
                        .. "use Class.sealed() instead of table.freeze()",
                    3,
                    functionName
                )
            end
            for k, v in pairs(inherited) do
                rawset(current, k, v)
            end
            rawset(current, "__index", current)
        end

        prepared[current] = true
    end
end

function Internal.isA(value: any, class: any, functionName: string): boolean
    if type(class) ~= "table" then
        return false
    end

    -- Floyd's tortoise and hare cycle checking
    local slow = getmetatable(value)
    local fast = slow
    while type(slow) == "table" do
        if rawequal(slow, class) then
            return true
        end

        slow = parentOf(slow)
        fast = parentOf(parentOf(fast))
        if fast ~= nil and rawequal(slow, fast) then
            fail(
                "Circular inheritance detected; "
                    .. "likely caused by setmetatable tampering",
                3,
                functionName
            )
        end
    end

    return false
end

function Internal.new(class: any, fields: any?): any
    if type(class) ~= "table" then
        fail(`Expected a class table, got {type(class)}`)
    elseif fields ~= nil and type(fields) ~= "table" then
        fail(`Expected a fields table or nil, got {type(fields)}`)
    elseif fields ~= nil and table.isfrozen(fields) then
        fail("Cannot use a frozen fields table")
    elseif fields ~= nil and getmetatable(fields) ~= nil then
        fail("Cannot use a fields table that already has a metatable")
    end

    Internal.prepare(class, "new")
    return setmetatable(fields or {}, class)
end

--[=[
    Returns the metatable to create a subclass of `base` with:

    ```lua
    local Dog = setmetatable({}, Class.extends(Animal))
    ```

    The returned metatable is `{ __index = base }`, frozen, so anything the
    subclass does not define is looked up on the base class: fields, methods,
    and constructors alike. Since constructors are inherited too, give each
    subclass its own `new`, or `Dog.new` will create `Animal`s.

    Metamethods such as `__tostring` and `__eq` are not looked up through
    `__index`, so [Class.new] and [Class.sealed] copy the base class's
    metamethods into the subclass instead, unless the subclass defines its own.
    Every key starting with `__` is copied, except `__index` and `__metatable`,
    so non-metamethod fields such as `__name` are copied too.

    :::info Why `setmetatable` is called by hand
    Luau only lets a table type gain new fields after it is created if the
    table came from a table literal, or from `setmetatable` called on one.
    Calling `setmetatable` yourself keeps the subclass open, so methods can be
    added to it afterward with full types. A table returned by `Class.extends`
    itself could not be added to.
    :::

    @since [UNRELEASED]
    @param base B -- The base class to extend
    @return { read __index: B } -- The frozen metatable to create the subclass with
    @error "[Class.extends()]: Expected a base class table, got {type(base)}" -- Thrown if `base` is not a table
    @error "[Class.extends()]: Cannot extend a sealed base class" -- Thrown if `base` was sealed with [Class.sealed]
    @error "[Class.extends()]: Base class must not have an __index other than itself" -- Thrown if `base.__index` is set to anything other than `base`
    @error "[Class.extends()]: Circular inheritance detected in base class" -- Thrown if `base`'s inheritance chain loops, which can only happen if metatables were changed by hand
]=]
function Class.extends<B>(base: B): { read __index: B }
    if type(base) ~= "table" then
        fail(`Expected a base class table, got {type(base)}`)
    elseif Class.isSealed(base) then
        fail("Cannot extend a sealed base class")
    end

    local index = rawget(base :: any, "__index")
    if index ~= nil and not rawequal(index, base) then
        fail("Base class must not have an __index other than itself")
    end

    -- Floyd's tortoise and hare cycle checking
    local slow, fast = parentOf(base), parentOf(parentOf(base))
    while type(slow) == "table" do
        if fast ~= nil and rawequal(slow, fast) then
            fail("Circular inheritance detected in base class")
        end
        slow = parentOf(slow)
        fast = parentOf(parentOf(fast))
    end

    return table.freeze({ __index = base })
end

--[=[
    Creates an instance of `class`, by setting `fields`' metatable to `class`.
    `fields` is the instance itself, not a copy, and defaults to a new, empty
    table.

    ```lua
    function Dog.new(name: string, breed: string)
        return Class.new(Dog, { name = name, breed = breed })
    end
    ```

    The first time a class is used with `Class.new` or [Class.sealed], it is
    set up: its `__index` is set to itself, and its base class's metamethods
    are copied into it, as described in [Class.extends]. Its base classes are
    set up first, if they have not been already. This means:
    * Classes do not need `Class.__index = Class`, though setting it by hand
    is allowed.
    * Metamethods must be defined before the class's first instance is
    created. Ones added to a base class afterward are not inherited.
    * Instances created with `setmetatable` directly skip this setup, so they
    will not find the class's methods unless the class was already set up.

    The returned instance is typed with the fields and every method of `class`
    and its base classes.

    @function new
    @within Class
    @since [UNRELEASED]
    @param class C -- The class to create an instance of
    @param fields F? -- The instance's fields (defaults to a new, empty table)
    @return setmetatable<F, { __index: C }> -- `fields`, now an instance of `class`
    @error "[Class.new()]: Expected a class table, got {type(class)}" -- Thrown if `class` is not a table
    @error "[Class.new()]: Expected a fields table or nil, got {type(fields)}" -- Thrown if `fields` is neither a table nor `nil`
    @error "[Class.new()]: Cannot use a frozen fields table" -- Thrown if `fields` is frozen
    @error "[Class.new()]: Cannot use a fields table that already has a metatable" -- Thrown if `fields` already has a metatable, such as an instance of another class
    @error "[Class.new()]: Class must not have an __index other than itself" -- Thrown if `class` or one of its base classes has an `__index` set to anything other than itself
    @error "[Class.new()]: Cannot set up a frozen class; use Class.sealed() instead of table.freeze()" -- Thrown if `class` or one of its base classes was frozen with `table.freeze()` before being set up
    @error "[Class.new()]: Circular inheritance detected" -- Thrown if `class`'s inheritance chain loops, which can only happen if metatables were changed by hand
]=]
Class.new = Internal.new :: New

--[=[
    Seals a class, making it immutable. The class is set up as described in
    [Class.new], then its `__metatable` field is set to itself and it is
    frozen. The class is modified in place and returned.

    Sealing has three effects:
    * The class is frozen, so no fields or methods can be added, changed, or
    removed. The freeze is shallow, like `table.freeze()`, so tables stored in
    the class can still be modified.
    * Instances' metatables are protected: `getmetatable(instance)` still
    returns the class, but `setmetatable(instance, ...)` throws an error.
    * The class cannot be extended with [Class.extends], making it final.

    Define everything on the class before sealing it, since it cannot be
    changed afterward. Sealing is for finished, immutable classes, not for
    freezing regular tables, which should be done with `table.freeze()`.

    ```lua
    local Person = {}

    function Person.new(name: string)
        return Class.new(Person, { name = name })
    end

    -- define constants, functions, and methods...

    return Class.sealed(Person) -- class is immutable
    ```

    Subclasses can be sealed too, as long as nothing needs to extend them:

    ```lua
    local Student = setmetatable({}, Class.extends(Person))

    -- define constants, functions, and methods...

    return Class.sealed(Student)
    ```

    @since [UNRELEASED]
    @param class T -- The class to seal
    @return T -- The same class, now sealed
    @error "[Class.sealed()]: Expected a class table, got {type(class)}" -- Thrown if `class` is not a table
    @error "[Class.sealed()]: Cannot seal a frozen table" -- Thrown if `class` is already frozen, including if it is already sealed
    @error "[Class.sealed()]: Class must not have an __index other than itself" -- Thrown if `class` or one of its base classes has an `__index` set to anything other than itself
    @error "[Class.sealed()]: Cannot set up a frozen class; use Class.sealed() instead of table.freeze()" -- Thrown if one of `class`'s base classes was frozen with `table.freeze()` before being set up
    @error "[Class.sealed()]: Circular inheritance detected" -- Thrown if `class`'s inheritance chain loops, which can only happen if metatables were changed by hand
]=]
function Class.sealed<T>(class: T): T
    if type(class) ~= "table" then
        fail(`Expected a class table, got {type(class)}`)
    elseif table.isfrozen(class) then
        fail("Cannot seal a frozen table")
    end

    Internal.prepare(class, "sealed")
    rawset(class :: any, "__metatable", class)
    return table.freeze(class)
end

--[=[
    Returns `true` if the class has been sealed with [Class.sealed].

    A class is sealed if its own `__metatable` field is itself and it is
    frozen. Values that are not tables always return `false`.

    ```lua
    local Person = {}

    Class.isSealed(Person) -- false
    Class.sealed(Person)
    Class.isSealed(Person) -- true
    Class.isSealed(table.freeze({})) -- false, since freezing alone is not sealing
    ```

    @since [UNRELEASED]
    @param class any -- The class to check
    @return boolean -- Whether the class has been sealed
]=]
function Class.isSealed(class: any): boolean
    if type(class) ~= "table" then
        return false
    end
    return rawequal(rawget(class, "__metatable"), class)
        and table.isfrozen(class)
end

--[=[
    Returns `true` if the value is an instance of the class or one of its
    subclasses.

    The value's class is found with `getmetatable(value)`, then each base class
    is found through the `__index` of the previous class's metatable, as set up
    by [Class.extends]. Hierarchies built by hand the same way also work.

    `false` is returned if:
    * `class` is not a table,
    * `value` has no metatable,
    * `value`'s metatable is locked with a `__metatable` field that is not its
    class (sealed classes are fine, since their `__metatable` is the class
    itself), or
    * `value` is a class rather than an instance: `Class.isA(Dog, Animal)` is
    `false`.

    ROBLOX `Instance`s always return `false`, since their metatables are locked.
    Use `Instance:IsA()` for those.

    ```lua
    local Animal = {}
    local Dog = setmetatable({}, Class.extends(Animal))
    local dog = Class.new(Dog)

    Class.isA(dog, Dog) -- true
    Class.isA(dog, Animal) -- true, since Dog extends Animal
    Class.isA(Class.new(Animal), Dog) -- false
    Class.isA(Dog, Animal) -- false, since Dog is a class, not an instance
    Class.isA({}, Animal) -- false
    ```

    @since [UNRELEASED]
    @param value any -- The value to check
    @param class any -- The class to check against
    @return boolean -- Whether the value is an instance of the class or one of its subclasses
    @error "[Class.isA()]: Circular inheritance detected; likely caused by setmetatable tampering" -- Thrown if the value's inheritance chain loops, which can only happen if metatables were changed by hand
]=]
function Class.isA(value: any, class: any): boolean
    return Internal.isA(value, class, "isA")
end

--[=[
    Returns `value` typed as an instance of `class`, after checking at runtime
    that it is an instance of `class` or one of its subclasses with
    [Class.isA]. Throws an error if it is not.

    This is how subclass instances are passed where a [Class.IsA] of a base
    class is expected, since Luau does not accept them directly; see the
    caution in [Class]. It can also cast to a class between the value's class
    and the base class, keeping that class's fields and methods:

    ```lua
    local puppy = Puppy.new("Bit") -- Puppy extends Dog, which extends Animal

    greet(Class.cast(puppy, Animal)) -- greet takes a Luautils.IsA<typeof(Animal)>
    Class.cast(puppy, Dog):fetch() -- Dog's methods are kept
    Class.cast(puppy, Animal):fetch() -- type error, since Animals cannot fetch
    Class.cast(Animal.new("Generic"), Dog) -- error, since it is not a Dog
    ```

    Unlike `value :: any`, the value is checked, so the cast cannot be wrong
    about the class, and is only as loose as [Class.IsA]'s shape.

    @since [UNRELEASED]
    @param value any -- The value to cast
    @param class C -- The class to cast to
    @return IsA<C> -- `value`, typed as an instance of `class`
    @error "[Class.cast()]: Expected a class table, got {type(class)}" -- Thrown if `class` is not a table
    @error "[Class.cast()]: Value is not an instance of the class" -- Thrown if `value` is not an instance of `class` or one of its subclasses
    @error "[Class.cast()]: Circular inheritance detected; likely caused by setmetatable tampering" -- Thrown if the value's inheritance chain loops, which can only happen if metatables were changed by hand
]=]
function Class.cast<C>(value: any, class: C): IsA<C>
    if type(class) ~= "table" then
        fail(`Expected a class table, got {type(class)}`)
    elseif not Internal.isA(value, class, "cast") then
        fail("Value is not an instance of the class")
    end
    return value
end

return table.freeze(Class)
