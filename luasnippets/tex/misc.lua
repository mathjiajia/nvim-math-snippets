local tex = require("math-snippets.latex")
local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local pattern_engine = require("luasnip.nodes.util.trig_engines").pattern

local opts = { condition = tex.in_text }

local function appended_space_after_insert()
	vim.api.nvim_create_autocmd("InsertCharPre", {
		callback = function ()
			if vim.v.char:find("%a") then
				vim.v.char = " " .. vim.v.char
			end
		end,
		buf = 0,
		once = true,
		desc = "Auto Add a Space after Inline Math"
	})
end

local function surround_with_inline_math(_, snip)
	local captures = snip.captures
	return captures[1] .. "\\(" .. captures[2] .. "\\)" .. captures[3] .. captures[4]
end

local function whitespace_pattern(trig, options)
	local match = pattern_engine(trig, options)
	return function (line_to_cursor, trigger)
		-- All automatic inline-math patterns require trailing whitespace.
		if not line_to_cursor:sub(-1):find("%s") then
			return nil
		end
		return match(line_to_cursor, trigger)
	end
end

local function automatic_inline_math(trig, name)
	return s({
		trig = trig,
		name = name,
		wordTrig = false,
		trigEngine = whitespace_pattern,
		hidden = true
	}, f(surround_with_inline_math), opts)
end

return nil, {
		automatic_inline_math("(%s)([b-zB-HJ-Z0-9])([,;.%-%)]?)(%s+)", "single-letter variable"),
		automatic_inline_math("(%s)([0-9]+[a-zA-Z]+)([,;.%)]?)(%s+)", "surround word starting with number"),
		automatic_inline_math("(%s)(%w[-_+=><]%w)([,;.%)]?)(%s+)", "surround i+1"),
		s({
			trig = "mk",
			name = "inline math",
			desc = "Insert inline Math Environment.",
			hidden = true,
			condition = tex.in_text
		},
			fmt([[\({}\){}]], { i(1), i(0) }), {
				callbacks = {
					[-1] = {
						[events.leave] = appended_space_after_insert
					}
				}
			}),
		s({
			trig = "dm",
			name = "display math",
			desc = "Insert display Math Environment."
		}, fmt([[
			\[
				{}
			\]
			{}
			]], { i(1), i(0) }), opts),
		s({
			trig = "pha",
			name = "phantom",
			desc = "create a space",
			hidden = true,
			condition = expand_line_begin * tex.in_align
		}, { t("&\\phantom{\\;=\\;} ") }),

		s({
			trig = "ni",
			name = "non-indented paragraph",
			desc = "Insert non-indented paragraph."
		}, { t({ "\\noindent", "" }) }, opts)
	}
