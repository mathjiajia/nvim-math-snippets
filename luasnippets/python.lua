local expand_line_begin = require("luasnip.extras.conditions.expand").line_begin
local conditions = require("math-snippets.conditions")

return {
	s(
		{ trig = "env", name = "python3 environment", desc = "Declare py3 environment" },
		t({ "#!/usr/bin/env python3", "" }),
		{
			condition = conditions.on_top * expand_line_begin,
			show_condition = conditions.on_top * conditions.show_line_begin
		}
	)
}
