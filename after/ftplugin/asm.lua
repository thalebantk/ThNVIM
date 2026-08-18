-- Assembly -- Linux kernel coding style
--
-- Covers .S, .s and .asm, which Neovim all detects as filetype "asm".
--
-- Sourced after $VIMRUNTIME/ftplugin/asm.vim, which is NASM-oriented: it sets
-- `commentstring=; %s` and a NASM comment list. Kernel .S files are run
-- through the C preprocessor and use C comments, so both are replaced below.

local o = vim.opt_local

-- Indentation: hard tabs, 8 columns, same as the C side. Labels sit at column
-- 0 and instructions one tab in.
o.tabstop = 8
o.softtabstop = 8
o.shiftwidth = 8
o.expandtab = false

-- There is no indent/asm.vim in the runtime, so nothing sets 'indentexpr' and
-- indenting is manual. autoindent at least carries the current indent onto the
-- next line, which is what you want between instructions.
o.autoindent = true
-- Explicitly off: smartindent applies C heuristics (it indents after `{` and
-- shifts lines starting with `#` to column 0), which misfires on assembly.
o.smartindent = false
o.cindent = false

-- 80 column limit, marked at the first column over.
o.textwidth = 80
o.colorcolumn = "81"

-- No line wrapping, matching the C configuration.
o.wrap = false

-- Kernel assembly uses C comments, since .S goes through cpp.
o.commentstring = "/* %s */"
-- Recognise C block comments, // and # so that comment continuation and gq
-- behave. Kept in this order so /* */ wins for new comments.
o.comments = "s1:/*,mb:*,ex:*/,://,:#"

-- Trailing whitespace fails checkpatch here too. Tabs stay plain blanks; the
-- guides come from indent-blankline, as in after/ftplugin/c.lua.
o.list = true
o.listchars = { tab = "  ", trail = "·", nbsp = "␣" }

-- Restore everything above when the filetype changes, per ftplugin convention.
local undo = "setl ts< sts< sw< et< ai< si< cin< tw< cc< wrap< cms< com< list< lcs<"
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
