--!strict

-- Class helpers library
-- author(s): @vuppyan

local Values = require("./Values")

local fail = require("./Errors").errorWithScope("Class")

--[=[
    A helper sublibrary for object-oriented paradigm enforcement in Luau.

    Error messages thrown by `Class` functions are prefixed with the function
    that threw them, such as `[Class.new()]: `, after the usual position prefix
    added by `error()`.

    @class Class
    @since [UNRELEASED]
]=]
local Class = {}

--[=[
    Seals a class, making it immutable by freezing it and settings its
    metatable to itself.

    This method is explicitly for creating immutable classes, not for freezing
    regular tables, which should be done with `table.freeze()`, or for creating
    mutable/stateful classes.

    ```lua
    local Person = {}
    Person.__index = Person

    -- define constants, functions, and methods...

    return Class.sealed(Person) -- class is immutable
    ```

    @since [UNRELEASED]
    @param class T -- The class to seal
    @return T -- The sealed class
]=]
function Class.sealed<T>(class: T): T
    if type(class) ~= "table" then
        fail("Class to seal must be a table")
    elseif not (class :: any).__index then
        fail("Class to seal must have an __index")
    elseif table.isfrozen(class) then
        fail("Cannot seal a frozen table")
    end

    (class :: any).__metatable = class
    return table.freeze(class)
end

--[=[
    Checks if the given has been sealed.

    A class is sealed if its metatable is itself and it is frozen.

    @since [UNRELEASED]
    @param class any -- The class to check
    @return boolean -- Whether the class has been sealed
]=]
function Class.isSealed(class: any): boolean
    if type(class) ~= "table" then
        fail("Expected a table, got " .. type(class))
    end
    return rawget(class, "__metatable") == class and table.isfrozen(class)
end

return table.freeze(Class)
