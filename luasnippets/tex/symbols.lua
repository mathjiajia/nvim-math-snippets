local autosnips = {}

local tex = require("math-snippets.latex")

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }

local get_visual = function(_, parent)
	return sn(nil, i(1, parent.snippet.env.SELECT_RAW))
end

local function symbol_snippet(context, cmd)
	context.desc = cmd
	context.name = context.name or cmd:gsub([[\]], "")
	context.docstring = (cmd .. [[{0}]])
	context.wordTrig = false
	local j, _ = string.find(cmd, context.trig)
	if j == 2 then -- command always starts with backslash
		context.trigEngine = "ecma"
		context.trig = "(?<!\\\\)" .. "(" .. context.trig .. ")"
		context.hidden = true
	end
	return s(context, t(cmd), math_opts)
end

local function single_command_snippet(context, cmd, ext)
	context.desc = context.desc or cmd
	context.name = context.name or context.desc
	local docstring, offset, cnode, lnode
	if ext.choice == true then
		docstring = "[" .. [[(<1>)?]] .. "]" .. [[{]] .. [[<2>]] .. [[}]] .. [[<0>]]
		offset = 1
		cnode = c(1, { t(""), sn(nil, { t("["), i(1, "opt"), t("]") }) })
	else
		docstring = [[{]] .. [[<1>]] .. [[}]] .. [[<0>]]
	end
	if ext.label == true then
		docstring = [[{]] .. [[<1>]] .. [[}]] .. [[\zlabel{(]] .. ext.short .. [[:<2>)?}]] .. [[<0>]]
		ext.short = ext.short or cmd
		lnode = c(2 + (offset or 0), {
			t(""),
			sn(nil, fmta([[\zlabel{<>:<>}]], { t(ext.short), i(1) })),
		})
	end
	context.docstring = context.docstring or (cmd .. docstring)
	local j, _ = string.find(cmd, context.trig)
	if j == 2 then
		context.trigEngine = "ecma"
		context.trig = "(?<!\\\\)" .. "(" .. context.trig .. ")"
		context.hidden = true
	end
	-- stype = ext.stype or s
	return s(
		context,
		fmta(cmd .. [[<>{<>}<><>]], { cnode or t(""), d(1 + (offset or 0), get_visual), (lnode or t("")), i(0) }),
		math_opts
	)
end

