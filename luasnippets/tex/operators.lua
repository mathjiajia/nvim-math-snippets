local snips, autosnips = {}, {}

local tex = require("math-snippets.latex")

local opts = { condition = tex.in_math, show_condition = tex.in_math }

local function auto_trigger(trig)
	return "(?<!\\\\)" .. "(" .. trig .. ")"
end

local function sequence_snippet(trig, cmd, desc)
	return s(
		{
			trig = auto_trigger(trig),
			name = desc,
			desc = desc .. "with automatic backslash",
			trigEngine = "ecma",
		},
		fmta([[\<><><>]], {
			t(cmd),
			c(1, { fmta([[_{<>}^{<>}]], { i(1, "i=0"), i(2, "\\infty") }), t("") }),
			i(0),
		}),
		opts
	)
end

local function auto_backslash_snippet(trig)
	return s(
		{
			trig = auto_trigger(trig),
			name = trig,
			desc = trig .. "with automatic backslash",
			trigEngine = "ecma",
			docstring = [[\]] .. trig,
			hidden = true,
		},
		fmta([[\<><>]], { f(function(_, snip)
			return snip.captures[1]
		end), i(0) }),
		opts
	)
end

snips = {
	s({
		trig = "/",
		name = "fraction",
		desc = "Insert a fraction notation.",
		wordTrig = false,
		hidden = true,
	}, fmta([[\frac{<>}{<>}<>]], { i(1), i(2), i(0) }), opts),
}

autosnips = {
	s(
		{ trig = "([hH])_(%d)(%u)", name = "cohomology-d", trigEngine = "pattern", hidden = true },
		fmta([[<><>)]], {
			f(function(_, snip)
				return snip.captures[1] .. "^{" .. snip.captures[2] .. "}(" .. snip.captures[3] .. ","
			end, {}),
			i(1),
		}),
		opts
	),

	s({ trig = "(%a)p(%d)", name = "x[n+1]", trigEngine = "pattern", hidden = true }, {
		f(function(_, snip)
			return snip.captures[1] .. "_{n+" .. snip.captures[2] .. "}"
		end, {}),
	}, opts),

	s(
		{ trig = "dint", name = "integral", desc = "Insert integral notation.", hidden = true },
		fmta([[\int_{<>}^{<>} <>]], { i(1, "-\\infty"), i(2, "\\infty"), i(0) }),
		opts
	),

	s(
		{ trig = "(%w)//", name = "fraction with a single numerator", trigEngine = "pattern", hidden = true },
		fmta([[\frac{<>}{<>}<>]], { f(function(_, snip)
			return snip.captures[1]
		end), i(1), i(0) }),
		opts
	),

	-- fractions
	s(
		{ trig = "//", name = "fraction", desc = "fraction (general)" },
		fmta([[\frac{<>}{<>}<>]], { i(1), i(2), i(0) }),
		opts
	),
	s(
		{ trig = "(?<!\\^)(%d+)/", name = "fraction", desc = "auto fraction 1", trigEngine = "ecma", hidden = true },
		fmta([[\frac{<>}{<>}<>]], { f(function(_, snip)
			return snip.captures[1]
		end), i(1), i(0) }),
		opts
	),

	s(
		{ trig = auto_trigger("lim"), name = "lim(sup|inf)", desc = "lim(sup|inf)", trigEngine = "ecma" },
		fmta([[\lim<><><>]], {
			c(1, { t(""), t("sup"), t("inf") }),
			c(2, { t(""), fmta([[_{<> \to <>}]], { i(1, "n"), i(2, "\\infty") }) }),
			i(0),
		}),
		opts
	),
	s(
		{ trig = "set", name = "set", desc = "set" },
		fmta([[\{<>\}<>]], { c(1, { r(1, ""), sn(nil, { r(1, ""), t(" \\mid "), i(2) }) }), i(0) }),
		opts
	),
	s(
		{ trig = "bnc", name = "binomial", desc = "binomial (nCR)" },
		fmta([[\binom{<>}{<>}<>]], { i(1), i(2), i(0) }),
		opts
	),

	s(
		{ trig = "ses", name = "short exact sequence", hidden = true },
		fmt(
			[[{}\longrightarrow {}\longrightarrow {}\longrightarrow {}\longrightarrow {}]],
			{ c(1, { t("0"), t("1") }), i(2), i(3), i(4), rep(1) }
		),
		opts
	),

	s(
		{ trig = "([hH])([i-npq])(%u)", name = "cohomology-a", trigEngine = "pattern", hidden = true },
		fmta([[<><>)]], {
			f(function(_, snip)
				return snip.captures[1] .. "^{" .. snip.captures[2] .. "}(" .. snip.captures[3] .. ","
			end, {}),
			i(1),
		}),
		opts
	),

	s(
		{ trig = "rij", name = "(x_n) n ∈ N", hidden = true },
		fmta([[(<>_<>)_{<>\in <>}]], { i(1, "x"), i(2, "n"), rep(2), i(3, "\\mathbb{N}") }),
		opts
	),
	s(
		{ trig = "rg", name = "i = 1, ..., n", hidden = true },
		fmta([[<> = <> \dots <>]], { i(1, "i"), i(2, "1"), i(0, "n") }),
		opts
	),
	s(
		{ trig = "ls", name = "a_1, ..., a_n", hidden = true },
		fmta([[<>_{<>}, \dots, <>_{<>}]], { i(1, "a"), i(2, "1"), rep(1), i(3, "n") }),
		opts
	),
}

local sequence_specs = {
	cprod = { "coprod", "coproduct" },
	prod = { "prod", "product" },
	nnn = { "bigcap", "intersection" },
	sum = { "sum", "summation" },
	uuu = { "bigcup", "union" },
}

local operator_specs = {
	"arccos",
	"arcsin",
	"arctan",
	"ast",
	"cod",
	"coker",
	"cos",
	"cot",
	"csc",
	"deg",
	"det",
	"dim",
	"exp",
	"hom",
	"inf",
	"int",
	"ker",
	"log",
	"max",
	"min",
	"perp",
	"sec",
	"sin",
	"star",
	"tan",
	"Gr",
	"Quot",
}

for k, v in pairs(sequence_specs) do
	table.insert(autosnips, sequence_snippet(k, v[1], v[2]))
end

for _, v in ipairs(operator_specs) do
	table.insert(autosnips, auto_backslash_snippet(v))
end

return snips, autosnips
