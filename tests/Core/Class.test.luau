--!strict

-- Class tests
-- by @vuppyan

local test = require("@std/test")
local Helpers = require("../Helpers")
local Class = require("../../src/luautils/Core/Class")

-- fixtures

-- a concrete stand-in for any class, since `setmetatable` types cannot be
-- built from values typed `any`
type AnyClass = { [any]: any }

-- a fresh, empty class that has not been set up
local function newClass(): AnyClass
    return {}
end

-- a fresh subclass of `base`, created the documented way
local function subclass(base: AnyClass): AnyClass
    return setmetatable({}, Class.extends(base)) :: any
end

-- a class chain `depth` levels deep, returned as (root, leaf)
local function chain(depth: number): (AnyClass, AnyClass)
    local root = newClass()
    local leaf = root
    for _ = 1, depth do
        leaf = subclass(leaf)
    end
    return root, leaf
end

-- two classes whose metatables point at each other, which `extends` never
-- builds on its own
local function loop(): (AnyClass, AnyClass)
    local a, b = newClass(), newClass()
    setmetatable(a, { __index = b })
    setmetatable(b, { __index = a })
    return a, b
end

test.suite("module", function(suite)
    suite:case("Class is frozen", function(asserts)
        asserts.eq(true, table.isfrozen(Class))
    end)
end)

