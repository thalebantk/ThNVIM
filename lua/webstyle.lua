-- Editor settings shared by the four Next.js filetypes: typescript,
-- typescriptreact, javascript and javascriptreact.
--
-- The C and assembly ftplugins each stand alone because they genuinely differ
-- -- comment syntax, indenting engine, column limit. These four differ in
-- nothing at all, so rather than four copies of the same block they are thin
-- wrappers over this module. It lives outside lua/plugins/ on purpose: lazy
-- imports that directory and would try to read this as a plugin spec.
--
-- The values track Prettier's defaults rather than personal preference.
-- Prettier rewrites these files on save, so anything set here that disagreed
-- with it would simply be undone the moment the buffer is written.

local M = {}

function M.apply()
	local o = vim.opt_local

	-- Prettier's tabWidth is 2 and it indents with spaces unless useTabs is
	-- set. This is the one corner of the config that is not the kernel's 8.
	o.expandtab = true
	o.shiftwidth = 2
	o.softtabstop = 2
	o.tabstop = 2

	-- Prettier's printWidth default is 80. It is a target Prettier wraps to,
	-- not a limit the typist enforces, so colorcolumn marks it while
	-- textwidth stays 0 -- otherwise Vim would break lines mid-edit and
	-- Prettier would immediately rejoin them.
	o.colorcolumn = "81"
	o.textwidth = 0

	-- No line wrapping, matching the rest of the config.
	o.wrap = false

	-- Same whitespace marks as everywhere else, though a tab in these files
	-- is a mistake rather than a style: Prettier writes spaces.
	o.list = true
	o.listchars = { tab = "  ", trail = "·", nbsp = "␣" }

	local undo = "setl et< sw< sts< ts< cc< tw< wrap< list< lcs<"
	vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
end

return M
