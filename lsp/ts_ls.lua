-- typescript-language-server -- TypeScript and JavaScript, including the TSX
-- and JSX that Next.js pages and components are written in.
--
-- Resolved by vim.lsp.enable("ts_ls") in init.lua. Requires the
-- typescript-language-server binary; install.sh installs it with npm into
-- ~/.local along with the typescript package. Both are needed: tsserver is a
-- library shipped by typescript, and the language server drives it rather than
-- carrying its own copy, so installing the server alone leaves it unable to
-- start.

-- Same pattern as clangd, asm_lsp and pyright.
local ok, blink = pcall(require, "blink.cmp")
local capabilities = ok and blink.get_lsp_capabilities() or nil

return {
	cmd = { "typescript-language-server", "--stdio" },
	filetypes = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
	},
	-- Restricted to Next.js trees, the same restriction format-on-save uses.
	--
	-- root_dir is a function rather than a root_markers list because that is
	-- what makes the restriction possible: Neovim starts the server only once
	-- on_dir is called, so declining to call it is how a buffer is left with
	-- no server at all. Plain TypeScript and JavaScript projects therefore get
	-- no completion, no diagnostics and no go-to-definition -- that is the
	-- intent, not an oversight.
	--
	-- The Next.js root is also the right root to hand over: it is where
	-- tsconfig.json sits, which is what teaches the server the
	-- "@/components/..." aliases create-next-app writes. Without it every
	-- aliased import resolves to nothing and the whole file lights up red.
	root_dir = function(bufnr, on_dir)
		local root = require("nextjs").root(vim.api.nvim_buf_get_name(bufnr))
		if root then
			on_dir(root)
		end
	end,
	on_attach = function(client)
		-- Prettier owns formatting (lua/plugins/format.lua). The server
		-- offers its own, which disagrees with Prettier about quotes,
		-- semicolons and JSX wrapping, so switch it off rather than leave
		-- two formatters overwriting each other's output on save.
		client.server_capabilities.documentFormattingProvider = false
		client.server_capabilities.documentRangeFormattingProvider = false
	end,
	capabilities = capabilities,
}
