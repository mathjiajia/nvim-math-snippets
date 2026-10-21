-- Run from the repository root:
--   nvim --headless -u NONE -i NONE -l tests/latex.lua
-- LuaSnip and the latex, lua, markdown, and markdown_inline parsers must be on 'runtimepath'.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.virtualedit = "onemore"

-- -u NONE skips the TeX language mappings supplied by the editor setup.
vim.treesitter.language.register("latex", { "tex", "plaintex" })

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
	local ok, err = pcall(function ()
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
check_case(
	"before end environment at column zero", "\\begin{align}\nx\n|\\end{align}",
	{
		in_math = true,
		in_align = true
	}
)
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

for _, command in ipairs(
	{ "text", "textbf", "textit", "textrm", "textnormal", "mbox", "operatorname", "tag", "label", "ref" }
) do
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
	check_case(
		environment .. " math", "\\begin{" .. environment .. "}\nx|\n\\end{" .. environment .. "}",
		{
			in_math = true
		}
	)
end
for _, environment in ipairs(
	{
		"align", "align*", "aligned", "alignedat", "alignat", "split", "eqnarray", "flalign", "array", "matrix", "pmatrix",
		"bmatrix", "Bmatrix", "vmatrix", "Vmatrix", "smallmatrix", "cases"
	}
) do
	local argument = ({ alignedat = "{2}", alignat = "{2}", array = "{cc}" })[environment] or ""
	check_case(
		environment .. " alignment",
		"\\begin{" .. environment
			.. "}" .. argument
			.. "\nx|\n\\end{" .. environment
			.. "}",
		{
			in_math = true,
			in_align = true
		}
	)
end
for _, environment in ipairs({ "pmatrix*", "dcases", "rcases", "drcases", "dcasesra", "drcasesra" }) do
	check_case(
		environment .. " family", "\\begin{" .. environment .. "}x|\\end{" .. environment .. "}",
		{
			in_math = true,
			in_align = true
		}
	)
end
check_case("multlined family", "\\begin{multlined}x|\\end{multlined}", { in_math = true })
-- Alignment names intentionally match families, including custom variants.
for _, environment in ipairs({ "alignment", "alignatfoo", "xmatrix", "matrixnotation", "rcasesra" }) do
	check_case(
		environment .. " alignment family", "\\begin{" .. environment .. "}x|\\end{" .. environment .. "}",
		{
			in_math = true,
			in_align = true
		}
	)
end
check_case("custom math family", "\\begin{displaymathematics}x|\\end{displaymathematics}", { in_math = true })
check_case("subequations preserves text", "\\begin{subequations}words|\\end{subequations}", {})
check_case(
	"math inside subequations", "\\begin{subequations}\\begin{equation}x|\\end{equation}\\end{subequations}",
	{
		in_math = true
	}
)
check_case("custom text command", "\\(\\mytext{word|}\\)", {})
check_case("textcolor preserves math", "\\(\\textcolor{red}{x|}\\)", { in_math = true })
check_case("textwidth is not a text-mode command", "\\(\\textwidth{x|}\\)", { in_math = true })
check_case("boxed preserves math", "\\(\\boxed{x|}\\)", { in_math = true })
check_case("sin is not a unit command", "\\(\\sin{x|}\\)", { in_math = true })
check_case("custom reference command", "\\(\\zcustomref{eq:a|}\\)", {})
-- Name matching is case-sensitive; only the explicitly anchored names are exact.
for _, command in ipairs({ "emph", "fbox", "SI", "si", "qty", "unit", "num", "SI*", "zcustomlabel", "zcustomrefmore" }) do
	check_case(command .. " text or opaque argument", "\\(\\" .. command .. "{word|}\\)", {})
end
for _, command in ipairs({ "SIunit", "units", "number", "myText", "Box", "Zref", "azref" }) do
	check_case(command .. " preserves math", "\\(\\" .. command .. "{x|}\\)", { in_math = true })
end
for _, environment in ipairs({ "Split", "splitextra", "extrasplit", "ALIGN" }) do
	check_case(environment .. " is not a math family", "\\begin{" .. environment .. "}x|\\end{" .. environment .. "}", {})
end
for _, environment in ipairs({ "arrayextra", "alignatfoo", "alignedatextra" }) do
	check_case(
		environment .. " first group is math", "\\begin{" .. environment .. "}{x|}\\end{" .. environment .. "}",
		{ in_math = true, in_align = true }
	)
end
check_case("starred alignedat column count", "\\begin{alignedat*}{2|}x\\end{alignedat*}", {})
check_case("url inside math", "\\(\\url{https://example.org/x|}\\)", {})
check_case("multiline begin name", "\\begin\n{aligned}\nx|\n\\end{aligned}", { in_math = true, in_align = true })
check_case("comment before begin name", "\\begin% comment\n{aligned}\nx|\n\\end{aligned}", { in_math = true, in_align = true })
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
-- The nearest math scope owns alignment/diagram flags; lists require text mode.
check_case("inline math inside alignment", "\\begin{align}\\(x|\\)\\end{align}", { in_math = true })
check_case("ensuremath inside alignment", "\\begin{align}\\ensuremath{x|}\\end{align}", { in_math = true })
check_case("inline math inside tikzcd", "\\begin{tikzcd}\\(A|\\)\\end{tikzcd}", { in_math = true })
check_case(
	"text inside math inside list", "\\begin{itemize}\\item \\(\\text{word|}\\)\\end{itemize}",
	{ in_bullets = true }
)
check_case(
	"math inside text inside list", "\\begin{itemize}\\item \\(\\text{word \\(x|\\)}\\)\\end{itemize}",
	{ in_math = true }
)
check_case("opaque command inside list", "\\begin{itemize}\\item \\zcref{eq:a|}\\end{itemize}", {})
for _, environment in ipairs({ "itemize", "enumerate" }) do
	check_case(
		environment .. " text", "\\begin{" .. environment .. "}\\item words|\\end{" .. environment .. "}",
		{
			in_bullets = true
		}
	)
end
check_case("custom list family", "\\begin{compactitemize}\\item words|\\end{compactitemize}", { in_bullets = true })
check_case("math within a list", "\\begin{itemize}\\item \\(x|\\)\\end{itemize}", { in_math = true })
check_case("outside a list", "\\begin{itemize}\\item words\\end{itemize}|", {})
check_case("unknown environment", "\\begin{unknown}words|\\end{unknown}", {})
check_case("no installed parser", "words $x|$", {}, "math_snippets_no_parser", false)

check_case("markdown prose", "Plain wo|rds", {}, "markdown", "markdown")
check_case("markdown inline injection", "Words $x|+y$ here", { in_math = true }, "markdown", "markdown")
check_case("markdown inline code", "Code `$x|+y$` here", {}, "markdown", "markdown")
check_case(
	"markdown latex fence injection", "```latex\n\\begin{aligned}x|\\end{aligned}\n```",
	{
		in_math = true,
		in_align = true
	},
	"markdown", "markdown"
)
check_case("markdown code fence without latex injection", "```text\n$x|+y$\n```", {}, "markdown", "markdown")

-- A custom injection must override the surrounding LaTeX math context.
-- Reset the temporary override afterward so subsequent fixtures use runtime queries.
vim.treesitter.query.set("latex", "injections", [[
((generic_command
  command: (command_name) @_command
  arg: (curly_group) @injection.content)
 (#eq? @_command "\\directlua")
 (#set! injection.language "lua")
 (#set! injection.include-children)
 (#offset! @injection.content 0 1 0 -1))
]])
check_case("custom Lua injection inside math", "\\(x + \\directlua{tex.sprint(1|)} + y\\)", {})
check_case("math after custom Lua injection", "\\(x + \\directlua{tex.sprint(1)} + y|\\)", { in_math = true })
vim.treesitter.query.set("latex", "injections", nil)

-- Filetype and language registration can change without any edit or cursor move.
local buffer = fixture("\\begin{aligned}x|\\end{aligned}", "tex", "latex")
local ok, err = pcall(function ()
	local tick = vim.api.nvim_buf_get_changedtick(buffer)
	equal("filetype change starts in math", conditions.in_math(), true)
	vim.bo[buffer].filetype = "text"
	equal("filetype change clears cached math", conditions.in_math(), false)
	vim.bo[buffer].filetype = "tex"
	equal("filetype restoration recovers math", conditions.in_math(), true)
	equal("filetype changes need no buffer edit", vim.api.nvim_buf_get_changedtick(buffer), tick)
end)
if not ok then
	failures[#failures + 1] = "filetype change checks: " .. tostring(err)
end
vim.api.nvim_buf_delete(buffer, { force = true })

local custom_filetype = "math_snippets_dynamic_language"
buffer = fixture("\\begin{aligned}x|\\end{aligned}", custom_filetype, false)
ok, err = pcall(function ()
	local tick = vim.api.nvim_buf_get_changedtick(buffer)
	equal("unregistered filetype has no math parser", conditions.in_math(), false)
	vim.treesitter.language.register("latex", custom_filetype)
	equal("new language registration recovers without editing", conditions.in_math(), true)
	vim.treesitter.language.register("markdown", custom_filetype)
	equal("changed language registration clears cached math", conditions.in_math(), false)
	vim.treesitter.language.register("latex", custom_filetype)
	equal("restored language registration recovers without editing", conditions.in_math(), true)
	equal("language registration needs no buffer edit", vim.api.nvim_buf_get_changedtick(buffer), tick)
	vim.treesitter.language.register("markdown", custom_filetype)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "\\begin{aligned}y\\end{aligned}" })
	equal("changed language registration is honored after editing", conditions.in_math(), false)
	vim.treesitter.language.register("latex", custom_filetype)
	equal("language registration recovers after editing", conditions.in_math(), true)
end)
if not ok then
	failures[#failures + 1] = "language registration checks: " .. tostring(err)
end
vim.api.nvim_buf_delete(buffer, { force = true })

custom_filetype = "math_snippets_remapped_language"
vim.treesitter.language.register("latex", custom_filetype)
buffer = fixture("\\begin{aligned}x|\\end{aligned}", custom_filetype, false)
ok, err = pcall(function ()
	equal("initial language registration enables math", conditions.in_math(), true)
	vim.treesitter.language.register("markdown", custom_filetype)
	equal("remapping a known language clears cached math", conditions.in_math(), false)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "\\begin{aligned}y\\end{aligned}" })
	equal("remapping a known language is honored after editing", conditions.in_math(), false)
	vim.treesitter.language.register("latex", custom_filetype)
	equal("restoring a known language recovers math", conditions.in_math(), true)
end)
if not ok then
	failures[#failures + 1] = "language remapping checks: " .. tostring(err)
end
vim.api.nvim_buf_delete(buffer, { force = true })

-- Updating an attached parser must invalidate context even when LuaSnip does
-- not pass a matched_trigger or passes one longer than a single character.
buffer = fixture("words|", "tex", "latex")
ok, err = pcall(function ()
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
ok, err = pcall(function ()
	local parses = 0
	parser.parse = function (self, ...)
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

	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "$z$" })
	vim.api.nvim_win_set_cursor(0, { 1, 2 })
	local failed_parses = 0
	parser.parse = function ()
		failed_parses = failed_parses + 1
		error("simulated parser failure")
	end
	equal("parse exception fails closed", conditions.in_math(), false)
	equal("parse exception retries", conditions.in_math(), false)
	equal("failed parses are not cached", failed_parses, 2)
	parser.parse = original_parse
	equal("parse exception recovers without editing", conditions.in_math(), true)

	vim.treesitter.get_parser = function ()
		return nil, "simulated unavailable parser"
	end
	equal("missing parser nil result is safe", conditions.in_math(), false)
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

-- An unavailable parser on the first lookup must not create a cached result.
buffer = fixture("$x|$", "tex", "latex")
ok, err = pcall(function ()
	local tick = vim.api.nvim_buf_get_changedtick(buffer)
	vim.treesitter.get_parser = function ()
		return nil, "simulated initially unavailable parser"
	end
	equal("initially missing parser fails closed", conditions.in_math(), false)
	equal("initially missing parser text complement", conditions.in_text(), true)
	vim.treesitter.get_parser = original_get_parser
	equal("initially missing parser recovers without editing", conditions.in_math(), true)
	equal("initial parser recovery needs no buffer edit", vim.api.nvim_buf_get_changedtick(buffer), tick)
end)
vim.treesitter.get_parser = original_get_parser
if not ok then
	failures[#failures + 1] = "initial parser recovery checks: " .. tostring(err)
end
vim.api.nvim_buf_delete(buffer, { force = true })

if #failures > 0 then
	io.stderr:write(table.concat(failures, "\n") .. "\n")
	io.stderr:write(("%d failure(s), %d assertions evaluated\n"):format(#failures, checks))
	vim.cmd("cquit 1")
end
print(("latex conditions: %d assertions passed"):format(checks))
