-- clangd -- C/C++ language server
--
-- Resolved by vim.lsp.enable("clangd") in init.lua. Requires the clangd binary
-- (install.sh installs it: clang-tools-extra / clangd depending on the distro).

-- Advertise blink.cmp's completion capabilities to the server. pcall so a
-- missing or not-yet-built blink leaves LSP working with stock capabilities.
local ok, blink = pcall(require, "blink.cmp")
local capabilities = ok and blink.get_lsp_capabilities() or nil

return {
	cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
		-- The kernel includes headers deliberately; never let clangd add
		-- them on completion.
		"--header-insertion=never",
		"--completion-style=detailed",
		"--function-arg-placeholders",
		-- Formatting comes from the .clang-format in the tree being
		-- edited (the kernel ships one). Without it, do not invent a
		-- style that conflicts with the ftplugin settings.
		"--fallback-style=none",
	},
	filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
	-- compile_commands.json is what makes clangd accurate on a kernel tree;
	-- generate it with scripts/clang-tools/gen_compile_commands.py.
	root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
	capabilities = capabilities,
}
