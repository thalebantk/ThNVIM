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

-- asm-lsp 0.10.1 always produces its diagnostics with a GAS assembler. The
-- .asm-lsp.toml settings (assembler, compiler, even diagnostics = false) are
-- all ignored for this -- verified against the real binary. On NASM sources
-- that means every line is flagged wrong:
--   error: invalid instruction mnemonic 'bits'
--   error: unknown use of instruction mnemonic without a size suffix
--
-- The hover and completion documentation is good and worth keeping, so drop
-- only the diagnostics, and only for NASM buffers. GAS .s/.S files, where the
-- diagnostics are correct, keep theirs.
--
-- Done at the handler rather than with vim.diagnostic.enable(false): the
-- server can publish before LspAttach runs, and marks already rendered are
-- not retracted by disabling afterwards.
local function drop_nasm_diagnostics(err, result, ctx, config)
	if result and result.uri then
		local bufnr = vim.uri_to_bufnr(result.uri)
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "nasm" then
			return
		end
	end
	return vim.lsp.handlers["textDocument/publishDiagnostics"](err, result, ctx, config)
end

return {
	cmd = { "asm-lsp" },
	handlers = {
		["textDocument/publishDiagnostics"] = drop_nasm_diagnostics,
	},
	-- Neovim detects .S, .s and .asm all as "asm"; the others are listed for
	-- configs that set a more specific filetype.
	filetypes = { "asm", "nasm", "vmasm" },
	-- .asm-lsp.toml selects the assembler and instruction set for a project
	-- (gas/x86-64 for the kernel). Without one the server falls back to its
	-- own defaults, so .git is enough to anchor a root.
	root_markers = { ".asm-lsp.toml", "compile_commands.json", ".git" },
	capabilities = capabilities,
}
