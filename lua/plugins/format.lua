-- conform.nvim -- format on save with Prettier, in Next.js projects only.
--
-- Two separate restrictions are at work here, and both are deliberate.
--
-- The first is by filetype: formatters_by_ft lists only the four web
-- filetypes, and conform does nothing at all for a filetype it has no
-- formatter for. C, assembly and Python are therefore untouched on save --
-- which matters most for kernel C, where reformatting a file would rewrite
-- lines the patch never meant to touch.
--
-- The second is by project: even in a .tsx buffer, format_on_save returns nil
-- unless the file sits inside a Next.js tree. Opening someone else's
-- TypeScript repo, or a stray .js script, will not silently rewrite it.
--
-- Prettier is called rather than the language server's own formatter, and
-- lsp/ts_ls.lua turns that formatter off so the two cannot both fire.
--
-- The project test is lua/nextjs.lua, shared with lsp/ts_ls.lua so the
-- server and the formatter cover exactly the same set of files.

return {
	{
		"stevearc/conform.nvim",
		-- Loaded on the first write rather than at startup. lazy.nvim
		-- re-emits the event once the plugin is in place, so the save that
		-- triggers the load is itself formatted.
		event = "BufWritePre",
		cmd = "ConformInfo",
		opts = {
			formatters_by_ft = {
				javascript = { "prettier" },
				javascriptreact = { "prettier" },
				typescript = { "prettier" },
				typescriptreact = { "prettier" },
			},
			format_on_save = function(bufnr)
				if not require("nextjs").is_project(bufnr) then
					return nil
				end
				-- lsp_format "never": Prettier is the only formatter, and
				-- falling back to the server's would reintroduce exactly
				-- the disagreement ts_ls.lua disables it to avoid.
				return { timeout_ms = 2000, lsp_format = "never" }
			end,
		},
	},
}