autosnips = {
	s({ trig = "rmap", name = "rational map arrow", wordTrig = false, hidden = true }, {
		d(1, function()
			if tex.in_tikzcd() then
				return sn(nil, { t({ "\\arrow[" }), i(1), t({ ",dashrightarrow]" }) })
			else
				return sn(nil, { t("\\dashrightarrow ") })
			end
		end),
	}, math_opts),

	s({ trig = "emb", name = "embeddeing map arrow", wordTrig = false, hidden = true }, {
		d(1, function()
			if tex.in_tikzcd() then
				return sn(nil, { t({ "\\arrow[" }), i(1), t({ ",hookrightarrow]" }) })
			else
				return sn(nil, { t("\\hookrightarrow ") })
			end
		end),
	}, math_opts),

	s({ trig = "\\varpii", name = "\\varpi_i", hidden = true }, { t("\\varpi_{i}") }, math_opts),
	s({ trig = "\\varphii", name = "\\varphi_i", hidden = true }, { t("\\varphi_{i}") }, math_opts),
	s(
		{ trig = "\\([xX])ii", name = "\\xi_{i}", trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return string.format("\\%si_{i}", snip.captures[1])
		end, {}) },
		math_opts
	),
	s(
		{ trig = "\\([pP])ii", name = "\\pi_{i}", trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return string.format("\\%si_{i}", snip.captures[1])
		end, {}) },
		math_opts
	),
	s(
		{ trig = "\\([pP])hii", name = "\\phi_{i}", trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return string.format("\\%shi_{i}", snip.captures[1])
		end, {}) },
		math_opts
	),
	s(
		{ trig = "\\([cC])hii", name = "\\chi_{i}", trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return string.format("\\%shi_{i}", snip.captures[1])
		end, {}) },
		math_opts
	),
	s(
		{ trig = "\\([pP])sii", name = "\\psi_{i}", trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return string.format("\\%ssi_{i}", snip.captures[1])
		end, {}) },
		math_opts
	),

	s({
		trig = "O([A-NP-Za-z])",
		name = "local ring, structure sheaf",
		wordTrig = false,
		trigEngine = "pattern",
		hidden = true,
	}, {
		f(function(_, snip)
			return "\\mathcal{O}_{" .. snip.captures[1] .. "}"
		end, {}),
	}, math_opts),

	s({
		trig = "(%a)(%d)",
		name = "auto subscript 1",
		desc = "Subscript with a single number.",
		wordTrig = false,
		trigEngine = "pattern",
		hidden = true,
	}, {
		f(function(_, snip)
			return string.format("%s_%s", snip.captures[1], snip.captures[2])
		end, {}),
	}, math_opts),

	s({
		trig = "(%a)_(%d%d)",
		name = "auto subscript 2",
		desc = "Subscript with two numbers.",
		wordTrig = false,
		trigEngine = "pattern",
		hidden = true,
	}, {
		f(function(_, snip)
			return string.format("%s_{%s}", snip.captures[1], snip.captures[2])
		end, {}),
	}, math_opts),

	-- s({ trig = "^-", name = "negative exponents", wordTrig = false, hidden = true }, fmta([[^{-<>}]], { i(1) }), opts),
	s(
		{ trig = "set", name = "set", desc = "set", hidden = true },
		fmta([[\{<>\}<>]], { c(1, { r(1, ""), sn(nil, { r(1, ""), t(" \\mid "), i(2) }) }), i(0) }),
		math_opts
	),
	s(
		{ trig = "nnn", name = "bigcap", desc = "bigcap", hidden = true },
		fmta([[\bigcap<> <>]], { c(1, { fmta([[_{<>}^{<>}]], { i(1, "i=0"), i(2, "\\infty") }), t("") }), i(0) }),
		math_opts
	),

	s(
		{ trig = "uuu", name = "bigcup", desc = "bigcup", hidden = true },
		fmta([[\bigcup<> <>]], { c(1, { fmta([[_{<>}^{<>}]], { i(1, "i=0"), i(2, "\\infty") }), t("") }), i(0) }),
		math_opts
	),
	-- s(
	-- 	{ trig = "<|", name = "triangleleft <|", wordTrig = false, hidden = true },
	-- 	{ t("\\triangleleft ") },
	-- 	opts
	-- ),
	-- s(
	-- 	{ trig = "|>", name = "triangleright |>", wordTrig = false, hidden = true },
	-- 	{ t("\\triangleright ") },
	-- 	opts
	-- ),

	s({ trig = "MK", name = "Mori-Kleiman cone", hidden = true }, { t("\\cNE("), i(1), t(")") }, math_opts),
	s(
		{ trig = "([QRZ])P", name = "positive", wordTrig = false, trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return "\\mathbb{" .. snip.captures[1] .. "}^{>0}"
		end, {}) },
		math_opts
	),

	s(
		{ trig = "([QRZ])N", name = "negative", wordTrig = false, trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return "\\mathbb{" .. snip.captures[1] .. "}^{<0}"
		end, {}) },
		math_opts
	),

	s(
		{ trig = "([qr])le", name = "linearly equivalent", wordTrig = false, trigEngine = "pattern", hidden = true },
		{ f(function(_, snip)
			return "\\sim_{\\mathbb{" .. string.upper(snip.captures[1]) .. "}}"
		end, {}) },
		math_opts
	),

	-- HACK: <Jia> do not use condition since it cannot be triggered
	s(
		{ trig = "^^", name = "auto supscript", wordTrig = false, hidden = true },
		fmta([[^{<>}<>]], { i(1), i(0) })
		-- opts
	),
	s(
		{ trig = "__", name = "auto subscript", wordTrig = false, hidden = true },
		fmta([[_{<>}<>]], { i(1), i(0) })
		-- opts
	),

	s(
		{ trig = "==", name = "align equls", wordTrig = false, hidden = true },
		{ t("& = ") },
		{ condition = tex.in_align }
	),
	s(
		{ trig = "ar", name = "normal arrows", hidden = true },
		{ t("\\arrow["), i(1), t("]") },
		{ condition = tex.in_tikzcd }
	),

	s({ trig = "(%a)ii", name = "alph i", wordTrig = false, trigEngine = "pattern", hidden = true }, {
		f(function(_, snip)
			return snip.captures[1] .. "_{i}"
		end, {}),
	}, math_opts),
	s({ trig = "(%a)jj", name = "alph j", wordTrig = false, trigEngine = "pattern", hidden = true }, {
		f(function(_, snip)
			return snip.captures[1] .. "_{j}"
		end, {}),
	}, math_opts),
}

