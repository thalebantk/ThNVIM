-- indent-blankline -- indent guides, drawn on blank lines too.
--
-- The guides were first done with 'listchars' (tab:│ ), which needs no plugin
-- at all and works because the C and assembly configs indent with real tabs:
-- the bar is the tab itself being rendered. What that cannot do is draw a line
-- where no character exists, so every blank line inside a block punched a hole
-- in the run. Filling those takes virtual text, which is this plugin.
--
-- It owns the guides outright now: the ftplugins are back to rendering tabs as
-- plain blanks, since a bar in 'listchars' would draw a second one underneath
-- ibl's on every line that is not blank.
--
-- Guides are derived from indentation alone, so .S and .asm are covered as
-- well as C -- unlike anything treesitter-driven, which has no parser for
-- either of them.
return {
	{
		"lukas-reineke/indent-blankline.nvim",
		-- The Lua module is "ibl", which does not match the repo name, so
		-- lazy.nvim has to be told which one to call setup() on.
		main = "ibl",
		-- BufNewFile as well as BufReadPost: guides should be there in a
		-- file being written from scratch, not only in one read off disk.
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			-- The same bar the listchars version drew.
			--
			-- tab_char has to be spelled out. Left alone it defaults to
			-- whatever 'listchars' uses for tab, which the ftplugins set to
			-- blanks -- so tab-indented buffers, meaning all of the C and
			-- assembly ones, drew their guides in spaces and showed nothing
			-- at all. Only space-indented Python looked right.
			indent = { char = "│", tab_char = "│" },
			-- Highlight the guide of the block the cursor is inside, so
			-- the enclosing scope reads differently from the levels around
			-- it.
			--
			-- This is the one part of ibl that needs a treesitter parser:
			-- it asks treesitter which node the cursor is in rather than
			-- working off indentation like the guides do. Neovim ships a C
			-- parser, so kernel C -- where the nesting actually is -- works.
			-- There is no parser for asm or nasm and none is coming, so
			-- assembly keeps plain guides; flat label-and-instruction code
			-- has little nesting to trace. Python leans on the parser in
			-- site/parser, which nothing here installs or maintains.
			--
			-- show_start/show_end underline the first and last line of the
			-- scope. That collides with the matchparen underline set in
			-- init.lua, which is already marking the enclosing braces, so
			-- only the bar is kept.
			scope = {
				enabled = true,
				show_start = false,
				show_end = false,
			},
		},
	},
}
