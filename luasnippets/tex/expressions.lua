local tex = require("math-snippets.latex")
local not_after_backslash = require("luasnip.extras.conditions.expand").trigger_not_preceded_by("\\")

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }
local command_opts = { condition = not_after_backslash * tex.in_math, show_condition = tex.in_math }

local brackets = {
	a = { "\\langle", "\\rangle" },
	A = { "\\lAngle", "\\rAngle" },
	b = { "[", "]" },
	B = { "\\lBrack", "\\rBrack" },
	c = { "\\lbrace", "\\rbrace" },
	m = { "|", "|" },
	p = { "(", ")" },
	v = { "\\Vert", "\\Vert" }
}

-- Visual-selection helper adapted from ejmastnak.
local function get_visual(_, parent)
	local selection = parent.snippet.env.LS_SELECT_RAW
	return sn(nil, i(1, selection))
end

local function bracket_snippet(trig, name, template)
	return s({
		trig = trig .. "([aAbBcmpv])",
		name = name,
		desc = name .. " delimiters",
		trigEngine = "pattern",
		trigEngineOpts = { max_len = #trig + 1 },
		hidden = true,
		condition = tex.in_math,
		show_condition = tex.in_math
	},
		fmta(template, {
			f(function (_, snip)
				return brackets[snip.captures[1] or "p"][1]
			end),
			d(1, get_visual),
			f(function (_, snip)
				return brackets[snip.captures[1] or "p"][2]
			end),
			i(0)
		}))
end

local function sequence_snippet(trig, cmd, desc)
	return s({
		trig = trig,
		name = desc,
		desc = desc .. " with automatic backslash"
	},
		fmta([[\<><><>]], {
			t(cmd),
			c(1, { fmta([[_{<>}^{<>}]], { i(1, "i=0"), i(2, "\\infty") }), t("") }),
			i(0)
		}), command_opts)
end

local function cohomology_snippet(trig, name, length)
	return s(
		{ trig = trig, name = name, trigEngine = "pattern", trigEngineOpts = { max_len = length }, hidden = true },
		fmta([[<><>)]], {
			f(function (_, snip)
				return snip.captures[1] .. "^{" .. snip.captures[2] .. "}(" .. snip.captures[3] .. ","
			end, {}),
			i(1)
		}),
		math_opts
	)
end

local function single_command_snippet(context, cmd, optional_arg)
	context.desc = context.desc or cmd
	context.name = context.name or context.desc
	context.docstring = context.docstring or (cmd .. (optional_arg and "[(<1>)?]{<2>}<0>" or "{<1>}<0>"))
	local opts = math_opts
	if cmd:find(context.trig) == 2 then
		context.hidden = true
		opts = command_opts
	end
	local optional = optional_arg and c(1, { t(""), sn(nil, { t("["), i(1, "opt"), t("]") }) }) or t("")
	return s(
		context, fmta(cmd .. [[<>{<>}<>]], { optional, d(optional_arg and 2 or 1, get_visual), i(0) }), opts
	)
end

local function generate_postfix_dynamicnode(_, parent, _, prefix)
	local capture = parent.snippet.env.POSTFIX_MATCH
	local content = #capture > 0 and t(capture) or i(1, parent.snippet.env.LS_SELECT_RAW)
	return sn(nil, { t(prefix), content, t("}"), i(0) })
end

