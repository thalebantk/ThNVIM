-- nvim-autopairs -- auto-close (), {}, [] and quotes.
--
-- Backspace over an empty pair removes both halves, and typing the closing
-- character skips over it instead of doubling it.
--
-- Highlighting of the matching pair under the cursor is not here: that is
-- Neovim's built-in matchparen, configured in init.lua.
return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		opts = {},
	},
}
