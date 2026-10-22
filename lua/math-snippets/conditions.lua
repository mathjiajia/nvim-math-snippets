local api = vim.api
local mkcond = require("luasnip.extras.conditions").make_condition

--- Check the Tree-sitter comment capture immediately before the cursor.
---@return boolean
local function in_comments()
	local bufnr = api.nvim_get_current_buf()
	local cursor = api.nvim_win_get_cursor(0)
	local captures = vim.treesitter.get_captures(bufnr, { cursor[1] - 1, cursor[2] - 1 })

	for _, capture in ipairs(captures) do
		if capture.capture == "comment" or capture.capture:match("^comment%.") then
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

return { in_comments = mkcond(in_comments), on_top = mkcond(on_top), show_line_begin = mkcond(show_line_begin) }
