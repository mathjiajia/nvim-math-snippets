local username = vim.env.USER:gsub("^%l", string.upper)

--- Options for marks to be used in a TODO comment
local marks = {
	signature = function ()
		return fmt("<{}>", i(1, username))
	end,
	date_signature = function ()
		return fmt("<{}{}>", { i(1, os.date("%d-%m-%y")), i(2, ", " .. username) })
	end,
	date = function ()
		return fmt("<{}>", i(1, os.date("%d-%m-%y")))
	end,
	empty = function ()
		return t("")
	end
}

local function todo_snippet_nodes(aliases)
	local aliases_nodes = vim.tbl_map(function (alias)
		return i(nil, alias) -- generate choices for [name-of-comment]
	end, aliases)
	local sigmark_nodes = {} -- choices for [comment-mark]
	for _, mark in pairs(marks) do
		table.insert(sigmark_nodes, mark())
	end
	-- format them into the actual snippet
	local comment_node = fmt("{} {}: {} {} {}", {
		f(function ()
			return vim.bo.commentstring:gsub("%s*%%s$", "")
		end),
		c(1, aliases_nodes), -- [name-of-comment]
		i(3),                -- {comment-text}
		c(2, sigmark_nodes), -- [comment-mark]
		i(0)
	})
	return comment_node
end

--- Generate a TODO comment snippet with an automatic description and docstring
---@param trig    string
---@param aliases string[] of aliases for the todo comment (ex.: {FIX, ISSUE, FIXIT, BUG})
local function todo_snippet(trig, aliases)
	local alias_string = table.concat(aliases, "|")

	local context = {
		trig = trig,
		name = alias_string .. " comment",
		desc = alias_string .. " comment with a signature-mark"
	}
	local comment_node = todo_snippet_nodes(aliases)

	return s(context, comment_node, {})
end

local base_specs = {
	todo = { "TODO" },
	fix = { "FIX", "BUG", "ISSUE", "FIXIT" },
	hack = { "HACK" },
	warn = { "WARN", "WARNING", "XXX" },
	perf = { "PERF", "PERFORMANCE", "OPTIM", "OPTIMIZE" },
	note = { "NOTE", "INFO" }
}

local todo_comment_snippets = {}

for k, v in pairs(base_specs) do
	table.insert(todo_comment_snippets, todo_snippet(k, v))
end

return todo_comment_snippets
