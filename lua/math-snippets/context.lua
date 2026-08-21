local M = {}

local api = vim.api
local mkcond = require("luasnip.extras.conditions").make_condition

--- Check if cursor is in treesitter capture
---@param capture string
---@return boolean
local function in_ts_capture(capture)
	local bufnr = api.nvim_get_current_buf()
	local cursor = api.nvim_win_get_cursor(0)

	local captures = vim.treesitter.get_captures_at_pos(bufnr, cursor[1] - 1, cursor[2] - 1)

	for _, c in ipairs(captures) do
		if c.capture == capture then
			return true
		end
	end

	return false
end

--- Check if cursor is in treesitter capture of 'comment'
---@return boolean
local function in_comments()
	return in_ts_capture("comment")
end

M.in_comments = mkcond(in_comments)

return M