test.suite("extends()", function(suite)
    suite:case(
        "returns a frozen { __index = base } metatable",
        function(asserts)
            local base = newClass()
            local link = Class.extends(base)

            asserts.eq(base, link.__index)
            asserts.eq(true, table.isfrozen(link))
        end
    )

    suite:case("returns a new metatable each call", function(asserts)
        local base = newClass()
        asserts.neq(Class.extends(base), Class.extends(base))
    end)

    suite:case("does not modify the base class", function(asserts)
        local base = newClass()
        Class.extends(base)

        asserts.eq(nil, rawget(base, "__index"))
        asserts.eq(nil, getmetatable(base))
    end)

    suite:case("subclasses find base class members", function(asserts)
        local base = newClass()
        base.KIND = "animal"
        function base.speak()
            return "..."
        end
        local sub = subclass(base)

        asserts.eq("animal", sub.KIND)
        asserts.eq("...", sub.speak())
    end)

    suite:case("accepts a base class whose __index is itself", function(asserts)
        local base = newClass()
        base.__index = base

        asserts.eq(base, Class.extends(base).__index)
    end)

    suite:case("accepts set-up and subclassed base classes", function(asserts)
        local base = subclass(newClass())
        Class.new(base)

        asserts.eq(base, Class.extends(base).__index)
    end)

    suite:case("allows chains deeper than 32 levels", function(asserts)
        local root, leaf = chain(40)
        asserts.eq(true, Class.isA(Class.new(leaf), root))
    end)

    suite:case("non-table base classes throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.extends(5 :: any)
        end, "[Class.extends()]: Expected a base class table, got number")
        Helpers.throwsWith(asserts, function()
            Class.extends(nil :: any)
        end, "[Class.extends()]: Expected a base class table, got nil")
    end)

    suite:case("sealed base classes throw", function(asserts)
        local base = Class.sealed(newClass())

        Helpers.throwsWith(asserts, function()
            Class.extends(base)
        end, "[Class.extends()]: Cannot extend a sealed class")
    end)

    suite:case("a foreign base __index throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Class.extends({ __index = {} })
            end,
            "[Class.extends()]: Base class must not have an __index other "
                .. "than itself"
        )
    end)

    suite:case("circular base classes throw", function(asserts)
        local a = loop()

        Helpers.throwsWith(asserts, function()
            Class.extends(a)
        end, "[Class.extends()]: Circular inheritance detected")
    end)

    suite:case("a base class that is its own parent throws", function(asserts)
        local base = newClass()
        setmetatable(base, { __index = base })

        Helpers.throwsWith(asserts, function()
            Class.extends(base)
        end, "[Class.extends()]: Circular inheritance detected")
    end)

    suite:case("frozen base classes that need setup throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Class.extends(table.freeze(newClass()))
            end,
            "[Class.extends()]: Cannot extend a class frozen with "
                .. "table.freeze() before being set up"
        )
    end)

    suite:case(
        "frozen base classes missing inherited keys throw",
        function(asserts)
            local root = newClass()
            function root.__tostring()
                return "root"
            end
            local base = subclass(root)
            base.__index = base
            table.freeze(base)

            Helpers.throwsWith(
                asserts,
                function()
                    Class.extends(base)
                end,
                "[Class.extends()]: Cannot extend a class frozen with "
                    .. "table.freeze() before being set up"
            )
        end
    )

    suite:case(
        "frozen base classes that need no setup can be extended",
        function(asserts)
            local base = newClass()
            base.__index = base
            table.freeze(base)
            local sub = subclass(base)

            asserts.eq(true, Class.isA(Class.new(sub), base))
        end
    )

    suite:case(
        "base classes frozen after being set up can be extended",
        function(asserts)
            local base = newClass()
            Class.new(base)
            table.freeze(base)
            local sub = subclass(base)

            asserts.eq(true, Class.isA(Class.new(sub), base))
        end
    )

    suite:case("errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.extends(5 :: any)
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.extends()]: `)
    end)
end)

test.suite("new()", function(suite)
    suite:case("returns fields as an instance of the class", function(asserts)
        local class = newClass()
        local fields = { name = "Rex" }
        local instance = Class.new(class, fields)

        asserts.eq(fields, instance)
        asserts.eq(class, getmetatable(instance))
        asserts.eq("Rex", instance.name)
    end)

    suite:case("defaults to a new, empty instance", function(asserts)
        local class = newClass()
        local a = Class.new(class)
        local b = Class.new(class)

        asserts.eq(class, getmetatable(a))
        asserts.eq(nil, next(a :: any))
        asserts.neq(a, b)
    end)

    suite:case("sets the class's __index to itself", function(asserts)
        local class = newClass()
        Class.new(class)

        asserts.eq(class, rawget(class, "__index"))
    end)

    suite:case("keeps an __index already set to the class", function(asserts)
        local class = newClass()
        class.__index = class
        Class.new(class)

        asserts.eq(class, rawget(class, "__index"))
    end)

    suite:case("instances find class methods", function(asserts)
        local class = newClass()
        function class.greet()
            return "hi"
        end

        asserts.eq("hi", (Class.new(class) :: any).greet())
    end)

    suite:case("instances find base class methods", function(asserts)
        local root, leaf = chain(3)
        function root.speak()
            return "..."
        end

        asserts.eq("...", (Class.new(leaf) :: any).speak())
    end)

    suite:case("subclass methods override base methods", function(asserts)
        local base = newClass()
        function base.speak()
            return "..."
        end
        local sub = subclass(base)
        function sub.speak()
            return "Woof!"
        end

        asserts.eq("Woof!", (Class.new(sub) :: any).speak())
        asserts.eq("...", (Class.new(base) :: any).speak())
    end)

    suite:case("instances see methods added later", function(asserts)
        local base = newClass()
        local instance = Class.new(subclass(base))
        function base.late()
            return "late"
        end

        asserts.eq("late", (instance :: any).late())
    end)

    suite:case("sets up unused base classes", function(asserts)
        local root = newClass()
        local base = subclass(root)
        Class.new(subclass(base))

        asserts.eq(root, rawget(root, "__index"))
        asserts.eq(base, rawget(base, "__index"))
    end)

    suite:case("copies base class metamethods", function(asserts)
        local base = newClass()
        function base.__tostring()
            return "base"
        end
        local sub = subclass(base)

        asserts.eq("base", tostring(Class.new(sub)))
        asserts.eq(base.__tostring, rawget(sub, "__tostring"))
    end)

    suite:case("copies metamethods through many levels", function(asserts)
        local root, leaf = chain(3)
        function root.__tostring()
            return "root"
        end

        asserts.eq("root", tostring(Class.new(leaf)))
    end)

    suite:case("does not override subclass metamethods", function(asserts)
        local base = newClass()
        function base.__tostring()
            return "base"
        end
        local sub = subclass(base)
        function sub.__tostring()
            return "sub"
        end

        asserts.eq("sub", tostring(Class.new(sub)))
    end)

    suite:case("copies every __ key except __index", function(asserts)
        local base = newClass()
        base.__name = "Base"
        local sub = subclass(base)
        Class.new(sub)

        asserts.eq("Base", rawget(sub, "__name"))
        asserts.eq(sub, rawget(sub, "__index"))
    end)

    suite:case("does not copy non-__ keys", function(asserts)
        local base = newClass()
        base.field = 1
        base._private = 2
        local sub = subclass(base)
        Class.new(sub)

        asserts.eq(nil, rawget(sub, "field"))
        asserts.eq(nil, rawget(sub, "_private"))
    end)

    suite:case("does not copy metamethods added after setup", function(asserts)
        local base = newClass()
        local sub = subclass(base)
        Class.new(sub)
        function base.__tostring()
            return "base"
        end

        asserts.eq(nil, rawget(sub, "__tostring"))
    end)

    suite:case("works with sealed classes", function(asserts)
        local class = newClass()
        function class.greet()
            return "hi"
        end
        Class.sealed(class)

        asserts.eq("hi", (Class.new(class) :: any).greet())
    end)

    suite:case("accepts frozen classes that need no setup", function(asserts)
        local class = newClass()
        class.__index = class
        table.freeze(class)

        asserts.eq(class, getmetatable(Class.new(class)))
    end)

    suite:case("non-table classes throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.new(5 :: any)
        end, "[Class.new()]: Expected a class table, got number")
    end)

    suite:case("non-table fields throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            (Class.new :: any)(newClass(), 5)
        end, "[Class.new()]: Expected a fields table or nil, got number")
    end)

    suite:case("frozen fields throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.new(newClass(), table.freeze({}))
        end, "[Class.new()]: Cannot use frozen fields")
    end)

    suite:case("fields with a metatable throw", function(asserts)
        local other = Class.new(newClass())

        Helpers.throwsWith(asserts, function()
            Class.new(newClass(), other)
        end, "[Class.new()]: Cannot use fields that already have a metatable")
    end)

    suite:case("a foreign __index throws", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.new({ __index = {} })
        end, "[Class.new()]: Class must not have an __index other than itself")
    end)

    suite:case("a foreign base class __index throws", function(asserts)
        local base = newClass()
        local sub = subclass(base)
        base.__index = {}

        Helpers.throwsWith(asserts, function()
            Class.new(sub)
        end, "[Class.new()]: Class must not have an __index other than itself")
    end)

    suite:case("frozen classes that need setup throw", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Class.new(table.freeze(newClass()))
            end,
            "[Class.new()]: Cannot set up a class frozen with table.freeze(); "
                .. "use Class.sealed() instead"
        )
    end)

    suite:case("failed setup leaves the class untouched", function(asserts)
        local base = newClass()
        function base.__tostring()
            return "base"
        end
        local sub = subclass(base)
        sub.__index = sub
        table.freeze(sub)
        pcall(function()
            Class.new(sub)
        end)

        asserts.eq(nil, rawget(sub, "__tostring"))
    end)

    suite:case("circular inheritance throws", function(asserts)
        local a = loop()

        Helpers.throwsWith(asserts, function()
            Class.new(a)
        end, "[Class.new()]: Circular inheritance detected")
    end)

    suite:case("errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.new(5 :: any)
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.new()]: `)
    end)

    suite:case("setup errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.new({ __index = {} })
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.new()]: `)
    end)
end)

test.suite("new() with inherited fields", function(suite)
    suite:case(
        "returns the inherited fields as an instance of the class",
        function(asserts)
            local sub = subclass(newClass())
            local inherited = { name = "Rex" }
            local result = Class.new(sub, inherited, { breed = "Labrador" })

            asserts.eq(inherited, result)
            asserts.eq(sub, getmetatable(result))
            asserts.eq("Rex", result.name)
            asserts.eq("Labrador", result.breed)
        end
    )

    suite:case("fields overwrite inherited fields", function(asserts)
        local sub = subclass(newClass())
        local result = Class.new(sub, { name = "Rex" }, { name = "Bit" })

        asserts.eq("Bit", result.name)
    end)

    suite:case("fields can be nil or frozen", function(asserts)
        local sub = subclass(newClass())
        -- `nil` fields are allowed at runtime, but untyped, since `nil & B`
        -- is uninhabited
        local a = (Class.new :: any)(sub, {}, nil)
        local b = Class.new(sub, {}, table.freeze({ x = 1 }))

        asserts.eq(sub, getmetatable(a))
        asserts.eq(1, b.x)
    end)

    suite:case("sets up the class", function(asserts)
        local base = newClass()
        function base.__tostring()
            return "base"
        end
        local sub = subclass(base)
        local result = Class.new(sub, {}, {})

        asserts.eq(sub, rawget(sub, "__index"))
        asserts.eq("base", tostring(result))
    end)

    suite:case("bad inherited fields throw", function(asserts)
        local sub = subclass(newClass())
        local new = Class.new :: any

        Helpers.throwsWith(
            asserts,
            function()
                new(sub, 5, {})
            end,
            "[Class.new()]: Expected inherited fields to be a table, got number"
        )
        Helpers.throwsWith(asserts, function()
            Class.new(sub, table.freeze({}), {})
        end, "[Class.new()]: Cannot use frozen inherited fields")
        Helpers.throwsWith(
            asserts,
            function()
                Class.new(sub, Class.new(newClass()), {})
            end,
            "[Class.new()]: Cannot use inherited fields that already have a "
                .. "metatable"
        )
    end)

    suite:case("bad fields throw", function(asserts)
        local sub = subclass(newClass())
        local new = Class.new :: any

        Helpers.throwsWith(asserts, function()
            new(sub, {}, 5)
        end, "[Class.new()]: Expected a fields table or nil, got number")
    end)

    suite:case("errors blame the caller", function(asserts)
        local sub = subclass(newClass())
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.new(sub, table.freeze({}), {})
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.new()]: `)
    end)
