-- vim-matchup -- highlight the enclosing pair, not just the one under the
-- cursor.
--
-- Built-in matchparen only highlights when the cursor sits on a delimiter.
-- matchup adds "surround always": park the cursor anywhere inside a block and
-- the innermost enclosing {} or () stays highlighted. It supersedes the
-- built-in plugin, which it disables itself to avoid double highlighting.
return {
	{
		"andymass/vim-matchup",
		event = "BufReadPost",
		init = function()
			-- The setting that does the work: keep the surrounding
			-- delimiters highlighted while the cursor is between them.
			vim.g.matchup_matchparen_hi_surround_always = 1

			-- Do the highlighting on a short timer rather than on every
			-- cursor move. Surround-always has to search outwards for the
			-- enclosing pair, which is the expensive case on large files.
			vim.g.matchup_matchparen_deferred = 1
			vim.g.matchup_matchparen_deferred_show_delay = 50
			vim.g.matchup_matchparen_deferred_hide_delay = 50

			-- When the opening delimiter has scrolled off the top, show it
			-- in a popup instead of hijacking the statusline.
			vim.g.matchup_matchparen_offscreen = { method = "popup" }
		end,
	},
}
