-- Conditions shared by several filetypes.
local api = vim.api
local mkcond = require("luasnip.extras.conditions").make_condition

-- A LuaSnip condition object: callable, and composable with `*`, `+`, `-`, `^`.
---@class math_snippets.Condition
---@field func fun(line_to_cursor: string, matched_trigger: string?, captures: string[]?): boolean
---@operator call(string?, string?, string[]?): boolean
---@operator mul(math_snippets.Condition): math_snippets.Condition
---@operator add(math_snippets.Condition): math_snippets.Condition
---@operator sub(math_snippets.Condition): math_snippets.Condition
---@operator unm: math_snippets.Condition

--- Check the Tree-sitter comment capture immediately before the cursor.
---@return boolean
local function in_comments()
	local bufnr = api.nvim_get_current_buf()
	local cursor = api.nvim_win_get_cursor(0)
	local captures = vim.treesitter.get_captures(bufnr, { cursor[1] - 1, cursor[2] - 1 })

	for _, capture in ipairs(captures) do
		local name = capture.capture
		if name == "comment" or name:find("comment.", 1, true) == 1 then
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
	return line_to_cursor:find("^%s*%S*$") ~= nil
end

---@class math_snippets.Conditions
---@field in_comments     math_snippets.Condition A `comment` or `comment.*` capture before the cursor; needs active highlighting
---@field on_top          math_snippets.Condition The cursor is in the first three lines
---@field show_line_begin math_snippets.Condition The line before the cursor holds only indentation and at most one token
local M = {
	in_comments = mkcond(in_comments),
	on_top = mkcond(on_top),
	show_line_begin = mkcond(show_line_begin)
}

return M
