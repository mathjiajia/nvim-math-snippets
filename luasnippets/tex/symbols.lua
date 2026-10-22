local tex = require("math-snippets.latex")
local not_after_backslash = require("luasnip.extras.conditions.expand").trigger_not_preceded_by("\\")

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }
local command_opts = { condition = not_after_backslash * tex.in_math, show_condition = tex.in_math }

local function symbol_snippet(context, cmd)
	context.desc = cmd
	context.name = context.name or cmd:gsub([[\]], "")
	context.docstring = cmd .. [[{0}]]
	context.wordTrig = false
	local opts = math_opts
	if cmd:find(context.trig) == 2 then -- command always starts with backslash
		context.hidden = true
		opts = command_opts
	end
	return s(context, t(cmd), opts)
end

local function auto_backslash_snippet(trig)
	return s({
		trig = trig,
		name = trig,
		desc = trig .. " with automatic backslash",
		docstring = "\\" .. trig
	}, { t("\\" .. trig), i(0) }, command_opts)
end

local function indexed_greek_snippet(trig, name, template, length)
	return s({ trig = trig, name = name, trigEngine = "pattern", trigEngineOpts = { max_len = length }, hidden = true }, {
		f(function (_, snip)
			return template:format(snip.captures[1])
		end, {})
	}, math_opts
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
	}, math_opts
	)
end

