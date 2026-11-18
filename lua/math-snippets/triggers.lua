-- Build the end-anchored Lua pattern once and allocate captures only on a match.
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
	if not max_len then
		return function (line) return matched(line, line:find(anchored)) end
	end
	max_len = math.max(0, max_len)
	-- A frontier can inspect the byte before the search starts, and position
	-- captures count from the start of the subject. Both need an actual suffix.
	if trig:find("%f", 1, true) or trig:find("()", 1, true) then
		return function (line)
			local suffix = line:sub(math.max(1, #line - max_len + 1))
			return matched(suffix, suffix:find(anchored))
		end
	end
	return function (line)
		local first = math.max(1, #line - max_len + 1)
		return matched(line, line:find(anchored, first))
	end
end

return { pattern = pattern }
