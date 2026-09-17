# nvim-math-snippets

A [LuaSnip][luasnip] collection for TeX, Markdown, Python, Git commits, and TODO comments.

Example (with [lazy.nvim][lazy]):

```lua
{
    "L3MON4D3/LuaSnip",
    build = "make install_jsregexp",
    dependencies = { "mathjiajia/nvim-math-snippets" },
    config = function()
        require("luasnip").setup({
            update_events = "TextChanged,TextChangedI",
            enable_autosnippets = true,
        })
        require("luasnip.loaders.from_lua").lazy_load({})
        -- other configuration
    end,
}
```

`jsregexp` enables the ECMAScript triggers used by the TeX snippets. The `eqref`
snippet opens LSP completion when `blink.cmp` is available; Blink is optional.

## LaTeX conditions

`require("math-snippets.latex")` provides composable LuaSnip conditions:

| Condition | When it matches |
| --- | --- |
| `in_math` | Inline/display math, math environments, matrices, cases, `tikzcd`, and `\ensuremath{...}` |
| `in_text` | The complement of `in_math`, including when no parser is available |
| `in_align` | Math in environment names containing `align`, `array`, `matrix`, or `case`, or named `split` |
| `in_bullets` | Text in environment names containing `itemize`, `enumerate`, or `description` |
| `in_tikzcd` | Math in a `tikzcd` environment |

The nearest math/text scope takes precedence: `\text{...}` disables math snippets,
while explicit math nested inside it enables them again.
Command names containing `text`, `emph`, `operatorname`, or `tag`, or ending in
`box`, disable math snippets, as do the exact commands `SI`, `si`, `qty`, `unit`,
and `num`.
`textcolor` and `textwidth` preserve the surrounding mode; `boxed` remains math.
Comments, verbatim/code regions, labels (including `\zlabel` / `\zcref`), citation
keys, paths, and environment names disable the positive conditions.
Array column specifications and `alignat` / `alignedat` column counts are excluded.
Explicit math in theorem titles and citation notes is supported.
`in_text` remains a complement, not a test for prose: it can be true in these regions.

Environment names may span lines, and starred and custom variants in these name
families are recognized. Other math environment names match `math`, `equation`,
`multline`, `gather`, or `tikzcd`.
The numbering wrapper `subequations` does not enable math by itself.
`gather`, `gathered`, and `multline` are math but do not match `in_align`, because
the snippets using that condition insert `&`.
Closing a text argument resumes the enclosing math scope; closing a formula or
environment leaves its scope immediately.

Detection uses Neovim's native [Tree-sitter API][treesitter-api], with synchronous
parsing of the cursor line's injections and one shared result per buffer change
and cursor position.
No highlighter or `nvim-treesitter.configs` module is needed.
LaTeX injected into Markdown works when the host parsers and injection queries
are installed; the host buffer is never forced through the LaTeX parser.

Install the `latex` parser, and `markdown` / `markdown_inline` for Markdown math.
With the current [`nvim-treesitter` main branch][treesitter], parser installation uses:

```lua
require("nvim-treesitter").install({ "latex", "markdown", "markdown_inline" })
```

Follow that plugin's current Neovim requirements and run `:TSUpdate` when updating it.
The conditions use native APIs available in Neovim 0.11 and later; the parser
installer can require a newer version.
Parsers installed by other managers also work.
`tex` and `plaintex` filetypes default to the `latex` parser unless explicitly mapped
to another language.

Missing/unavailable parsers safely return false for positive conditions.
Incomplete formulas are recognized when Tree-sitter recovers a math node with a
missing closer.
Malformed input that only produces `ERROR` nodes, such as an unmatched `\begin`,
may not be recognized until the surrounding syntax is completed.
Custom TeX macros and environments are not expanded; names follow these family
heuristics, which can be adjusted in `lua/math-snippets/latex.lua` if needed.

## Tests

With LuaSnip (including `jsregexp` for ECMAScript triggers), the LaTeX/Markdown
parsers, and their injection queries on `runtimepath`:

```sh
nvim --headless -u NONE -i NONE -l tests/latex.lua
nvim --headless -u NONE -i NONE -l tests/snippets.lua
```

The condition suite exercises real parser trees, nested contexts, cursor boundaries,
fresh edits, missing parsers, and Markdown injections without starting a highlighter.
The snippet suite checks loading, trigger guards, dynamic expansions, visual
selections, and optional completion integration.

## Acknowledgements

Inspired by

- [luasnip-latex-snippets.nvim](https://github.com/evesdropper/luasnip-latex-snippets.nvim)
- [latex-snippets](https://github.com/gillescastel/latex-snippets)

[lazy]: https://github.com/folke/lazy.nvim
[luasnip]: https://github.com/L3MON4D3/LuaSnip
[treesitter-api]: https://neovim.io/doc/user/treesitter/
[treesitter]: https://github.com/nvim-treesitter/nvim-treesitter/tree/main
