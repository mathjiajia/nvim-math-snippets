local tex = require("math-snippets.latex")
local pos = require("math-snippets.position")
local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin

local beamer_opts = {
	condition = expand_line_begin * pos.in_beamer * tex.in_text,
	show_condition = pos.show_line_begin * pos.in_beamer * tex.in_text
}

local begin_opts = { condition = expand_line_begin, show_condition = pos.show_line_begin }

local bullet_opts = {
	condition = expand_line_begin * tex.in_bullets,
	show_condition = pos.show_line_begin * tex.in_bullets
}

local env_opts = { condition = expand_line_begin * tex.in_text, show_condition = pos.show_line_begin * tex.in_text }

local math_opts = { condition = expand_line_begin * tex.in_math, show_condition = pos.show_line_begin * tex.in_math }

-- Restore keys keep cell contents when the matrix is regenerated.
local function generate_matrix(_, snip)
	local rows = tonumber(snip.captures[2])
	local cols = tonumber(snip.captures[3])
	local nodes = {}
	local insert_index = 1

	for row = 1, rows do
		for col = 1, cols do
			if col > 1 then
				table.insert(nodes, t(" & "))
			end
			table.insert(nodes, r(insert_index, string.format("%dx%d", row, col), i(1)))
			insert_index = insert_index + 1
		end

		if row ~= rows then
			table.insert(nodes, t({ " \\\\", "\t" }))
		end
	end

	return sn(nil, nodes)
end

local function generate_cases(_, snip)
	local rows = tonumber(snip.captures[1]) or 2
	local nodes = {}

	for row = 1, rows do
		table.insert(nodes, r(2 * row - 1, row .. "l", i(1)))
		table.insert(nodes, t(" & "))
		table.insert(nodes, r(2 * row, row .. "r", i(1)))
		if row ~= rows then
			table.insert(nodes, t({ " \\\\", "\t" }))
		end
	end

	return sn(nil, nodes)
end

local function env_snippet(trig, env)
	local context = { trig = trig, name = trig, desc = trig .. " Environment" }
	return s(context, fmta([[
			\begin{<>}
				<>
			\end{<>}
			]], { t(env), i(0), t(env) }), env_opts)
end

local function labeled_env_snippet(trig, env)
	local context = { trig = trig, name = trig, desc = "Labeled " .. trig .. " Environment" }
	return s(
		context,
		fmta(
			[[
			\begin{<>}[<>]\zlabel{<>:<>}
				<>
			\end{<>}
			]], { t(env), i(1), t(trig), l(l._1:gsub("[^%w]+", "_"):gsub("_$", ""):lower(), 1), i(0), t(env) }
		), env_opts
	)
end

local function sec_snippet(trig, name)
	local context = { trig = trig, name = name, desc = name }
	return s(
		context,
		fmta(
			[[
			\<>{<>}\zlabel{<>:<>}

			<>
			]], { t(name), i(1), t(trig), l(l._1:gsub("[^%w]+", "_"):gsub("_*$", ""):lower(), 1), i(0) }
		), env_opts
	)
end

local function matrix_name(_, snip)
	return snip.captures[1] .. "matrix"
end

local snips = {
	s({
		trig = "([bBpvV])mat_(%d+)x_(%d+)([ar])",
		name = "[bBpvV]matrix",
		desc = "matrices",
		trigEngine = "pattern",
		hidden = true
	},
		fmta([[
			\begin{<>}<>
				<>
			\end{<>}]], {
			f(matrix_name),
			f(function (_, snip)
				if snip.captures[4] == "a" then
					local out = string.rep("c", tonumber(snip.captures[3]) - 1)
					return "[" .. out .. "|c]"
				end
				return ""
			end),
			d(1, generate_matrix),
			f(matrix_name)
		}), math_opts)
}

