local tex = require("math-snippets.latex")
local not_after_backslash = require("luasnip.extras.conditions.expand").trigger_not_preceded_by("\\")

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }
-- Commands typed without their backslash must not expand after an existing one.
local command_opts = { condition = not_after_backslash * tex.in_math, show_condition = tex.in_math }

-- A symbol whose trigger is the command's own name is hidden from completion.
---@param trig     string
---@param name     string
---@param cmd      string   Command including its backslash
---@param priority integer?
local function symbol_snippet(trig, name, cmd, priority)
	local context = {
		trig = trig,
		name = name,
		desc = cmd,
		docstring = cmd .. [[{0}]],
		wordTrig = false,
		priority = priority
	}
	local opts = math_opts
	if cmd:sub(2, #trig + 1) == trig then
		context.hidden = true
		opts = command_opts
	end
	return s(context, t(cmd), opts)
end

---@param trig string Operator name, expanded to the same name with a backslash
local function auto_backslash_snippet(trig)
	return s({
		trig = trig,
		name = trig,
		desc = trig .. " with automatic backslash",
		docstring = "\\" .. trig
	}, { t("\\" .. trig), i(0) }, command_opts)
end

-- A hidden math snippet whose text is computed from its pattern captures.
---@param trig    string                          Lua pattern; its captures are passed to `render`
---@param name    string
---@param max_len integer                         Bound on the trigger length
---@param render  fun(captures: string[]): string
---@param context table?                          Extra context fields, such as `desc` or `wordTrig`
local function capture_snippet(trig, name, max_len, render, context)
	context = context or {}
	context.trig, context.name, context.hidden = trig, name, true
	context.trigEngine, context.trigEngineOpts = "pattern", { max_len = max_len }
	return s(context, f(function (_, snip) return render(snip.captures) end), math_opts)
end

---@param template string Format string for the first capture
---@return fun(captures: string[]): string
local function formatted(template)
	return function (captures)
		return template:format(captures[1])
	end
end

---@param trig    string
---@param name    string
---@param command string Arrow command without backslash; used as a tikzcd arrow option
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
	capture_snippet("O([A-NP-Za-z])", "local ring, structure sheaf", 2, function (captures)
		return "\\mathcal{O}_{" .. captures[1] .. "}"
	end, { wordTrig = false }
	),

	s({ trig = "MK", name = "Mori-Kleiman cone", hidden = true }, { t("\\cNE("), i(1), t(")") }, math_opts),

	capture_snippet("([QRZ])P", "positive", 2, function (captures)
		return "\\mathbb{" .. captures[1] .. "}^{>0}"
	end, { wordTrig = false }
	),

	capture_snippet("([QRZ])N", "negative", 2, function (captures)
		return "\\mathbb{" .. captures[1] .. "}^{<0}"
	end, { wordTrig = false }
	),

	capture_snippet("([qr])le", "linearly equivalent", 3, function (captures)
		return "\\sim_{\\mathbb{" .. string.upper(captures[1]) .. "}}"
	end, { wordTrig = false }
	),

	-- Indexed Greek letters.
	s({ trig = "\\varpii", name = "\\varpi_i", hidden = true }, { t("\\varpi_{i}") }, math_opts),
	s({ trig = "\\varphii", name = "\\varphi_i", hidden = true }, { t("\\varphi_{i}") }, math_opts),
	capture_snippet("\\([xX])ii", "\\xi_{i}", 4, formatted("\\%si_{i}")),
	capture_snippet("\\([pP])ii", "\\pi_{i}", 4, formatted("\\%si_{i}")),
	capture_snippet("\\([pP])hii", "\\phi_{i}", 5, formatted("\\%shi_{i}")),
	capture_snippet("\\([cC])hii", "\\chi_{i}", 5, formatted("\\%shi_{i}")),
	capture_snippet("\\([pP])sii", "\\psi_{i}", 5, formatted("\\%ssi_{i}")),

	-- Subscripts.
	capture_snippet("(%a)(%d)", "auto subscript 1", 2, function (captures)
		return ("%s_%s"):format(captures[1], captures[2])
	end, { desc = "Subscript with a single number.", wordTrig = false }
	),

	capture_snippet("(%a)_(%d%d)", "auto subscript 2", 4, function (captures)
		return ("%s_{%s}"):format(captures[1], captures[2])
	end, { desc = "Subscript with two numbers.", wordTrig = false }
	),

	capture_snippet("(%a)ii", "alph i", 3, function (captures)
		return captures[1] .. "_{i}"
	end, { wordTrig = false }
	),

	capture_snippet("(%a)jj", "alph j", 3, function (captures)
		return captures[1] .. "_{j}"
	end, { wordTrig = false }
	),

	capture_snippet("(%a)p(%d)", "x[n+1]", 3, function (captures)
		return captures[1] .. "_{n+" .. captures[2] .. "}"
	end),

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

-- trig = { name, command, priority? }
local greek_specs = {
	[";a"] = { "α", [[\alpha]] },
	[";b"] = { "β", [[\beta]] },
	[";c"] = { "χ", [[\chi]] },
	[";d"] = { "δ", [[\delta]] },
	[";e"] = { "ε", [[\epsilon]] },
	[";ve"] = { "ε", [[\varepsilon]] },
	[";f"] = { "φ", [[\phi]] },
	[";vf"] = { "φ", [[\varphi]] },
	[";g"] = { "γ", [[\gamma]] },
	[";h"] = { "η", [[\eta]] },
	[";i"] = { "ι", [[\iota]] },
	[";k"] = { "κ", [[\kappa]] },
	[";l"] = { "λ", [[\lambda]] },
	[";m"] = { "μ", [[\mu]] },
	[";n"] = { "ν", [[\nu]] },
	[";p"] = { "π", [[\pi]] },
	[";q"] = { "θ", [[\theta]] },
	[";r"] = { "ρ", [[\rho]] },
	[";s"] = { "σ", [[\sigma]] },
	[";t"] = { "τ", [[\tau]] },
	[";w"] = { "ω", [[\omega]] },
	[";u"] = { "υ", [[\upsilon]] },
	[";x"] = { "ξ", [[\xi]] },
	[";y"] = { "ψ", [[\psi]] },
	[";z"] = { "ζ", [[\zeta]] },
	[";D"] = { "Δ", [[\Delta]] },
	[";F"] = { "Φ", [[\Phi]] },
	[";G"] = { "Γ", [[\Gamma]] },
	[";L"] = { "Λ", [[\Lambda]] },
	[";P"] = { "Π", [[\Pi]] },
	[";Q"] = { "Θ", [[\Theta]] },
	[";S"] = { "Σ", [[\Sigma]] },
	[";U"] = { "Υ", [[\Upsilon]] },
	[";W"] = { "Ω", [[\Omega]] },
	[";X"] = { "Ξ", [[\Xi]] },
	[";Y"] = { "Ψ", [[\Psi]] }
}

-- trig = { name, command, priority? }
local symbol_specs = {
	-- logic
	inn = { "∈", [[\in ]] },
	["!in"] = { "∉", [[\not\in ]] },
	[";A"] = { "∀", [[\forall]] },
	[";E"] = { "∃", [[\exists]] },
	-- relations and operations
	["!="] = { "!=", [[\neq ]] },
	["<="] = { "≤", [[\leq ]] },
	[">="] = { "≥", [[\geq ]] },
	["<<"] = { "<<", [[\ll ]] },
	[">>"] = { ">>", [[\gg ]] },
	["~~"] = { "~", [[\sim ]] },
	["~="] = { "≃", [[\simeq ]] },
	["=~"] = { "≅", [[\cong ]] },
	["::"] = { ":", [[\colon ]] },
	[":="] = { "≔", [[\coloneqq ]] },
	["=:"] = { "≔", [[\eqqcolon ]] },
	["..."] = { "·", [[\dots]] },
	["||"] = { "|", [[\mid ]] },
	xx = { "×", [[\times]] },
	op = { "⊕", [[\oplus]] },
	ox = { "⊗", [[\otimes]] },
	nabl = { "∇", [[\nabla]] },
	[";="] = { "≡", [[\equiv ]] },
	[";-"] = { "∖", [[\setminus ]] },
	[";6"] = { "∂", [[\partial]] },
	[";8"] = { "∞", [[\infty]] },
	[";."] = { "·", [[\cdot]] },
	[";<"] = { "⟨", [[\langle]] },
	[";>"] = { "⟩", [[\rangle]] },
	-- number systems and sets
	AA = { "𝔸", [[\mathbb{A}]] },
	CC = { "ℂ", [[\mathbb{C}]] },
	DD = { "𝔻", [[\mathbb{D}]] },
	FF = { "𝔽", [[\mathbb{F}]] },
	GG = { "𝔾", [[\mathbb{G}]] },
	HH = { "ℍ", [[\mathbb{H}]] },
	NN = { "ℕ", [[\mathbb{N}]] },
	OO = { "O", [[\mathcal{O}]] },
	PP = { "ℙ", [[\mathbb{P}]] },
	QQ = { "ℚ", [[\mathbb{Q}]] },
	RR = { "ℝ", [[\mathbb{R}]] },
	ZZ = { "ℤ", [[\mathbb{Z}]] },
	cc = { "⊂", [[\subset ]] },
	cq = { "⊆", [[\subseteq ]] },
	qq = { "⊃", [[\supset ]] },
	qc = { "⊇", [[\supseteq ]] },
	Nn = { "∩", [[\cap ]] },
	UU = { "∪", [[\cup]] },
	[";0"] = { "∅", [[\emptyset]] },
	-- arrows
	["=>"] = { "⇒", [[\implies]] },
	["=<"] = { "⇐", [[\impliedby]] },
	["->"] = { "→", [[\to ]], 250 },
	["!>"] = { "↦", [[\mapsto ]] },
	["-->"] = { "⟶", [[\longrightarrow ]], 500 },
	["<->"] = { "↔", [[\leftrightarrow ]], 500 },
	["2>"] = { "⇉", [[\rightrightarrows ]], 400 },
	iff = { "⟺", [[\iff ]] },
	upar = { "↑", [[\uparrow]] },
	dnar = { "↓", [[\downarrow]] },
	-- spacing and other symbols
	dag = { "†", [[\dagger]] },
	lll = { "ℓ", [[\ell]] },
	quad = { " ", [[\quad ]] }
}

local operator_specs = {
	"arccos", "arcsin", "arctan", "ast", "cod", "coker", "cos", "cot", "csc", "deg", "det", "dim", "exp", "hom", "inf",
	"int", "ker", "log", "max", "min", "perp", "sec", "sin", "star", "tan", "Gr", "Quot"
}

for _, specs in ipairs({ greek_specs, symbol_specs }) do
	for trig, spec in pairs(specs) do
		table.insert(autosnips, symbol_snippet(trig, spec[1], spec[2], spec[3]))
	end
end

for _, trig in ipairs(operator_specs) do
	table.insert(autosnips, auto_backslash_snippet(trig))
end

return nil, autosnips
