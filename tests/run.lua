-- nvim --headless -u NONE -i NONE -l tests/run.lua [options]
local root = vim.fn.getcwd()
local function read(path)
	local file = assert(io.open(path, "rb"), "Cannot read " .. path)
	local text = file:read("*a")
	file:close()
	return text
end

local function write(path, text)
	local file = assert(io.open(path, "wb"), "Cannot write " .. path)
	file:write(text)
	file:close()
end

local function configure(environment)
	vim.opt.runtimepath = vim.list_extend({ root }, vim.deepcopy(environment.runtimepaths))
	vim.opt.packpath = ""
	package.path = environment.package_path
	package.cpath = environment.package_cpath
end

-- Each suite starts in a fresh process with only the recorded dependency paths.
if arg[1] == "--child" then
	local environment = vim.json.decode(read(assert(vim.env.MATH_SNIPPETS_TEST_ENV)))
	configure(environment)
	local suite = assert(arg[2])
	assert(vim.tbl_contains({ "latex", "snippets", "integration", "benchmark" }, suite), "Unknown test suite")
	_G.arg = { select(3, unpack(arg)) }
	dofile(root .. "/tests/" .. suite .. ".lua")
	return
end

local usage = [[Usage: nvim --headless -u NONE -i NONE -l tests/run.lua [options]
  --runtimepath DIR   Explicit dependency root; repeat for multiple roots
  --record FILE       Save dependency paths, versions and SHA-256 fingerprints
  --environment FILE Replay and verify a previously recorded environment
  --benchmark [REV]   Also run the benchmark, optionally against a Git revision
  --help              Show this help

Default: discover dependency roots, then run latex, snippets and integration
in isolated child processes. No plugins or parsers are downloaded.]]
local options = { runtimepaths = {} }
local index = 1
while arg[index] do
	local flag = arg[index]
	if flag == "--help" then
		print(usage)
		return
	elseif flag == "--runtimepath" or flag == "--record" or flag == "--environment" then
		local value = assert(arg[index + 1], "Missing value for " .. flag)
		assert(not value:match("^%-%-"), "Missing value for " .. flag)
		value = vim.fn.fnamemodify(value, ":p"):gsub("/$", "")
		if flag == "--runtimepath" then
			table.insert(options.runtimepaths, value)
		else
			options[flag:sub(3)] = value
		end
		index = index + 2
	elseif flag == "--benchmark" then
		options.benchmark = ""
		if arg[index + 1] and not arg[index + 1]:match("^%-%-") then
			options.benchmark = arg[index + 1]
			index = index + 1
		end
		index = index + 1
	else
		error("Unknown option: " .. flag .. "\n" .. usage)
	end
