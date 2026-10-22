# nvim-math-snippets

A [LuaSnip][luasnip] collection for TeX, Markdown, Python, Git commits, and TODO comments.

Targets Neovim 0.13 and LuaSnip 2.5.

Example (with [lazy.nvim][lazy]):

```lua
{
    "L3MON4D3/LuaSnip",
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

These snippets do not require `jsregexp`. The `eqref` snippet opens LSP completion
when `blink.cmp` is available; Blink is optional.

Visual-selection snippets use LuaSnip's `LS_SELECT_RAW`. Configure
`cut_selection_keys` in LuaSnip to choose the visual-mode mapping that stores the
selection for the next snippet.

## TeX snippet organization

The files in `luasnippets/tex/` are grouped by use:

| File | Contents |
| --- | --- |
| [structure.lua](luasnippets/tex/structure.lua) | Headings, theorem/proof environments, lists, Beamer, equations, matrices, cases, and diagram blocks |
| [text.lua](luasnippets/tex/text.lua) | Prose abbreviations, text styles, paragraphs, labels, citations, and references |
| [symbols.lua](luasnippets/tex/symbols.lua) | Greek letters, relations, named operators, arrows, subscripts, and superscripts |
| [expressions.lua](luasnippets/tex/expressions.lua) | Fractions, limits, sums/products, sequences, cohomology, delimiters, and commands around selections or preceding expressions |
| [inline_math.lua](luasnippets/tex/inline_math.lua) | Inline math, automatic wrapping of variables, and spacing after math |

The grouping also keeps shared imports together: `expressions.lua` owns the
visual-selection snippets, while `inline_math.lua` owns the whitespace trigger
engine and spacing callbacks. Imports are grouped at each file's top; optional
Blink completion is loaded only when entering a reference.

LuaSnip loads these files directly. Shared context detection lives in
`lua/math-snippets/`; the visual-selection helper is local to `expressions.lua`.
Command guards check for an existing backslash before checking math context.

## General conditions

`require("math-snippets.conditions")` provides conditions shared by filetypes:

| Condition | When it matches |
| --- | --- |
| `in_comments` | A Tree-sitter `comment` or `comment.*` capture immediately before the cursor; requires active highlighting |
| `on_top` | The cursor is in the first three lines |
| `show_line_begin` | The line before the cursor contains only indentation and at most one token; used for completion visibility |

`math-snippets.latex` contains the LaTeX-specific conditions, including Beamer
detection.

## LaTeX conditions

`require("math-snippets.latex")` provides composable LuaSnip conditions for the
cursor's LaTeX context:

| Condition    | When it matches                                                                              |
| ------------ | -------------------------------------------------------------------------------------------- |
| `in_math`    | Inline/display math, math environments, matrices, cases, `tikzcd`, and `\ensuremath{...}`    |
| `in_text`    | The complement of `in_math`, including when no parser is available                           |
| `in_align`   | Math in environment names containing `align`, `array`, `matrix`, or `case`, or named `split` |
| `in_bullets` | Text in environment names containing `itemize`, `enumerate`, or `description`                |
| `in_tikzcd`  | Math in a `tikzcd` environment                                                               |

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
No active highlighter is needed for the LaTeX conditions.
LaTeX injected into Markdown works when the host parsers and injection queries
are installed; the host buffer is never forced through the LaTeX parser.

Install the `latex` parser, and `markdown` / `markdown_inline` for Markdown math.
With the current [`nvim-treesitter` main branch][treesitter], parser installation uses:

```lua
require("nvim-treesitter").install({ "latex", "markdown", "markdown_inline" })
```

Follow that plugin's current Neovim requirements and run `:TSUpdate` when updating it.
Parsers installed by other managers also work with the appropriate Tree-sitter
filetype mappings. The module uses those mappings directly; TeX filetypes such as
`tex` and `plaintex` should already resolve to `latex` in your editor setup.

Missing/unavailable parsers safely return false for positive conditions.
Unexpected context-detection errors produce a warning once per distinct message;
positive conditions still return false, and subsequent calls retry detection.
Incomplete formulas are recognized when Tree-sitter recovers a math node with a
missing closer.
Malformed input that only produces `ERROR` nodes, such as an unmatched `\begin`,
may not be recognized until the surrounding syntax is completed.
Custom TeX macros and environments are not expanded; names follow these family
heuristics, which can be adjusted in `lua/math-snippets/latex.lua` if needed.

## Beamer snippets

`require("math-snippets.latex").in_beamer`, used by `bfr` and `bbl`, checks the
first `\documentclass` declaration in the current buffer. Detection uses the
LaTeX Tree-sitter parser, supports multiline
declarations and options, and ignores commented-out declarations. Results are
cached per buffer until its text changes or its parser is invalidated. Unloading
a buffer clears its cache entry. Unexpected detection failures warn once and
remain retryable without editing the buffer.

For an included file or a custom class, set a buffer-local override:

```lua
vim.b.math_snippets_beamer = true   -- Enable Beamer snippets
vim.b.math_snippets_beamer = false  -- Disable Beamer snippets
vim.b.math_snippets_beamer = nil    -- Use automatic detection
```

Without an override, an unavailable parser or absent class declaration returns
false. Automatic detection examines the current buffer and does not expand TeX
macros or resolve class inheritance.

## Tests

Run all correctness suites from the repository root with LuaSnip and the
LaTeX/Lua/Markdown parsers and queries installed:

```sh
nvim --headless -u NONE -i NONE -l tests/run.lua
```

The runner discovers the installed dependency roots, then passes explicit runtime
paths to fresh processes for the condition, snippet, and integration suites.
User configuration and plugin startup are disabled; state, cache, data, and logs
use a temporary directory. Dependencies are not downloaded. To select dependency
roots yourself, repeat `--runtimepath` for LuaSnip, parsers, and queries:

```sh
nvim --headless -u NONE -i NONE -l tests/run.lua \
  --runtimepath /path/to/LuaSnip \
  --runtimepath /path/to/parser-runtime \
  --runtimepath /path/to/query-runtime
