-- Python -- PEP 8
--
-- Sourced after $VIMRUNTIME/ftplugin/python.vim, which already sets a sane
-- commentstring (`# %s`), comments, include/define and suffixesadd. What it
-- does not set is indentation, which is what most of this file is for.
--
-- Note: $VIMRUNTIME/indent/python.vim installs 'indentexpr' (python#GetIndent)
-- and runs *after* this file. That is the correct Python indenter, so unlike
-- the C config nothing here tries to replace it.

local o = vim.opt_local

-- "Spaces are the preferred indentation method", 4 per level.
o.expandtab = true
o.shiftwidth = 4
o.softtabstop = 4
-- Deliberately 8, not 4: any literal tab that sneaks into a file renders at
-- double width and is immediately obvious. Python 3 rejects mixed tabs and
-- spaces outright, so making them visible is worth more than making them
-- blend in.
o.tabstop = 8

-- PEP 8 limits code to 79 columns; colorcolumn marks the first column over.
o.textwidth = 79
o.colorcolumn = "80"

-- No line wrapping, matching the C and assembly configs.
o.wrap = false

-- Trailing whitespace is a flake8/ruff error (W291/W293).
o.list = true
o.listchars = { tab = "  ", trail = "·", nbsp = "␣" }

-- Restore on filetype change. 'indentexpr' and friends are left out: they are
-- owned by indent/python.vim, which maintains its own b:undo_indent.
local undo = "setl et< sw< sts< ts< tw< cc< wrap< list< lcs<"
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
