-- Run from the repository root:
--   nvim --headless -u NONE -i NONE -l tests/latex.lua
-- LuaSnip and the latex, markdown, and markdown_inline parsers must be on 'runtimepath'.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.virtualedit = "onemore"

local conditions = require("math-snippets.latex")
local failures, checks = {}, 0

local function equal(label, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		failures[#failures + 1] = ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual))
	end
end

local function fixture(marked, filetype, language)
	local marker = assert(marked:find("|", 1, true), "fixture needs a cursor marker")
	assert(not marked:find("|", marker + 1, true), "fixture needs exactly one cursor marker")
	local before = marked:sub(1, marker - 1)
	local _, row = before:gsub("\n", "")
	local col = #(before:match("[^\n]*$") or "")
	local source = marked:sub(1, marker - 1) .. marked:sub(marker + 1)
	local buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buffer)
	vim.bo[buffer].filetype = filetype or "tex"
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(source, "\n", { plain = true }))
	vim.api.nvim_win_set_cursor(0, { row + 1, col })
	if language ~= false then
		-- Attach, but leave parsing to the public condition functions. This also
		-- checks their behavior when no highlighter has parsed the first edit.
		vim.treesitter.get_parser(buffer, language or "latex")
	end
	return buffer
end

local function check_case(name, source, expected, filetype, language)
	local buffer = fixture(source, filetype, language)
	local ok, err = pcall(function()
		for _, property in ipairs({ "in_math", "in_align", "in_bullets", "in_tikzcd" }) do
			equal(name .. ": " .. property, conditions[property](), expected[property] or false)
		end
		equal(name .. ": in_text", conditions.in_text(), not expected.in_math)
	end)
	if not ok then
		failures[#failures + 1] = name .. ": " .. tostring(err)
	end
	vim.api.nvim_buf_delete(buffer, { force = true })
end

check_case("ordinary text", "ordinary wo|rds", {})
check_case("empty buffer", "|", {})
check_case("start of buffer", "|ordinary", {})
check_case("parenthesized inline math", "before \\(x| + y\\) after", { in_math = true })
check_case("bracketed display math", "before \\[x| + y\\] after", { in_math = true })
check_case("dollar math", "before $x| + y$ after", { in_math = true })
check_case("double-dollar math", "before $$x| + y$$ after", { in_math = true })
check_case("unclosed dollar math", "$x|", { in_math = true })
check_case("unclosed parenthesized math", "\\(x|", { in_math = true })
check_case("unclosed double-dollar math", "$$x|", { in_math = true })
check_case("unclosed bracketed math", "\\[x|", { in_math = true })
check_case("empty inline math", "\\(|\\)", { in_math = true })
-- Although the parser sees a $$ token, the insertion point between paired
-- dollars is a common intermediate state while entering an inline formula.
check_case("empty paired dollar math", "$|$", { in_math = true })
check_case("empty dollar math", "$ |$", { in_math = true })
check_case("empty display math", "\\[|\\]", { in_math = true })
check_case("spaces in math", "\\(x   |   y\\)", { in_math = true })
check_case("blank math line", "\\[\n\n|\n\n\\]", { in_math = true })
check_case("just before math closing delimiter", "\\(x|\\)", { in_math = true })
check_case("after math closing delimiter", "\\(x\\)|", {})
check_case("after dollar closing delimiter", "$x$|", {})
check_case("after display closing delimiter", "\\[x\\]|", {})
check_case("after double-dollar closing delimiter", "$$x$$|", {})
check_case("before math opening delimiter", "text |\\(x\\)", {})
check_case("before opener at start of buffer", "|\\(x\\)", {})
check_case("before dollar at start of buffer", "|$x$", {})
check_case("before comment in math at column zero", "\\[\n|% comment\n\\]", { in_math = true })
check_case("before end environment at column zero", "\\begin{align}\nx\n|\\end{align}", { in_math = true, in_align = true })
check_case("unicode byte columns", "中文 \\(α + β|\\)", { in_math = true })
check_case("comment outside math", "% $x|$", {})
check_case("comment inside math", "\\[x % comme|nt\ny\\]", {})
check_case("math after comment line", "\\[\n% comment\n|x\\]", { in_math = true })
check_case("zlabel inside alignment", "\\begin{align}x \\zlabel{eq:a|}\\end{align}", {})
check_case("zcref inside alignment", "\\begin{align}x \\zcref{eq:a|}\\end{align}", {})
check_case("math after zlabel", "\\(x \\zlabel{eq:a}| + y\\)", { in_math = true })
check_case("citation keys inside math", "\\(x \\cite{ke|y}\\)", {})
check_case("math in citation note", "\\cite[see \\(x|\\)]{key}", { in_math = true })
check_case("math in theorem title", "\\begin{theorem}[\\(X|\\)]words\\end{theorem}", { in_math = true })

for _, command in ipairs({ "text", "textbf", "textit", "textrm", "textnormal", "mbox", "operatorname", "tag", "label", "ref" }) do
	check_case(command .. " argument inside math", "\\(x \\" .. command .. "{word|} y\\)", {})
end
check_case("nested math inside text", "\\(x \\text{words \\(y|\\) more words} z\\)", { in_math = true })
check_case("nested dollar math inside text", "\\(x \\text{words $y|$ more words} z\\)", { in_math = true })
check_case("inside text before its closing brace", "\\(\\text{word|} + x\\)", {})
check_case("math after text closing brace", "\\(\\text{word}| + x\\)", { in_math = true })
check_case("math after generic text command", "\\(\\textbf{word}| + x\\)", { in_math = true })
check_case("math after label closing brace", "\\(\\label{eq:word}|x\\)", { in_math = true })
check_case("math after reference closing brace", "\\(\\ref{eq:word}|x\\)", { in_math = true })
check_case("ensuremath in text", "words \\ensuremath{x|+y} words", { in_math = true })
check_case("ensuremath inside text command", "\\(\\text{word \\ensuremath{x|}}\\)", { in_math = true })
check_case("after ensuremath closing brace", "\\ensuremath{x}|", {})

for _, environment in ipairs({ "equation", "equation*", "displaymath", "math", "gather", "gathered", "multline" }) do
	check_case(environment .. " math", "\\begin{" .. environment .. "}\nx|\n\\end{" .. environment .. "}", { in_math = true })
end
for _, environment in ipairs({ "align", "align*", "aligned", "alignedat", "alignat", "split", "eqnarray", "flalign", "array", "matrix", "pmatrix", "bmatrix", "Bmatrix", "vmatrix", "Vmatrix", "smallmatrix", "cases" }) do
	local argument = ({ alignedat = "{2}", alignat = "{2}", array = "{cc}" })[environment] or ""
	check_case(environment .. " alignment", "\\begin{" .. environment .. "}" .. argument .. "\nx|\n\\end{" .. environment .. "}", { in_math = true, in_align = true })
end
for _, environment in ipairs({ "pmatrix*", "dcases", "rcases", "drcases", "dcasesra", "drcasesra" }) do
	check_case(environment .. " family", "\\begin{" .. environment .. "}x|\\end{" .. environment .. "}", { in_math = true, in_align = true })
end
check_case("multlined family", "\\begin{multlined}x|\\end{multlined}", { in_math = true })
-- Patterns must match complete supported names, not arbitrary prefixes/suffixes.
for _, environment in ipairs({ "alignment", "alignatfoo", "xmatrix", "matrixnotation", "rcasesra", "displaymathematics" }) do
	check_case(environment .. " is not a math family", "\\begin{" .. environment .. "}x|\\end{" .. environment .. "}", {})
end
check_case("textcolor preserves math", "\\(\\textcolor{red}{x|}\\)", { in_math = true })
check_case("textwidth is not a text-mode command", "\\(\\textwidth{x|}\\)", { in_math = true })
check_case("multiline begin name", "\\begin\n{aligned}\nx|\n\\end{aligned}", { in_math = true, in_align = true })
check_case("array column specification", "\\begin{array}{c|c}x\\end{array}", {})
check_case("alignat column count", "\\begin{alignat}{2|}x\\end{alignat}", {})
check_case("math after array specification", "\\begin{array}{cc}|x\\end{array}", { in_math = true, in_align = true })
check_case("inside begin name", "\\begin{ali|gn}x\\end{align}", {})
check_case("inside end name", "\\begin{align}x\\end{ali|gn}", {})
check_case("after begin name", "\\begin{align}|x\\end{align}", { in_math = true, in_align = true })
check_case("after math environment", "\\begin{align}x\\end{align}|", {})
check_case("text inside alignment", "\\begin{align}x + \\text{words|}\\end{align}", {})
check_case("comment inside alignment", "\\begin{align}\nx % words|\n\\end{align}", {})
check_case("tikzcd", "\\begin{tikzcd}A|\\end{tikzcd}", { in_math = true, in_tikzcd = true })
check_case("tikzcd text", "\\begin{tikzcd}\\text{words|}\\end{tikzcd}", {})
for _, environment in ipairs({ "itemize", "enumerate" }) do
	check_case(environment .. " text", "\\begin{" .. environment .. "}\\item words|\\end{" .. environment .. "}", { in_bullets = true })
end
check_case("math within a list", "\\begin{itemize}\\item \\(x|\\)\\end{itemize}", { in_math = true })
check_case("outside a list", "\\begin{itemize}\\item words\\end{itemize}|", {})
check_case("unknown environment", "\\begin{unknown}words|\\end{unknown}", {})
check_case("no installed parser", "words $x|$", {}, "math_snippets_no_parser", false)

check_case("markdown prose", "Plain wo|rds", {}, "markdown", "markdown")
check_case("markdown inline injection", "Words $x|+y$ here", { in_math = true }, "markdown", "markdown")
check_case("markdown inline code", "Code `$x|+y$` here", {}, "markdown", "markdown")
check_case("markdown latex fence injection", "```latex\n\\begin{aligned}x|\\end{aligned}\n```", { in_math = true, in_align = true }, "markdown", "markdown")
check_case("markdown code fence without latex injection", "```text\n$x|+y$\n```", {}, "markdown", "markdown")

-- Updating an attached parser must invalidate context even when LuaSnip does
-- not pass a matched_trigger or passes one longer than a single character.
local buffer = fixture("words|", "tex", "latex")
local ok, err = pcall(function()
	equal("before edit", conditions.in_math(), false)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "\\(x\\)" })
	vim.api.nvim_win_set_cursor(0, { 1, 3 })
	equal("fresh edit without trigger", conditions.in_math(), true)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "words" })
	vim.api.nvim_win_set_cursor(0, { 1, 5 })
	equal("fresh edit with long trigger", conditions.in_math("words", "rds"), false)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "$x$" })
	vim.api.nvim_win_set_cursor(0, { 1, 2 })
	equal("fresh edit with single-character trigger", conditions.in_math("$x", "x"), true)
	equal("LuaSnip condition conjunction", (conditions.in_math * -conditions.in_text)(), true)
	equal("LuaSnip condition disjunction", (conditions.in_text + conditions.in_math)(), true)
	equal("LuaSnip condition negation", (-conditions.in_math)(), false)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "$x$ word $y$" })
	vim.api.nvim_win_set_cursor(0, { 1, 2 })
	equal("cursor movement first math", conditions.in_math(), true)
	vim.api.nvim_win_set_cursor(0, { 1, 8 })
	equal("cursor movement into text", conditions.in_math(), false)
	vim.api.nvim_win_set_cursor(0, { 1, 11 })
	equal("cursor movement second math", conditions.in_math(), true)
