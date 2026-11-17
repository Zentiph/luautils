--!strict

-- Class tests that must fail to type check
-- by @vuppyan

-- Checked by `.lute/typing.luau`: each `-- error: <text>` comment expects an
-- error containing `<text>` on the next line of code, and any other error
-- fails the check.

local Class = require("../../../src/luautils/Core/Class")

local Animal = {}

export type AnimalFields = { name: string }

function Animal.fields(name: string): AnimalFields
    return { name = name }
end

function Animal.new(name: string)
    return Class.new(Animal, Animal.fields(name))
end

function Animal.speak(_self): string
    return "..."
end

local Dog = setmetatable({}, Class.extends(Animal))

export type DogFields = AnimalFields & { breed: string }

function Dog.fields(name: string, breed: string): DogFields
    return Class.merge(Animal.fields(name), { breed = breed })
end

function Dog.new(name: string)
    return Class.new(Dog, Dog.fields(name, "mutt"))
end

function Dog.fetch(_self): string
    return "ball"
end

type AnyAnimal = Class.IsA<typeof(Animal)>

local animal: AnyAnimal = Animal.new("Generic")

-- error: Key 'fetch' not found in table
local _missing = animal:fetch()

-- error: Expected this to be 'number', but got 'string'
local _wrongField: number = animal.name

-- error: Property speak of table
animal.speak = Animal.speak

-- error: Key 'new' not found in table
local _constructor = animal.new

-- static functions are left out
-- error: Key 'fields' not found in table
local _static = animal.fields

-- subclass instances must go through Class.cast
-- error: Expected this to be
local _direct: AnyAnimal = Dog.new("Rex")

-- error: Key 'fetch' not found
local _castMissing = Class.cast(Dog.new("Rex"), Animal):fetch()

-- tryCast results may be nil
local unknownValue: unknown = Dog.new("Rex")
-- error: Value of type
local _unchecked = Class.tryCast(unknownValue, Dog).breed

-- merged fields are checked
-- error: Expected this to be 'number', but got 'string'
local _mergedName: number = Dog.fields("Rex", "mutt").name

-- instances built on inherited fields are still checked
local Puppy = setmetatable({}, Class.extends(Dog))

function Puppy.new(name: string)
    return Class.new(Puppy, Dog.fields(name, "mutt"), { age = 0 })
end

local puppy = Puppy.new("Bit")

-- error: Expected this to be 'string', but got 'number'
local _wrongAge: string = puppy.age

-- error: Expected this to be 'number', but got 'string'
local _wrongName: number = puppy.name

-- error: does not have key 'unknown'
local _unknown = puppy.unknown
