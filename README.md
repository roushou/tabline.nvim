# tabline.nvim

A small, clickable **buffer tabline** for Neovim 0.10+. Listed buffers appear in
buffer-number order, with a filled accent for the current buffer and a marker
for unsaved changes.

- Keeps the current buffer visible as the window narrows or the buffer list grows.
- Distinguishes duplicate filenames with parent paths; clips labels in display
  cells, including wide and combining characters.
- Left-click to switch; middle-click to close an unmodified buffer.
- Optional file icons from `mini.icons`, `nvim-web-devicons`, or your own callback.
- No required dependencies, global Lua variables, Vimscript wrappers, or keymaps.
- Explicit, repeatable setup; `disable()` restores the options it still owns.

## Installation

Requires **Neovim 0.10 or newer**. This checkout can be used immediately:

```lua
vim.opt.runtimepath:prepend(vim.fn.expand("~/dev/tabline.nvim"))
require("tabline").setup()
```

Once published at `roushou/tabline.nvim`, install with **vim.pack** (Neovim 0.12+):

```lua
vim.pack.add({ "https://github.com/roushou/tabline.nvim" })
require("tabline").setup()
```

Or **lazy.nvim**:

```lua
{ "roushou/tabline.nvim", lazy = false, opts = {} }
```

Mouse clicks follow your existing `'mouse'` setting. To enable them:

```lua
vim.opt.mouse = "a"
```

Nerd Font glyphs are only needed if your icon provider uses them. Without an icon
provider, filenames and modified markers still work.

## Configuration

Every `setup(opts)` call starts from these defaults. Unknown options and invalid
values raise an error before changing the running tabline.

```lua
require("tabline").setup({
  max_visible = 15,       -- maximum buffers; screen width can reduce this further
  max_name_length = 32,   -- filename width in display cells before truncation
  padding = 2,           -- spaces on either side of each label
  icons = true,          -- automatic provider, false, or function(bufnr)
  modified = " ●",       -- includes the space before the marker
  separator = "▍",       -- tail on the current buffer's label
  overflow = "…",        -- indicator for buffers outside the visible range
  showtabline = 2,        -- 0, 1, 2, or false to preserve your option
})
```

`max_visible` and `max_name_length` accept integers from 1 to 10000; `padding`
accepts 0 to 10000. Text options must contain no control characters. Setting a
text option to `""` hides that element.

The renderer first limits the buffer count, then trims labels from the ends of
that range to fit `'columns'`. The current buffer stays visible. For a single
oversized label it drops padding and icons, then truncates the filename while
retaining the modified marker when space permits. Truncation may hide the
unique part of a duplicate filename. In an unlisted buffer (such as a picker),
the range begins at the first listed buffer and no label is highlighted.

`icons = true` tries `mini.icons`, then `nvim-web-devicons`; neither is required.
Providers loaded after setup are recognized on the next redraw. A custom callback
receives a buffer number and returns plain text or `nil`. Invalid results and
callback errors omit the icon. Callbacks run during rendering: keep them fast,
side-effect free, and avoid changing editor state.

```lua
require("tabline").setup({
  icons = function(bufnr)
    return vim.bo[bufnr].buftype == "terminal" and ">_" or nil
  end,
})
```

## Navigation and lifecycle

```lua
vim.keymap.set("n", "H", function()
  require("tabline").cycle(-1)
end, { desc = "Previous buffer" })
vim.keymap.set("n", "L", function()
  require("tabline").cycle(1)
end, { desc = "Next buffer" })

require("tabline").disable()
```

`cycle(direction)` accepts any finite integer and wraps around the listed buffer
list. Zero does nothing. From an unlisted buffer, positive directions select the
first buffer and negative directions select the last. Switching respects Neovim's
unsaved-buffer rules; rejected switches report a warning through `vim.notify`.

Middle-click never forces deletion; modified buffers remain open. Deletion uses
`nvim_buf_delete`, so windows displaying the buffer follow Neovim's normal buffer
deletion behavior. No window-layout preservation is added.

`require("tabline")` alone has no editor side effects. `setup()` installs the
expression and one autocmd group; `disable()` removes that group, cancels pending
redraws, and restores `'tabline'` and `'showtabline'` if they still have the values
installed by the plugin. Highlights remain available. Mouse settings and keymaps
are owned by your config. The plugin replaces the built-in tab-page labels with
buffers; `'showtabline' = 1` still follows the **tab-page count**, not buffer count.
GUIs using an external tabline may display their own widget instead.

## Highlights

| Group | Default |
| --- | --- |
| `TablineActive` | Accent background from `Directory` / `Function`; foreground from `StatusLine` / `Normal` background |
| `TablineActiveTail` | Accent foreground |
| `TablineOverflow` | Links to `Comment` |
| `TabLine` / `TabLineFill` | Existing colorscheme groups |

Linked groups are resolved when deriving colors. Defaults refresh on
`ColorScheme`; explicit user overrides are preserved. Define your colors after
loading a colorscheme, or in a `ColorScheme` autocmd, as usual:

```lua
vim.api.nvim_set_hl(0, "TablineActive", { fg = "#16161d", bg = "#7e9cd8", bold = true })
```

## Help and development

See `:help tabline.nvim` and `:checkhealth tabline`. For a runtimepath checkout,
run `:helptags ~/dev/tabline.nvim/doc` once to index its help.

```sh
stylua --check .
nvim --headless -i NONE -u tests/minimal_init.lua -l tests/run.lua
```

The dependency-free tests cover rendering, Unicode widths, literal format
characters, optional icons, navigation, safe deletion, option ownership,
configuration validation, and mouse dispatch in an attached Neovim UI.
CI targets Neovim 0.10.0, 0.11.0, 0.12.0, stable, and nightly.

Extracted from [roushou/neovim](https://github.com/roushou/neovim).
[MIT license](./LICENSE).