end)
if not ok then
	failures[#failures + 1] = "edit and composition checks: " .. tostring(err)
end
vim.api.nvim_buf_delete(buffer, { force = true })

-- Wrap a real parser to verify shared work and recovery from transient failures.
buffer = fixture("$x|$", "tex", "latex")
local parser = vim.treesitter.get_parser(buffer, "latex")
local original_parse = parser.parse
local original_get_parser = vim.treesitter.get_parser
ok, err = pcall(function()
	local parses = 0
	parser.parse = function(self, ...)
		parses = parses + 1
		return original_parse(self, ...)
	end
	equal("cache initial math", conditions.in_math(), true)
	local initial_parses = parses
	equal("cache initial parse occurred", initial_parses > 0, true)
	conditions.in_text()
	conditions.in_align()
	conditions.in_bullets()
	conditions.in_tikzcd()
	equal("conditions share the cached parse", parses, initial_parses)
	local tick = vim.api.nvim_buf_get_changedtick(buffer)
	parser:invalidate()
	equal("parser invalidation recovers cached context", conditions.in_math(), true)
	equal("parser invalidation requires a new parse", parses > initial_parses, true)
	equal("parser invalidation needs no buffer edit", vim.api.nvim_buf_get_changedtick(buffer), tick)

	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "$y$" })
	vim.api.nvim_win_set_cursor(0, { 1, 2 })
	parser.parse = function()
		parses = parses + 1
		return nil
	end
	equal("nil parse result fails closed", conditions.in_math(), false)
	local failed_parses = parses
	equal("nil parse result retries", conditions.in_math(), false)
	equal("failed parses are not cached", parses, failed_parses + 1)
	parser.parse = original_parse
	equal("nil parse result recovers without editing", conditions.in_math(), true)

	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "$z$" })
	vim.api.nvim_win_set_cursor(0, { 1, 2 })
	parser.parse = function()
		error("simulated parser failure")
	end
	equal("parse exception fails closed", conditions.in_math(), false)
	parser.parse = original_parse
	equal("parse exception recovers without editing", conditions.in_math(), true)

	vim.treesitter.get_parser = function()
		error("simulated unavailable parser")
	end
	equal("missing parser exception is safe", conditions.in_math(), false)
	equal("missing parser text complement", conditions.in_text(), true)
	vim.treesitter.get_parser = original_get_parser
	equal("parser lookup recovers", conditions.in_math(), true)
end)
parser.parse = original_parse
vim.treesitter.get_parser = original_get_parser
if not ok then
	failures[#failures + 1] = "cache and failure recovery checks: " .. tostring(err)
end
vim.api.nvim_buf_delete(buffer, { force = true })

if #failures > 0 then
	io.stderr:write(table.concat(failures, "\n") .. "\n")
	io.stderr:write(("%d failure(s), %d assertions evaluated\n"):format(#failures, checks))
	vim.cmd("cquit 1")
end
print(("latex conditions: %d assertions passed"):format(checks))
