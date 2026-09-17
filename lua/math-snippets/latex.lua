local M = {}

local api = vim.api
local ts = vim.treesitter
local mkcond = require("luasnip.extras.conditions").make_condition

-- Compile anchored Vim regexes once. Optional groups keep related names together
-- without prefix matches accidentally accepting names such as "alignment".
local function matcher(expression)
	local pattern = vim.regex("\\v\\C^(" .. expression .. ")$")
	return function(value)
		return type(value) == "string" and pattern:match_str(value) ~= nil
	end
end

local MATH_NODES = matcher("displayed_equation|inline_formula|math_environment")

-- These conditions guard snippets that insert an alignment tab (&).
local ALIGN_ENVS = matcher(
	"align(ed)?(at)?|flalign|(eqn)?array|split|([pbBvV]|small)?matrix|d?r?cases|dr?casesra"
)
-- Alignment environments are already math; only additional families go here.
-- gather, gathered and multline do not accept alignment tabs.
local MATH_ENVS = matcher("(display)?math|equation|multlined?|gather(ed)?|tikzcd")
local BULLET_ENVS = matcher("itemize|enumerate|description")
local ARGUMENT_ENVS = matcher("array|align(ed)?at")
local TEXT_COMMANDS = matcher(
	"text(normal|rm|sf|tt|up|it|sl|sc|bf|md)?|(short)?intertext|emph|([mhf]|make|frame|par)box"
		.. "|operatorname|tag|SI|si|qty|unit|num"
)
-- zref commands used by this collection are generic_command in the grammar.
local OPAQUE_COMMANDS = matcher("z(label|ref|[cC](page)?ref)")
local OPAQUE_NODES = matcher(
	"((line|block)_)?comment|source_code|label_(definition|reference(_range)?|number)|uri|path"
		.. "|(comment|verbatim|listing|minted|asy(def)?|pycode|luacode|sage(silent|block))_environment"
)

-- Node types are a finite vocabulary supplied by the parser. Cache both matches
-- and misses so ordinary text/groups need neither regexes nor scope checks.
-- Do not cache arbitrary command/environment names, which come from the buffer.
local NODE_TYPES = setmetatable({}, {
	__index = function(types, kind)
		local math_node, opaque = MATH_NODES(kind), OPAQUE_NODES(kind)
		local relevant = math_node or opaque or kind == "generic_environment" or kind == "generic_command"
			or kind == "text_mode" or kind == "begin" or kind == "end" or kind == "citation" or kind == "$$"
		local flags = relevant and { math = math_node, opaque = opaque } or false
		types[kind] = flags
		return flags
	end,
})

---@param node TSNode
---@param name string
---@return TSNode?
local function field(node, name)
	return node:field(name)[1]
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

-- The node immediately left of the insertion point includes closing delimiters.
-- Once a real closing delimiter has been passed, its scope no longer applies.
-- A missing delimiter is different: "$x|" is still inside an unfinished formula.
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

---@param node  TSNode?
---@param bufnr integer
---@param row   integer
---@param col   integer
---@return math_snippets.Context
local function classify(node, bufnr, row, col)
	local context = { math = false, align = false, bullets = false, tikzcd = false }
	local mode_found = false
	local child
	while node do
		local kind = node:type()
		local flags = NODE_TYPES[kind]
		if flags and in_scope(node, row, col, kind) then
			if flags.opaque then
				return EMPTY
			end
			if kind == "begin" or kind == "end" or kind == "citation" then
				-- Header names and citation keys are not math. Optional titles/notes
				-- can contain explicit formulas, whose mode was already found below.
				local in_note = child
					and (child == field(node, "options") or child == field(node, "prenote") or child == field(node, "postnote"))
				if not context.math or not in_note then
					return EMPTY
				end
			end
			local env, align
			if kind == "math_environment" or kind == "generic_environment" then
				env = environment_name(node, bufnr)
				-- These mandatory arguments specify columns/counts, not math content.
				if ARGUMENT_ENVS(env) and child and child == node:named_child(1) and child:type() == "curly_group"
					and in_scope(child, row, col) then
					return EMPTY
				end
				context.bullets = context.bullets or BULLET_ENVS(env)
				if not mode_found then
					align = ALIGN_ENVS(env)
				end
			end
			local command = kind == "generic_command" and command_name(node, bufnr)
			if OPAQUE_COMMANDS(command) then
				return EMPTY
			end
			-- The nearest mode switch wins: text inside math, and math inside text.
			if not mode_found then
				-- An empty $|$ pair is lexed as one $$ token rather than inline_formula.
				local empty_inline = false
				if kind == "$$" then
					local start_row, start_col = node:start()
					empty_inline = row == start_row and col == start_col + 1
				end
				if kind == "text_mode" or TEXT_COMMANDS(command) then
					mode_found = true
				elseif flags.math or align or MATH_ENVS(env) or command == "ensuremath" or empty_inline then
					mode_found = true
					context.math = true
					context.align = align == true
					context.tikzcd = env == "tikzcd"
				end
			end
		end
		child, node = node, node:parent()
	end
	context.bullets = context.bullets and not context.math
	return context
