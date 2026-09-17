-- Run from the repository root:
--   nvim --headless -u NONE -i NONE -l tests/snippets.lua
-- LuaSnip (with jsregexp) and the latex parser must be on 'runtimepath'.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.virtualedit = "onemore"

local ls = require("luasnip")
local session = require("luasnip.session")
local snip_env = session.get_snip_env()
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
	check("load " .. path, function()
		local env = setmetatable({}, {
			__index = function(_, key)
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

local function find(file, property, value)
	for _, snippet in ipairs(assert(loaded["luasnippets/" .. file .. ".lua"], "file did not load: " .. file)) do
		if snippet[property] == value then
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
	return with_buffer({ "" }, function()
		ls.snip_expand(snippet, options)
		return buffer_text()
	end)
end

local function expand_trigger(snippet, source, cursor)
	local lines = type(source) == "table" and source or { source }
	return with_buffer(lines, function()
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local before = lines[row]:sub(1, col)
		local match = assert(snippet:matches(before), "trigger did not match: " .. before)
		ls.snip_expand(snippet, {
			expand_params = match,
			clear_region = match.clear_region or { from = { row - 1, #before - #match.trigger }, to = { row - 1, #before } }
		})
		return buffer_text()
	end, cursor)
end

for _, trigger in ipairs({ "feat", "fix", "chore", "revert", "refactor", "cleanup" }) do
	check("Git commit " .. trigger, function()
		equal(trigger .. " commit", expand_trigger(find("gitcommit", "trigger", trigger), trigger), trigger .. "(scope): title")
	end)
end

check("Python shebang", function()
	local env = find("python", "trigger", "env")
	equal("shebang expansion", expand_trigger(env, "env"), "#!/usr/bin/env python3\n")
	with_buffer({ "", "", "", "env" }, function()
		equal("shebang restricted to top", env:matches("env"), nil)
	end, { 4, 3 })
end)

check("Markdown conditions", function()
	local code = find("markdown", "trigger", "code")
	with_buffer({ "code" }, function()
		equal("fenced code at line start", code:matches("code") ~= nil, true)
	end)
	with_buffer({ "words code" }, function()
		equal("fenced code in prose", code:matches("words code"), nil)
	end)
	equal("fenced code shown for full trigger", code.show_condition("code"), true)
	equal("fenced code shown with indentation", code.show_condition("  code"), true)
	equal("fenced code hidden in prose", code.show_condition("words code"), false)
	equal("fenced code expansion", expand(code), "``` lang\n\n```")
	local meta = find("markdown", "trigger", "meta")
	with_buffer({ "", "", "", "" }, function()
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
		check(prefix .. key, function()
			local snippet = find("tex/delimiters", "name", prefix == "bk" and "brackets" or "left right")
			local left = (prefix == "lr" and "\\left" or "") .. pair[1]
			local right = (prefix == "lr" and "\\right" or "") .. pair[2]
			equal(prefix .. key .. " expansion", expand_trigger(snippet, "$ " .. prefix .. key .. "$", 5), "$ " .. left .. " " .. right .. "$")
		end)
	end
end

check("symbol output and metadata", function()
	local nabla = find("tex/symbols", "name", "∇")
	equal("nabla has one command backslash", expand(nabla), "\\nabla")
	local eta = find("tex/symbols", "trigger", ";h")
	equal("eta label", eta.name, "η")
	equal("eta command", expand(eta), "\\eta")
end)

for _, trigger in ipairs({ "set", "nnn", "uuu" }) do
	check(trigger .. " has one expansion", function()
		local line = "$ " .. trigger
		with_buffer({ line .. "$" }, function()
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
		end, #line)
	end)
end

for _, case in ipairs({
	{ "single-letter variable", "x", ".", "  " },
	{ "surround word starting with number", "2x", ",", "\t" },
	{ "surround i+1", "i+1", ";", " \t " }
}) do
	check(case[1], function()
		local snippet = find("tex/misc", "name", case[1])
		local source = "words " .. case[2] .. case[3] .. case[4]
		local expected = "words \\(" .. case[2] .. "\\)" .. case[3] .. case[4]
		equal(case[1] .. " retains trailing whitespace", expand_trigger(snippet, source), expected)
	end)
end

for _, case in ipairs({
	{ "cohomology-d", "H_2X", "H^{2}(X,)" },
	{ "cohomology-a", "HiX", "H^{i}(X,)" },
}) do
	check(case[1], function()
		local snippet = find("tex/operators", "name", case[1])
		equal(case[1] .. " expansion", expand_trigger(snippet, "$ " .. case[2] .. "$", #case[2] + 2), "$ " .. case[3] .. "$")
	end)
end

for _, operator in ipairs({ "sin", "ker", "Quot" }) do
	check(operator .. " backslash", function()
		local snippet = find("tex/operators", "name", operator)
		equal(operator .. " expansion", expand_trigger(snippet, "$ " .. operator .. "$", #operator + 2), "$ \\" .. operator .. "$")
		with_buffer({ "$ \\" .. operator .. "$" }, function()
			equal(operator .. " preserves existing backslash", snippet:matches("$ \\" .. operator), nil)
		end, #operator + 3)
	end)
end

for _, case in ipairs({ { "rmap", "dashrightarrow" }, { "emb", "hookrightarrow" } }) do
	check(case[1] .. " arrow", function()
		local snippet = find("tex/symbols", "trigger", case[1])
		equal(case[1] .. " in math", expand_trigger(snippet, "$ " .. case[1] .. "$", #case[1] + 2), "$ \\" .. case[2] .. " $")
		local prefix, suffix = "\\begin{tikzcd}", "\\end{tikzcd}"
		equal(case[1] .. " in diagram", expand_trigger(snippet, prefix .. case[1] .. suffix, #prefix + #case[1]),
			prefix .. "\\ar[," .. case[2] .. "]" .. suffix)
	end)
end

for _, case in ipairs({ { "mbb", "mathbb" }, { "hat", "widehat" }, { "bar", "overline" } }) do
	check(case[1] .. " postfix", function()
		local snippet = find("tex/style", "trigger", case[1])
		equal(case[1] .. " wraps preceding text", expand_trigger(snippet, "$ x" .. case[1] .. "$", #case[1] + 3),
			"$ \\" .. case[2] .. "{x}$")
		equal(case[1] .. " wraps selection", expand(snippet, {
			expand_params = { env_override = { POSTFIX_MATCH = "", SELECT_RAW = { "x + y" }, LS_SELECT_RAW = { "x + y" } } }
		}), "\\" .. case[2] .. "{x + y}")
	end)
end

for _, case in ipairs({
	{ "\\([xX])ii", "\\Xii", "\\Xi_{i}" },
	{ "\\([pP])ii", "\\pii", "\\pi_{i}" },
	{ "\\([pP])hii", "\\Phii", "\\Phi_{i}" },
	{ "\\([cC])hii", "\\chii", "\\chi_{i}" },
	{ "\\([pP])sii", "\\Psii", "\\Psi_{i}" },
}) do
	check(case[2], function()
		local snippet = find("tex/symbols", "trigger", case[1])
		equal(case[2] .. " indexed Greek letter", expand_trigger(snippet, "$ " .. case[2] .. "$", #case[2] + 2), "$ " .. case[3] .. "$")
	end)
end

check("text phrases", function()
	for _, case in ipairs({ { "([qr])c", "qc", "Q", "Cartier" }, { "([qr])d", "rd", "R", "divisor" } }) do
		local snippet = find("tex/phrases", "trigger", case[1])
		equal(case[2] .. " phrase", expand_trigger(snippet, case[2]), "\\(\\mathbb{" .. case[3] .. "}\\)-" .. case[4])
	end
	local cite = find("tex/phrases", "trigger", "cf")
	equal("citation in text", expand_trigger(cite, "cf"), "\\cite[]{}")
	with_buffer({ "$ cf$" }, function()
		equal("citation disabled in math", cite:matches("$ cf"), nil)
	end, 4)
end)

check("optional command argument", function()
	local sqrt = find("tex/symbols", "name", "sqrt")
	with_buffer({ "" }, function()
		ls.snip_expand(sqrt)
		equal("sqrt default", buffer_text(), "\\sqrt{}")
		ls.change_choice(1)
		equal("sqrt optional argument", buffer_text(), "\\sqrt[opt]{}")
	end)
end)

check("matrix and cases", function()
	local matrix = find("tex/environments", "trigger", "([bBpvV])mat_(%d+)x_(%d+)([ar])")
	local cases = find("tex/environments", "trigger", "(%d?)cases")
	for _, case in ipairs({
		{ matrix, "bmat_2x_2r", "\\begin{bmatrix}\n\t &  \\\\\n\t & \n\\end{bmatrix}" },
		{ cases, "cases", "\\begin{cases}\n\t &  \\\\\n\t & \n\\end{cases}" },
		{ cases, "1cases", "\\begin{cases}\n\t & \n\\end{cases}" },
	}) do
		equal(case[2] .. " expansion", expand_trigger(case[1], { "\\[", case[2], "\\]" }, { 2, #case[2] }),
			"\\[\n" .. case[3] .. "\n\\]")
	end
end)

check("TODO comment wrappers", function()
	local todo = find("all", "trigger", "todo")
	local mark = "<" .. (vim.env.USER or ""):gsub("^%l", string.upper) .. ">"
	for _, wrapper in ipairs({ { "-- ", "" }, { "/* ", " */" }, { "<!-- ", " -->" }, { "", "" } }) do
		local commentstring = wrapper[1] == "" and "" or wrapper[1] .. "%s" .. wrapper[2]
		local actual = with_buffer({ "" }, function()
			vim.bo.commentstring = commentstring
			ls.snip_expand(todo)
			return buffer_text()
		end)
		equal("TODO inside " .. commentstring, actual, wrapper[1] .. "TODO:  " .. mark .. wrapper[2])
	end
	with_buffer({ "" }, function()
		vim.bo.commentstring = "-- %s"
		ls.snip_expand(todo)
		ls.jump(1)
		for _, mark_text in ipairs({ os.date("%d-%m-%y") .. ", " .. mark:sub(2, -2), os.date("%d-%m-%y"), false }) do
			ls.change_choice(1)
			equal("TODO signature choice", buffer_text(), "-- TODO:  " .. (mark_text and "<" .. mark_text .. ">" or ""))
		end
	end)
end)

check("visual selections", function()
	local get_visual = require("math-snippets.util").get_visual
	for _, case in ipairs({
		{ "no selection", {}, "" },
		{ "empty selection", { LS_SELECT_RAW = {} }, "" },
		{ "selected text", { LS_SELECT_RAW = { "x + y" } }, "x + y" },
		{ "multiline selection", { LS_SELECT_RAW = { "x", "y" } }, "x\ny" },
		{ "legacy selection", { SELECT_RAW = { "legacy" } }, "legacy" }
	}) do
		local snippet = ls.snippet("visual", {
			ls.dynamic_node(1, function()
				return get_visual(nil, { snippet = { env = case[2] } })
			end)
		})
		equal(case[1], expand(snippet), case[3])
	end
end)

check("optional Blink completion", function()
	local eqref = find("tex/phrases", "trigger", "eqref")
	local previous_loaded, previous_preload = package.loaded["blink.cmp"], package.preload["blink.cmp"]
	local ok, err = pcall(function()
		package.loaded["blink.cmp"] = nil
		package.preload["blink.cmp"] = function()
			error("Blink intentionally unavailable in this test")
		end
		equal("eqref without Blink", expand(eqref), "\\eqref{eq:}")
		local shown
		package.loaded["blink.cmp"] = {
			show = function(options)
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
