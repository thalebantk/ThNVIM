-- blink.cmp -- completion / auto-suggest
--
-- Loaded eagerly rather than on InsertEnter: lsp/clangd.lua asks blink for its
-- LSP capabilities when the server starts, which happens before the first
-- insert, and the startup cost is negligible.
return {
	{
		"saghen/blink.cmp",
		-- Release tag, so the prebuilt Rust fuzzy matcher is downloaded
		-- instead of requiring a local cargo build.
		version = "1.*",
		opts = {
			keymap = {
				-- <C-space> opens, <C-y> accepts, <C-n>/<C-p> cycle,
				-- <C-e> dismisses.
				preset = "default",

				-- vim-style motion through the menu. These are
				-- insert-mode maps, so bare j/k is not an option: it
				-- would swallow the letter whenever the menu happens to
				-- be open mid-word.
				--
				-- "fallback" keeps the original key behaviour when no
				-- menu is showing, so <C-k> still inserts digraphs and
				-- <C-j> still breaks the line.
				["<C-j>"] = { "select_next", "fallback" },
				["<C-k>"] = { "select_prev", "fallback" },
			},
			appearance = { nerd_font_variant = "mono" },
			completion = {
				-- The auto-suggest behaviour: menu appears as you type,
				-- docs after a short pause.
				menu = { auto_show = true },
				documentation = { auto_show = true, auto_show_delay_ms = 200 },
			},
			signature = { enabled = true },
			sources = { default = { "lsp", "path", "snippets", "buffer" } },
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		opts_extend = { "sources.default" },
	},
}