end

---@param parser vim.treesitter.LanguageTree
---@param bufnr integer
---@param row integer
---@param col integer
---@param range integer[]
---@return math_snippets.Context?
local function parse_context(parser, bufnr, row, col, range)
	-- Explicit synchronous parsing is required even without a highlighter.
	-- Restrict injection parsing to the cursor vicinity, regardless of trigger length.
	if not parser:parse(range) then
		return nil
	end
	local left = math.max(col - 1, 0)
	local point = { row, left, row, left }
	local language_tree = parser:language_for_range(point)
	local node = language_tree:node_for_range(point, { ignore_injections = true })
	-- At column zero, inserting before an injected comment belongs to its
	-- parent language. Do not mistake the right-hand injection for context.
	while col == 0 and node and language_tree:lang() ~= "latex" and language_tree:parent() do
		local start_row, start_col = node:tree():root():start()
		if start_row ~= row or start_col ~= col then
			break
		end
		language_tree = language_tree:parent()
		node = language_tree:node_for_range(point, { ignore_injections = true })
	end
	if language_tree:lang() ~= "latex" then
		return EMPTY
	end
	return classify(node, bufnr, row, col)
end

-- Keep a single result, not TSNodes or a per-buffer cache requiring cleanup.
-- All LuaSnip conditions at the same insertion point share the parse and walk.
local cache

---@return math_snippets.Context
local function get_context()
	local bufnr = api.nvim_get_current_buf()
	local cursor = api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local tick = api.nvim_buf_get_changedtick(bufnr)
	-- Let the buffer filetype choose the root parser so Markdown injections work.
	local lang = ts.language.get_lang(vim.bo[bufnr].filetype)
	-- TeX filetype aliases may not be registered when using standalone parsers.
	if lang == "tex" or lang == "plaintex" then
		lang = "latex"
	end
	-- Older Nvim throws for missing parsers; newer Nvim may return nil instead.
	local ok, parser = pcall(ts.get_parser, bufnr, lang)
	if not ok or not parser then
		return EMPTY
	end
	if cache and cache.bufnr == bufnr and cache.tick == tick and cache.row == row and cache.col == col
		and cache.parser == parser and parser:is_valid(false, cache.range) then
		return cache.context
	end

	local range = { row, row + 1 }
	local parsed, context = pcall(parse_context, parser, bufnr, row, col, range)
	if not parsed or not context then
		-- Do not cache failures: a parser/query can become available without an edit.
		return EMPTY
	end
	cache = { bufnr = bufnr, tick = tick, row = row, col = col, parser = parser, range = range, context = context }
	return context
end

M.in_math = mkcond(function ()
	return get_context().math
end)
-- Preserve the public complement semantics, including buffers without a parser.
M.in_text = mkcond(function ()
	return not get_context().math
end)
M.in_align = mkcond(function ()
	return get_context().align
end)
M.in_bullets = mkcond(function ()
	return get_context().bullets
end)
M.in_tikzcd = mkcond(function ()
	return get_context().tikzcd
end)

return M
