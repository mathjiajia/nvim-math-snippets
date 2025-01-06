local snips, autosnips = {}, {}

local conds_expand = require("luasnip.extras.conditions.expand")
local tex = require("mySnippets.latex")
local pos = require("mySnippets.position")

local reference_snippet_table = {
	a = "auto",
	r = "",
	z = "zc",
}

local opts = { condition = tex.in_text, show_condition = tex.in_text }
local opts2 = {
	condition = conds_expand.line_begin * tex.in_text,
	show_condition = pos.line_begin * tex.in_text,
}

local function phrase_snippet(trig, body)
	return s({ trig = trig, desc = trig }, t(body), opts)
end

snips = {
	s(
		{ trig = "cf", name = "cross refrence", condition = tex.in_text, show_condition = tex.in_text },
		fmta([[\cite[<>]{<>}<>]], { i(1), i(2), i(0) })
		-- {
		-- 	callbacks = {
		-- 		[1] = {
		-- 			[events.enter] = function()
		-- 				require("telescope").extensions.bibtex.bibtex(
		-- 					require("telescope.themes").get_dropdown({ previewer = false })
		-- 				)
		-- 			end,
		-- 		},
		-- 	},
		-- }
	),
}

autosnips = {
	s({ trig = "alab", name = "label", dscr = "add a label" }, fmta([[\zlabel{<>:<>}<>]], { i(1), i(2), i(0) })),

	s(
		{
			trig = "([arz])ref",
			name = "(arz)?ref",
			desc = "add a reference (with autoref, zcref)",
			trigEngine = "pattern",
			hidden = true,
		},
		fmta(
			[[\<>ref{<>}<>]],
			{ f(function(_, snip)
				return reference_snippet_table[snip.captures[1]]
			end), i(1), i(0) }
		),
		opts
	),

	s(
		{ trig = "eqref", desc = "add a reference with eqref", hidden = true },
		fmta([[\eqref{eq:<>}<>]], { i(1), i(0) }),
		{
			condition = tex.in_text,
			show_condition = tex.in_text,
			callbacks = {
				[1] = {
					[events.enter] = function()
						require("blink.cmp").show({ providers = { "lsp" } })
					end,
				},
			},
		}
	),

	s({
		trig = "Tfae",
		name = "The following are equivalent",
	}, { t("The following are equivalent") }, opts2),

	s({
		trig = "([wW])log",
		name = "without loss of generality",
		trigEngine = "pattern",
	}, {
		f(function(_, snip)
			return snip.captures[1] .. "ithout loss of generality"
		end, {}),
	}, opts2),

	s({ trig = "([qr])c", name = "Cartier", trigEngine = "pattern" }, {
		f(function(_, snip)
			return "\\(\\mathbb{" .. string.upper(snip.captures[1]) .. "}\\)-Cartier"
		end, {}),
	}, opts),
	s({ trig = "([qr])d", name = "divisor", trigEngine = "pattern" }, {
		f(function(_, snip)
			return "\\(\\mathbb{" .. string.upper(snip.captures[1]) .. "}\\)-divisor"
		end, {}),
	}, opts),
}

local phrase_specs = {
	-- cf = "cf.~",
	klt = "Kawamata log terminal",
	resp = "resp.\\ ",
	ses = "short exact sequence",
}

local auto_phrase_specs = {
	bqf = "base point free",
	cd = "Cartier divisor",
	egg = "e.g., ",
	fgd = "finitely generated",
	gbgs = "generated by global sections",
	ggg = "generically globally generated",
	iee = "i.e., ",
	iff = "if and only if ",
	lci = "local complete intersection",
	lmm = "log minimal model",
	mfs = "Mori fibre space",
	nbhd = "neighbourhood",
	nc = "\\((-1)\\)-curve",
	pef = "pseudo-effective",
	qf = "\\(\\mathbb{Q}\\)-factorial",
	snc = "simple normal crossing",
	stt = "such that",
	tfae = "the following are equivalent",
	wd = "Weil divisor",
	wrt = "with respect to ",
}

for k, v in pairs(phrase_specs) do
	table.insert(snips, phrase_snippet(k, v))
end
for k, v in pairs(auto_phrase_specs) do
	table.insert(autosnips, phrase_snippet(k, v))
end

return snips, autosnips
