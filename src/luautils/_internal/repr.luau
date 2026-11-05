--!strict

-- repr function
-- by @vuppyan

-- Returns a string representation of a value for printing.
--
-- This function currently only performs operations on strings, adding quotes
-- around the value. Otherwise, the value is passed to `tostring`.
return function(v: any): string
    -- TODO: replace eventually with a string tools implementation,
    --       one that works with tables too
    return if type(v) == "string" then string.format("%q", v) else tostring(v)
end
