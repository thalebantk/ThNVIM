-- NASM assembly (Intel syntax)
--
-- Neovim detects .asm as filetype "asm", which is the GAS/AT&T syntax file.
-- init.lua remaps .asm to "nasm" so this file and syntax/nasm.vim apply, which
-- is what recognises BITS/ORG, Intel operand order and the 16-bit registers.
--
-- The kernel .S conventions live in after/ftplugin/asm.lua; this is the NASM
-- counterpart, and the comment character is the main difference.

local o = vim.opt_local

-- Hard tabs, 8 columns, matching the C and GAS configs.
o.tabstop = 8
o.softtabstop = 8
o.shiftwidth = 8
o.expandtab = false

o.autoindent = true
o.smartindent = false
o.cindent = false

o.textwidth = 80
o.colorcolumn = "81"
o.wrap = false

-- NASM comments are ';' -- not the C-style /* */ used for cpp-processed .S.
o.commentstring = "; %s"
o.comments = ":;"

-- Same whitespace marks as the C and GAS configs.
o.list = true
o.listchars = { tab = "  ", trail = "·", nbsp = "␣" }

local undo = "setl ts< sts< sw< et< ai< si< cin< tw< cc< wrap< cms< com< list< lcs<"
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