local autosnips = {
	-- Algebraic notation.
	s({
		trig = "O([A-NP-Za-z])",
		name = "local ring, structure sheaf",
		wordTrig = false,
		trigEngine = "pattern",
		trigEngineOpts = { max_len = 2 },
		hidden = true
	},
		{
			f(function (_, snip)
				return "\\mathcal{O}_{" .. snip.captures[1] .. "}"
			end, {})
		}, math_opts),

	s({ trig = "MK", name = "Mori-Kleiman cone", hidden = true }, { t("\\cNE("), i(1), t(")") }, math_opts),

	s({
		trig = "([QRZ])P",
		name = "positive",
		wordTrig = false,
		trigEngine = "pattern",
		trigEngineOpts = { max_len = 2 },
		hidden = true
	},
		{
			f(function (_, snip)
				return "\\mathbb{" .. snip.captures[1] .. "}^{>0}"
			end, {})
		}, math_opts),

	s({
		trig = "([QRZ])N",
		name = "negative",
		wordTrig = false,
		trigEngine = "pattern",
		trigEngineOpts = { max_len = 2 },
		hidden = true
	},
		{
			f(function (_, snip)
				return "\\mathbb{" .. snip.captures[1] .. "}^{<0}"
			end, {})
		}, math_opts),

	s({
		trig = "([qr])le",
		name = "linearly equivalent",
		wordTrig = false,
		trigEngine = "pattern",
		trigEngineOpts = {
			max_len = 3
		},
		hidden = true
	},
		{
			f(function (_, snip)
				return "\\sim_{\\mathbb{" .. string.upper(snip.captures[1]) .. "}}"
			end, {})
		}, math_opts),

	-- Indexed Greek letters.
	s({ trig = "\\varpii", name = "\\varpi_i", hidden = true }, { t("\\varpi_{i}") }, math_opts),
	s({ trig = "\\varphii", name = "\\varphi_i", hidden = true }, { t("\\varphi_{i}") }, math_opts),
	indexed_greek_snippet("\\([xX])ii", "\\xi_{i}", "\\%si_{i}", 4),
	indexed_greek_snippet("\\([pP])ii", "\\pi_{i}", "\\%si_{i}", 4),
	indexed_greek_snippet("\\([pP])hii", "\\phi_{i}", "\\%shi_{i}", 5),
	indexed_greek_snippet("\\([cC])hii", "\\chi_{i}", "\\%shi_{i}", 5),
	indexed_greek_snippet("\\([pP])sii", "\\psi_{i}", "\\%ssi_{i}", 5),

	-- Subscripts.
	s({
		trig = "(%a)(%d)",
		name = "auto subscript 1",
		desc = "Subscript with a single number.",
		wordTrig = false,
		trigEngine = "pattern",
		trigEngineOpts = { max_len = 2 },
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
		trigEngineOpts = { max_len = 4 },
		hidden = true
	},
		{
			f(function (_, snip)
				return string.format("%s_{%s}", snip.captures[1], snip.captures[2])
			end, {})
		}, math_opts),

	s({
		trig = "(%a)ii",
		name = "alph i",
		wordTrig = false,
		trigEngine = "pattern",
		trigEngineOpts = { max_len = 3 },
		hidden = true
	},
		{
			f(function (_, snip)
				return snip.captures[1] .. "_{i}"
			end, {})
		}, math_opts),

	s({
		trig = "(%a)jj",
		name = "alph j",
		wordTrig = false,
		trigEngine = "pattern",
		trigEngineOpts = { max_len = 3 },
		hidden = true
	},
		{
			f(function (_, snip)
				return snip.captures[1] .. "_{j}"
			end, {})
		}, math_opts),

	s({ trig = "(%a)p(%d)", name = "x[n+1]", trigEngine = "pattern", trigEngineOpts = { max_len = 3 }, hidden = true }, {
		f(function (_, snip)
			return snip.captures[1] .. "_{n+" .. snip.captures[2] .. "}"
		end, {})
	}, math_opts
	),

	s(
		{ trig = "tss", name = "text subscript", wordTrig = false, hidden = true }, { t("_{\\mathrm{"), i(1), t("}}") },
		{ condition = tex.in_math }
	),

	-- Keep these unconditional: the existing math-condition workaround is intentional.
	s({ trig = "^^", name = "auto superscript", wordTrig = false, hidden = true }, fmta([[^{<>}<>]], { i(1), i(0) })),
	s({ trig = "__", name = "auto subscript", wordTrig = false, hidden = true }, fmta([[_{<>}<>]], { i(1), i(0) })),

	-- Powers.
	s({ trig = "**", name = "*", desc = "^{*}", docstring = "^{*}{0}", wordTrig = false }, t("^{*}"), math_opts),
	s({ trig = "nvs", name = "-1", desc = "^{-1}", docstring = "^{-1}{0}", wordTrig = false }, t("^{-1}"), math_opts),

	-- Arrows that adapt to a tikzcd environment.
	s({ trig = "ar", name = "normal arrows", hidden = true }, { t("\\ar["), i(1), t("]") }, { condition = tex.in_tikzcd }),
	arrow_snippet("rmap", "rational map arrow", "dashrightarrow"),
	arrow_snippet("emb", "embedding map arrow", "hookrightarrow")
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
	-- relations and operations
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
	["..."] = { context = { name = "·" }, cmd = [[\dots]] },
	["||"] = { context = { name = "|" }, cmd = [[\mid ]] },
	xx = { context = { name = "×" }, cmd = [[\times]] },
	op = { context = { name = "⊕" }, cmd = [[\oplus]] },
	ox = { context = { name = "⊗" }, cmd = [[\otimes]] },
	nabl = { context = { name = "∇" }, cmd = [[\nabla]] },
	[";="] = { context = { name = "≡" }, cmd = [[\equiv ]] },
	[";-"] = { context = { name = "∖" }, cmd = [[\setminus ]] },
	[";6"] = { context = { name = "∂" }, cmd = [[\partial]] },
	[";8"] = { context = { name = "∞" }, cmd = [[\infty]] },
	[";."] = { context = { name = "·" }, cmd = [[\cdot]] },
	[";<"] = { context = { name = "⟨" }, cmd = [[\langle]] },
	[";>"] = { context = { name = "⟩" }, cmd = [[\rangle]] },
	-- number systems and sets
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
	-- spacing and other symbols
	dag = { context = { name = "†" }, cmd = [[\dagger]] },
	lll = { context = { name = "ℓ" }, cmd = [[\ell]] },
	quad = { context = { name = " " }, cmd = [[\quad ]] }
}

local operator_specs = {
	"arccos", "arcsin", "arctan", "ast", "cod", "coker", "cos", "cot", "csc", "deg", "det", "dim", "exp", "hom", "inf",
	"int", "ker", "log", "max", "min", "perp", "sec", "sin", "star", "tan", "Gr", "Quot"
}

for trig, spec in pairs(greek_specs) do
	local context = vim.tbl_deep_extend("keep", { trig = trig }, spec.context)
	table.insert(autosnips, symbol_snippet(context, spec.command))
end

for trig, spec in pairs(symbol_specs) do
	local context = vim.tbl_deep_extend("keep", { trig = trig }, spec.context)
	table.insert(autosnips, symbol_snippet(context, spec.cmd))
end

for _, trig in ipairs(operator_specs) do
	table.insert(autosnips, auto_backslash_snippet(trig))
end

return nil, autosnips
