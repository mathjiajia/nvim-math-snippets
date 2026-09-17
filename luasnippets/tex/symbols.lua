local tex = require("math-snippets.latex")
local util = require("math-snippets.util")

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }

local function guard_command(context, cmd)
	if cmd:find(context.trig) == 2 then -- command always starts with backslash
		context.trigEngine = "ecma"
		context.trig = util.auto_trigger(context.trig)
		context.hidden = true
	end
end

local function symbol_snippet(context, cmd)
	context.desc = cmd
	context.name = context.name or cmd:gsub([[\]], "")
	context.docstring = cmd .. [[{0}]]
	context.wordTrig = false
	guard_command(context, cmd)
	return s(context, t(cmd), math_opts)
end

local function single_command_snippet(context, cmd, optional_arg)
	context.desc = context.desc or cmd
	context.name = context.name or context.desc
	context.docstring = context.docstring or (cmd .. (optional_arg and "[(<1>)?]{<2>}<0>" or "{<1>}<0>"))
	guard_command(context, cmd)
	local optional = optional_arg and c(1, { t(""), sn(nil, { t("["), i(1, "opt"), t("]") }) }) or t("")
	return s(
		context, fmta(cmd .. [[<>{<>}<>]], { optional, d(optional_arg and 2 or 1, util.get_visual), i(0) }),
		math_opts
	)
end

local function arrow_snippet(trig, name, command)
	return s({ trig = trig, name = name, wordTrig = false, hidden = true }, {
		d(1, function ()
			if tex.in_tikzcd() then
				return sn(nil, { t("\\ar["), i(1), t("," .. command .. "]") })
			end
			return sn(nil, { t("\\" .. command .. " ") })
		end)
	}, math_opts)
end

local function indexed_greek_snippet(trig, name, template)
	return s({ trig = trig, name = name, trigEngine = "pattern", hidden = true }, {
		f(function (_, snip)
			return template:format(snip.captures[1])
		end, {})
	}, math_opts)
end