end
assert(vim.fn.filereadable(root .. "/tests/latex.lua") == 1, "Run tests/run.lua from the repository root")
assert(not options.environment or #options.runtimepaths == 0, "Use either --environment or --runtimepath")

local languages = { "latex", "lua", "markdown", "markdown_inline" }
local required_queries = {
	latex = { "highlights", "injections" },
	markdown = { "injections" },
	markdown_inline = { "injections" }
}

local function inventory(executable)
	local files = {}
	local function fingerprint(path)
		if path and vim.fn.filereadable(path) == 1 then
			files[path] = { resolved = vim.fn.resolve(path), sha256 = vim.fn.sha256(read(path)) }
		end
	end
	fingerprint(executable)
	local patterns = {
		"lua/luasnip.lua", "lua/luasnip/**/*", "lua/luasnip-jsregexp.*", "lua/jsregexp.lua", "lua/jsregexp/**/*",
		"lua/vim/treesitter.lua", "lua/vim/treesitter/**/*"
	}
	for _, language in ipairs(languages) do
		patterns[#patterns + 1] = "parser/" .. language .. ".*"
		patterns[#patterns + 1] = "queries/" .. language .. "/*.scm"
	end
	for _, pattern in ipairs(patterns) do
		for _, path in ipairs(vim.api.nvim_get_runtime_file(pattern, true)) do
			fingerprint(path)
		end
	end
	-- Nix and LuaRocks may provide jsregexp through package paths rather than RTP.
	for _, module in ipairs({ "jsregexp", "jsregexp.core", "luasnip-jsregexp" }) do
		fingerprint(package.searchpath(module, package.path))
		fingerprint(package.searchpath(module, package.cpath))
	end
	local luasnip = vim.api.nvim_get_runtime_file("lua/luasnip/init.lua", false)[1]
	if luasnip then
		local source_root = vim.fn.fnamemodify(vim.fn.resolve(luasnip), ":h:h:h")
		for _, directory in ipairs({ "deps", ".deps" }) do
			for _, path in ipairs(vim.fn.glob(source_root .. "/" .. directory .. "/*", false, true)) do
				fingerprint(path)
			end
		end
	end
	return files
end

local function discover()
	local original_paths = vim.api.nvim_list_runtime_paths()
	local selected = {}
	local function select_path(path, suffix)
		local dependency_root = assert(path:match("^(.*)/" .. suffix .. "$"), path)
		selected[dependency_root] = true
	end
	if #options.runtimepaths > 0 then
		for _, path in ipairs(options.runtimepaths) do
			assert(vim.fn.isdirectory(path) == 1, "Missing runtime directory: " .. path)
		end
		vim.opt.runtimepath = vim.list_extend(vim.deepcopy(options.runtimepaths), { vim.env.VIMRUNTIME })
	else
		local luasnip = vim.api.nvim_get_runtime_file("lua/luasnip/init.lua", false)[1]
		assert(luasnip, "LuaSnip not found; supply --runtimepath with its directory")
		select_path(luasnip, "lua/luasnip/init%.lua")
		for _, language in ipairs(languages) do
			local parser = vim.api.nvim_get_runtime_file("parser/" .. language .. ".*", false)[1]
			assert(parser, "Missing " .. language .. " parser; supply its --runtimepath directory")
			select_path(parser, "parser/[^/]+")
			for _, query in ipairs(vim.api.nvim_get_runtime_file("queries/" .. language .. "/*.scm", true)) do
				select_path(query, "queries/[^/]+/[^/]+")
			end
		end
		selected[vim.env.VIMRUNTIME] = true
		local paths = {}
		for _, path in ipairs(original_paths) do
			if selected[path] then
				paths[#paths + 1] = path
				selected[path] = nil
			end
		end
		assert(next(selected) == nil, "A discovered dependency is outside runtimepath; supply explicit --runtimepath roots")
		vim.opt.runtimepath = paths
	end
	vim.opt.packpath = ""

	local environment = {
		schema = 2,
		nvim = {
			executable = vim.v.progpath,
			runtime = vim.env.VIMRUNTIME,
			version = vim.split(vim.api.nvim_exec2("version", { output = true }).output, "\n")[1]
		},
		runtimepaths = vim.api.nvim_list_runtime_paths(),
		package_path = package.path,
		package_cpath = package.cpath,
		parsers = {},
		queries = {}
	}
	local luasnip = assert(vim.api.nvim_get_runtime_file("lua/luasnip/init.lua", false)[1], "LuaSnip is missing")
	local source_root = vim.fn.fnamemodify(vim.fn.resolve(luasnip), ":h:h:h")
	environment.luasnip = source_root
	environment.luasnip_version = source_root:match("luasnip%-(%d+%.%d+%.%d+)")
	if vim.fn.isdirectory(source_root .. "/.git") == 1 or vim.fn.filereadable(source_root .. "/.git") == 1 then
		local revision = vim
			.system({ "git", "-C", source_root, "describe", "--tags", "--always", "--dirty" }, { text = true })
			:wait()
		if revision.code == 0 then
			environment.luasnip_version = vim.trim(revision.stdout)
		end
	end
	for _, language in ipairs(languages) do
		local path = assert(
			vim.api.nvim_get_runtime_file("parser/" .. language .. ".*", false)[1], "Missing parser: " .. language
		)
		local loaded, load_error = vim.treesitter.language.add(language)
		assert(loaded, "Cannot load " .. language .. " parser: " .. tostring(load_error))
		environment.parsers[language] = {
			path = vim.fn.resolve(path),
			abi = vim.treesitter.language.inspect(language).abi_version,
			revision = vim.fn.resolve(path):match("rev=([^/]+)")
		}
		for _, kind in ipairs(required_queries[language] or {}) do
			assert(vim.treesitter.query.get(language, kind), "Missing " .. language .. "/" .. kind .. " query")
		end
		for _, query in ipairs(vim.api.nvim_get_runtime_file("queries/" .. language .. "/*.scm", true)) do
			environment.queries[#environment.queries + 1] = vim.fn.resolve(query)
		end
	end
	environment.files = inventory(environment.nvim.executable)
	return environment
end

local environment = options.environment and vim.json.decode(read(options.environment)) or discover()
assert(environment.schema == 2, "Unsupported environment report format; record a new environment")
assert(environment.nvim.runtime, "Environment lacks the core runtime path; record a new environment")
for _, path in ipairs(environment.runtimepaths) do
	assert(vim.fn.isdirectory(path) == 1, "Recorded runtime directory is missing: " .. path)
end
configure(environment)
local actual = inventory(environment.nvim.executable)
for path, expected in pairs(environment.files) do
	assert(vim.deep_equal(actual[path], expected), "Dependency changed or disappeared since recording: " .. path)
	actual[path] = nil
end
assert(next(actual) == nil, "New dependency file appeared since recording: " .. tostring(next(actual)))
local serialized = vim.json.encode(environment)
if options.record then
	write(options.record, serialized .. "\n")
end
print(environment.nvim.version .. "\nNeovim: " .. environment.nvim.executable)
print("LuaSnip " .. (environment.luasnip_version or "(identified by file fingerprints)") .. ": " .. environment.luasnip)
for _, language in ipairs(languages) do
	local parser = environment.parsers[language]
	print(
		("%s parser (ABI %s%s): %s"):format(
			language, tostring(parser.abi), parser.revision and ", rev " .. parser.revision or "", parser.path
		)
	)
end
print(("Dependency files verified: %d"):format(vim.tbl_count(environment.files)))
if options.record then
	print("Environment recorded: " .. options.record)
end

local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary .. "/state/nvim/logs", "p")
write(temporary .. "/environment.json", serialized)
local suites = { "latex", "snippets", "integration" }
if options.benchmark then
	suites[#suites + 1] = "benchmark"
end
local ok, err = xpcall(function ()
	for _, suite in ipairs(suites) do
		local command = {
			environment.nvim.executable, "--headless", "-u", "NONE", "-i", "NONE", "-l", root .. "/tests/run.lua", "--child",
			suite
		}
		if suite == "benchmark" and options.benchmark ~= "" then
			command[#command + 1] = options.benchmark
		end
		print("Running " .. suite .. "...")
		local result = vim.system(command, {
			cwd = root,
			text = true,
			env = {
				MATH_SNIPPETS_TEST_ENV = temporary .. "/environment.json",
				XDG_CONFIG_HOME = temporary .. "/config",
				XDG_DATA_HOME = temporary .. "/data",
				XDG_CACHE_HOME = temporary .. "/cache",
				XDG_STATE_HOME = temporary .. "/state",
				NVIM_APPNAME = "nvim",
				VIMRUNTIME = environment.nvim.runtime,
				NVIM_LOG_FILE = temporary .. "/nvim.log"
			}
		}):wait(60000)
		if result.stdout ~= "" then
			io.stdout:write(result.stdout)
		end
		if result.stderr ~= "" then
			io.stderr:write(result.stderr)
		end
		assert(result.code == 0, suite .. " failed (exit " .. tostring(result.code) .. ")")
	end
end, debug.traceback)
vim.fn.delete(temporary, "rf")
assert(ok, err)
print("All requested suites passed")
