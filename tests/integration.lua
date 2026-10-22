-- Run from the repository root:
--   nvim --headless -u NONE -i NONE -l tests/integration.lua
-- LuaSnip and the latex parser must be on 'runtimepath'.
-- An embedded editor processes real input/events while this process asserts
-- its state. Keeping its RPC channel open also prevents stdin EOF from ending
-- a failing Insert-mode test before it can report a failure.
local stderr = {}
local editor = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE" }, {
	rpc = true,
	cwd = vim.fn.getcwd(),
	on_stderr = function (_, lines)
		vim.list_extend(stderr, lines)
	end
})
assert(editor > 0, "could not start the integration-test editor")

local function request(method, ...)
	return vim.fn.rpcrequest(editor, method, ...)
end

local function execute(code, ...)
	return request("nvim_exec_lua", code, { ... })
end

local fixture
local scenarios, steps, checks = 0, 0, 0

local function equal(label, actual, expected)
	checks = checks + 1
	assert(
		vim.deep_equal(actual, expected),
		("%s: expected %s, got %s"):format(label, vim.inspect(expected), vim.inspect(actual))
	)
end

local function text(buffer)
	return table.concat(request("nvim_buf_get_lines", buffer or fixture.buffer, 0, -1, false), "\n")
end

local function input(keys, expected)
	expected = expected or {}
	expected.buffer = expected.buffer or fixture.buffer
	local before = execute("return InputTests.state(...)", expected.buffer).counts
	request("nvim_input", keys)
	local actual
	local ok = vim.wait(5000, function ()
		actual = execute("return InputTests.state(...)", expected.buffer)
		if actual.buffer ~= expected.buffer or expected.mode and actual.mode ~= expected.mode
			or expected.text and actual.text ~= expected.text or expected.cursor
				and not vim.deep_equal(actual.cursor, expected.cursor) then
			return false
		end
		for _, event in ipairs(expected.events or {}) do
			if (actual.counts[event] or 0) <= (before[event] or 0) then
				return false
			end
		end
		return true
	end, 1
	)
	assert(
		ok,
		("%s: timed out after %s; expected %s; got %s; recent events %s"):format(
			fixture.name, vim.inspect(keys), vim.inspect(expected), vim.inspect(actual),
			vim.inspect(execute("return InputTests.recent_events()"))
		)
	)
	steps = steps + 1
end

local function type_text(keys, expected)
	input(keys, { text = expected, mode = "i", events = { "InsertCharPre", "TextChangedI" } })
end

local function at_math_exit()
	input("i", { mode = "i", events = { "InsertEnter" } })
	-- Expand by typing the trigger through the normal autosnippet machinery.
	type_text("mk", [[\(\)]])
	type_text("x", [[\(x\)]])
	input("<F6>", { text = [[\(x\)]], cursor = { 1, 5 }, mode = "i", events = { "CursorMovedI" } })
end

local function normal_mode()
	input("<Esc>", { mode = "n", events = { "InsertLeave" } })
end

local function with_buffer(name, callback)
	fixture = { name = name, buffer = execute("return InputTests.new_buffer()") }
	callback()
	if request("nvim_get_mode").mode ~= "n" then
		normal_mode()
	end
	equal(name .. " leaves expected text", text(), fixture.expected)
	request("nvim_buf_delete", fixture.buffer, { force = true })
	if fixture.other then
		request("nvim_buf_delete", fixture.other, { force = true })
	end
	-- Queued input can display an autocmd error without failing the RPC request.
	-- Check after cleanup too; this recognizes Neovim's English Lua error heading.
	local messages = request("nvim_exec2", "messages", { output = true }).output
	assert(not messages:find("Error in ", 1, true), name .. ": " .. messages)
	scenarios = scenarios + 1
end

