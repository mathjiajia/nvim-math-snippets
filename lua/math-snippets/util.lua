local ls = require("luasnip")

local M = {}

-- Match a command trigger without inserting a second backslash.
function M.auto_trigger(trig)
	return "(?<!\\\\)(" .. trig .. ")"
end

-- Visual-selection helper adapted from ejmastnak.
function M.get_visual(_, parent)
	local env = parent.snippet.env
	local selection = env.LS_SELECT_RAW or env.SELECT_RAW
	return ls.snippet_node(nil, ls.insert_node(1, selection))
end

return M
