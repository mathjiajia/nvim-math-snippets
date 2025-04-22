local snips, autosnips = {}, {}

local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin

local opts = { condition = expand_line_begin }

snips = {
	s({
		trig = "([%*>~%-])([2-6])",
		name = "Heading, Quote, List",
		desc = "Add Heading",
		trigEngine = "pattern",
		hidden = true,
	}, {
		f(function(_, snip)
			return string.rep(snip.captures[1], tonumber(snip.captures[2], 10)) .. " "
		end, {}),
	}, opts),

	s(
		{ trig = "link", name = "Neorg Links", desc = "Insert a Link" },
		fmta([[{<>}[<>]<>]], { i(1, "url"), i(2, "title"), i(0) })
	),
}

local block_specs = {
	code = true,
	embed = true,
	image = true,
	date = false,
	math = false,
	table = false,
}

local function block_snippet(trig, labeled)
	local context = { trig = trig, name = trig, desc = trig .. " block" }
	local prefix = { t("@"), t(trig) }
	local postfix = { t({ "", "\t" }), i(0), t({ "", "@end" }) }

	vim.list_extend(prefix, labeled and { t(" "), i(1) } or {})
	return s(context, vim.list_extend(prefix, postfix), opts)
end

local block_snippets = {}
for k, v in pairs(block_specs) do
	table.insert(block_snippets, block_snippet(k, v))
end

vim.list_extend(snips, block_snippets)

autosnips = {
	s({ trig = ";b", name = "bold" }, fmt([[*{}*{}]], { i(1), i(0) })),
	s({ trig = ";i", name = "italic" }, fmt([[/{}/{}]], { i(1), i(0) })),
	s({ trig = ";u", name = "underline" }, fmt([[_{}_{}]], { i(1), i(0) })),
	s({ trig = ";s", name = "strikethrough" }, fmt([[-{}-{}]], { i(1), i(0) })),
	s({ trig = ";|", name = "spoiler" }, fmt([[|{}|{}]], { i(1), i(0) })),
	s({ trig = ";c", name = "inline code" }, fmt([[`{}`{}]], { i(1), i(0) })),
	s({ trig = ";^", name = "supscript" }, fmt([[^{}^{}]], { i(1), i(0) })),
	s({ trig = ";_", name = "subscript" }, fmt([[,{},{}]], { i(1), i(0) })),
	s({ trig = "mk", name = "inline math" }, fmt([[${}${}]], { i(1), i(0) })),
	s({ trig = ";v", name = "variable" }, fmt([[={}={}]], { i(1), i(0) })),
	s({ trig = ";+", name = "comment" }, fmt([[+{}+{}]], { i(1), i(0) })),
}

return snips, autosnips
