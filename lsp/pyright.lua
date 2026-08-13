-- pyright -- Python language server
--
-- Resolved by vim.lsp.enable("pyright") in init.lua. Requires the
-- pyright-langserver binary; install.sh installs it with npm into ~/.local.
--
-- Note the command is pyright-langserver, not pyright: the latter is the
-- one-shot CLI type checker and does not speak LSP over stdio.

-- Same pattern as clangd and asm_lsp.
local ok, blink = pcall(require, "blink.cmp")
local capabilities = ok and blink.get_lsp_capabilities() or nil

return {
	cmd = { "pyright-langserver", "--stdio" },
	filetypes = { "python" },
	-- pyright resolves imports relative to the project root, so anchoring on
	-- the packaging files matters more here than for the C servers.
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"requirements.txt",
		"Pipfile",
		"pyrightconfig.json",
		".git",
	},
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				-- Only diagnose open files. "workspace" re-checks the whole
				-- tree on every change, which is painful on large projects.
				diagnosticMode = "openFilesOnly",
			},
		},
	},
	capabilities = capabilities,
}