local autosnips = {
	-- Beamer
	s(
		{ trig = "bfr", name = "Beamer Frame Environment" },
		fmta([[
			\begin{frame}
				\frametitle{<>}
				<>
			\end{frame}
			]], { i(1, "frame title"), i(0) }), beamer_opts
	),
	s(
		{ trig = "bbl", name = "Beamer Block Environment" },
		fmta([[
			\begin{block}{<>}
				<>
			\end{block}
			]], { i(1), i(0) }), beamer_opts
	),

	-- Environments
	s({
		trig = "beg",
		name = "begin/end",
		desc = "begin/end environment (generic)"
	}, fmta([[
			\begin{<>}
				<>
			\end{<>}
			]], { i(1), i(0), rep(1) }), begin_opts),
	s(
		{ trig = "lprf", name = "Titled Proof", desc = "Create a titled proof environment." },
		fmta([[
			\begin{proof}[Proof of \zcref{<>}]
				<>
			\end{proof}
			]], { i(1), i(0) }), env_opts
	),

	s(
		{ trig = "(%d?)cases", name = "cases", desc = "cases", trigEngine = "pattern", hidden = true },
		fmta([[
			\begin{cases}
				<>
			\end{cases}
			]], { d(1, generate_cases) }), math_opts
	),

	s(
		{ trig = "tkz", name = "tikzcd Environment", desc = "Create a tikzcd environment." },
		fmta([[
			\[
				\begin{tikzcd}
					<> \\
				\end{tikzcd}
			\]
			<>
			]], { i(1), i(0) }), env_opts
	),
	s(
		{ trig = "bit", name = "itemize", desc = "bullet points (itemize)" },
		fmta(
			[[
			\begin{itemize}
				\item <>
			\end{itemize}
			]], { c(1, { i(0), sn(nil, fmta([[[<>] <>]], { i(1), i(0) })) }) }
		), env_opts
	),

	-- requires enumitem
	s(
		{ trig = "ben", name = "enumerate", desc = "numbered list (enumerate)" },
		fmta([[
			\begin{enumerate}<>
				\item <>
			\end{enumerate}
			]], {
			c(1, {
				t(""),
				sn(nil, fmta([[[label=<>] ]], { c(1, { t("(\\arabic*)"), t("(\\alph*)"), t("(\\roman*)"), i(1) }) }))
			}),
			c(2, { i(0), sn(nil, fmta([[[<>] <>]], { i(1), i(0) })) })
		}),
		env_opts
	),

	-- generate new bullet points
	s({ trig = "--", hidden = true }, { t("\\item ") }, bullet_opts),
	s({
		trig = "!-",
		name = "bullet point",
		desc = "bullet point with custom text"
	}, fmta([[\item [<>]<>]], { i(1), i(0) }), bullet_opts),

	s({
		trig = "bal",
		name = "align(|*|ed)",
		desc = "align math"
	}, fmta([[
			\begin{align<>}
				<>
			\end{align<>}
			]], { c(1, { t("*"), t(""), t("ed") }), i(2), rep(1) }), begin_opts),

	s({
		trig = "bfu",
		name = "function"
	}, fmta(
		[[
			\begin{equation*}
				<>\colon <>\longrightarrow <>, \quad <>\longmapsto <>(<>)=<>
			\end{equation*}
			]], { i(1), i(2), i(3), i(4), rep(1), rep(4), i(0) }
	), begin_opts),

	s({
		trig = "beq",
		desc = "labeled equation"
	}, fmta([[
			\begin{equation}\zlabel{eq:<>}
				<>
			\end{equation}
			]], { i(2), i(1) }), begin_opts)
}

local sec_specs = { cha = "chapter", sec = "section", ssec = "section*", sub = "subsection", ssub = "subsection*" }

for trig, command in pairs(sec_specs) do
	table.insert(snips, sec_snippet(trig, command))
end

local env_specs = {
	bseq = "equation*",
	proof = "proof",
	conj = "conjecture",
	cor = "corollary",
	dfn = "definition",
	lem = "lemma",
	prop = "proposition",
	rem = "remark",
	thm = "theorem"
}

local labeled_env_specs = {
	lconj = "conjecture",
	lcor = "corollary",
	ldfn = "definition",
	llem = "lemma",
	lprop = "proposition",
	lrem = "remark",
	lthm = "theorem"
}

for trig, env in pairs(env_specs) do
	table.insert(autosnips, env_snippet(trig, env))
end
for trig, env in pairs(labeled_env_specs) do
	table.insert(autosnips, labeled_env_snippet(trig, env))
end

return snips, autosnips
