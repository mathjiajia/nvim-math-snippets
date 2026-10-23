local tex = require("math-snippets.latex")

local text_opts = { condition = tex.in_text }
local spacing_group = vim.api.nvim_create_augroup("math-snippets.inline-space", { clear = true })

-- Insert a space between inline math and a letter typed directly after it.
local function appended_space_after_insert()
	-- Reentering and leaving a snippet must not stack pending spaces.
	vim.api.nvim_clear_autocmds({ group = spacing_group, event = "InsertCharPre", buf = 0 })
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = spacing_group,
		callback = function ()
			local col = vim.api.nvim_win_get_cursor(0)[2]
			if col >= 2 and vim.api.nvim_get_current_line():sub(col - 1, col) == [[\)]] and vim.v.char:find("%a") then
				vim.v.char = " " .. vim.v.char
			end
		end,
		buf = 0,
		once = true,
		desc = "Auto Add a Space after Inline Math"
	})
end

---@param _    string[]
---@param snip table    LuaSnip snippet with pattern captures
---@return string
local function surround_with_inline_math(_, snip)
	local captures = snip.captures
	return captures[1] .. "\\(" .. captures[2] .. "\\)" .. captures[3] .. captures[4]
end

-- Bytes matched by the `%s` class, so the scan below agrees with the pattern engine.
---@type table<integer, boolean>
local SPACE = {}
for byte = 0, 255 do
	SPACE[byte] = string.char(byte):find("^%s") ~= nil
end

---@param from integer?
---@param _    integer?
---@param ...  string
---@return string[]?
local function captures_of(from, _, ...)
	if from then
		return { ... }
	end
end

-- Trigger engine for patterns shaped `(%s)<token>(%s+)`, where `<token>` matches no
-- whitespace. Such a match can only start at the whitespace before the last
-- token, so only that tail is matched instead of scanning the whole line for a
-- `$`-anchored pattern on every keystroke. Equivalent to LuaSnip's pattern
-- engine for these triggers; trigEngineOpts are not supported.
---@param trig string
---@return fun(line_to_cursor: string): string?, string[]?
local function whitespace_pattern(trig)
	local anchored = "^" .. trig .. "$"
	local byte = string.byte
	return function (line_to_cursor)
		local last = #line_to_cursor
		local token_end = last
		while token_end > 0 and SPACE[byte(line_to_cursor, token_end)] do
			token_end = token_end - 1
		end
		-- All automatic inline-math patterns require trailing whitespace.
		if token_end == last then
			return nil
		end
		local space = token_end
		while space > 0 and not SPACE[byte(line_to_cursor, space)] do
			space = space - 1
		end
		if space == 0 then
			return nil
		end
		local tail = line_to_cursor:sub(space)
		local captures = captures_of(tail:find(anchored))
		if captures then
			return tail, captures
		end
		return nil
	end
end

---@param trig string
---@param name string
local function automatic_inline_math(trig, name)
	return s({
		trig = trig,
		name = name,
		wordTrig = false,
		trigEngine = whitespace_pattern,
		hidden = true
	}, f(surround_with_inline_math), text_opts)
end

local autosnips = {
	automatic_inline_math("(%s)([b-zB-HJ-Z0-9])([,;.%-%)]?)(%s+)", "single-letter variable"),

	automatic_inline_math("(%s)([0-9]+[a-zA-Z]+)([,;.%)]?)(%s+)", "surround word starting with number"),

	automatic_inline_math("(%s)(%w[-_+=><]%w)([,;.%)]?)(%s+)", "surround i+1"),

	s({
		trig = "mk",
		name = "inline math",
		desc = "Insert inline Math Environment.",
		hidden = true,
		condition = tex.in_text
	},
		fmt([[\({}\){}]], { i(1), i(0) }), {
			callbacks = {
				[-1] = {
					[events.leave] = appended_space_after_insert
				}
			}
		})
}

return nil, autosnips
