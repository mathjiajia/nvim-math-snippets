-- LuaSnip-compatible Lua patterns: compile the end anchor once and only allocate
-- the capture table after a successful match.
---@param line  string
---@param first integer?
---@param _     integer?
---@param ...   string | integer
---@return string?, (string | integer)[]?
local function matched(line, first, _, ...)
	if first then
		return line:sub(first), { ... }
	end
end

---@param trig string
---@param opts { max_len?: integer }?
---@return fun(line_to_cursor: string): string?, (string | integer)[]?
local function pattern(trig, opts)
	local anchored = trig .. "$"
	local max_len = opts and opts.max_len
	return function (line_to_cursor)
		if max_len then
			-- Keep substring semantics for frontier patterns and position captures.
			line_to_cursor = line_to_cursor:sub(math.max(1, #line_to_cursor - max_len + 1))
		end
		return matched(line_to_cursor, line_to_cursor:find(anchored))
	end
end

return { pattern = pattern }
