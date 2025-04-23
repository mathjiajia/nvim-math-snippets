local snips, autosnips = {}, {}

local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local pos = require("math-snippets.position")

local opts = { condition = expand_line_begin, show_condition = pos.show_line_begin }

snips = {
	s({ trig = "#([2-6])", name = "Heading", desc = "Add Heading", trigEngine = "pattern", hidden = true }, {
		f(function(_, snip)
			return string.rep("#", tonumber(snip.captures[1], 10)) .. " "
		end, {}),
	}, opts),

	s(
		{ trig = "code", name = "Insert fenced code block" },
		{ t("``` "), i(1, "lang"), t({ "", "" }), i(0), t({ "", "```" }) },
		fmt(
			[[
			``` {}
			{}
			```
			]],
			{ i(1, "lang"), i(0) }
		),
		opts
	),

	s(
		{ trig = "meta", name = "Markdown front matter (YAML format)" },
		fmt(
			[[
			---
			title: {}
			date: {}
			tags: ["{}"]
			categories: ["{}"]
			series: ["{}"]
			---
			{}
			]],
			{ i(1), p(os.date, "%Y-%m-%dT%H:%M:%S+0800"), i(2), i(3), i(4), i(0) }
		),
		{
			condition = pos.on_top * expand_line_begin,
			show_condition = pos.on_top * pos.line_begin,
		}
	),

	s({ trig = "td", name = "too long, do not read" }, { t("tl;dr: ") }, opts),

	s(
		{ trig = "link", name = "Markdown Links", desc = "Insert a Link" },
		fmt([[[{}]({})]], { i(1, "title"), i(2, "url") })
	),
}

autosnips = {
	s({ trig = ";b", name = "bold" }, fmt("**{}**", { i(1) })),
	s({ trig = ";i", name = "italic" }, fmt("*{}*", { i(1) })),
	s({ trig = ";c", name = "code" }, fmt("`{}`", { i(1) })),
	s({ trig = ";s", name = "strikethrough" }, fmt("~~{}~~", { i(1) })),
}

return snips, autosnips