end)

test.suite("sealed()", function(suite)
    suite:case("returns the same class", function(asserts)
        local class = newClass()
        asserts.eq(class, Class.sealed(class))
    end)

    suite:case("freezes the class", function(asserts)
        local class = Class.sealed(newClass())

        asserts.eq(true, table.isfrozen(class))
        Helpers.throwsWith(asserts, function()
            class.method = print
        end, "readonly")
    end)

    suite:case("does not set __metatable", function(asserts)
        local class = Class.sealed(newClass())
        asserts.eq(nil, rawget(class, "__metatable"))
    end)

    suite:case("sets up the class first", function(asserts)
        local base = newClass()
        function base.__tostring()
            return "base"
        end
        local sub = Class.sealed(subclass(base))

        asserts.eq(sub, rawget(sub, "__index"))
        asserts.eq(base.__tostring, rawget(sub, "__tostring"))
    end)

    suite:case("instances still report the class", function(asserts)
        local class = Class.sealed(newClass())
        asserts.eq(class, getmetatable(Class.new(class)))
    end)

    suite:case("instances can be frozen", function(asserts)
        local class = Class.sealed(newClass())
        local instance = table.freeze(Class.new(class, { x = 1 }))

        asserts.eq(true, table.isfrozen(instance))
        asserts.eq(class, getmetatable(instance))
    end)

    suite:case("freezes shallowly", function(asserts)
        local class = newClass()
        class.items = {}
        Class.sealed(class)

        class.items.a = 1
        asserts.eq(1, class.items.a)
    end)

    suite:case("seals subclasses", function(asserts)
        local base = newClass()
        local sub = Class.sealed(subclass(base))

        asserts.eq(true, Class.isSealed(sub))
        asserts.eq(true, Class.isA(Class.new(sub), base))
    end)

    suite:case("non-tables throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.sealed(5 :: any)
        end, "[Class.sealed()]: Expected a class table, got number")
        Helpers.throwsWith(asserts, function()
            Class.sealed(nil :: any)
        end, "[Class.sealed()]: Expected a class table, got nil")
    end)

    suite:case("frozen tables throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.sealed(table.freeze(newClass()))
        end, "[Class.sealed()]: Cannot seal a frozen table")
    end)

    suite:case("sealing twice throws", function(asserts)
        local class = Class.sealed(newClass())

        Helpers.throwsWith(asserts, function()
            Class.sealed(class)
        end, "[Class.sealed()]: Cannot seal a frozen table")
    end)

    suite:case("a foreign __index throws", function(asserts)
        Helpers.throwsWith(
            asserts,
            function()
                Class.sealed({ __index = {} })
            end,
            "[Class.sealed()]: Class must not have an __index other than "
                .. "itself"
        )
    end)

    suite:case("frozen base classes that need setup throw", function(asserts)
        local base = newClass()
        local sub = subclass(base)
        table.freeze(base)

        Helpers.throwsWith(
            asserts,
            function()
                Class.sealed(sub)
            end,
            "[Class.sealed()]: Cannot set up a class frozen with table.freeze(); "
                .. "use Class.sealed() instead"
        )
    end)

    suite:case("circular inheritance throws", function(asserts)
        local a = loop()

        Helpers.throwsWith(asserts, function()
            Class.sealed(a)
        end, "[Class.sealed()]: Circular inheritance detected")
    end)

    suite:case("errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.sealed(5 :: any)
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.sealed()]: `)
    end)

    suite:case("setup errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.sealed({ __index = {} })
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.sealed()]: `)
    end)