local autosnips = {
	arrow_snippet("rmap", "rational map arrow", "dashrightarrow"),
	arrow_snippet("emb", "embedding map arrow", "hookrightarrow"),
	s({ trig = "\\varpii", name = "\\varpi_i", hidden = true }, { t("\\varpi_{i}") }, math_opts),
	s({ trig = "\\varphii", name = "\\varphi_i", hidden = true }, { t("\\varphi_{i}") }, math_opts),
	indexed_greek_snippet("\\([xX])ii", "\\xi_{i}", "\\%si_{i}"),
	indexed_greek_snippet("\\([pP])ii", "\\pi_{i}", "\\%si_{i}"),
	indexed_greek_snippet("\\([pP])hii", "\\phi_{i}", "\\%shi_{i}"),
	indexed_greek_snippet("\\([cC])hii", "\\chi_{i}", "\\%shi_{i}"),
	indexed_greek_snippet("\\([pP])sii", "\\psi_{i}", "\\%ssi_{i}"),

	s({
		trig = "O([A-NP-Za-z])",
		name = "local ring, structure sheaf",
		wordTrig = false,
		trigEngine = "pattern",
		hidden = true
	},
		{
			f(function (_, snip)
				return "\\mathcal{O}_{" .. snip.captures[1] .. "}"
			end, {})
		}, math_opts),

	s({
		trig = "(%a)(%d)",
		name = "auto subscript 1",
		desc = "Subscript with a single number.",
		wordTrig = false,
		trigEngine = "pattern",
		hidden = true
	},
		{
			f(function (_, snip)
				return string.format("%s_%s", snip.captures[1], snip.captures[2])
			end, {})
		}, math_opts),

	s({
		trig = "(%a)_(%d%d)",
		name = "auto subscript 2",
		desc = "Subscript with two numbers.",
		wordTrig = false,
		trigEngine = "pattern",
		hidden = true
	},
		{
			f(function (_, snip)
				return string.format("%s_{%s}", snip.captures[1], snip.captures[2])
			end, {})
		}, math_opts),

	s({ trig = "MK", name = "Mori-Kleiman cone", hidden = true }, { t("\\cNE("), i(1), t(")") }, math_opts),
	s({ trig = "([QRZ])P", name = "positive", wordTrig = false, trigEngine = "pattern", hidden = true }, {
		f(function (_, snip)
			return "\\mathbb{" .. snip.captures[1] .. "}^{>0}"
		end, {})
	}, math_opts
	),

	s({ trig = "([QRZ])N", name = "negative", wordTrig = false, trigEngine = "pattern", hidden = true }, {
		f(function (_, snip)
			return "\\mathbb{" .. snip.captures[1] .. "}^{<0}"
		end, {})
	}, math_opts
	),

	s({ trig = "([qr])le", name = "linearly equivalent", wordTrig = false, trigEngine = "pattern", hidden = true }, {
		f(function (_, snip)
			return "\\sim_{\\mathbb{" .. string.upper(snip.captures[1]) .. "}}"
		end, {})
	}, math_opts
	),

	-- HACK: <Jia> do not use condition since it cannot be triggered
	s(
		{ trig = "^^", name = "auto superscript", wordTrig = false, hidden = true },
		fmta([[^{<>}<>]], { i(1), i(0) })
	),
	s(
		{ trig = "__", name = "auto subscript", wordTrig = false, hidden = true },
		fmta([[_{<>}<>]], { i(1), i(0) })
	),

	s(
		{ trig = "==", name = "align equals", wordTrig = false, hidden = true }, { t("& = ") }, { condition = tex.in_align }
	),
	s({ trig = "ar", name = "normal arrows", hidden = true }, { t("\\ar["), i(1), t("]") }, { condition = tex.in_tikzcd }),
	s({ trig = "(%a)ii", name = "alph i", wordTrig = false, trigEngine = "pattern", hidden = true }, {
		f(function (_, snip)
			return snip.captures[1] .. "_{i}"
		end, {})
	}, math_opts
	),
	s({ trig = "(%a)jj", name = "alph j", wordTrig = false, trigEngine = "pattern", hidden = true }, {
		f(function (_, snip)
			return snip.captures[1] .. "_{j}"
		end, {})
	}, math_opts
	)
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

local greek_specs = {
	[";a"] = { context = { name = "α" }, command = [[\alpha]] },
	[";b"] = { context = { name = "β" }, command = [[\beta]] },
	[";c"] = { context = { name = "χ" }, command = [[\chi]] },
	[";d"] = { context = { name = "δ" }, command = [[\delta]] },
	[";e"] = { context = { name = "ε" }, command = [[\epsilon]] },
	[";ve"] = { context = { name = "ε" }, command = [[\varepsilon]] },
	[";f"] = { context = { name = "φ" }, command = [[\phi]] },
	[";vf"] = { context = { name = "φ" }, command = [[\varphi]] },
	[";g"] = { context = { name = "γ" }, command = [[\gamma]] },
	[";h"] = { context = { name = "η" }, command = [[\eta]] },
	[";i"] = { context = { name = "ι" }, command = [[\iota]] },
	[";k"] = { context = { name = "κ" }, command = [[\kappa]] },
	[";l"] = { context = { name = "λ" }, command = [[\lambda]] },
	[";m"] = { context = { name = "μ" }, command = [[\mu]] },
	[";n"] = { context = { name = "ν" }, command = [[\nu]] },
	[";p"] = { context = { name = "π" }, command = [[\pi]] },
	[";q"] = { context = { name = "θ" }, command = [[\theta]] },
	[";r"] = { context = { name = "ρ" }, command = [[\rho]] },
	[";s"] = { context = { name = "σ" }, command = [[\sigma]] },
	[";t"] = { context = { name = "τ" }, command = [[\tau]] },
	[";w"] = { context = { name = "ω" }, command = [[\omega]] },
	[";u"] = { context = { name = "υ" }, command = [[\upsilon]] },
	[";x"] = { context = { name = "ξ" }, command = [[\xi]] },
	[";y"] = { context = { name = "ψ" }, command = [[\psi]] },
	[";z"] = { context = { name = "ζ" }, command = [[\zeta]] },
	[";D"] = { context = { name = "Δ" }, command = [[\Delta]] },
	[";F"] = { context = { name = "Φ" }, command = [[\Phi]] },
	[";G"] = { context = { name = "Γ" }, command = [[\Gamma]] },
	[";L"] = { context = { name = "Λ" }, command = [[\Lambda]] },
	[";P"] = { context = { name = "Π" }, command = [[\Pi]] },
	[";Q"] = { context = { name = "Θ" }, command = [[\Theta]] },
	[";S"] = { context = { name = "Σ" }, command = [[\Sigma]] },
	[";U"] = { context = { name = "Υ" }, command = [[\Upsilon]] },
	[";W"] = { context = { name = "Ω" }, command = [[\Omega]] },
	[";X"] = { context = { name = "Ξ" }, command = [[\Xi]] },
	[";Y"] = { context = { name = "Ψ" }, command = [[\Psi]] }
}

local symbol_specs = {
	-- logic
	inn = { context = { name = "∈" }, cmd = [[\in ]] },
	["!in"] = { context = { name = "∉" }, cmd = [[\not\in ]] },
	[";A"] = { context = { name = "∀" }, cmd = [[\forall]] },
	[";E"] = { context = { name = "∃" }, cmd = [[\exists]] },
	-- operators
	["!="] = { context = { name = "!=" }, cmd = [[\neq ]] },
	["<="] = { context = { name = "≤" }, cmd = [[\leq ]] },
	[">="] = { context = { name = "≥" }, cmd = [[\geq ]] },
	["<<"] = { context = { name = "<<" }, cmd = [[\ll ]] },
	[">>"] = { context = { name = ">>" }, cmd = [[\gg ]] },
	["~~"] = { context = { name = "~" }, cmd = [[\sim ]] },
	["~="] = { context = { name = "≃" }, cmd = [[\simeq ]] },
	["=~"] = { context = { name = "≅" }, cmd = [[\cong ]] },
	["::"] = { context = { name = ":" }, cmd = [[\colon ]] },
	[":="] = { context = { name = "≔" }, cmd = [[\coloneqq ]] },
	["=:"] = { context = { name = "≔" }, cmd = [[\eqqcolon ]] },
	["**"] = { context = { name = "*" }, cmd = [[^{*}]] },
	["..."] = { context = { name = "·" }, cmd = [[\dots]] },
	["||"] = { context = { name = "|" }, cmd = [[\mid ]] },
	xx = { context = { name = "×" }, cmd = [[\times]] },
	op = { context = { name = "⊕" }, cmd = [[\oplus]] },
	ox = { context = { name = "⊗" }, cmd = [[\otimes]] },
	nvs = { context = { name = "-1" }, cmd = [[^{-1}]] },
	nabl = { context = { name = "∇" }, cmd = [[\nabla]] },
	[";="] = { context = { name = "≡" }, cmd = [[\equiv ]] },
	[";-"] = { context = { name = "∖" }, cmd = [[\setminus ]] },
	[";6"] = { context = { name = "∂" }, cmd = [[\partial]] },
	[";8"] = { context = { name = "∞" }, cmd = [[\infty]] },
	[";."] = { context = { name = "·" }, cmd = [[\cdot]] },
	[";<"] = { context = { name = "⟨" }, cmd = [[\langle]] },
	[";>"] = { context = { name = "⟩" }, cmd = [[\rangle]] },
	-- sets
	AA = { context = { name = "𝔸" }, cmd = [[\mathbb{A}]] },
	CC = { context = { name = "ℂ" }, cmd = [[\mathbb{C}]] },
	DD = { context = { name = "𝔻" }, cmd = [[\mathbb{D}]] },
	FF = { context = { name = "𝔽" }, cmd = [[\mathbb{F}]] },
	GG = { context = { name = "𝔾" }, cmd = [[\mathbb{G}]] },
	HH = { context = { name = "ℍ" }, cmd = [[\mathbb{H}]] },
	NN = { context = { name = "ℕ" }, cmd = [[\mathbb{N}]] },
	OO = { context = { name = "O" }, cmd = [[\mathcal{O}]] },
	PP = { context = { name = "ℙ" }, cmd = [[\mathbb{P}]] },
	QQ = { context = { name = "ℚ" }, cmd = [[\mathbb{Q}]] },
	RR = { context = { name = "ℝ" }, cmd = [[\mathbb{R}]] },
	ZZ = { context = { name = "ℤ" }, cmd = [[\mathbb{Z}]] },
	cc = { context = { name = "⊂" }, cmd = [[\subset ]] },
	cq = { context = { name = "⊆" }, cmd = [[\subseteq ]] },
	qq = { context = { name = "⊃" }, cmd = [[\supset ]] },
	qc = { context = { name = "⊇" }, cmd = [[\supseteq ]] },
	Nn = { context = { name = "∩" }, cmd = [[\cap ]] },
	UU = { context = { name = "∪" }, cmd = [[\cup]] },
	[";0"] = { context = { name = "∅" }, cmd = [[\emptyset]] },
	-- arrows
	["=>"] = { context = { name = "⇒" }, cmd = [[\implies]] },
	["=<"] = { context = { name = "⇐" }, cmd = [[\impliedby]] },
	["->"] = { context = { name = "→", priority = 250 }, cmd = [[\to ]] },
	["!>"] = { context = { name = "↦" }, cmd = [[\mapsto ]] },
	["-->"] = { context = { name = "⟶", priority = 500 }, cmd = [[\longrightarrow ]] },
	["<->"] = { context = { name = "↔", priority = 500 }, cmd = [[\leftrightarrow ]] },
	["2>"] = { context = { name = "⇉", priority = 400 }, cmd = [[\rightrightarrows ]] },
	iff = { context = { name = "⟺" }, cmd = [[\iff ]] },
	upar = { context = { name = "↑" }, cmd = [[\uparrow]] },
	dnar = { context = { name = "↓" }, cmd = [[\downarrow]] },
	-- etc
	dag = { context = { name = "†" }, cmd = [[\dagger]] },
	lll = { context = { name = "ℓ" }, cmd = [[\ell]] },
	quad = { context = { name = " " }, cmd = [[\quad ]] }
}

local function merge_context(trig, context)
	return vim.tbl_deep_extend("keep", { trig = trig }, context)
end

for k, v in pairs(greek_specs) do
	table.insert(autosnips, symbol_snippet(merge_context(k, v.context), v.command))
end

for k, v in pairs(single_command_math_specs) do
	table.insert(autosnips, single_command_snippet(merge_context(k, v.context), v.cmd, v.optional_arg))
end

for k, v in pairs(symbol_specs) do
	table.insert(autosnips, symbol_snippet(merge_context(k, v.context), v.cmd))
end

return nil, autosnips
