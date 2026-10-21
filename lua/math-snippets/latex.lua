local api = vim.api
local ts = vim.treesitter
local mkcond = require("luasnip.extras.conditions").make_condition

-- Match name families with Lua patterns unless explicitly anchored.
---@param ... string
---@return fun(value: any): boolean
local function matcher(...)
	local patterns = { ... }
	return function (value)
		if type(value) ~= "string" then
			return false
		end
		for _, pattern in ipairs(patterns) do
			if value:find(pattern) then
				return true
			end
		end
		return false
	end
end

local MATH_NODES = matcher("equation", "formula", "^math_environment$")

-- Name families accepting alignment tabs (&), plus the exact name split.
local ALIGN_ENVS = matcher("align", "array", "matrix", "case", "^split$")
-- Additional math families; gather and multline do not accept alignment tabs.
local MATH_ENVS = matcher("math", "equation", "multline", "gather", "tikzcd")
local BULLET_ENVS = matcher("itemize", "enumerate", "description")
-- Argument layouts are known only for these exact environment names.
local ARGUMENT_ENVS = { array = true, alignat = true, alignedat = true }
-- Keep boxed in math, and do not confuse short unit commands with sin, etc.
local TEXT_COMMANDS = matcher("text", "emph", "box$", "operatorname", "tag", "^SI$", "^si$", "^qty$", "^unit$", "^num$")
-- zref commands used by this collection are generic_command in the grammar.
local OPAQUE_COMMANDS = matcher("^z.*label", "^z.*ref")
local OPAQUE_NODES = matcher("comment", "code", "label", "verbatim", "listing", "minted", "asy", "sage", "uri", "path")

-- Memoize the finite node vocabulary, including misses; never cache user names.
---@type table<string, { math: boolean, opaque: boolean } | false>
local NODE_TYPES = setmetatable({}, {
	__index = function (types, kind)
		local math_node, opaque = MATH_NODES(kind), OPAQUE_NODES(kind)
		local relevant = math_node or opaque
			or kind == "generic_environment" or kind == "generic_command"
			or kind == "text_mode" or kind == "begin"
			or kind == "end" or kind == "citation"
			or kind == "$$"
		local flags = relevant and { math = math_node, opaque = opaque } or false
		types[kind] = flags
		return flags
	end
})

---@param node TSNode
---@param name string
---@return TSNode?
local function field(node, name)
	-- field() scans all children; stop at the first match in large environments.
	for child, field_name in node:iter_children() do
		if field_name == name then
			return child
		end
	end
end

---@param node  TSNode
---@param bufnr integer
---@return string?
local function environment_name(node, bufnr)
	local begin = field(node, "begin")
	local name = begin and field(begin, "name")
	if name then
		-- Read only the name, not the text of the entire environment.
		local text = ts.get_node_text(name, bufnr):match("^%{%s*([^}%s]+)%s*%}$")
		return text and (text:gsub("%*$", ""))
	end
end

---@param node  TSNode
---@param bufnr integer
---@return string?
local function command_name(node, bufnr)
	local command = field(node, "command")
	if command then
		return (ts.get_node_text(command, bufnr):gsub("^\\", ""):gsub("%*$", ""))
	end
end

-- A real closer ends scope; missing closers keep unfinished formulas in scope.
---@param node TSNode
---@param row  integer
---@param col  integer
---@param kind string?
---@return boolean
local function in_scope(node, row, col, kind)
	local start_row, start_col, end_row, end_col = node:range()
	-- At column zero the lookup uses the character to the right of the cursor.
	-- Inserting before an opener/comment must not enter its scope prematurely.
	if row < start_row or (row == start_row and col <= start_col) then
		return false
	end
	if row < end_row or (row == end_row and col < end_col) then
		return true
	end
	if row ~= end_row or col ~= end_col then
		return false
	end
	kind = kind or node:type()
	if kind == "line_comment" or kind == "comment" or kind == "source_code" then
		return true
	end
	local last = node:child(node:child_count() - 1)
	while last do
		if last:missing() then
			return true
		end
		last = last:child(last:child_count() - 1)
	end
	return false
end

---@class math_snippets.Context
---@field math    boolean
---@field align   boolean
---@field bullets boolean
---@field tikzcd  boolean

local EMPTY = { math = false, align = false, bullets = false, tikzcd = false }

---@class math_snippets.Scope
---@field math_mode        boolean?  nil until a mode switch is found
---@field math_environment string?   Environment establishing the nearest math mode
---@field environments     string[]? Enclosing environments, nearest first

---@param node      TSNode
---@param kind      string
---@param math_node boolean
---@param env       string?
---@param command   string | false | nil
---@param row       integer
---@param col       integer
---@return boolean?
local function node_math_mode(node, kind, math_node, env, command, row, col)
	-- textcolor/textwidth and the numbering wrapper subequations preserve mode.
	if kind == "text_mode" or (command and command ~= "textcolor" and command ~= "textwidth" and TEXT_COMMANDS(command)) then
		return false
	end
	if math_node or ALIGN_ENVS(env) or (env and env ~= "subequations" and MATH_ENVS(env)) or command == "ensuremath" then
		return true
	end
	-- An empty $|$ pair is lexed as one $$ token rather than inline_formula.
	if kind == "$$" then
		local start_row, start_col = node:start()
		if row == start_row and col == start_col + 1 then
			return true
		end
	end
end

---@param scope math_snippets.Scope
---@return boolean
local function in_math(scope)
	return scope.math_mode == true
end

---@param scope math_snippets.Scope
---@return boolean
local function in_align(scope)
	-- Explicit math nested inside an alignment establishes its own scope.
	return in_math(scope) and ALIGN_ENVS(scope.math_environment)