end)

test.suite("isSealed()", function(suite)
    suite:case("sealed classes are sealed", function(asserts)
        asserts.eq(true, Class.isSealed(Class.sealed(newClass())))
    end)

    suite:case("unsealed classes are not sealed", function(asserts)
        local class = newClass()
        Class.new(class)

        asserts.eq(false, Class.isSealed(class))
        asserts.eq(false, Class.isSealed(subclass(newClass())))
    end)

    suite:case("frozen tables are not sealed", function(asserts)
        asserts.eq(false, Class.isSealed(table.freeze({})))
    end)

    suite:case("requires a frozen class", function(asserts)
        local class = newClass()
        class.__metatable = class

        asserts.eq(false, Class.isSealed(class))
    end)

    suite:case("requires __metatable to be the class itself", function(asserts)
        local class = newClass()
        class.__metatable = "locked"
        table.freeze(class)

        asserts.eq(false, Class.isSealed(class))
    end)

    suite:case("instances are not sealed", function(asserts)
        asserts.eq(false, Class.isSealed(Class.new(Class.sealed(newClass()))))
    end)

    suite:case("non-tables are not sealed", function(asserts)
        asserts.eq(false, Class.isSealed(nil))
        asserts.eq(false, Class.isSealed(5))
        asserts.eq(false, Class.isSealed("class"))
        asserts.eq(false, Class.isSealed(print))
    end)
end)

