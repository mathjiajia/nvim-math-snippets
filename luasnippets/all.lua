local username = (vim.env.USER or ""):gsub("^%l", string.upper)

local function todo_snippet(trig, aliases)
	local name = table.concat(aliases, "|")
	local context = { trig = trig, name = name .. " comment", desc = name .. " comment with a signature-mark" }
	return s(context, fmt("{}{}: {} {}{}{}", {
		f(function ()
			return vim.bo.commentstring:match("^(.-)%%s") or ""
		end),
		c(1, vim.tbl_map(function (alias)
			return i(nil, alias)
		end, aliases)),
		i(3),
		c(2, {
			fmt("<{}>", i(1, username)),
			fmt("<{}{}>", { i(1, os.date("%d-%m-%y")), i(2, ", " .. username) }),
			fmt("<{}>", i(1, os.date("%d-%m-%y"))),
			t("")
		}),
		i(0),
		f(function ()
			return vim.bo.commentstring:match("%%s(.*)$") or ""
		end)
	}))
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
