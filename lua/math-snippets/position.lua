local api = vim.api
local mkcond = require("luasnip.extras.conditions").make_condition

--- Check the first ten lines for a Beamer document class.
---@return boolean
local function in_beamer()
	local lines = api.nvim_buf_get_lines(0, 0, 10, false)
	for _, line in ipairs(lines) do
		if line:match("^\\documentclass.*{beamer}$") then
			return true
		end
	end
	return false
end

--- Check if the cursor is in the first three lines.
---@return boolean
local function on_top()
	return api.nvim_win_get_cursor(0)[1] <= 3
end

--- Show line-start snippets while typing the first word, allowing indentation.
---@param line_to_cursor string
---@return boolean
local function show_line_begin(line_to_cursor)
	return line_to_cursor:match("^%s*%S*$") ~= nil
end

return {
	in_beamer = mkcond(in_beamer),
	on_top = mkcond(on_top),
	show_line_begin = mkcond(show_line_begin)
}