local single_command_math_specs = {
	tt = {
		context = { name = "text (math)", desc = "text in math mode" },
		cmd = [[\text]],
	},
	sbf = {
		context = { name = "symbf", desc = "bold math text" },
		cmd = [[\symbf]],
	},
	syi = {
		context = { name = "symit", desc = "italic math text" },
		cmd = [[\symit]],
	},
	sq = {
		context = { name = "sqrt", desc = "sqrt" },
		cmd = [[\sqrt]],
		ext = { choice = true },
	},
	hat = {
		context = { name = "hat", desc = "wide hat" },
		cmd = [[\widehat]],
	},
	bar = {
		context = { name = "overline", desc = "overline" },
		cmd = [[\overline]],
	},
	td = {
		context = { name = "tilde", desc = "wide tilde" },
		cmd = [[\widetilde]],
	},
	abs = {
		context = { name = "abs", desc = "absolute value" },
		cmd = [[\abs]],
	},
	udd = {
		context = { name = "underline (math)", desc = "underlined text in math mode" },
		cmd = [[\underline]],
	},
	sbt = {
		context = { name = "substack", desc = "substack for sums/products" },
		cmd = [[\substack]],
	},
	rup = {
		context = { name = "round up", desc = "auto round up", wordTrig = false },
		cmd = [[\rup]],
	},
	rdn = {
		context = { name = "round down", desc = "auto round down", wordTrig = false },
		cmd = [[\rdown]],
	},
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
	[";h"] = { context = { name = "θ" }, command = [[\eta]] },
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
	[";Y"] = { context = { name = "Ψ" }, command = [[\Psi]] },
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
	nabl = { context = { name = "∇" }, cmd = [[\\nabla]] },
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
	quad = { context = { name = " " }, cmd = [[\quad ]] },
	-- xmm = { context = { name = "x_m" }, cmd = [[x_{m}]] },
	-- xnn = { context = { name = "x_n" }, cmd = [[x_{n}]] },
	-- ymm = { context = { name = "y_m" }, cmd = [[y_{m}]] },
	-- ynn = { context = { name = "y_n" }, cmd = [[y_{n}]] },
}

local function merge_context(trig, context)
	return vim.tbl_deep_extend("keep", { trig = trig }, context)
end

-- ==========================================
-- Greek Letter Snippets
-- ==========================================
local greek_snippets = {}

for k, v in pairs(greek_specs) do
	table.insert(greek_snippets, symbol_snippet(merge_context(k, v.context), v.command))
end

vim.list_extend(autosnips, greek_snippets)

-- ==========================================
-- math symbol Snippets
-- ==========================================
local symbol_snippets = {}

for k, v in pairs(single_command_math_specs) do
	table.insert(symbol_snippets, single_command_snippet(merge_context(k, v.context), v.cmd, v.ext or {}))
end

for k, v in pairs(symbol_specs) do
	table.insert(symbol_snippets, symbol_snippet(merge_context(k, v.context), v.cmd))
end

vim.list_extend(autosnips, symbol_snippets)

return nil, autosnips
