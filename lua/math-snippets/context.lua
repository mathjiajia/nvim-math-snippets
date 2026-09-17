local api = vim.api
local mkcond = require("luasnip.extras.conditions").make_condition

--- Check the Tree-sitter comment capture immediately before the cursor.
---@return boolean
local function in_comments()
	local bufnr = api.nvim_get_current_buf()
	local cursor = api.nvim_win_get_cursor(0)
	local captures = vim.treesitter.get_captures_at_pos(bufnr, cursor[1] - 1, cursor[2] - 1)

	for _, capture in ipairs(captures) do
		if capture.capture == "comment" then
			return true
		end
	end
	return false
end

return { in_comments = mkcond(in_comments) }
