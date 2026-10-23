-- Run from the repository root:
--   nvim --headless -u NONE -i NONE -l tests/snippets.lua
-- LuaSnip and the latex parser must be on 'runtimepath'.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.virtualedit = "onemore"

-- -u NONE skips the TeX language mappings supplied by the editor setup.
vim.treesitter.language.register("latex", { "tex", "plaintex" })

local ls = require("luasnip")
local session = require("luasnip.session")
local snip_env = ls.get_snip_env()
local failures, checks = {}, 0
local loaded = {}

local function equal(label, actual, expected)
	checks = checks + 1
	if not vim.deep_equal(actual, expected) then
		failures[#failures + 1] = ("%s: expected %s, got %s"):format(label, vim.inspect(expected), vim.inspect(actual))
	end
end

local function check(label, callback)
	local ok, err = pcall(callback)
	if not ok then
		checks = checks + 1
		failures[#failures + 1] = label .. ": " .. tostring(err)
	end
end

for _, path in ipairs(vim.fn.glob("luasnippets/**/*.lua", false, true)) do
	check("load " .. path, function ()
		local env = setmetatable({}, {
			__index = function (_, key)
				return snip_env[key] or _G[key]
			end
		})
		local chunk = assert(loadfile(path))
		setfenv(chunk, env)
		local snippets, autosnippets = chunk()
		local all = vim.list_extend(snippets or {}, autosnippets or {})
		equal(path .. " contains snippets", #all > 0, true)
		loaded[path] = all
	end)
end

local function find(file, property, value, priority)
	for _, snippet in ipairs(assert(loaded["luasnippets/" .. file .. ".lua"], "file did not load: " .. file)) do
		if snippet[property] == value and (not priority or snippet.priority == priority) then
			return snippet
		end
	end
	error(("missing snippet %s=%s in %s"):format(property, value, file))
end

local function with_buffer(lines, callback, cursor)
	local buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buffer)
	vim.bo[buffer].filetype = "tex"
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
	vim.api.nvim_win_set_cursor(0, type(cursor) == "table" and cursor or { 1, cursor or #lines[1] })
	vim.treesitter.get_parser(buffer, "latex")
	local ok, result = pcall(callback)
	if session.current_nodes[buffer] then
		ls.unlink_current()
	end
	vim.api.nvim_buf_delete(buffer, { force = true })
	if not ok then
		error(result)
	end
	return result
end

local function buffer_text()
	return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

local function expand(snippet, options)
	return with_buffer({ "" }, function ()
		ls.snip_expand(snippet, options)
		return buffer_text()
	end)
end

local function expand_trigger(snippet, source, cursor)
	local lines = type(source) == "table" and source or { source }
	return with_buffer(lines, function ()
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local before = lines[row]:sub(1, col)
		local match = assert(snippet:matches(before), "trigger did not match: " .. before)
		ls.snip_expand(snippet, {
			expand_params = match,
			clear_region = match.clear_region or { from = { row - 1, #before - #match.trigger }, to = { row - 1, #before } }
		})
		return buffer_text()
	end, cursor
	)
end

for _, trigger in ipairs({ "feat", "fix", "chore", "revert", "refactor", "cleanup" }) do
	check("Git commit " .. trigger, function ()
		equal(
			trigger .. " commit", expand_trigger(find("gitcommit", "trigger", trigger), trigger), trigger .. "(scope): title"
		)
	end)
end

check("Python shebang", function ()
	local env = find("python", "trigger", "env")
	equal("shebang expansion", expand_trigger(env, "env"), "#!/usr/bin/env python3\n")
	with_buffer({ "", "", "", "env" }, function ()
		equal("shebang restricted to top", env:matches("env"), nil)
	end, { 4, 3 }
	)
end)

check("comment captures", function ()
	local conditions = require("math-snippets.conditions")
	with_buffer({ "% comment", "ordinary" }, function ()
		equal("comment detection without highlighting", conditions.in_comments(), false)
		vim.treesitter.start(0, "latex")
		equal("comment capture before cursor", conditions.in_comments(), true)
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		equal("before comment at column zero", conditions.in_comments(), false)
		vim.api.nvim_win_set_cursor(0, { 2, 4 })
		equal("ordinary text has no comment capture", conditions.in_comments(), false)
		vim.treesitter.stop(0)
	end, { 1, 4 }
	)
end)

check("specialized comment captures", function ()
	local conditions = require("math-snippets.conditions")
	local ok, err = pcall(function ()
		for _, case in ipairs({
			{ "comment.documentation", true },
			{ "comment.todo", true },
			{ "comment.documentation.latex", true },
			{ "commentish", false },
			{ "commentary", false },
			{ "punctuation.comment", false }
		}) do
			vim.treesitter.query.set("latex", "highlights", "(line_comment) @" .. case[1])
			with_buffer({ "% comment" }, function ()
				vim.treesitter.start(0, "latex")
				local captures = vim.treesitter.get_captures(0, { 0, 3 })
				local names = vim.tbl_map(function (capture) return capture.capture end, captures)
				equal("fixture has only @" .. case[1], names, { case[1] })
				equal("comment detection for @" .. case[1], conditions.in_comments(), case[2])
				vim.treesitter.stop(0)
			end, { 1, 4 }
			)
		end
	end)
	vim.treesitter.query.set("latex", "highlights", nil)
	if not ok then
		error(err)
	end
end)

check("Markdown conditions", function ()
	local code = find("markdown", "trigger", "code")
	with_buffer({ "code" }, function ()
		equal("fenced code at line start", code:matches("code") ~= nil, true)
	end)
	with_buffer({ "words code" }, function ()
		equal("fenced code in prose", code:matches("words code"), nil)
	end)
	equal("fenced code shown for full trigger", code.show_condition("code"), true)
	equal("fenced code shown with indentation", code.show_condition("  code"), true)
	equal("fenced code hidden in prose", code.show_condition("words code"), false)
	equal("fenced code expansion", expand(code), "``` lang\n\n```")
	local meta = find("markdown", "trigger", "meta")
	with_buffer({ "", "", "", "" }, function ()
		equal("front matter shown at top", meta.show_condition(""), true)
		equal("front matter shown for full trigger", meta.show_condition("meta"), true)
		equal("front matter shown with indentation", meta.show_condition("  meta"), true)
		equal("front matter hidden in prose", meta.show_condition("words meta"), false)
		vim.api.nvim_win_set_cursor(0, { 4, 0 })
		equal("front matter hidden below top", meta.show_condition(""), false)
	end)
end)

local delimiters = {
	a = { "\\langle", "\\rangle" },
	A = { "\\lAngle", "\\rAngle" },
	b = { "[", "]" },
	B = { "\\lBrack", "\\rBrack" },
	c = { "\\lbrace", "\\rbrace" },
	m = { "|", "|" },
	p = { "(", ")" },
	v = { "\\Vert", "\\Vert" }
}
for key, pair in pairs(delimiters) do
	for _, prefix in ipairs({ "bk", "lr" }) do
		check(prefix .. key, function ()
			local snippet = find("tex/expressions", "name", prefix == "bk" and "brackets" or "left right")
			local left = (prefix == "lr" and "\\left" or "") .. pair[1]
			local right = (prefix == "lr" and "\\right" or "") .. pair[2]
			equal(
				prefix .. key .. " expansion", expand_trigger(snippet, "$ " .. prefix .. key .. "$", 5),
				"$ " .. left .. " " .. right .. "$"
			)
		end)
	end
end

check("symbol output and metadata", function ()
	local nabla = find("tex/symbols", "name", "∇")
	equal("nabla has one command backslash", expand(nabla), "\\nabla")
	local eta = find("tex/symbols", "trigger", ";h")
	equal("eta label", eta.name, "η")
	equal("eta command", expand(eta), "\\eta")
end)

for _, trigger in ipairs({ "set", "nnn", "uuu" }) do
	check(trigger .. " has one expansion", function ()
		local line = "$ " .. trigger
		with_buffer({ line .. "$" }, function ()
			local count = 0
			for path, snippets in pairs(loaded) do
				if path:match("^luasnippets/tex/") then
					for _, snippet in ipairs(snippets) do
						if snippet:matches(line) then
							count = count + 1
						end
					end
				end
			end
			equal(trigger .. " matching snippets", count, 1)
		end, #line
		)
	end)
end

for _, case in ipairs({
	{ "single-letter variable", "x", ".", "  " },
	{ "surround word starting with number", "2x", ",", "\t" },
	{ "surround i+1", "i+1", ";", " \t " }
}) do
	check(case[1], function ()
		local snippet = find("tex/inline_math", "name", case[1])
		local source = "words " .. case[2] .. case[3] .. case[4]
		local expected = "words \\(" .. case[2] .. "\\)" .. case[3] .. case[4]
		equal(case[1] .. " retains trailing whitespace", expand_trigger(snippet, source), expected)
	end)
end

check("inline math exit callback", function ()
	with_buffer({ "" }, function ()
		local buffer = vim.api.nvim_get_current_buf()
		local function callbacks()
			return vim.tbl_filter(function (autocmd)
				return autocmd.desc == "Auto Add a Space after Inline Math"
			end, vim.api.nvim_get_autocmds({ event = "InsertCharPre", buf = buffer }))
		end
		ls.snip_expand(find("tex/inline_math", "trigger", "mk"))
		equal("no spacing callback before leaving math", #callbacks(), 0)
		ls.jump(1)
		local pending = callbacks()
		equal("leaving math creates one callback", #pending, 1)
		equal("spacing callback belongs to current buffer", pending[1].buf, buffer)
		equal("spacing callback runs once", pending[1].once, true)
		vim.api.nvim_exec_autocmds("InsertCharPre", { buf = buffer })
		equal("spacing callback removed after firing", #callbacks(), 0)
	end)
end)

check("inline math next character spacing", function ()
	for _, character in ipairs({ "a", "Z", ".", ",", ")", " ", "7", "中" }) do
		with_buffer({ "" }, function ()
			vim.api.nvim_create_autocmd("InsertCharPre", {
				buf = 0,
				once = true,
				callback = function () vim.v.char = character end
			})
			ls.snip_expand(find("tex/inline_math", "trigger", "mk"))
			ls.jump(1)
			vim.api.nvim_exec_autocmds("InsertCharPre", { buf = 0 })
			local expected = (character == "a" or character == "Z") and " " .. character or character
			equal("inline math next character " .. character, vim.v.char, expected)
		end)
	end
end)

check("automatic inline math preserves pattern matches", function ()
	local cases = {
		"words x", "words a", "words I", "words 2ab", "words i+1", "words x_y", "words x=y", "words x,", "words 2ab;",
		"words i+1.", "words x-", "words x)", "words x!", "中😀 x", "中😀 2ab", "中😀 i+1", "words α", "",
		"plain words", ("prefix "):rep(512) .. "x", "words " .. ("1"):rep(1024) .. ("a"):rep(1024)
	}
	for _, name in ipairs({ "single-letter variable", "surround word starting with number", "surround i+1" }) do
		local snippet = find("tex/inline_math", "name", name)
		local reference = ls.snippet(
			{ trig = snippet.trigger, trigEngine = "pattern", wordTrig = false },
			ls.text_node(""),
			{
				condition = require("math-snippets.latex").in_text
			}
		)
		with_buffer({ "" }, function ()
			for case_index, source in ipairs(cases) do
				for suffix_index, suffix in ipairs({ "", "x", "!", " ", "\t", " \t ", (" \t"):rep(512) }) do
					local line = source .. suffix
					vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
					vim.api.nvim_win_set_cursor(0, { 1, #line })
					local actual, expected = snippet:matches(line), reference:matches(line)
					equal(
						("%s pattern equivalence %d/%d"):format(name, case_index, suffix_index),
						actual and { actual.trigger, actual.captures }, expected and { expected.trigger, expected.captures }
					)
				end
			end
		end)
	end
end)

check("Beamer document class detection", function ()
	local frame = find("tex/structure", "trigger", "bfr")
	for _, case in ipairs({
		{ "\\documentclass{beamer}", true },
		{ "  \\documentclass{beamer}", true },
		{ "\\documentclass{beamer} \t", true },
		{ "\\documentclass{beamer} % slides", true },
		{ "\\documentclass[aspectratio=169]{beamer}", true },
		{ "  \\documentclass [aspectratio=169] { beamer }   % slides", true },
		{ "% \\documentclass{beamer}", false },
		{ "  % \\documentclass{beamer}", false },
		{ "\\documentclass{article}", false },
		{ "\\documentclass{article} % {beamer}", false },
		{ "\\documentclassfoo{beamer}", false },
		{ "\\documentclass{beamer} text after the declaration", true },
		{ "\\documentclass\n[aspectratio=169]\n{beamer}", true },
		{ "\\documentclass% comment\n[aspectratio=169]% comment\n{beamer}", true },
		{ "% \\documentclass{beamer}\n\\documentclass{article}", false },
		{ "\\documentclass{article}\n\\documentclass{beamer}", false },
		{ "\\documentclass{beamer}\n\\documentclass{article}", true },
		{ "\\documentclass[beamer]{article}", false },
		{ "\\documentclass{beamerarticle}", false },
		{ "ordinary text", false }
	}) do
		local lines = vim.split(case[1], "\n", { plain = true })
		vim.list_extend(lines, { "", "bfr" })
		with_buffer(lines, function ()
			equal("Beamer expansion for " .. case[1], frame:matches("bfr") ~= nil, case[2])
			equal("Beamer completion for " .. case[1], frame.show_condition("bfr"), case[2])
		end, { #lines, 3 }
		)
	end
	for _, row in ipairs({ 10, 11, 100 }) do
		local lines = {}
		for index = 1, row - 1 do
			lines[index] = ""
		end
		lines[row], lines[row + 1] = "\\documentclass{beamer}", "bfr"
		with_buffer(lines, function ()
			equal("Beamer declaration on line " .. row, frame:matches("bfr") ~= nil, true)
		end, { row + 1, 3 }
		)
	end
end)

check("Beamer incomplete declarations at EOF", function ()
	local tex = require("math-snippets.latex")
	local original_notify_once = vim.notify_once
	local notifications = {}
	vim.notify_once = function (message) notifications[#notifications + 1] = message end
	local ok, err = pcall(function ()
		for _, case in ipairs({
			{ "\\documentclass{beamer", true },
			{ "\\documentclass{article", false },
			{ "\\documentclass\n{\nbeamer\n", true },
			{ "\\documentclass\n{\narticle\n", false }
		}) do
			-- No following snippet line: recovered path nodes can end just beyond EOF.
			local lines = vim.split(case[1], "\n", { plain = true })
			local row, col = #lines - 1, #lines[#lines]
			with_buffer(lines, function ()
				notifications = {}
				equal("incomplete class at EOF: " .. case[1], tex.in_beamer(), case[2])
				equal("incomplete class stays quiet: " .. case[1], #notifications, 0)
				notifications = {}
				vim.api.nvim_buf_set_text(0, row, col, row, col, { "}" })
				equal("completed class after EOF edit: " .. case[1], tex.in_beamer(), case[2])
				equal("completed class stays quiet: " .. case[1], #notifications, 0)
			end, { row + 1, col }
			)
		end
	end)
	vim.notify_once = original_notify_once
	if not ok then
		error(err)
	end
end)

check("Beamer cache across buffers and unload", function ()
	local tex = require("math-snippets.latex")
	local reference = setmetatable({}, { __mode = "v" })
	with_buffer({ "\\documentclass{beamer}" }, function ()
		local buffer = vim.api.nvim_get_current_buf()
		local parser = vim.treesitter.get_parser(buffer, "latex")
		reference[1] = parser
		local original_parse = parser.parse
		local parses = 0
		parser.parse = function (self, ...)
			parses = parses + 1
			return original_parse(self, ...)
		end
		local ok, err = pcall(function ()
			equal("Beamer first buffer detection", tex.in_beamer(), true)
			with_buffer({ "\\documentclass{article}" }, function ()
				equal("Beamer second buffer detection", tex.in_beamer(), false)
			end)
			vim.api.nvim_set_current_buf(buffer)
			equal("Beamer first buffer after switching", tex.in_beamer(), true)
			equal("Beamer cache survives switching and unloading another buffer", parses, 1)
		end)
		parser.parse = original_parse
		if not ok then
			error(err)
		end
	end)
	collectgarbage("collect")
	collectgarbage("collect")
	equal("Beamer cache releases an unloaded buffer's parser", reference[1] == nil, true)
end)

check("Beamer cache, overrides and recovery", function ()
	local tex = require("math-snippets.latex")
	with_buffer({ "\\documentclass{beamer}" }, function ()
		local buffer = vim.api.nvim_get_current_buf()
		local parser = vim.treesitter.get_parser(buffer, "latex")
		local original_parse = parser.parse
		local original_get_parser = vim.treesitter.get_parser
		local original_notify = vim.notify
		local notifications = {}
		vim.notify = function (message, level)
			notifications[#notifications + 1] = { message = message, level = level }
		end
		local ok, err = pcall(function ()
			local parses = 0
			parser.parse = function (self, ...)
				parses = parses + 1
				return original_parse(self, ...)
			end
			equal("Beamer initial detection", tex.in_beamer(), true)
			equal("Beamer cached detection", tex.in_beamer(), true)
			equal("Beamer detection shares a cached parse", parses, 1)
			local tick = vim.api.nvim_buf_get_changedtick(buffer)
			parser:invalidate()
			equal("Beamer invalidation recovers", tex.in_beamer(), true)
			equal("Beamer invalidation reparses", parses, 2)
			equal("Beamer invalidation needs no edit", vim.api.nvim_buf_get_changedtick(buffer), tick)

			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "\\documentclass{article}" })
			equal("Beamer edit updates the class", tex.in_beamer(), false)
			local before_override = parses
			vim.b.math_snippets_beamer = true
			equal("Beamer override enables an article buffer", tex.in_beamer(), true)
			vim.b.math_snippets_beamer = false
			equal("Beamer override disables detection", tex.in_beamer(), false)
			equal("Beamer overrides skip parsing", parses, before_override)
			vim.b.math_snippets_beamer = nil
			equal("clearing Beamer override restores detection", tex.in_beamer(), false)

			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "\\documentclass{beamer}" })
			parser.parse = function () error("simulated Beamer parser failure") end
			equal("Beamer parse exception fails closed", tex.in_beamer(), false)
			equal("Beamer parse exception retries", tex.in_beamer(), false)
			equal("Beamer parse exception warns once", #notifications, 1)
			equal("Beamer warning severity", (notifications[1] or {}).level, vim.log.levels.WARN)
			equal("Beamer warning includes the error",
				((notifications[1] or {}).message or ""):find("simulated Beamer parser failure", 1, true) ~= nil, true)
			parser.parse = original_parse
			equal("Beamer detection recovers without an edit", tex.in_beamer(), true)
			vim.treesitter.get_parser = function () return nil, "unavailable parser" end
			equal("missing Beamer parser fails closed", tex.in_beamer(), false)
			equal("missing Beamer parser stays quiet", #notifications, 1)
			vim.treesitter.get_parser = original_get_parser
			equal("Beamer parser lookup recovers", tex.in_beamer(), true)
		end)
		parser.parse = original_parse
		vim.treesitter.get_parser = original_get_parser
		vim.notify = original_notify
		vim.b.math_snippets_beamer = nil
		if not ok then
			error(err)
		end
	end)
end)

for _, case in ipairs({
	{ "cohomology-d", "H_2X", "H^{2}(X,)" },
	{ "cohomology-a", "HiX", "H^{i}(X,)" }
}) do
	check(case[1], function ()
		local snippet = find("tex/expressions", "name", case[1])
		equal(
			case[1] .. " expansion", expand_trigger(snippet, "$ " .. case[2] .. "$", #case[2] + 2), "$ " .. case[3] .. "$"
		)
	end)
end

for _, operator in ipairs({ "sin", "ker", "Quot" }) do
	check(operator .. " backslash", function ()
		local snippet = find("tex/symbols", "name", operator)
		equal(
			operator .. " expansion", expand_trigger(snippet, "$ " .. operator .. "$", #operator + 2),
			"$ \\" .. operator .. "$"
		)
		with_buffer({ "$ \\" .. operator .. "$" }, function ()
			equal(operator .. " preserves existing backslash", snippet:matches("$ \\" .. operator), nil)
		end, #operator + 3
		)
	end)
end

check("command trigger boundaries", function ()
	for _, case in ipairs({
		{ "tex/symbols", "sin", true },
		{ "tex/expressions", "sq", true },
		{ "tex/symbols", "op", false },
		{ "tex/symbols", "nabl", false }
	}) do
		local snippet = find(case[1], "trigger", case[2])
		for _, prefix in ipairs(
			{ "", " ", "\t", "(", "x", "_", "7", "α", "中", "😀", "é", ("x "):rep(1024) .. "😀" }
		) do
			local line = prefix .. case[2]
			with_buffer({ "\\[", line, "\\]" }, function ()
				local match = snippet:matches(line)
				local blocked = case[3] and (prefix == "x" or prefix == "_" or prefix == "7")
				equal(
					case[2] .. " after " .. (prefix:sub(1, 12)), match and match.trigger,
					not blocked and case[2] or nil
				)
			end, { 2, #line }
			)
		end
		for _, line in ipairs({ "\\" .. case[2], "\\\\" .. case[2], "中\\" .. case[2], case[2] .. "x", case[2] .. " " }) do
			with_buffer({ "\\[", line, "\\]" }, function ()
				equal(case[2] .. " rejects " .. line, snippet:matches(line), nil)
			end, { 2, #line }
			)
		end
	end
	for _, case in ipairs({
		{ "tex/symbols", "sin", "αsin", "α\\sin" },
		{ "tex/symbols", "op", "xop", "x\\oplus" },
		{ "tex/expressions", "sq", "中sq", "中\\sqrt{}" }
	}) do
		equal(
			case[2] .. " preserves preceding text",
			expand_trigger(find(case[1], "trigger", case[2]), "$ " .. case[3] .. "$", #case[3] + 2), "$ " .. case[4] .. "$"
		)
	end
end)

check("bounded pattern matches and captures", function ()
	for _, case in ipairs({
		{ "tex/expressions", "cohomology-d", "H_2X", { "H", "2", "X" } },
		{ "tex/expressions", "cohomology-a", "HiX", { "H", "i", "X" } },
		{ "tex/symbols", "x[n+1]", "xp2", { "x", "2" } },
		{ "tex/text", "Cartier", "qc", { "q" }, "text" },
		{ "tex/text", "divisor", "rd", { "r" }, "text" },
		{ "tex/text", "(arz)?ref", "zref", { "z" }, "text" },
		{ "tex/text", "without loss of generality", "Wlog", { "W" }, "line" },
		{ "tex/symbols", "\\xi_{i}", "\\Xii", { "X" } },
		{ "tex/symbols", "\\pi_{i}", "\\pii", { "p" } },
		{ "tex/symbols", "\\phi_{i}", "\\Phii", { "P" } },
		{ "tex/symbols", "\\chi_{i}", "\\chii", { "c" } },
		{ "tex/symbols", "\\psi_{i}", "\\Psii", { "P" } },
		{ "tex/symbols", "local ring, structure sheaf", "OZ", { "Z" } },
		{ "tex/symbols", "auto subscript 1", "x7", { "x", "7" } },
		{ "tex/symbols", "auto subscript 2", "x_12", { "x", "12" } },
		{ "tex/symbols", "positive", "QP", { "Q" } },
		{ "tex/symbols", "negative", "RN", { "R" } },
		{ "tex/symbols", "linearly equivalent", "qle", { "q" } },
		{ "tex/symbols", "alph i", "xii", { "x" } },
		{ "tex/symbols", "alph j", "yjj", { "y" } },
		{ "tex/expressions", "brackets", "bkp", { "p" } },
		{ "tex/expressions", "left right", "lrv", { "v" } }
	}) do
		local snippet = find(case[1], "name", case[2])
		local prefixes = case[5] == "line" and { "", (" \t"):rep(1024) }
			or { "", "α", "中", "😀", ("x "):rep(1024) .. "😀" }
		for _, prefix in ipairs(prefixes) do
			local line = prefix .. case[3]
			local lines = case[5] and { line } or { "\\[", line, "\\]" }
			with_buffer(lines, function ()
				local match = snippet:matches(line)
				equal(
					case[2] .. " suffix and captures after " .. prefix:sub(1, 12), match and { match.trigger, match.captures },
					{ case[3], case[4] }
				)
				equal(case[2] .. " remains end anchored", snippet:matches(line .. "!"), nil)
			end, { case[5] and 1 or 2, #line }
			)
		end
	end
	local wlog = find("tex/text", "name", "without loss of generality")
	with_buffer({ "preceding text Wlog" }, function ()
		equal("bounded matching preserves full line for conditions", wlog:matches("preceding text Wlog"), nil)
	end)
	equal(
		"bounded matching preserves word boundaries",
		with_buffer({ "$ xHiX$" }, function ()
			return find("tex/expressions", "name", "cohomology-a"):matches("$ xHiX")
		end, 6
		),
		nil
	)
end)

for _, case in ipairs({ { "rmap", "dashrightarrow" }, { "emb", "hookrightarrow" } }) do
	check(case[1] .. " arrow", function ()
		local snippet = find("tex/symbols", "trigger", case[1])
		equal(
			case[1] .. " in math", expand_trigger(snippet, "$ " .. case[1] .. "$", #case[1] + 2), "$ \\" .. case[2] .. " $"
		)
		local prefix, suffix = "\\begin{tikzcd}", "\\end{tikzcd}"
		equal(
			case[1] .. " in diagram", expand_trigger(snippet, prefix .. case[1] .. suffix, #prefix + #case[1]),
			prefix .. "\\ar[," .. case[2] .. "]" .. suffix
		)
	end)
end

for _, case in ipairs({ { "mbb", "mathbb" }, { "hat", "widehat", 500 }, { "bar", "overline", 500 } }) do
	check(case[1] .. " postfix", function ()
		local snippet = find("tex/expressions", "trigger", case[1], case[3])
		equal(
			case[1] .. " wraps preceding text", expand_trigger(snippet, "$ x" .. case[1] .. "$", #case[1] + 3),
			"$ \\" .. case[2] .. "{x}$"
		)
		equal(
			case[1] .. " wraps selection",
			expand(snippet, {
				expand_params = { env_override = { POSTFIX_MATCH = "", LS_SELECT_RAW = { "x + y" } } }
			}),
			"\\" .. case[2] .. "{x + y}"
		)
		equal(
			case[1] .. " wraps multiline selection",
			expand(snippet, {
				expand_params = { env_override = { POSTFIX_MATCH = "", LS_SELECT_RAW = { "x", "y" } } }
			}),
			"\\" .. case[2] .. "{x\ny}"
		)
	end)
end

for _, case in ipairs({
	{ "\\([xX])ii", "\\Xii", "\\Xi_{i}" },
	{ "\\([pP])ii", "\\pii", "\\pi_{i}" },
	{ "\\([pP])hii", "\\Phii", "\\Phi_{i}" },
	{ "\\([cC])hii", "\\chii", "\\chi_{i}" },
	{ "\\([pP])sii", "\\Psii", "\\Psi_{i}" }
}) do
	check(case[2], function ()
		local snippet = find("tex/symbols", "trigger", case[1])
		equal(
			case[2] .. " indexed Greek letter", expand_trigger(snippet, "$ " .. case[2] .. "$", #case[2] + 2),
			"$ " .. case[3] .. "$"
		)
	end)
end

check("text phrases", function ()
	for _, case in ipairs({ { "([qr])c", "qc", "Q", "Cartier" }, { "([qr])d", "rd", "R", "divisor" } }) do
		local snippet = find("tex/text", "trigger", case[1])
		equal(case[2] .. " phrase", expand_trigger(snippet, case[2]), "\\(\\mathbb{" .. case[3] .. "}\\)-" .. case[4])
	end
	local cite = find("tex/text", "trigger", "cf")
	equal("citation in text", expand_trigger(cite, "cf"), "\\cite[]{}")
	with_buffer({ "$ cf$" }, function ()
		equal("citation disabled in math", cite:matches("$ cf"), nil)
	end, 4
	)
end)

check("optional command argument", function ()
	local sqrt = find("tex/expressions", "name", "sqrt")
	with_buffer({ "" }, function ()
		ls.snip_expand(sqrt)
		equal("sqrt default", buffer_text(), "\\sqrt{}")
		ls.change_choice(1)
		equal("sqrt optional argument", buffer_text(), "\\sqrt[opt]{}")
	end)
end)

check("matrix and cases", function ()
	local matrix = find("tex/structure", "trigger", "([bBpvV])mat_(%d+)x_(%d+)([ar])")
	local cases = find("tex/structure", "trigger", "(%d?)cases")
	for _, case in ipairs({
		{ matrix, "bmat_2x_2r", "\\begin{bmatrix}\n\t &  \\\\\n\t & \n\\end{bmatrix}" },
		{ cases, "cases", "\\begin{cases}\n\t &  \\\\\n\t & \n\\end{cases}" },
		{ cases, "1cases", "\\begin{cases}\n\t & \n\\end{cases}" }
	}) do
		equal(
			case[2] .. " expansion", expand_trigger(case[1], { "\\[", case[2], "\\]" }, { 2, #case[2] }),
			"\\[\n" .. case[3] .. "\n\\]"
		)
	end
end)

check("TODO comment wrappers", function ()
	local todo = find("all", "trigger", "todo")
	local mark = "<" .. (vim.env.USER or ""):gsub("^%l", string.upper) .. ">"
	for _, wrapper in ipairs({ { "-- ", "" }, { "/* ", " */" }, { "<!-- ", " -->" }, { "", "" } }) do
		local commentstring = wrapper[1] == "" and "" or wrapper[1] .. "%s" .. wrapper[2]
		local actual = with_buffer({ "" }, function ()
			vim.bo.commentstring = commentstring
			ls.snip_expand(todo)
			return buffer_text()
		end)
		equal("TODO inside " .. commentstring, actual, wrapper[1] .. "TODO:  " .. mark .. wrapper[2])
	end
	with_buffer({ "" }, function ()
		vim.bo.commentstring = "-- %s"
		ls.snip_expand(todo)
		ls.jump(1)
		for _, mark_text in ipairs({ os.date("%d-%m-%y") .. ", " .. mark:sub(2, -2), os.date("%d-%m-%y"), false }) do
			ls.change_choice(1)
			equal("TODO signature choice", buffer_text(), "-- TODO:  " .. (mark_text and "<" .. mark_text .. ">" or ""))
		end
	end)
end)

check("TODO dates remain fresh and editable", function ()
	local original_date = os.date
	local today = "01-01-26"
	os.date = function (format, ...)
		return format == "%d-%m-%y" and today or original_date(format, ...)
	end
	local ok, err = pcall(function ()
		local todo = find("all", "trigger", "todo")
		local username = (vim.env.USER or ""):gsub("^%l", string.upper)
		with_buffer({ "" }, function ()
			vim.bo.commentstring = "-- %s"
			ls.snip_expand(todo)
			ls.jump(1)
			today = "02-01-26"
			ls.change_choice(1)
			equal(
				"TODO date is fresh when its choice is first selected", buffer_text(),
				"-- TODO:  <" .. today .. ", " .. username .. ">"
			)
			local node = session.current_nodes[vim.api.nvim_get_current_buf()]
			equal("TODO date is an editable insert node", node.type, require("luasnip.util.types").insertNode)
			equal("TODO jumps into the date field", node:get_text(), { today })
			local first, last = node.mark:pos_begin_end_raw()
			vim.api.nvim_buf_set_text(0, first[1], first[2], last[1], last[2], { "custom date" })
			ls.active_update_dependents()
			equal("TODO date accepts edits", buffer_text(), "-- TODO:  <custom date, " .. username .. ">")
			today = "03-01-26"
			ls.change_choice(1)
			equal("TODO date-only choice starts with current date", buffer_text(), "-- TODO:  <" .. today .. ">")
			ls.change_choice(-1)
			equal(
				"TODO signature switching preserves edited date", buffer_text(), "-- TODO:  <custom date, " .. username .. ">"
			)
			ls.jump(1)
			equal(
				"TODO date is followed by username field", session.current_nodes[vim.api.nvim_get_current_buf()]:get_text(),
				{ ", " .. username }
			)
			ls.jump(1)
			equal(
				"TODO signature is followed by description field",
				session.current_nodes[vim.api.nvim_get_current_buf()]:get_text(), { "" }
			)
		end)
		today = "04-01-26"
		for _, case in ipairs({
			{ "todo", "TODO" },
			{ "fix", "FIX" },
			{ "hack", "HACK" },
			{ "warn", "WARN" },
			{ "perf", "PERF" },
			{ "note", "NOTE" }
		}) do
			with_buffer({ "" }, function ()
				vim.bo.commentstring = "-- %s"
				ls.snip_expand(find("all", "trigger", case[1]))
				ls.jump(1)
				ls.change_choice(1)
				equal(
					case[1] .. " expansion after date change", buffer_text(),
					"-- " .. case[2] .. ":  <" .. today .. ", " .. username .. ">"
				)
			end)
		end
	end)
	os.date = original_date
	if not ok then
		error(err)
	end
end)

check("visual selections", function ()
	local snippet = find("tex/expressions", "trigger", "tt")
	for _, case in ipairs({
		{ "no selection", {}, "" },
		{ "empty selection", { LS_SELECT_RAW = {} }, "" },
		{ "selected text", { LS_SELECT_RAW = { "x + y" } }, "x + y" },
		{ "multiline selection", { LS_SELECT_RAW = { "x", "y" } }, "x\ny" }
	}) do
		equal(
			case[1], expand(snippet, { expand_params = { env_override = case[2] } }), "\\text{" .. case[3] .. "}"
		)
	end
end)

check("optional Blink completion", function ()
	local eqref = find("tex/text", "trigger", "eqref")
	local previous_loaded, previous_preload = package.loaded["blink.cmp"], package.preload["blink.cmp"]
	local ok, err = pcall(function ()
		package.loaded["blink.cmp"] = nil
		package.preload["blink.cmp"] = function ()
			error("Blink intentionally unavailable in this test")
		end
		equal("eqref without Blink", expand(eqref), "\\eqref{eq:}")
		local shown
		package.loaded["blink.cmp"] = {
			show = function (options)
				shown = options
			end
		}
		equal("eqref with Blink", expand(eqref), "\\eqref{eq:}")
		equal("eqref requests LSP completion", shown, { providers = { "lsp" } })
	end)
	package.loaded["blink.cmp"], package.preload["blink.cmp"] = previous_loaded, previous_preload
	if not ok then
		error(err)
	end
end)

if #failures > 0 then
	io.stderr:write(table.concat(failures, "\n") .. "\n")
	error(("%d of %d snippet checks failed"):format(#failures, checks))
end
print(("Passed %d snippet checks"):format(checks))
