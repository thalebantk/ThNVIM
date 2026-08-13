-- asm-lsp -- assembly language server
--
-- Resolved by vim.lsp.enable("asm_lsp") in init.lua. Requires the asm-lsp
-- binary; install.sh fetches the prebuilt release into ~/.local/bin.
--
-- Instruction/register documentation on hover and completion come from the
-- server, so blink's "lsp" source picks them up with no extra wiring.

-- Same pattern as clangd: advertise blink's completion capabilities, but keep
-- working with stock ones if blink is missing.
local ok, blink = pcall(require, "blink.cmp")
local capabilities = ok and blink.get_lsp_capabilities() or nil

return {
	cmd = { "asm-lsp" },
	-- Neovim detects .S, .s and .asm all as "asm"; the others are listed for
	-- configs that set a more specific filetype.
	filetypes = { "asm", "nasm", "vmasm" },
	-- .asm-lsp.toml selects the assembler and instruction set for a project
	-- (gas/x86-64 for the kernel). Without one the server falls back to its
	-- own defaults, so .git is enough to anchor a root.
	root_markers = { ".asm-lsp.toml", "compile_commands.json", ".git" },
	capabilities = capabilities,
}
