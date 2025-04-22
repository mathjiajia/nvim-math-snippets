local M = {}

local api = vim.api
local mkcond = require("luasnip.extras.conditions").make_condition

---Check if the current tex file is a beamer class
---@return boolean
local function in_beamer()
	local lines = vim.api.nvim_buf_get_lines(0, 0, 10, false)
	for _, line in ipairs(lines) do
		if line:match("^\\documentclass.*{beamer}$") then
			return true
		end
	end
	return false
end

---Check if cursor is in the top 3 lines of a file
---@return boolean
local function on_top()
	local cursor = api.nvim_win_get_cursor(0)
	if cursor[1] <= 3 then
		return true
	end
	return false
end

---Check if cursor is in the beginning of a line
---@return boolean
local function show_line_begin(line_to_cursor)
	return #line_to_cursor <= 3
end

M.in_beamer = mkcond(in_beamer)
M.on_top = mkcond(on_top)
M.show_line_begin = mkcond(show_line_begin)

return M
