local snips, autosnips = {}, {}

local conds_expand = require("luasnip.extras.conditions.expand")
local tex = require("math-snippets.latex")
local pos = require("math-snippets.position")

local opts = {
	condition = conds_expand.line_begin * tex.in_text,
	show_condition = pos.line_begin * tex.in_text,
}

-- Generating function for LaTeX environments like matrix and cases
local function generate_env(rows, cols, default_cols)
	cols = cols or default_cols
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
	return nodes
end

local generate_matrix = function(_, snip)
	local nodes = generate_env(tonumber(snip.captures[2]), tonumber(snip.captures[3]))
	-- fix last node.
	nodes[#nodes] = t("\\\\")
	return sn(nil, nodes)
end

local generate_cases = function(_, snip)
	local nodes = generate_env(tonumber(snip.captures[1]), 2)
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
		opts
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
		opts
	)
end

snips = {
	s(
		{
			trig = "([bBpvV])mat_(%d+)x_(%d+)([ar])",
			name = "[bBpvV]matrix",
			desc = "matrices",
			trigEngine = "pattern",
			hidden = true,
			condition = tex.in_math,
		},
		fmta(
			[[
			\begin{<>}<>
				<>
			\end{<>}
			]],
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
		)
	),
}

autosnips = {
	s(
		{
			trig = "beg",
			name = "begin/end",
			desc = "begin/end environment (generic)",
			condition = conds_expand.line_begin,
			show_condition = pos.line_begin,
		},
		fmta(
			[[
			\begin{<>}
				<>
			\end{<>}
			]],
			{ i(1), i(0), rep(1) }
		)
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
		opts
	),

	s(
		{ trig = "(%d?)cases", name = "cases", desc = "cases", trigEngine = "pattern", hidden = true },
		fmta(
			[[
			\begin{cases}
				<>
			\end{cases}
			]],
			{ d(1, generate_cases) }
		),
		opts
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
		opts
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
		opts
	),
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
		opts
	),

	-- generate new bullet points
	s({
		trig = "--",
		hidden = true,
		condition = conds_expand.line_begin * tex.in_bullets,
		show_condition = pos.line_begin * tex.in_bullets,
	}, { t("\\item ") }),

	s({
		trig = "!-",
		name = "bullet point",
		desc = "bullet point with custom text",
		condition = conds_expand.line_begin * tex.in_bullets,
		show_condition = pos.line_begin * tex.in_bullets,
	}, fmta([[\item [<>]<>]], { i(1), i(0) })),

	s(
		{
			trig = "bal",
			name = "align(|*|ed)",
			desc = "align math",
			condition = conds_expand.line_begin,
			show_condition = pos.line_begin,
		},
		fmta(
			[[
			\begin{align<>}
				<>
			\end{align<>}
			]],
			{ c(1, { t("*"), t(""), t("ed") }), i(2), rep(1) }
		)
	),

	s(
		{
			trig = "bfu",
			name = "function",
			condition = conds_expand.line_begin,
			show_condition = pos.line_begin,
		},
		fmta(
			[[
			\begin{equation*}
				<>\colon <>\longrightarrow <>, \quad <>\longmapsto <>(<>)=<>
			\end{equation*}
			]],
			{ i(1), i(2), i(3), i(4), rep(1), rep(4), i(0) }
		)
	),

	s(
		{
			trig = "beq",
			desc = "labeled_equation",
			condition = conds_expand.line_begin,
			show_condition = pos.line_begin,
		},
		fmta(
			[[
			\begin{equation}\zlabel{eq:<>}
				<>
			\end{equation}
			]],
			{ i(2), i(1) }
		)
	),
}

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