```

Record or replay the dependency environment:

```sh
nvim --headless -u NONE -i NONE -l tests/run.lua --record /tmp/math-snippets-env.json
nvim --headless -u NONE -i NONE -l tests/run.lua --environment /tmp/math-snippets-env.json
```

The JSON report records the Neovim executable/version, LuaSnip source/version when
available, parser revisions/ABIs, runtime and Lua package paths, and SHA-256
fingerprints of dependency files. Replay uses the recorded executable and absolute
paths, which must still exist. It verifies file contents, symlink targets, and the
dependency inventory before running tests, including optional `jsregexp` artifacts
when installed. File fingerprints identify dependencies that lack version metadata.

The condition suite exercises real parser trees, nested contexts, cursor boundaries,
fresh edits, parser recovery, filetype and language-mapping changes, and Markdown
and custom LaTeX injections without starting a highlighter. The snippet suite checks
trigger guards, dynamic expansions, visual selections, and optional completion.
The integration suite types into an embedded Neovim editor, waits for actual input
events, and checks jumps, spacing, movement, buffer changes, and undo/redo. Input
failures produce a nonzero exit with the expected state and recent event trace.
An injected-error scenario also verifies that displayed Lua autocmd errors fail
the integration tests.

For an individual suite, replace `tests/run.lua` in the headless command with
`tests/latex.lua`, `tests/snippets.lua`, or `tests/integration.lua`, with the same
dependencies on `runtimepath`.

Benchmark TeX autosnippet matching, optionally comparing the working tree with a
Git revision:

```sh
nvim --headless -u NONE -i NONE -l tests/run.lua --benchmark
nvim --headless -u NONE -i NONE -l tests/run.lua --benchmark 8abb907
```

The benchmark reports separate workloads: unmatched prose ending in punctuation
or whitespace at 80, 500, and 2,000 bytes; successful literal and capture-based math
triggers with context classification; and a one-character edit followed by
reparsing and matching in a 900-line buffer with a highlighter attached. Expected
matches, captures, and parser invalidation are checked outside timed operations.
It reports medians from five warmed rounds, alternating version order when
comparing revisions. Expansion and redraw are excluded, and there are no timing
pass/fail thresholds. The edit workload includes buffer mutation and parsing
demanded by matching. Comparing an older revision that uses ECMA triggers requires
`jsregexp` for that revision. To run only timings, use `tests/benchmark.lua` directly
with an optional baseline revision.

## Acknowledgements

Inspired by

- [luasnip-latex-snippets.nvim](https://github.com/evesdropper/luasnip-latex-snippets.nvim)
- [latex-snippets](https://github.com/gillescastel/latex-snippets)

[lazy]: https://github.com/folke/lazy.nvim
[luasnip]: https://github.com/L3MON4D3/LuaSnip
[treesitter-api]: https://neovim.io/doc/user/treesitter/
[treesitter]: https://github.com/nvim-treesitter/nvim-treesitter/tree/main
