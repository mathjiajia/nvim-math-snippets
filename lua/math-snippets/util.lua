local ls = require("luasnip")

local M = {}

-- LuaSnip trigger engine for literal commands without an existing backslash.
function M.command_trigger(trig)
	local length = #trig
	return function (line_to_cursor)
		local start = #line_to_cursor - length + 1
		if start < 1 or line_to_cursor:sub(start) ~= trig or line_to_cursor:sub(start - 1, start - 1) == "\\" then
			return nil
		end
		-- Keep the matched command available as capture 1.
		return trig, { trig }
	end
end

-- Visual-selection helper adapted from ejmastnak.
function M.get_visual(_, parent)
	local selection = parent.snippet.env.LS_SELECT_RAW
	return ls.snippet_node(nil, ls.insert_node(1, selection))
end

return M
