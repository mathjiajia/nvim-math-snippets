local M = {}

local mkcond = require("luasnip.extras.conditions").make_condition

local MATH_IGNORE = { "label_definition", "label_reference", "text_mode" }
local MATH_NODES = { "displayed_equation", "inline_formula", "math_environment" }
local MATH_ENVIRONMENTS = { "aligned" }
local MATH_IGNORE_COMMANDS = { "SI", "tag", "textbf", "textit" }

local ALIGN_ENVS = { "multline", "eqnarray", "align", "array", "split", "alignat", "gather", "flalign" }
local BULLET_ENVS = { "itemize", "enumerate" }

---An insert mode implementation of `vim.treesitter`'s `get_node`
---@param opts table? Opts to be passed to `get_node`
---@return TSNode|nil node The node at the cursor
local function get_node_insert_mode(opts)
	opts = opts or {}
	local ins_curs = vim.api.nvim_win_get_cursor(0)
	ins_curs[1] = math.max(ins_curs[1] - 1, 0)
	ins_curs[2] = math.max(ins_curs[2] - 1, 0)
	opts.pos = ins_curs
	return vim.treesitter.get_node(opts)
end

---@param node TSNode
---@return string|nil
local function get_environment(node)
	local node_text = vim.treesitter.get_node_text(node, 0)
	local first_line = vim.split(node_text, "\n")[1]
	local env_name = first_line:match("\\begin{([^*}]+)%*?}")
	return env_name
end

---@param node TSNode
---@return string|nil
local function get_command(node)
	local cmd = node:named_child(0)
	if cmd then
		local cmd_name = vim.treesitter.get_node_text(cmd, 0):gsub("^\\", "")
		return cmd_name
	end
end

---Check if cursor is in treesitter node of 'math'
---@return boolean
local function in_math()
	local cursor_node = get_node_insert_mode()
	local ancestor_node = cursor_node:tree():root()
	while ancestor_node do
		if vim.list_contains(MATH_IGNORE, ancestor_node:type()) then
			return false
		elseif vim.list_contains(MATH_NODES, ancestor_node:type()) then
			return true
		elseif
			ancestor_node:type() == "generic_command"
			and vim.list_contains(MATH_IGNORE_COMMANDS, get_command(ancestor_node))
		then
			return false
		elseif
			ancestor_node:type() == "generic_environment"
			and vim.list_contains(MATH_ENVIRONMENTS, get_environment(ancestor_node))
		then
			return true
		end
		ancestor_node = ancestor_node:child_with_descendant(cursor_node)
	end
	return false
end

---Check if cursor is in treesitter node of 'text'
---@return boolean
local function in_text()
	return not M.in_math()
end

---Check if cursor is in treesitter node of 'math_environment': 'align'
---@return boolean
local function in_align()
	local cursor_node = get_node_insert_mode()
	local ancestor_node = cursor_node:tree():root()
	while ancestor_node do
		if
			ancestor_node:type() == "math_environment"
			and vim.list_contains(ALIGN_ENVS, get_environment(ancestor_node))
		then
			return true
		end
		ancestor_node = ancestor_node:child_with_descendant(cursor_node)
	end
	return false
end

local function in_bullets()
	local cursor_node = get_node_insert_mode()
	local ancestor_node = cursor_node:tree():root()
	while ancestor_node do
		if
			ancestor_node:type() == "generic_environment"
			and vim.list_contains(BULLET_ENVS, get_environment(ancestor_node))
		then
			return true
		end
		ancestor_node = ancestor_node:child_with_descendant(cursor_node)
	end
	return false
end

---Check if cursor is in treesitter node of 'math_environment': 'tikzcd'
---@return boolean
local function in_tikzcd()
	local cursor_node = get_node_insert_mode()
	local ancestor_node = cursor_node:tree():root()
	while ancestor_node do
		if ancestor_node:type() == "generic_environment" and get_environment(ancestor_node) == "tikzcd" then
			return true
		end
		ancestor_node = ancestor_node:child_with_descendant(cursor_node)
	end
	return false
end

---Check if cursor is in treesitter node of 'generic_command': '\xymatrix'
---@return boolean
-- local function in_xymatrix()
-- 	local cursor_node = get_node_insert_mode()
-- 	local ancestor_node = cursor_node:tree():root()
-- 	while ancestor_node do
-- 		if ancestor_node:type() == "generic_command" and get_command(ancestor_node) == "xymatrix" then
-- 			return true
-- 		end
-- 		ancestor_node = ancestor_node:child_with_descendant(cursor_node)
-- 	end
-- 	return false
-- end

M.in_math = mkcond(in_math)
M.in_text = mkcond(in_text)
M.in_align = mkcond(in_align)
M.in_bullets = mkcond(in_bullets)
M.in_tikzcd = mkcond(in_tikzcd)
-- M.in_xymatrix = mkcond(in_xymatrix)

return M
