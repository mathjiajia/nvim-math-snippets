local snips = {}

local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local pos = require("math-snippets.position")

snips = {
	s(
		{ trig = "env", name = "python3 environment", desc = "Declare py3 environment" },
		{ t({ "#!/usr/bin/env python3", "" }) },
		{
			condition = pos.on_top * expand_line_begin,
			show_condition = pos.on_top * pos.show_line_begin,
		}
	),
}

return snips
