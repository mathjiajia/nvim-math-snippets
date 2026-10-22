local tex = require("math-snippets.latex")
local pattern_engine = require("luasnip.nodes.util.trig_engines").pattern

local text_opts = { condition = tex.in_text }
local spacing_group = vim.api.nvim_create_augroup("math-snippets.inline-space", { clear = true })

local function appended_space_after_insert()
	-- Reentering and leaving a snippet must not stack pending spaces.
	vim.api.nvim_clear_autocmds({ group = spacing_group, event = "InsertCharPre", buf = 0 })
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = spacing_group,
		callback = function ()
			local col = vim.api.nvim_win_get_cursor(0)[2]
			local before = vim.api.nvim_get_current_line():sub(1, col)
			if before:sub(-2) == [[\)]] and vim.v.char:find("%a") then
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
	}, f(surround_with_inline_math), text_opts)
end

local autosnips = {
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
		})
}

return nil, autosnips