test.suite("isA()", function(suite)
    suite:case("instances are instances of their class", function(asserts)
        local class = newClass()
        asserts.eq(true, Class.isA(Class.new(class), class))
    end)

    suite:case("instances are instances of base classes", function(asserts)
        local base = newClass()
        local sub = subclass(base)
        local leaf = subclass(sub)
        local instance = Class.new(leaf)

        asserts.eq(true, Class.isA(instance, leaf))
        asserts.eq(true, Class.isA(instance, sub))
        asserts.eq(true, Class.isA(instance, base))
    end)

    suite:case("instances are not instances of subclasses", function(asserts)
        local base = newClass()
        local sub = subclass(base)

        asserts.eq(false, Class.isA(Class.new(base), sub))
    end)

    suite:case("instances are not instances of siblings", function(asserts)
        local base = newClass()
        local a = subclass(base)
        local b = subclass(base)

        asserts.eq(false, Class.isA(Class.new(a), b))
    end)

    suite:case("instances of unrelated classes are not", function(asserts)
        asserts.eq(false, Class.isA(Class.new(newClass()), newClass()))
    end)

    suite:case("works with sealed classes", function(asserts)
        local base = newClass()
        local sub = Class.sealed(subclass(base))
        local instance = Class.new(sub)

        asserts.eq(true, Class.isA(instance, sub))
        asserts.eq(true, Class.isA(instance, base))
    end)

    suite:case("works on chains deeper than 32 levels", function(asserts)
        local root, leaf = chain(40)
        asserts.eq(true, Class.isA(Class.new(leaf), root))
        asserts.eq(false, Class.isA(Class.new(leaf), newClass()))
    end)

    suite:case("works on hierarchies built by hand", function(asserts)
        local base = newClass()
        base.__index = base
        local sub = newClass()
        sub.__index = sub
        setmetatable(sub, { __index = base })

        asserts.eq(true, Class.isA(setmetatable({}, sub), base))
    end)

    suite:case("classes are not instances", function(asserts)
        local base = newClass()
        local sub = subclass(base)

        asserts.eq(false, Class.isA(sub, base))
        asserts.eq(false, Class.isA(base, base))
    end)

    suite:case("values without a metatable are not instances", function(asserts)
        local class = newClass()

        asserts.eq(false, Class.isA({}, class))
        asserts.eq(false, Class.isA(nil, class))
        asserts.eq(false, Class.isA(5, class))
        asserts.eq(false, Class.isA(print, class))
    end)

    suite:case("locked metatables are not instances", function(asserts)
        local class = newClass()
        class.__metatable = "locked"

        asserts.eq(false, Class.isA(Class.new(class), class))
    end)

    suite:case("non-table classes return false", function(asserts)
        local instance = Class.new(newClass())

        asserts.eq(false, Class.isA(instance, nil))
        asserts.eq(false, Class.isA(instance, "class"))
        asserts.eq(false, Class.isA("hi", "string"))
    end)

    suite:case("does not use __eq", function(asserts)
        local eqSpy = Helpers.spy(function()
            return true
        end)
        local base = newClass()
        setmetatable(base, { __eq = eqSpy.fn })
        local other = newClass()
        setmetatable(other, { __eq = eqSpy.fn })

        asserts.eq(false, Class.isA(setmetatable({}, base), other))
        asserts.eq(0, eqSpy.calls)
    end)

    suite:case("circular inheritance throws", function(asserts)
        local a = loop()

        Helpers.throwsWith(asserts, function()
            Class.isA(setmetatable({}, a), newClass())
        end, "[Class.isA()]: Circular inheritance detected")
    end)

    suite:case("errors blame the caller", function(asserts)
        local a = loop()
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.isA(setmetatable({}, a), newClass())
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.isA()]: `)
    end)
end)

test.suite("isSubclassOf()", function(suite)
    suite:case("direct subclasses are subclasses", function(asserts)
        local base = newClass()

        asserts.eq(true, Class.isSubclassOf(subclass(base), base))
    end)

    suite:case("subclasses at any depth are subclasses", function(asserts)
        local root, leaf = chain(5)

        asserts.eq(true, Class.isSubclassOf(leaf, root))
    end)

    suite:case("a class is not its own subclass", function(asserts)
        local base = newClass()
        local sub = subclass(base)

        asserts.eq(false, Class.isSubclassOf(base, base))
        asserts.eq(false, Class.isSubclassOf(sub, sub))
    end)

    suite:case("base classes are not subclasses", function(asserts)
        local base = newClass()

        asserts.eq(false, Class.isSubclassOf(base, subclass(base)))
    end)

    suite:case("unrelated classes are not subclasses", function(asserts)
        asserts.eq(
            false,
            Class.isSubclassOf(subclass(newClass()), subclass(newClass()))
        )
    end)

    suite:case("works with sealed classes", function(asserts)
        local base = newClass()
        local sub = Class.sealed(subclass(base))

        asserts.eq(true, Class.isSubclassOf(sub, base))
    end)

    suite:case("non-tables return false", function(asserts)
        local base = newClass()

        asserts.eq(false, Class.isSubclassOf(5, base))
        asserts.eq(false, Class.isSubclassOf(subclass(base), "base"))
        asserts.eq(false, Class.isSubclassOf(nil, nil))
    end)

    suite:case("circular inheritance throws", function(asserts)
        local a, b = loop()

        Helpers.throwsWith(asserts, function()
            Class.isSubclassOf(a, newClass())
        end, "[Class.isSubclassOf()]: Circular inheritance detected")
        asserts.eq(true, Class.isSubclassOf(a, b))
    end)

    suite:case("errors blame the caller", function(asserts)
        local a = loop()
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.isSubclassOf(a, newClass())
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.isSubclassOf()]: `)
    end)
