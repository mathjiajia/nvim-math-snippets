local tex = require("math-snippets.latex")
local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local pattern_engine = require("luasnip.nodes.util.trig_engines").pattern
local api = vim.api

local opts = { condition = tex.in_text }

local function appended_space_after_insert(snip)
	local buffer = api.nvim_get_current_buf()
	local group = api.nvim_create_augroup("MathSnippetsInlineMathSpace", { clear = false })
	local function clear()
		api.nvim_clear_autocmds({ group = group, buffer = buffer })
	end
	-- Leaving the same snippet again must replace any pending spacing callback.
	clear()
	local exit = snip.insert_nodes[0]:get_buf_position()
	local tick = api.nvim_buf_get_changedtick(buffer)
	local function at_exit()
		local cursor = api.nvim_win_get_cursor(0)
		return api.nvim_get_current_buf() == buffer and cursor[1] == exit[1] + 1
			and cursor[2] == exit[2] and api.nvim_buf_get_changedtick(buffer) == tick
	end
	api.nvim_create_autocmd("InsertCharPre", {
		callback = function ()
			local add_space = at_exit() and vim.v.char:find("%a")
			clear()
			if add_space then
				vim.v.char = " " .. vim.v.char
			end
		end,
		group = group,
		buffer = buffer,
		once = true,
		desc = "Auto Add a Space after Inline Math"
	})
	api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "BufWipeout" }, {
		group = group,
		buffer = buffer,
		callback = clear,
		desc = "Cancel Pending Inline Math Space"
	})
	api.nvim_create_autocmd("CursorMovedI", {
		group = group,
		buffer = buffer,
		callback = function ()
			if not at_exit() then
				clear()
			end
		end,
		desc = "Cancel Inline Math Space after Moving"
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