local function run()
	execute(
		[[
		local runtimepath, packpath, lua_path, lua_cpath, root = ...
		vim.opt.runtimepath = runtimepath
		vim.opt.packpath = packpath
		package.path = lua_path
		package.cpath = lua_cpath
		vim.opt.runtimepath:prepend(root)
		vim.opt.virtualedit = "onemore"
		vim.opt.swapfile = false
		vim.opt.showmode = false
		vim.opt.hidden = true
		vim.treesitter.language.register("latex", { "tex", "plaintex" })
		local api = vim.api
		local ls = require("luasnip")
		ls.setup({
			-- Enable history to test jumping back into a completed snippet too.
			history = true,
			enable_autosnippets = true,
			update_events = { "TextChanged", "TextChangedI" },
			delete_check_events = "TextChanged"
		})
		local env = setmetatable({}, {
			__index = function (_, key) return ls.get_snip_env()[key] or _G[key] end
		})
		for _, file in ipairs({ "misc", "symbols" }) do
			local chunk = assert(loadfile("luasnippets/tex/" .. file .. ".lua"))
			setfenv(chunk, env)
			local _, autosnippets = chunk()
			ls.add_snippets("tex", autosnippets, { type = "autosnippets" })
		end

		InputTests = { events = {}, counts = {} }
		api.nvim_create_autocmd({ "InsertEnter", "InsertLeave", "InsertCharPre", "CursorMovedI", "TextChangedI", "BufLeave" }, {
			callback = function (event)
				InputTests.counts[event.buf] = InputTests.counts[event.buf] or {}
				local counts = InputTests.counts[event.buf]
				counts[event.event] = (counts[event.event] or 0) + 1
				InputTests.events[#InputTests.events + 1] = {
					event.event, event.buf, api.nvim_get_mode().mode,
					api.nvim_win_get_cursor(0), api.nvim_get_current_line()
				}
			end
		})
		function InputTests.new_buffer()
			local buffer = api.nvim_create_buf(false, true)
			api.nvim_set_current_buf(buffer)
			vim.bo[buffer].filetype = "tex"
			vim.bo[buffer].undolevels = 100
			vim.keymap.set({ "i", "s" }, "<F6>", function () ls.jump(1) end, { buf = buffer })
			vim.keymap.set({ "i", "s" }, "<F7>", function () ls.jump(-1) end, { buf = buffer })
			vim.treesitter.get_parser(buffer, "latex")
			return buffer
		end
		function InputTests.state(buffer)
			return {
				buffer = api.nvim_get_current_buf(),
				mode = api.nvim_get_mode().mode,
				text = table.concat(api.nvim_buf_get_lines(buffer, 0, -1, false), "\n"),
				cursor = api.nvim_win_get_cursor(0),
				counts = InputTests.counts[buffer] or {},
				error = vim.v.errmsg
			}
		end
		function InputTests.recent_events()
			return vim.list_slice(InputTests.events, math.max(1, #InputTests.events - 11))
		end
	]], vim.o.runtimepath, vim.o.packpath, package.path, package.cpath, vim.fn.getcwd()
	)

	with_buffer("letter immediately after math", function ()
		at_math_exit()
		type_text("a", [[\(x\) a]])
		type_text("b", [[\(x\) ab]])
		fixture.expected = [[\(x\) ab]]
	end)

	with_buffer("punctuation consumes pending spacing", function ()
		at_math_exit()
		type_text(",", [[\(x\),]])
		type_text("a", [[\(x\),a]])
		fixture.expected = [[\(x\),a]]
	end)

	with_buffer("typing away from math does not insert a space", function ()
		at_math_exit()
		input("<Home>", { cursor = { 1, 0 }, mode = "i", events = { "CursorMovedI" } })
		type_text("a", [[a\(x\)]])
		fixture.expected = [[a\(x\)]]
	end)

	with_buffer("repeated math exit inserts only one space", function ()
		at_math_exit()
		input("<F7>", { mode = "s" })
		input("<F6>", { cursor = { 1, 5 }, mode = "i" })
		type_text("a", [[\(x\) a]])
		fixture.expected = [[\(x\) a]]
	end)

	with_buffer("moving away and back retains spacing", function ()
		at_math_exit()
		input("<Left>", { cursor = { 1, 4 }, mode = "i", events = { "CursorMovedI" } })
		input("<Right>", { cursor = { 1, 5 }, mode = "i", events = { "CursorMovedI" } })
		type_text("a", [[\(x\) a]])
		fixture.expected = [[\(x\) a]]
	end)

	with_buffer("leaving and reentering Insert mode retains spacing", function ()
		at_math_exit()
		normal_mode()
		input("A", { mode = "i", events = { "InsertEnter" } })
		type_text("a", [[\(x\) a]])
		fixture.expected = [[\(x\) a]]
	end)

	with_buffer("switching buffers and returning retains spacing", function ()
		fixture.other = execute(
			[[
			local original = ...
			local other = vim.api.nvim_create_buf(false, true)
			vim.keymap.set("i", "<F8>", function () vim.api.nvim_set_current_buf(other) end, { buf = original })
			vim.keymap.set("i", "<F8>", function () vim.api.nvim_set_current_buf(original) end, { buf = other })
			return other
		]], fixture.buffer
		)
		at_math_exit()
		input("<F8>", { buffer = fixture.other, mode = "i", text = "" })
		input("<F8>", { text = [[\(x\)]], mode = "i" })
		type_text("a", [[\(x\) a]])
		equal("other buffer remains empty", text(fixture.other), "")
		fixture.expected = [[\(x\) a]]
	end)

	with_buffer("undo and redo preserve the inserted space", function ()
		at_math_exit()
		type_text("<C-g>ua", [[\(x\) a]])
		normal_mode()
		input("u", { text = [[\(x\)]], mode = "n" })
		input("<C-r>", { text = [[\(x\) a]], mode = "n" })
		input("A", { mode = "i", events = { "InsertEnter" } })
		type_text("b", [[\(x\) ab]])
		fixture.expected = [[\(x\) ab]]
	end)

	local accepted, err = pcall(with_buffer, "displayed autocmd error is rejected", function ()
		execute(
			[[
			vim.api.nvim_create_autocmd("InsertEnter", {
				buf = ...,
				once = true,
				callback = function () error("INTEGRATION INJECTED INSERTENTER ERROR") end
			})
		]], fixture.buffer
		)
		input("i", { mode = "i", events = { "InsertEnter" } })
		fixture.expected = ""
	end)
	equal("displayed autocmd error fails the scenario", accepted, false)
	equal(
		"failure includes the displayed error", tostring(err):find("INTEGRATION INJECTED INSERTENTER ERROR", 1, true) ~= nil,
		true
	)
	request("nvim_command", "messages clear")
	scenarios = scenarios + 1
end

-- Inputs are separated by assertions on their effects and the editor events.
-- One synchronous feedkeys batch can skip CursorMovedI/TextChangedI between keys.
local ok, err = xpcall(run, debug.traceback)
pcall(request, "nvim_command", "qa!")
if vim.fn.jobwait({ editor }, 1000)[1] == -1 then
	vim.fn.jobstop(editor)
end
if not ok then
	io.stderr:write(err .. "\n")
	if #stderr > 0 then
		io.stderr:write(table.concat(stderr, "\n") .. "\n")
	end
	os.exit(1)
end
print(("Passed %d real-input integration scenarios (%d input stages, %d checks)"):format(scenarios, steps, checks))
