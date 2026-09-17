local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local tex = require("math-snippets.latex")
local get_visual = require("math-snippets.util").get_visual

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

local function bracket_snippet(trig, name, template)
	return s({
		trig = trig .. "([aAbBcmpv])",
		name = name,
		desc = name .. " delimiters",
		trigEngine = "pattern",
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

return nil, {
	bracket_snippet("bk", "brackets", [[<> <><><>]]),
	bracket_snippet("lr", "left right", [[\left<> <>\right<><>]]),
	s({
		trig = "cvec",
		name = "column vector",
		hidden = true,
		condition = expand_line_begin * tex.in_math
	}, fmta(
		[[
			\begin{pmatrix}
				<>_<> \\
				\vdots \\
				<>_<>
			\end{pmatrix}
			]], { i(1, "x"), i(2, "1"), rep(1), i(3, "n") }
	))
}