end)

test.suite("parentOf()", function(suite)
    suite:case("returns a subclass's base class", function(asserts)
        local base = newClass()

        asserts.eq(base, Class.parentOf(subclass(base)))
    end)

    suite:case("returns nil for classes without one", function(asserts)
        local base = newClass()
        Class.new(base)

        asserts.eq(nil, Class.parentOf(base))
        asserts.eq(nil, Class.parentOf(newClass()))
    end)

    suite:case("returns nil for non-tables", function(asserts)
        asserts.eq(nil, Class.parentOf(5))
        asserts.eq(nil, Class.parentOf("string"))
        asserts.eq(nil, Class.parentOf(nil))
    end)
end)

test.suite("classOf()", function(suite)
    suite:case("returns an instance's class", function(asserts)
        local base = newClass()
        local sub = subclass(base)

        asserts.eq(base, Class.classOf(Class.new(base)))
        asserts.eq(sub, Class.classOf(Class.new(sub)))
    end)

    suite:case("works with sealed classes", function(asserts)
        local class = Class.sealed(newClass())

        asserts.eq(class, Class.classOf(Class.new(class)))
    end)

    suite:case("returns nil without a metatable", function(asserts)
        asserts.eq(nil, Class.classOf({}))
    end)

    suite:case("returns nil for non-tables", function(asserts)
        asserts.eq(nil, Class.classOf(5))
        asserts.eq(nil, Class.classOf("string"))
        asserts.eq(nil, Class.classOf(nil))
    end)
end)

