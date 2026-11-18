local pattern = require("math-snippets.triggers").pattern
local tex = require("math-snippets.latex")

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }

-- A hidden math snippet whose text is computed from its pattern captures.
---@param trig    string                          Lua pattern; its captures are passed to `render`
---@param name    string
---@param max_len integer                         Bound on the trigger length
---@param render  fun(captures: string[]): string
---@param context table?                          Extra context fields, such as `desc` or `wordTrig`
local function capture_snippet(trig, name, max_len, render, context)
	context = context or {}
	context.trig, context.name, context.hidden = trig, name, true
	context.trigEngine, context.trigEngineOpts = pattern, { max_len = max_len }
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

	-- LuaSnip assigns priority per snippet. Keep these arrows individually overridable.
	s({ trig = "->", name = "→", priority = 250, wordTrig = false, hidden = true }, t([[\to ]]), math_opts),
	s({ trig = "2>", name = "⇉", priority = 400, wordTrig = false, hidden = true }, t([[\rightrightarrows ]]), math_opts),
	s({ trig = "-->", name = "⟶", priority = 500, wordTrig = false, hidden = true }, t([[\longrightarrow ]]), math_opts),
	s({ trig = "<->", name = "↔", priority = 500, wordTrig = false, hidden = true }, t([[\leftrightarrow ]]), math_opts),

	-- Arrows that adapt to a tikzcd environment.
	s({ trig = "ar", name = "normal arrows", hidden = true }, { t("\\ar["), i(1), t("]") }, { condition = tex.in_tikzcd }),
	arrow_snippet("rmap", "rational map arrow", "dashrightarrow"),
	arrow_snippet("emb", "embedding map arrow", "hookrightarrow")
}

-- Fixed symbols, all expanded by the `symbols` snippet below. trig = command
local greek_specs = {
	[";a"] = [[\alpha]],
	[";b"] = [[\beta]],
	[";c"] = [[\chi]],
	[";d"] = [[\delta]],
	[";e"] = [[\epsilon]],
	[";ve"] = [[\varepsilon]],
	[";f"] = [[\phi]],
	[";vf"] = [[\varphi]],
	[";g"] = [[\gamma]],
	[";h"] = [[\eta]],
	[";i"] = [[\iota]],
	[";k"] = [[\kappa]],
	[";l"] = [[\lambda]],
	[";m"] = [[\mu]],
	[";n"] = [[\nu]],
	[";p"] = [[\pi]],
	[";q"] = [[\theta]],
	[";r"] = [[\rho]],
	[";s"] = [[\sigma]],
	[";t"] = [[\tau]],
	[";w"] = [[\omega]],
	[";u"] = [[\upsilon]],
	[";x"] = [[\xi]],
	[";y"] = [[\psi]],
	[";z"] = [[\zeta]],
	[";D"] = [[\Delta]],
	[";F"] = [[\Phi]],
	[";G"] = [[\Gamma]],
	[";L"] = [[\Lambda]],
	[";P"] = [[\Pi]],
	[";Q"] = [[\Theta]],
	[";S"] = [[\Sigma]],
	[";U"] = [[\Upsilon]],
	[";W"] = [[\Omega]],
	[";X"] = [[\Xi]],
	[";Y"] = [[\Psi]]
}

