local snips = {}

local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local pos = require("math-snippets.position")

local commit_specs = {
	"feat",
	"fix",
	"chore",
	"revert",
	"refactor",
	"cleanup",
}

local function commit_snippet(context)
	context.name = context.trig
	context.desc = "git commit " .. context.trig
	return s(
		context,
		fmta([[<>(<>): <>]], { t(context.trig), i(1, "scope"), i(0, "title") }),
		{ condition = expand_line_begin, show_condition = pos.show_line_begin }
	)
end

for _, v in ipairs(commit_specs) do
	table.insert(snips, commit_snippet({ trig = v }))
end

return snips
