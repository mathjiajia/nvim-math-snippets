local tex = require("math-snippets.latex")
local not_after_backslash = require("luasnip.extras.conditions.expand").trigger_not_preceded_by("\\")

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }
-- Commands typed without their backslash must not expand after an existing one.
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
---@param _      string[]
---@param parent table    LuaSnip node whose snippet environment holds LS_SELECT_RAW
local function get_visual(_, parent)
	local selection = parent.snippet.env.LS_SELECT_RAW
	return sn(nil, i(1, selection))
end

---@param side 1 | 2 Opening or closing delimiter
---@return fun(_: string[], snip: table): string
local function bracket(side)
	return function (_, snip)
		return brackets[snip.captures[1] or "p"][side]
	end
end

---@param trig     string Trigger prefix; the delimiter letter is captured after it
---@param name     string
---@param template string fmta template with four slots: open, content, close, exit
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
	}, fmta(template, { f(bracket(1)), d(1, get_visual), f(bracket(2)), i(0) }))
end

---@param trig string
---@param cmd  string Command name without backslash
---@param desc string
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

---@param _    string[]
---@param snip table    LuaSnip snippet with captures: group, degree, space
---@return string
local function cohomology_prefix(_, snip)
	local captures = snip.captures
	return captures[1] .. "^{" .. captures[2] .. "}(" .. captures[3] .. ","
end

---@param trig   string  Lua pattern with three captures
---@param name   string
---@param length integer Bound on the trigger length
local function cohomology_snippet(trig, name, length)
	return s(
		{ trig = trig, name = name, trigEngine = "pattern", trigEngineOpts = { max_len = length }, hidden = true },
		fmta([[<><>)]], { f(cohomology_prefix), i(1) }), math_opts
	)
end

-- A command whose trigger is its own name, typed without the backslash, is
-- hidden from completion and must not expand after an existing backslash.
---@param context      table    LuaSnip context with at least `trig`
---@param cmd          string   Command including its backslash
---@param optional_arg boolean? Offer an optional `[...]` argument first
local function single_command_snippet(context, cmd, optional_arg)
	context.desc = context.desc or cmd
	context.name = context.name or context.desc
	context.docstring = context.docstring or (cmd .. (optional_arg and "[(<1>)?]{<2>}<0>" or "{<1>}<0>"))
	local opts = math_opts
	if cmd:sub(2, #context.trig + 1) == context.trig then
		context.hidden = true
		opts = command_opts
	end
	local optional = optional_arg and c(1, { t(""), sn(nil, { t("["), i(1, "opt"), t("]") }) }) or t("")
	return s(context, fmta(cmd .. [[<>{<>}<>]], { optional, d(optional_arg and 2 or 1, get_visual), i(0) }), opts)
end

---@param _      string[]
---@param parent table
---@param _      any
---@param prefix string   Command with its opening brace
local function generate_postfix_dynamicnode(_, parent, _, prefix)
	local capture = parent.snippet.env.POSTFIX_MATCH
	local content = #capture > 0 and t(capture) or i(1, parent.snippet.env.LS_SELECT_RAW)
	return sn(nil, { t(prefix), content, t("}"), i(0) })
end

---@param trig        string
---@param command     string   Command name without backslash
---@param description string
---@param priority    integer?
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
		{ trig = "bnc", name = "binomial", desc = "binomial (nCR)" }, fmta([[\binom{<>}{<>}<>]], { i(1), i(2), i(0) }),
		math_opts
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

-- trig = { command, description }
local sequence_specs = {
	cprod = { "coprod", "coproduct" },
	prod = { "prod", "product" },
	nnn = { "bigcap", "intersection" },
	sum = { "sum", "summation" },
	uuu = { "bigcup", "union" }
}

-- trig = { context, cmd, optional_arg? }
local single_command_math_specs = {
	tt = { { name = "text (math)", desc = "text in math mode" }, [[\text]] },
	sbf = { { name = "symbf", desc = "bold math text" }, [[\symbf]] },
	syi = { { name = "symit", desc = "italic math text" }, [[\symit]] },
	sq = { { name = "sqrt", desc = "sqrt" }, [[\sqrt]], true },
	hat = { { name = "hat", desc = "wide hat" }, [[\widehat]] },
	bar = { { name = "overline", desc = "overline" }, [[\overline]] },
	td = { { name = "tilde", desc = "wide tilde" }, [[\widetilde]] },
	abs = { { name = "abs", desc = "absolute value" }, [[\abs]] },
	udd = { { name = "underline (math)", desc = "underlined text in math mode" }, [[\underline]] },
	sbt = { { name = "substack", desc = "substack for sums/products" }, [[\substack]] },
	rup = { { name = "round up", desc = "auto round up", wordTrig = false }, [[\rup]] },
	rdn = { { name = "round down", desc = "auto round down", wordTrig = false }, [[\rdown]] }
}

-- trig = { command, description, priority? }
local postfix_math_specs = {
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
	local context = spec[1]
	context.trig = trig
	table.insert(autosnips, single_command_snippet(context, spec[2], spec[3]))
end

for trig, spec in pairs(postfix_math_specs) do
	table.insert(autosnips, postfix_snippet(trig, spec[1], spec[2], spec[3]))
end

return snips, autosnips
