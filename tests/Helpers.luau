--!strict

-- helpers for test writing
-- by @vuppyan

local types = require("@std/test/types")

local Helpers = {}

--- Compares two values using `==` and `tostring` for better debugging.
function Helpers.eqByStr<T>(asserts: types.Asserts, expected: T, actual: T)
    asserts.eq(tostring(expected), tostring(actual)) -- for better debug
    asserts.eq(expected, actual)
end

--- Compares two values using `~=` and `tostring` for better debugging.
function Helpers.neqByStr<T>(asserts: types.Asserts, expected: T, actual: T)
    asserts.neq(tostring(expected), tostring(actual)) -- for better debug
    asserts.neq(expected, actual)
end

--- Asserts that `fn` throws an error containing `substring`.
function Helpers.throwsWith(
    asserts: types.Asserts,
    fn: () -> (),
    substring: string
)
    local ok, err = pcall(fn)
    asserts.eq(false, ok)
    asserts.strContains(tostring(err), substring)
end

--- Creates a spy function that counts the number of times it is called.
function Helpers.spy<A..., R...>(
    impl: ((A...) -> R...)?
): { calls: number, fn: (A...) -> R... }
    local state = { calls = 0 }
    state.fn = function(...: A...): R...
        state.calls += 1
        return if impl then impl(...) else nil :: any
    end
    return state
end

return Helpers
