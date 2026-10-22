-- Run from the repository root:
--   nvim --headless -u NONE -i NONE -l tests/benchmark.lua [baseline-revision]
-- LuaSnip, the latex parser and highlight queries must be on 'runtimepath'.
-- Older ECMA snippets also need jsregexp.
local usage = "Usage: nvim --headless -u NONE -i NONE -l tests/benchmark.lua [baseline-revision]"
if arg[1] == "--help" then
	print(usage)
	return
end
assert(not arg[2], usage)

local root = vim.fn.getcwd()
assert(vim.fn.isdirectory(root .. "/luasnippets/tex") == 1, "Run the benchmark from the repository root")
vim.opt.runtimepath:prepend(root)
vim.opt.virtualedit = "onemore"
vim.treesitter.language.register("latex", { "tex", "plaintex" })

local ls = require("luasnip")
local collection = require("luasnip.session.snippet_collection")
local snippet_env = ls.get_snip_env()
local rounds, iterations, warmup = 5, 100, 100

local function git(...)
	local result = vim.system({ "git", ... }, { cwd = root, text = true }):wait()
	assert(result.code == 0, vim.trim(result.stderr))
	return result.stdout
end

local function load_version(label, revision)
	local function source(path)
		if revision then
			return git("show", revision .. ":" .. path)
		end
		local file = assert(io.open(root .. "/" .. path, "rb"))
		local text = file:read("*a")
		file:close()
		return text
	end

	local function chunk(path, env)
		local fn = assert(loadstring(source(path), "@" .. label .. "/" .. path))
		setfenv(fn, env)
		return fn()
	end

	-- Keep each revision's helpers and context cache separate, while sharing LuaSnip.
	local modules = {}
	local module_env = setmetatable({}, { __index = _G })
	local function version_require(name)
		if not name:match("^math%-snippets%.") then
			return require(name)
		end
		if modules[name] == nil then
			modules[name] = chunk("lua/" .. name:gsub("%.", "/") .. ".lua", module_env)
		end
		return modules[name]
	end
	module_env.require = version_require
	local env = setmetatable({ require = version_require }, {
		__index = function (_, key)
			return snippet_env[key] or _G[key]
		end
	})
	for _, name in ipairs({ "s", "postfix" }) do
		local factory = snippet_env[name]
		env[name] = function (context, ...)
			-- LuaSnip silently treats ECMA triggers as plain strings without jsregexp.
			-- Reject that fallback: it would benchmark different matching behavior.
			if type(context) == "table" and context.trigEngine == "ecma" then
				assert(type(require("luasnip.util.jsregexp")) == "function", label .. " requires jsregexp for ECMA triggers")
			end
			return factory(context, ...)
		end
	end

	local paths = revision
		and vim.split(git("ls-tree", "-r", "--name-only", revision, "--", "luasnippets/tex"), "\n", { trimempty = true })
		or vim.fn.glob("luasnippets/tex/**/*.lua", false, true)
	table.sort(paths)
	local autosnippets = {}
	for _, path in ipairs(paths) do
		if path:match("%.lua$") then
			local _, automatic = chunk(path, env)
			vim.list_extend(autosnippets, automatic or {})
		end
	end
	assert(#autosnippets > 0, label .. " has no TeX autosnippets")
	local filetype = "math_snippets_benchmark_" .. label
	ls.add_snippets(filetype, autosnippets, { type = "autosnippets" })
	return { label = label, filetypes = { filetype }, count = #autosnippets }
end

local versions = {}
if arg[1] then
	local revision = vim.trim(git("rev-parse", "--verify", "--end-of-options", arg[1] .. "^{commit}"))
	versions[#versions + 1] = load_version("baseline", revision)
	print("Baseline revision: " .. revision)
end
versions[#versions + 1] = load_version("current")

local function scan(version, line)
	return collection.match_snippet(line, version.filetypes, "autosnippets")
end

local function measure(state)
	for _ = 1, warmup do
		state.run()
	end
	collectgarbage("collect")
	local start = vim.uv.hrtime()
	for _ = 1, iterations do
		state.run()
	end
	return (vim.uv.hrtime() - start) / iterations / 1000
end

print(("Neovim %s; %d rounds, %d warmups and %d measured operations per round")
		:format(tostring(vim.version()), rounds, warmup, iterations))
for _, version in ipairs(versions) do
	print(("%s: %d TeX autosnippets"):format(version.label, version.count))
end
print("Median microseconds per operation. Expansion and UI rendering are never timed; there are no timing thresholds.")

local function new_buffer(lines)
	local buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buffer)
	vim.bo[buffer].filetype = "tex"
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
	return buffer
end

local function expect_match(version, line, name, trigger, captures)
	local snippet, params = scan(version, line)
	assert(snippet and params, version.label .. " did not match " .. name)
	assert(snippet.name == name, ("%s: expected %s, got %s"):format(version.label, name, snippet.name))
	assert(params.trigger == trigger, version.label .. " returned an unexpected matched trigger")
	if captures then
		assert(
			vim.deep_equal(params.captures, captures),
			version.label .. " returned unexpected captures: "
				.. vim.inspect(params.captures)
		)
	end
end

local function table_header(title)
	print("\n" .. title)
	print(
		#versions == 2 and "  Case                    Baseline us     Current us    Speedup"
			or "  Case                     Current us"
	)
end

local function benchmark(label, setup)
	local states = {}
	local times = {}
	for _, version in ipairs(versions) do
		states[version.label] = setup(version)
		-- Check expected matching behavior before any timed operations.
		states[version.label].validate()
		times[version.label] = {}
	end
	for round = 1, rounds do
		-- Alternate version order to reduce warmup and scheduling bias.
		for index = 1, #versions do
			local version = versions[round % 2 == 0 and index or #versions - index + 1]
			local state = states[version.label]
			vim.api.nvim_set_current_buf(state.buffer)
			table.insert(times[version.label], measure(state))
		end
	end
	local medians = {}
	for label, samples in pairs(times) do
		table.sort(samples)
		medians[label] = samples[math.ceil(rounds / 2)]
	end
	if medians.baseline then
		print(
			("  %-20s %14.2f %14.2f %9.2fx"):format(
				label, medians.baseline, medians.current, medians.baseline / medians.current
			)
		)
	else
		print(("  %-20s %14.2f"):format(label, medians.current))
	end
	for _, state in pairs(states) do
		vim.api.nvim_buf_delete(state.buffer, { force = true })
	end
end

local function unmatched(version, line)
	local buffer = new_buffer({ line })
	vim.api.nvim_win_set_cursor(0, { 1, #line })
	return {
		buffer = buffer,
		validate = function ()
			assert(scan(version, line) == nil, version.label .. " unexpectedly matches unmatched prose")
		end,
		run = function ()
			scan(version, line)
		end
	}
end

table_header("Unmatched prose ending in !: collection matching only")
for _, length in ipairs({ 80, 500, 2000 }) do
	local line = ("ordinary text "):rep(math.ceil(length / 14)):sub(1, length - 1) .. "!"
	benchmark(length .. " bytes", function (version) return unmatched(version, line) end)
end

table_header("Unmatched prose ending in a space: includes whitespace-pattern scans")
for _, length in ipairs({ 80, 500, 2000 }) do
	-- Keep the last word whole so none of the automatic inline-math rules match.
	local line = ("ordinary prose "):rep(math.ceil(length / 15)):sub(1, length - 6) .. "words "
	benchmark(length .. " bytes", function (version) return unmatched(version, line) end)
end

local function math_document(line)
	return { "\\documentclass{article}", "\\begin{document}", "\\[", line, line, "\\]", "\\end{document}" }
end

table_header("Successful math triggers: cursor movement + collection matching and context classification (valid tree)")
for _, case in ipairs({
	{ trigger = "sin", name = "sin" },
	{ trigger = "x7", name = "auto subscript 1", captures = { "x", "7" } },
	{ trigger = "H_2X", name = "cohomology-d", captures = { "H", "2", "X" } }
}) do
	local line = ("x + "):rep(123) .. case.trigger
	benchmark(case.trigger, function (version)
		local buffer = new_buffer(math_document(line))
		vim.treesitter.get_parser(buffer, "latex"):parse(true)
		local row = 4
		return {
			buffer = buffer,
			validate = function ()
				for target = 4, 5 do
					vim.api.nvim_win_set_cursor(0, { target, #line })
					expect_match(version, line, case.name, case.trigger, case.captures)
				end
			end,
			run = function ()
				-- Alternate insertion points so each match classifies a new context.
				row = row == 4 and 5 or 4
				vim.api.nvim_win_set_cursor(0, { row, #line })
				scan(version, line)
			end
		}
	end)
end

assert(
	vim.treesitter.query.get("latex", "highlights"), "The edit workload requires latex highlight queries on 'runtimepath'"
)
table_header("Edit + reparse + successful matching: one-character replacement, highlighter attached (900 lines)")
benchmark("sin after edit", function (version)
	local line = "\\( x + sin\\)"
	local target = 450
	local lines = { "\\documentclass{article}", "\\begin{document}" }
	for row = 3, 899 do
		lines[row] = "Ordinary prose with $x_1$ and \\emph{words}."
	end
	lines[target] = line
	lines[900] = "\\end{document}"
	local buffer = new_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { target, #line - 2 })
	vim.treesitter.start(buffer, "latex")
	local parser = vim.treesitter.get_parser(buffer, "latex")
	parser:parse(true)
	assert(vim.treesitter.highlighter.active[buffer], "LaTeX highlighter did not attach")
	local range = { target - 1, target }
	local value = "x"
	local function edit()
		value = value == "x" and "y" or "x"
		vim.api.nvim_buf_set_text(buffer, target - 1, 3, target - 1, 4, { value })
		-- The edit keeps the cursor and trigger fixed; the changed tick invalidates context.
		line = "\\( " .. value .. " + sin\\)"
	end
	return {
		buffer = buffer,
		validate = function ()
			for _ = 1, 2 do
				edit()
				assert(not parser:is_valid(false, range), "The edit did not invalidate the target parse range")
				expect_match(version, line:sub(1, #line - 2), "sin", "sin")
				assert(parser:is_valid(false, range), version.label .. " did not reparse the edited context")
			end
		end,
		run = function ()
			edit()
			scan(version, line:sub(1, #line - 2))
		end
	}
end)
print(
	"The edit workload times buffer mutation and parsing demanded by matching, with an attached highlighter; it does not time redraw."
)
