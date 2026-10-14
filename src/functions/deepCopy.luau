--!strict

-- deepCopy function
-- by @vuppyan

type Table = { [any]: any }

local function deepCopyImpl(t: Table, visited: Table): Table
	local copy = {}
	visited[t] = copy

	for key, value in t do
		if type(value) == "table" then
			if visited[value] then
				copy[key] = visited[value]
			else
				copy[key] = deepCopyImpl(value, visited)
			end
		else
			copy[key] = value
		end
	end

	local mt = getmetatable(t :: any)
	if type(mt) == "table" then
		setmetatable(copy, mt)
	end

	return copy
end

--[=[
	Creates a deep copy of the given table.

	@param tbl T -- The table to copy.
	@return T -- A deep copy of the given table.
]=]
return function<T>(tbl: T): T
	return (deepCopyImpl((tbl :: any) :: Table, {}) :: any) :: T
end