local function postfix_snippet(trig, command, description, priority)
	local prefix = "\\" .. command .. "{"
	local context = {
		trig = trig,
		name = description,
		desc = description,
		priority = priority,
		docstring = prefix .. [[(POSTFIX_MATCH|VISUAL|<1>)}]],
		match_pattern = [[[%w%.%_%-%"%']*$]]
	}
	return postfix(context, { d(1, generate_postfix_dynamicnode, {}, { user_args = { prefix } }) }, math_opts)
end

local snips = {
	s({
		trig = "/",
		name = "fraction",
		desc = "Insert a fraction notation.",
		wordTrig = false,
		hidden = true
	}, fmta([[\frac{<>}{<>}<>]], { i(1), i(2), i(0) }), math_opts)
}

local autosnips = {
	-- Fractions and binomials.
	s(
		{ trig = "//", name = "fraction", desc = "fraction (general)" },
		fmta([[\frac{<>}{<>}<>]], { d(1, get_visual), i(2), i(0) }), math_opts
	),

	s(
		{ trig = "bnc", name = "binomial", desc = "binomial (nCR)" }, fmta([[\binom{<>}{<>}<>]], { i(1), i(2), i(0) }), math_opts
	),

	-- Integrals and limits.
	s(
		{ trig = "dint", name = "integral", desc = "Insert integral notation.", hidden = true },
		fmta([[\int_{<>}^{<>} <>]], { i(1, "-\\infty"), i(2, "\\infty"), i(0) }), math_opts
	),

	s(
		{ trig = "lim", name = "lim(sup|inf)", desc = "lim(sup|inf)" },
		fmta([[\lim<><><>]], {
			c(1, { t(""), t("sup"), t("inf") }),
			c(2, { t(""), fmta([[_{<> \to <>}]], { i(1, "n"), i(2, "\\infty") }) }),
			i(0)
		}),
		command_opts
	),

	-- Sequences and cohomology.
	cohomology_snippet("([hH])_(%d)(%u)", "cohomology-d", 4),

	s(
		{ trig = "ses", name = "short exact sequence", hidden = true },
		fmt(
			[[{}\longrightarrow {}\longrightarrow {}\longrightarrow {}\longrightarrow {}]],
			{ c(1, { t("0"), t("1") }), i(2), i(3), i(4), rep(1) }
		), math_opts
	),

	cohomology_snippet("([hH])([i-npq])(%u)", "cohomology-a", 3),

	s(
		{ trig = "rij", name = "(x_n) n ∈ N", hidden = true },
		fmta([[(<>_<>)_{<>\in <>}]], { i(1, "x"), i(2, "n"), rep(2), i(3, "\\mathbb{N}") }), math_opts
	),

	s(
		{ trig = "rg", name = "i = 1, ..., n", hidden = true },
		fmta([[<> = <> \dots <>]], { i(1, "i"), i(2, "1"), i(0, "n") }), math_opts
	),

	s(
		{ trig = "ls", name = "a_1, ..., a_n", hidden = true },
		fmta([[<>_{<>}, \dots, <>_{<>}]], { i(1, "a"), i(2, "1"), rep(1), i(3, "n") }), math_opts
	),

	-- Delimiters and set-builder notation.
	bracket_snippet("bk", "brackets", [[<> <><><>]]),
	bracket_snippet("lr", "left right", [[\left<> <>\right<><>]]),

	s(
		{ trig = "set", name = "set", desc = "set" },
		fmta([[\{<>\}<>]], { c(1, { r(1, ""), sn(nil, { r(1, ""), t(" \\mid "), i(2) }) }), i(0) }), math_opts
	)
}

local sequence_specs = {
	cprod = { "coprod", "coproduct" },
	prod = { "prod", "product" },
	nnn = { "bigcap", "intersection" },
	sum = { "sum", "summation" },
	uuu = { "bigcup", "union" }
}

local single_command_math_specs = {
	tt = {
		context = { name = "text (math)", desc = "text in math mode" },
		cmd = [[\text]]
	},
	sbf = {
		context = { name = "symbf", desc = "bold math text" },
		cmd = [[\symbf]]
	},
	syi = {
		context = { name = "symit", desc = "italic math text" },
		cmd = [[\symit]]
	},
	sq = {
		context = { name = "sqrt", desc = "sqrt" },
		cmd = [[\sqrt]],
		optional_arg = true
	},
	hat = {
		context = { name = "hat", desc = "wide hat" },
		cmd = [[\widehat]]
	},
	bar = {
		context = { name = "overline", desc = "overline" },
		cmd = [[\overline]]
	},
	td = {
		context = { name = "tilde", desc = "wide tilde" },
		cmd = [[\widetilde]]
	},
	abs = {
		context = { name = "abs", desc = "absolute value" },
		cmd = [[\abs]]
	},
	udd = {
		context = { name = "underline (math)", desc = "underlined text in math mode" },
		cmd = [[\underline]]
	},
	sbt = {
		context = { name = "substack", desc = "substack for sums/products" },
		cmd = [[\substack]]
	},
	rup = {
		context = { name = "round up", desc = "auto round up", wordTrig = false },
		cmd = [[\rup]]
	},
	rdn = {
		context = { name = "round down", desc = "auto round down", wordTrig = false },
		cmd = [[\rdown]]
	}
}

local postfix_math_specs = {
	-- command, description, optional priority
	mbb = { "mathbb", "math blackboard bold" },
	mcal = { "mathcal", "math calligraphic" },
	mscr = { "mathscr", "math script" },
	mfr = { "mathfrak", "mathfrak" },
	hat = { "widehat", "hat", 500 },
	bar = { "overline", "bar (overline)", 500 },
	td = { "widetilde", "tilde", 500 }
}

for trig, spec in pairs(sequence_specs) do
	table.insert(autosnips, sequence_snippet(trig, spec[1], spec[2]))
end

for trig, spec in pairs(single_command_math_specs) do
	local context = vim.tbl_deep_extend("keep", { trig = trig }, spec.context)
	table.insert(autosnips, single_command_snippet(context, spec.cmd, spec.optional_arg))
end

for trig, spec in pairs(postfix_math_specs) do
	table.insert(autosnips, postfix_snippet(trig, spec[1], spec[2], spec[3]))
end

return snips, autosnips