test.suite("cast()", function(suite)
    suite:case("returns the same value", function(asserts)
        local class = newClass()
        local instance = Class.new(class)

        asserts.eq(instance, Class.cast(instance, class))
    end)

    suite:case("casts to base classes at any depth", function(asserts)
        local root, leaf = chain(5)
        local instance = Class.new(leaf)

        asserts.eq(instance, Class.cast(instance, root))
        asserts.eq(instance, Class.cast(instance, leaf))
    end)

    suite:case("works with sealed classes", function(asserts)
        local base = newClass()
        local sub = Class.sealed(subclass(base))
        local instance = Class.new(sub)

        asserts.eq(instance, Class.cast(instance, base))
    end)

    suite:case("non-instances throw", function(asserts)
        local base = newClass()
        local sub = subclass(base)

        Helpers.throwsWith(asserts, function()
            Class.cast(Class.new(base), sub)
        end, "[Class.cast()]: Value is not an instance of the class")
        Helpers.throwsWith(asserts, function()
            Class.cast({}, base)
        end, "[Class.cast()]: Value is not an instance of the class")
        Helpers.throwsWith(asserts, function()
            Class.cast(nil, base)
        end, "[Class.cast()]: Value is not an instance of the class")
        Helpers.throwsWith(asserts, function()
            Class.cast(sub, base)
        end, "[Class.cast()]: Value is not an instance of the class")
    end)

    suite:case("non-table classes throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.cast(Class.new(newClass()), 5 :: any)
        end, "[Class.cast()]: Expected a class table, got number")
    end)

    suite:case("circular inheritance throws", function(asserts)
        local a = loop()

        Helpers.throwsWith(asserts, function()
            Class.cast(setmetatable({}, a), newClass())
        end, "[Class.cast()]: Circular inheritance detected")
    end)

    suite:case("errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.cast({}, newClass())
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.cast()]: `)
    end)

    suite:case("walk errors blame the caller", function(asserts)
        local a = loop()
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.cast(setmetatable({}, a), newClass())
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.cast()]: `)
    end)
end)

