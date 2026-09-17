local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local pos = require("math-snippets.position")

local commit_specs = { "feat", "fix", "chore", "revert", "refactor", "cleanup" }
local opts = { condition = expand_line_begin, show_condition = pos.show_line_begin }
local snips = {}

for _, trig in ipairs(commit_specs) do
	table.insert(snips, s(
		{ trig = trig, name = trig, desc = "git commit " .. trig },
		fmta([[<>(<>): <>]], { t(trig), i(1, "scope"), i(0, "title") }), opts
	))
end

return snips
