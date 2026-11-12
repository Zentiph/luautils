--!strict

-- Class.IsA and Class.cast tests that must fail to type check
-- by @vuppyan

-- Checked by `.lute/typing.luau`: each `-- error: <text>` comment expects an
-- error containing `<text>` on the next line of code, and any other error
-- fails the check.

local Class = require("../../../src/luautils/Core/Class")

local Animal = {}

function Animal.new(name: string)
    return Class.new(Animal, { name = name })
end

function Animal.speak(_self): string
    return "..."
end

local Dog = setmetatable({}, Class.extends(Animal))

function Dog.new(name: string)
    return Class.new(Dog, { name = name })
end

function Dog.fetch(_self): string
    return "ball"
end

type AnyAnimal = Class.IsA<typeof(Animal)>

local animal: AnyAnimal = Animal.new("Generic")

-- error: Key 'fetch' not found in table 'AnyAnimal'
local _missing = animal:fetch()

-- error: Expected this to be 'number', but got 'string'
local _wrongField: number = animal.name

-- error: Property speak of table 'AnyAnimal' is read-only
animal.speak = Animal.speak

-- error: Key 'new' not found in table 'AnyAnimal'
local _constructor = animal.new

-- subclass instances must go through Class.cast
-- error: Expected this to be 'AnyAnimal'
local _direct: AnyAnimal = Dog.new("Rex")

-- error: Key 'fetch' not found
local _castMissing = Class.cast(Dog.new("Rex"), Animal):fetch()