-- trig = command
local symbol_specs = {
	-- logic
	inn = [[\in ]],
	["!in"] = [[\not\in ]],
	[";A"] = [[\forall]],
	[";E"] = [[\exists]],
	-- relations and operations
	["!="] = [[\neq ]],
	["<="] = [[\leq ]],
	[">="] = [[\geq ]],
	["<<"] = [[\ll ]],
	[">>"] = [[\gg ]],
	["~~"] = [[\sim ]],
	["~="] = [[\simeq ]],
	["=~"] = [[\cong ]],
	["::"] = [[\colon ]],
	[":="] = [[\coloneqq ]],
	["=:"] = [[\eqqcolon ]],
	["..."] = [[\dots]],
	["||"] = [[\mid ]],
	xx = [[\times]],
	op = [[\oplus]],
	ox = [[\otimes]],
	nabl = [[\nabla]],
	[";="] = [[\equiv ]],
	[";-"] = [[\setminus ]],
	[";6"] = [[\partial]],
	[";8"] = [[\infty]],
	[";."] = [[\cdot]],
	[";<"] = [[\langle]],
	[";>"] = [[\rangle]],
	-- number systems and sets
	AA = [[\mathbb{A}]],
	CC = [[\mathbb{C}]],
	DD = [[\mathbb{D}]],
	FF = [[\mathbb{F}]],
	GG = [[\mathbb{G}]],
	HH = [[\mathbb{H}]],
	NN = [[\mathbb{N}]],
	OO = [[\mathcal{O}]],
	PP = [[\mathbb{P}]],
	QQ = [[\mathbb{Q}]],
	RR = [[\mathbb{R}]],
	ZZ = [[\mathbb{Z}]],
	cc = [[\subset ]],
	cq = [[\subseteq ]],
	qq = [[\supset ]],
	qc = [[\supseteq ]],
	Nn = [[\cap ]],
	UU = [[\cup]],
	[";0"] = [[\emptyset]],
	-- arrows
	["=>"] = [[\implies]],
	["=<"] = [[\impliedby]],
	["!>"] = [[\mapsto ]],
	iff = [[\iff ]],
	upar = [[\uparrow]],
	dnar = [[\downarrow]],
	-- spacing and other symbols
	dag = [[\dagger]],
	lll = [[\ell]],
	quad = [[\quad ]]
}

local operator_specs = {
	"arccos", "arcsin", "arctan", "ast", "cod", "coker", "cos", "cot", "csc", "deg", "det", "dim", "exp", "hom", "inf",
	"int", "ker", "log", "max", "min", "perp", "sec", "sin", "star", "tan", "Gr", "Quot"
}

-- One snippet looks up the typed text in this table, instead of LuaSnip testing
-- about 120 separate triggers on every keystroke.
---@type table<string, { command: string, word_start: boolean }>
local symbols = {}
for _, specs in ipairs({ greek_specs, symbol_specs }) do
	for trig, command in pairs(specs) do
		symbols[trig] = { command = command, word_start = false }
	end
end
-- Operator names expand only at the start of a word, so `arcsin` is not `arc\sin`.
for _, name in ipairs(operator_specs) do
	symbols[name] = { command = "\\" .. name, word_start = true }
end

local longest_trigger = 0
for trig in pairs(symbols) do
	longest_trigger = math.max(longest_trigger, #trig)
end

-- Try longer suffixes such as `arcsin` before `sin`.
---@return fun(line_to_cursor: string): string?, string[]?
local function symbol_trigger()
	return function (line_to_cursor)
		for length = math.min(longest_trigger, #line_to_cursor), 1, -1 do
			local trig = line_to_cursor:sub(-length)
			local symbol = symbols[trig]
			if symbol then
				local before = line_to_cursor:sub(-length - 1, -length - 1)
				-- A command typed without its backslash must not expand after one.
				local after_backslash = before == "\\" and symbol.command:sub(2, length + 1) == trig
				local inside_word = symbol.word_start and before:find("[%w_]") ~= nil
				if not after_backslash and not inside_word then
					return trig, {}
				end
			end
		end
	end
end

-- `trig` is only a label; `symbol_trigger` does the matching. Hidden, because a
-- completion menu cannot list the individual symbols of one snippet.
table.insert(autosnips, s({
	trig = "symbols",
	name = "symbols",
	desc = "Greek letters, relations, arrows and operator names",
	docTrig = ";a", -- LuaSnip uses this trigger for the static preview.
	trigEngine = symbol_trigger,
	wordTrig = false,
	hidden = true
}, f(function (_, snip)
	return symbols[snip.trigger].command
end), math_opts))

return nil, autosnips
