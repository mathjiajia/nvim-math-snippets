local tex = require("math-snippets.latex")
local auto_trigger = require("math-snippets.util").auto_trigger

local math_opts = { condition = tex.in_math, show_condition = tex.in_math }
local text_opts = { condition = tex.in_text, show_condition = tex.in_text }

-- Dynamically generates snippets based on matched postfix.
local function generate_postfix_dynamicnode(_, parent, _, prefix)
	local capture = parent.snippet.env.POSTFIX_MATCH
	local content = #capture > 0 and t(capture) or i(1, parent.snippet.env.SELECT_RAW)
	return sn(nil, { t(prefix), content, t("}"), i(0) })
end

local function postfix_snippet(trig, command, description, priority)
	local prefix = "\\" .. command .. "{"
	local context = {
		trig = trig,
		name = description,
		desc = description,
		priority = priority,
		docstring = prefix .. [[(POSTFIX_MATCH|VISUAL|<1>)}]],
		match_pattern = [[[%w%.%_%-%"%']*$]]
	}
	if prefix:find(trig) == 2 then
		context.trigEngine = "ecma"
		context.trig = auto_trigger(trig)
		context.hidden = true
	end
	return postfix(context, { d(1, generate_postfix_dynamicnode, {}, { user_args = { prefix } }) }, math_opts)
end

local snips = {
	s({ trig = "bf", name = "bold", desc = "Insert bold text." }, { t("\\textbf{"), i(1), t("}") }, text_opts),
	s({ trig = "it", name = "italic", desc = "Insert italic text." }, { t("\\textit{"), i(1), t("}") }, text_opts),
	s({ trig = "em", name = "emphasize", desc = "Insert emphasized text." }, { t("\\emph{"), i(1), t("}") }, text_opts)
}

local autosnips = {
	s(
		{ trig = "tss", name = "text subscript", wordTrig = false, hidden = true }, { t("_{\\mathrm{"), i(1), t("}}") },
		{ condition = tex.in_math }
	)
}

local postfix_math_specs = {
	-- command, description, optional priority
	mbb = { "mathbb", "math blackboard bold" },
	mcal = { "mathcal", "math calligraphic" },
	mscr = { "mathscr", "math script" },
	mfr = { "mathfrak", "mathfrak" },
	hat = { "widehat", "hat", 500 },
	bar = { "overline", "bar (overline)", 500 },
	td = { "widetilde", "tilde", 500 }
}

for trig, spec in pairs(postfix_math_specs) do
	table.insert(autosnips, postfix_snippet(trig, spec[1], spec[2], spec[3]))
end

return snips, autosnips
