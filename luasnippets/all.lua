-- TODO-style comment snippets, wrapped in the buffer's commentstring.
local username = (vim.env.USER or ""):gsub("^%l", string.upper)

local function date_node()
	return sn(nil, { i(1, os.date("%d-%m-%y")) })
end

-- The parts of 'commentstring' around %s, read at expansion time.
local function comment_prefix()
	return vim.bo.commentstring:match("^(.-)%%s") or ""
end

local function comment_suffix()
	return vim.bo.commentstring:match("%%s(.*)$") or ""
end

---@param trig    string
---@param aliases string[] Keyword choices, the first being the default
local function todo_snippet(trig, aliases)
	local name = table.concat(aliases, "|")
	local context = { trig = trig, name = name .. " comment", desc = name .. " comment with a signature-mark" }
	return s(
		context,
		fmt("{}{}: {} {}{}{}", {
			f(comment_prefix),
			c(
				1,
				vim.tbl_map(function (alias)
					return i(nil, alias)
				end, aliases)
			),
			i(3),
			c(2, {
				fmt("<{}>", i(1, username)),
				fmt("<{}{}>", { d(1, date_node), i(2, ", " .. username) }),
				fmt("<{}>", d(1, date_node)),
				t("")
			}),
			i(0),
			f(comment_suffix)
		})
	)
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

for trig, aliases in pairs(base_specs) do
	table.insert(todo_comment_snippets, todo_snippet(trig, aliases))
end

return todo_comment_snippets
