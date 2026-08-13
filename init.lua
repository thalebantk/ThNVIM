-- ThNVIM
--
-- Layout:
--   init.lua                  bootstrap and global settings
--   lua/plugins/<name>.lua    plugin specs, imported by lazy.nvim
--   lsp/<server>.lua          per-server LSP settings (native vim.lsp.config)
--   after/ftplugin/<ft>.lua   per-language settings
--
-- Per-language config lives in after/ftplugin/ rather than ftplugin/ so it is
-- sourced *after* $VIMRUNTIME/ftplugin/<ft>.vim and wins any conflict.

vim.cmd("filetype plugin indent on")

-- Remote plugin providers, none of which this config uses. Left enabled they
-- each cost a startup probe and report a :checkhealth warning for a missing
-- interpreter package. Re-enable one if a plugin ever needs it.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0

-- Set before lazy.nvim loads, so plugin <leader> mappings resolve to this.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- True colour, required by the colour scheme.
vim.o.termguicolors = true

-- Line numbers.
vim.o.number = true

-- Use the system clipboard as the unnamed register, so y/d/p share it with
-- everything else on the desktop. Neovim picks the backend itself: wl-copy on
-- Wayland, xclip/xsel on X11 -- install.sh installs both.
--
-- Set directly, not deferred: Neovim resolves the clipboard provider on first
-- use, so this costs nothing at startup (measured: no difference).
vim.o.clipboard = "unnamedplus"

-- Highlight the cursor's line number. cursorlineopt=number restricts the
-- highlight to the number column, so the code itself keeps its normal
-- background instead of being washed over.
vim.o.cursorline = true
vim.o.cursorlineopt = "number"

-- Matching pair highlighting is Neovim's built-in matchparen plugin: put the
-- cursor on a bracket and both halves are highlighted. It is on by default,
-- so there is nothing to install.
--
-- This keeps whatever colours the active scheme defines for MatchParen and
-- only adds emphasis on top, so it layers over moonfly rather than replacing
-- it. Re-applied on ColorScheme because loading a scheme resets highlights.
local function emphasise_matchparen()
	local hl = vim.api.nvim_get_hl(0, { name = "MatchParen", link = false })
	hl.bold = true
	hl.underline = true
	vim.api.nvim_set_hl(0, "MatchParen", hl)
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("ThNVIMMatchParen", { clear = true }),
	callback = emphasise_matchparen,
})
emphasise_matchparen()

-- ------------------------------------------------------------- plugins ----

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local out = vim.fn.system({
		"git", "clone", "--filter=blob:none", "--branch=stable",
		"https://github.com/folke/lazy.nvim.git", lazypath,
	})
	if vim.v.shell_error ~= 0 then
		error("failed to clone lazy.nvim:\n" .. out)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = { { import = "plugins" } },
	change_detection = { notify = false },
	-- No plugin here needs luarocks. Without this, lazy bootstraps hererocks
	-- and reports it as a health error when that fails.
	rocks = { enabled = false },
})

-- ----------------------------------------------------------------- lsp ----

-- Settings for each server live in lsp/<server>.lua and are resolved by
-- Neovim's native LSP loader when a matching filetype is opened.
vim.lsp.enable({ "clangd", "asm_lsp", "pyright" })

-- Diagnostics stay as they are -- sign column letter plus underline, no inline
-- text. The message is shown on demand instead, by <leader>e.
vim.diagnostic.config({
	-- Errors win over warnings on a line that has both.
	severity_sort = true,
	-- Settings for the popup that <leader>e opens.
	float = {
		border = "rounded",
		-- Say which server reported it, and drop the "Diagnostics:" title.
		source = true,
		header = "",
		prefix = "",
	},
})

-- Show why the line under the cursor is marked. Press it twice to move the
-- cursor into the popup, then q or <Esc> to close.
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, {
	desc = "Show diagnostic message",
})
