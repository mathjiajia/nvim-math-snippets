local snips, autosnips = {}, {}

local tex = require("math-snippets.latex")
local pos = require("math-snippets.position")
local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin

local beamer_opts = {
	condition = expand_line_begin * pos.in_beamer * tex.in_text,
	show_condition = pos.show_line_begin * pos.in_beamer * tex.in_text,
}

local begin_opts = {
	condition = expand_line_begin,
	show_condition = pos.show_line_begin,
}

local bullet_opts = {
	condition = expand_line_begin * tex.in_bullets,
	show_condition = pos.show_line_begin * tex.in_bullets,
}

local env_opts = {
	condition = expand_line_begin * tex.in_text,
	show_condition = pos.show_line_begin * tex.in_text,
}

local math_opts = {
	condition = expand_line_begin * tex.in_math,
	show_condition = pos.show_line_begin * tex.in_math,
}

-- Generating functions for Matrix/Cases
local generate_matrix = function(_, snip)
	local rows = tonumber(snip.captures[2])
	local cols = tonumber(snip.captures[3])
	local nodes = {}
	local ins_indx = 1
	for j = 1, rows do
		table.insert(nodes, r(ins_indx, tostring(j) .. "x1", i(1)))
		ins_indx = ins_indx + 1
		for k = 2, cols do
			table.insert(nodes, t(" & "))
			table.insert(nodes, r(ins_indx, tostring(j) .. "x" .. tostring(k), i(1)))
			ins_indx = ins_indx + 1
		end
		table.insert(nodes, t({ "\\\\", "" }))
	end
	-- fix last node.
	nodes[#nodes] = t("\\\\")
	return sn(nil, nodes)
end

-- update for cases
local generate_cases = function(_, snip)
	local rows = tonumber(snip.captures[1]) or 2 -- default option 2 for cases
	local cols = 2 -- fix to 2 cols
	local nodes = {}
	local ins_indx = 1
	for j = 1, rows do
		table.insert(nodes, r(ins_indx, tostring(j) .. "x1", i(1)))
		ins_indx = ins_indx + 1
		for k = 2, cols do
			table.insert(nodes, t(" & "))
			table.insert(nodes, r(ins_indx, tostring(j) .. "x" .. tostring(k), i(1)))
			ins_indx = ins_indx + 1
		end
		table.insert(nodes, t({ "\\\\", "" }))
	end
	-- fix last node.
	table.remove(nodes, #nodes)
	return sn(nil, nodes)
end

local function env_snippet(trig, env)
	local context = { trig = trig, name = trig, desc = trig .. " Environment" }
	return s(
		context,
		fmta(
			[[
			\begin{<>}
				<>
			\end{<>}
			]],
			{ t(env), i(0), t(env) }
		),
		env_opts
	)
end

local function labeled_env_snippet(trig, env)
	local context = { trig = trig, name = trig, desc = "Labeled" .. trig .. " Environment" }
	return s(
		context,
		fmta(
			[[
			\begin{<>}[<>]\zlabel{<>:<>}
				<>
			\end{<>}
			]],
			{ t(env), i(1), t(trig), l(l._1:gsub("[^%w]+", "_"):gsub("_$", ""):lower(), 1), i(0), t(env) }
		),
		env_opts
	)
end

local function sec_snippet(trig, name)
	local context = {
		trig = trig,
		name = name,
		desc = name,
	}
	return s(
		context,
		fmta(
			[[
			\<>{<>}\zlabel{<>:<>}

			<>
			]],
			{ t(name), i(1), t(trig), l(l._1:gsub("[^%w]+", "_"):gsub("_*$", ""):lower(), 1), i(0) }
		),
		env_opts
	)
end

snips = {
	s(
		{
			trig = "([bBpvV])mat_(%d+)x_(%d+)([ar])",
			name = "[bBpvV]matrix",
			dscr = "matrices",
			trigEngine = "pattern",
			hidden = true,
		},
		fmta(
			[[
    \begin{<>}<>
    <>
    \end{<>}]],
			{
				f(function(_, snip)
					return snip.captures[1] .. "matrix"
				end),
				f(function(_, snip)
					if snip.captures[4] == "a" then
						local out = string.rep("c", tonumber(snip.captures[3]) - 1)
						return "[" .. out .. "|c]"
					end
					return ""
				end),
				d(1, generate_matrix),
				f(function(_, snip)
					return snip.captures[1] .. "matrix"
				end),
			}
		),
		math_opts
	),
}

autosnips = {
	------------
	-- BEAMER --
	------------
	s(
		{ trig = "bfr", name = "Beamer Frame Environment" },
		fmta(
			[[
			\begin{frame}
				\frametitle{<>}
				<>
			\end{frame}
			]],
			{ i(1, "frame title"), i(0) }
		),
		beamer_opts
	),
	s(
		{ trig = "bbl", name = "Beamer Block Environment" },
		fmta(
			[[
			\begin{block}{<>}
				<>
			\end{block}
			]],
			{ i(1), i(0) }
		),
		beamer_opts
	),

	---------
	-- ENV --
	---------
	s(
		{
			trig = "beg",
			name = "begin/end",
			desc = "begin/end environment (generic)",
		},
		fmta(
			[[
			\begin{<>}
				<>
			\end{<>}
			]],
			{ i(1), i(0), rep(1) }
		),
		begin_opts
	),
	s(
		{ trig = "lprf", name = "Titled Proof", desc = "Create a titled proof environment." },
		fmta(
			[[
			\begin{proof}[Proof of \zcref{<>}]
				<>
			\end{proof}
			]],
			{ i(1), i(0) }
		),
		env_opts
	),

	s(
		{ trig = "(%d?)cases", name = "eases", desc = "cases", trigEngine = "pattern", hidden = true },
		fmta(
			[[
			\begin{cases}
				<>
			\end{cases}
			]],
			{ d(1, generate_cases) }
		),
		math_opts
	),

	s(
		{ trig = "tkz", name = "tikzcd Environment", desc = "Create a tikzcd environment." },
		fmta(
			[[
			\[
				\begin{tikzcd}
					<> \\
				\end{tikzcd}
			\]
			<>
			]],
			{ i(1), i(0) }
		),
		env_opts
	),
	s(
		{ trig = "bit", name = "itemize", desc = "bullet points (itemize)" },
		fmta(
			[[
			\begin{itemize}
				\item <>
			\end{itemize}
			]],
			{ c(1, { i(0), sn(nil, fmta([[[<>] <>]], { i(1), i(0) })) }) }
		),
		env_opts
	),

	-- requires enumitem
	s(
		{ trig = "ben", name = "enumerate", desc = "numbered list (enumerate)" },
		fmta(
			[[
			\begin{enumerate}<>
				\item <>
			\end{enumerate}
			]],
			{
				c(1, {
					t(""),
					sn(
						nil,
						fmta([[[label=<>] ]], { c(1, { t("(\\arabic*)"), t("(\\alph*)"), t("(\\roman*)"), i(1) }) })
					),
				}),
				c(2, { i(0), sn(nil, fmta([[[<>] <>]], { i(1), i(0) })) }),
			}
		),
		env_opts
	),

	-- generate new bullet points
	s({ trig = "--", hidden = true }, { t("\\item ") }, bullet_opts),
	s({
		trig = "!-",
		name = "bullet point",
		desc = "bullet point with custom text",
	}, fmta([[\item [<>]<>]], { i(1), i(0) }), bullet_opts),

	s(
		{
			trig = "bal",
			name = "align(|*|ed)",
			desc = "align math",
		},
		fmta(
			[[
			\begin{align<>}
				<>
			\end{align<>}
			]],
			{ c(1, { t("*"), t(""), t("ed") }), i(2), rep(1) }
		),
		begin_opts
	),

	s(
		{
			trig = "bfu",
			name = "function",
		},
		fmta(
			[[
			\begin{equation*}
				<>\colon <>\longrightarrow <>, \quad <>\longmapsto <>(<>)=<>
			\end{equation*}
			]],
			{ i(1), i(2), i(3), i(4), rep(1), rep(4), i(0) }
		),
		begin_opts
	),

	s(
		{
			trig = "beq",
			desc = "labeled_equation",
		},
		fmta(
			[[
			\begin{equation}\zlabel{eq:<>}
				<>
			\end{equation}
			]],
			{ i(2), i(1) }
		),
		begin_opts
	),
}

local sec_specs = {
	cha = "chapter",
	sec = "section",
	ssec = "section*",
	sub = "subsection",
	ssub = "subsection*",
}

for k, v in pairs(sec_specs) do
	table.insert(snips, sec_snippet(k, v))
end

local env_specs = {
	-- beq = "equation",
	bseq = "equation*",
	proof = "proof",
	conj = "conjecture",
	cor = "corollary",
	dfn = "definition",
	lem = "lemma",
	prop = "proposition",
	rem = "remark",
	thm = "theorem",
}

local labeled_env_specs = {
	lconj = "conjecture",
	lcor = "corollary",
	ldfn = "definition",
	llem = "lemma",
	lprop = "proposition",
	lrem = "remark",
	lthm = "theorem",
}

local env_snippets = {}

for k, v in pairs(env_specs) do
	table.insert(env_snippets, env_snippet(k, v))
end
for k, v in pairs(labeled_env_specs) do
	table.insert(env_snippets, labeled_env_snippet(k, v))
end

vim.list_extend(autosnips, env_snippets)

return snips, autosnips
