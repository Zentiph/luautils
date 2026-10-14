--!strict

-- typeMatches function
-- by @vuppyan

--[=[
	Checks if `value` is compatible with the type of `reference`.

	@param value any -- The value to check
	@param reference any -- The reference value to compare against
	@return boolean -- Returns `true` if `value` is compatible with the type of `reference`, otherwise returns `false`
]=]
return function(value: any, reference: any): boolean
	local refType = typeof(reference)
	if refType == "table" then
		return typeof(value) == "table"
	end
	return typeof(value) == refType
end
