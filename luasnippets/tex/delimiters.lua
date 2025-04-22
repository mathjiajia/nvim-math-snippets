local autosnips = {}

local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local tex = require("math-snippets.latex")

local brackets = {
	a = { "\\langle", "\\rangle" },
	m = { "|", "|" },
	v = { "\\Vert", "\\Vert" },
}
local lrbrackets = {
	a = { "\\langle", "\\rangle" },
	A = { "Angle", "Angle" },
	b = { "brack", "brack" },
	B = { "Brack", "Brack" },
	c = { "brace", "brace" },
	m = { "|", "|" },
	p = { "(", ")" },
}

local function get_visual(_, parent)
	if #parent.snippet.env.SELECT_RAW > 0 then
		return sn(nil, i(1, parent.snippet.env.SELECT_RAW))
	else
		return sn(nil, i(1))
	end
end

autosnips = {
	s(
		{
			trig = "bk([aAbBcm])",
			name = "brackets",
			desc = "brackets delimiters",
			trigEngine = "pattern",
			hidden = true,
			condition = tex.in_math,
			show_condition = tex.in_math,
		},
		fmta([[<> <><><>]], {
			f(function(_, snip)
				local cap = snip.captures[1] or "p"
				return brackets[cap][1]
			end),
			d(1, get_visual),
			f(function(_, snip)
				local cap = snip.captures[1] or "p"
				return brackets[cap][2]
			end),
			i(0),
		})
	),
	s(
		{
			trig = "lr([aAbBcmp])",
			name = "left right",
			desc = "left right delimiters",
			trigEngine = "pattern",
			hidden = true,
			condition = tex.in_math,
			show_condition = tex.in_math,
		},
		fmta([[\left<> <>\right<><>]], {
			f(function(_, snip)
				local cap = snip.captures[1] or "p"
				return lrbrackets[cap][1]
			end),
			d(1, get_visual),
			f(function(_, snip)
				local cap = snip.captures[1] or "p"
				return lrbrackets[cap][2]
			end),
			i(0),
		})
	),

	s(
		{
			trig = "cvec",
			name = "column vector",
			hidden = true,
			condition = expand_line_begin * tex.in_math,
		},
		fmta(
			[[
			\begin{pmatrix}
				<>_<> \\
				\vdots \\
				<>_<>
			\end{pmatrix}
			]],
			{ i(1, "x"), i(2, "1"), rep(1), i(3, "n") }
		)
	),
}

return nil, autosnips