test.suite("merge()", function(suite)
    suite:case("returns a new table with both tables' fields", function(asserts)
        local base = { name = "Rex", health = 10 }
        local fields = { breed = "Labrador" }
        local merged = Class.merge(base, fields)

        asserts.neq(base, merged)
        asserts.neq(fields, merged)
        asserts.eq("Rex", merged.name)
        asserts.eq(10, merged.health)
        asserts.eq("Labrador", merged.breed)
    end)

    suite:case("does not change either table", function(asserts)
        local base = { name = "Rex" }
        local fields = { breed = "Labrador" }
        Class.merge(base, fields)

        asserts.eq(nil, (base :: any).breed)
        asserts.eq(nil, (fields :: any).name)
    end)

    suite:case("fields win over base", function(asserts)
        local merged = Class.merge({ name = "Rex" }, { name = "Bit" })
        asserts.eq("Bit", merged.name)
    end)

    suite:case(
        "accepts frozen tables and returns an unfrozen one",
        function(asserts)
            local merged =
                Class.merge(table.freeze({ a = 1 }), table.freeze({ b = 2 }))

            asserts.eq(false, table.isfrozen(merged))
            asserts.eq(1, merged.a)
            asserts.eq(2, merged.b)
        end
    )

    suite:case("the result can become an instance", function(asserts)
        local base = newClass()
        local sub = subclass(base)
        local instance = Class.new(sub, Class.merge({ a = 1 }, { b = 2 }))

        asserts.eq(true, Class.isA(instance, base))
        asserts.eq(2, instance.b)
    end)

    suite:case("non-tables throw", function(asserts)
        local merge = Class.merge :: any

        Helpers.throwsWith(asserts, function()
            merge(5, {})
        end, "[Class.merge()]: Expected base to be a table, got number")
        Helpers.throwsWith(asserts, function()
            merge({}, nil)
        end, "[Class.merge()]: Expected fields to be a table, got nil")
    end)

    suite:case("tables with metatables throw", function(asserts)
        local instance = Class.new(newClass())

        Helpers.throwsWith(asserts, function()
            Class.merge(instance, {})
        end, "[Class.merge()]: Cannot merge base that has a metatable")
        Helpers.throwsWith(asserts, function()
            Class.merge({}, instance)
        end, "[Class.merge()]: Cannot merge fields that has a metatable")
    end)

    suite:case("errors blame the caller", function(asserts)
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.merge(Class.new(newClass()), {})
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.merge()]: `)
    end)
end)

test.suite("tryCast()", function(suite)
    suite:case("returns instances of the class", function(asserts)
        local root, leaf = chain(3)
        local instance = Class.new(leaf)

        asserts.eq(instance, Class.tryCast(instance, root))
        asserts.eq(instance, Class.tryCast(instance, leaf))
    end)

    suite:case("returns nil for anything else", function(asserts)
        local base = newClass()
        local sub = subclass(base)

        asserts.eq(nil, Class.tryCast(Class.new(base), sub))
        asserts.eq(nil, Class.tryCast({}, base))
        asserts.eq(nil, Class.tryCast(nil, base))
        asserts.eq(nil, Class.tryCast(5, base))
        asserts.eq(nil, Class.tryCast(sub, base))
    end)

    suite:case("non-table classes throw", function(asserts)
        Helpers.throwsWith(asserts, function()
            Class.tryCast({}, 5 :: any)
        end, "[Class.tryCast()]: Expected a class table, got number")
    end)

    suite:case("circular inheritance throws", function(asserts)
        local a = loop()

        Helpers.throwsWith(asserts, function()
            Class.tryCast(setmetatable({}, a), newClass())
        end, "[Class.tryCast()]: Circular inheritance detected")
    end)

    suite:case("walk errors blame the caller", function(asserts)
        local a = loop()
        local line
        local ok, err = pcall(function()
            line = debug.info(1, "l") :: number + 1
            Class.tryCast(setmetatable({}, a), newClass())
        end)

        asserts.eq(false, ok)
        asserts.strContains(tostring(err), `:{line}: [Class.tryCast()]: `)
    end)
end)