end

---@param scope math_snippets.Scope
---@return boolean
local function in_bullets(scope)
	if not in_math(scope) and scope.environments then
		for _, env in ipairs(scope.environments) do
			if BULLET_ENVS(env) then
				return true
			end
		end
	end
	return false
end

---@param scope math_snippets.Scope
---@return boolean
local function in_tikzcd(scope)
	return in_math(scope) and scope.math_environment == "tikzcd"
end

---@param node  TSNode?
---@param bufnr integer
---@param row   integer
---@param col   integer
---@return math_snippets.Scope? nil in an excluded region
local function scan_scope(node, bufnr, row, col)
	-- nil: no mode found yet; false: text; true: math.
	---@type boolean?
	local math_mode
	---@type string?
	local math_environment
	---@type string[]?
	local environments
	---@type TSNode?
	local child
	while node do
		local kind = node:type()
		local flags = NODE_TYPES[kind]
		if flags and in_scope(node, row, col, kind) then
			if flags.opaque then
				return nil
			end
			if kind == "begin" or kind == "end" or kind == "citation" then
				-- Only explicit math in an optional title/note survives this boundary.
				local in_note = math_mode and child
					and (child == field(node, "options") or child == field(node, "prenote") or child == field(node, "postnote"))
				if not in_note then
					return nil
				end
			end
			local env
			if kind == "math_environment" or kind == "generic_environment" then
				env = environment_name(node, bufnr)
				-- Column specifications/counts are not math content.
				if ARGUMENT_ENVS[env] and child and child == node:named_child(1) and child:type() == "curly_group"
					and in_scope(child, row, col) then
					return nil
				end
				if env then
					environments = environments or {}
					environments[#environments + 1] = env
				end
			end
			local command = kind == "generic_command" and command_name(node, bufnr)
			if command and OPAQUE_COMMANDS(command) then
				return nil
			end
			-- The nearest mode switch wins: text inside math, and math inside text.
			if math_mode == nil then
				math_mode = node_math_mode(node, kind, flags.math, env, command, row, col)
				if math_mode then
					math_environment = env
				end
			end
		end
		child, node = node, node:parent()
	end
	return { math_mode = math_mode, math_environment = math_environment, environments = environments }
end

---@param node  TSNode?
---@param bufnr integer
---@param row   integer
---@param col   integer
---@return math_snippets.Context
local function classify(node, bufnr, row, col)
	local scope = scan_scope(node, bufnr, row, col)
	if not scope then
		return EMPTY
	end
	return { math = in_math(scope), align = in_align(scope), bullets = in_bullets(scope), tikzcd = in_tikzcd(scope) }
end

---@param parser vim.treesitter.LanguageTree
---@param bufnr  integer
---@param row    integer
---@param col    integer
---@param range  [integer, integer]
---@return math_snippets.Context
local function parse_context(parser, bufnr, row, col, range)
	-- Parse synchronously without a highlighter; limit injections to the cursor line.
	parser:parse(range)
	local left = math.max(col - 1, 0)
	local point = { row, left, row, left }
	local language_tree = parser:language_for_range(point)
	local node = language_tree:node_for_range(point, { ignore_injections = true })
	-- At column zero, inserting before an injected comment belongs to its
	-- parent language. Do not mistake the right-hand injection for context.
	while col == 0 and node and language_tree:lang() ~= "latex" do
		local parent = language_tree:parent()
		if not parent then
			break
		end
		local start_row, start_col = node:tree():root():start()
		if start_row ~= row or start_col ~= col then
			break
		end
		language_tree = parent
		node = language_tree:node_for_range(point, { ignore_injections = true })
	end
	if language_tree:lang() ~= "latex" then
		return EMPTY
	end
	return classify(node, bufnr, row, col)
end

-- Share one result across conditions at the same insertion point; no cleanup needed.
---@class math_snippets.ContextCache
---@field bufnr   integer
---@field tick    integer
---@field row     integer
---@field col     integer
---@field parser  vim.treesitter.LanguageTree
---@field range   [integer, integer]
---@field context math_snippets.Context

---@type math_snippets.ContextCache?
local cache

---@return math_snippets.Context
local function get_context()
	local bufnr = api.nvim_get_current_buf()
	---@type [integer, integer]
	local cursor = api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local tick = api.nvim_buf_get_changedtick(bufnr)
	-- Let the buffer filetype choose the root parser so Markdown injections work.
	local lang = ts.language.get_lang(api.nvim_get_option_value("filetype", { buf = bufnr }))
	-- TeX filetype aliases may not be registered when using standalone parsers.
	if lang == "tex" or lang == "plaintex" then
		lang = "latex"
	end
	local parser = ts.get_parser(bufnr, lang)
	if not parser then
		return EMPTY
	end
	if cache and cache.bufnr == bufnr and cache.tick == tick and cache.row == row and cache.col == col
		and cache.parser == parser and parser:is_valid(false, cache.range) then
		return cache.context
	end

	local range = { row, row + 1 }
	local parsed, context = pcall(parse_context, parser, bufnr, row, col, range)
	if not parsed then
		-- Do not cache failures: a parser/query can become available without an edit.
		return EMPTY
	end
	cache = { bufnr = bufnr, tick = tick, row = row, col = col, parser = parser, range = range, context = context }
	return context
end

-- Preserve the public complement semantics, including buffers without a parser.
return {
	in_math = mkcond(function () return get_context().math end),
	in_text = mkcond(function () return not get_context().math end),
	in_align = mkcond(function () return get_context().align end),
	in_bullets = mkcond(function () return get_context().bullets end),
	in_tikzcd = mkcond(function () return get_context().tikzcd end)
}
