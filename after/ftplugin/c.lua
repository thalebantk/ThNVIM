-- C -- Linux kernel coding style
-- Reference: Documentation/process/coding-style.rst
--
-- Sourced after $VIMRUNTIME/ftplugin/c.vim, so the settings here are final.

local o = vim.opt_local

-- Indentation: hard tabs, 8 columns wide.
-- "Tabs are 8 characters, and thus indentations are also 8 characters."
o.tabstop = 8
o.softtabstop = 8
o.shiftwidth = 8
o.expandtab = false

-- C indenting.
--   :0  case labels flush with the switch, not indented a level
--   l1  case bodies aligned to the case label
--   t0  function return type at column 0
--   g0  C++ scope declarations at column 0 (no-op in C, kept for c/cpp parity)
--   (0  continuation lines aligned under an unclosed paren
o.cindent = true
o.cinoptions = ":0,l1,t0,g0,(0"

-- 80 column limit. 'textwidth' drives gq and comment formatting;
-- 'colorcolumn' marks the first column over the limit.
o.textwidth = 80
o.colorcolumn = "81"

-- No line wrapping: long lines run off the right edge instead of folding
-- into the next screen row.
o.wrap = false

-- Kernel comment style is /* ... */ with inner spaces.
o.commentstring = "/* %s */"

-- Trailing whitespace is a patch-check failure, so make it visible.
-- Tabs render as plain blanks; only the violations are marked.
o.list = true
o.listchars = { tab = "  ", trail = "·", nbsp = "␣" }

-- Restore everything above when the filetype changes, per ftplugin convention.
local undo = "setl ts< sts< sw< et< cin< cino< tw< cc< wrap< cms< list< lcs<"
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
