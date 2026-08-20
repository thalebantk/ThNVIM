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

-- .asm is NASM by convention (bootloaders, DOS-era sources); Neovim's default
-- maps it to "asm", which is the GAS/AT&T syntax and mis-colours Intel operand
-- order and directives like BITS/ORG. .s and .S stay "asm" -- those really are
-- GAS, and that is what the kernel uses.
vim.filetype.add({
	extension = { asm = "nasm" },
})

-- Treesitter looks a parser up by language name, and the name defaults to the
-- filetype. There is no grammar called "typescriptreact" -- the TSX one is
-- "tsx" -- so vim.treesitter.get_parser() returns nil on every .tsx buffer
-- rather than erroring, and everything built on it silently does nothing. That
-- is what left indent-blankline's scope highlighting alive in C and dead in
-- Next.js pages. JSX is handled by the plain javascript grammar and needs the
-- same declaration.
--
-- nvim-treesitter would register these; this config does not use it, so they
-- are stated here. They are inert without the matching parsers installed.
vim.treesitter.language.register("tsx", "typescriptreact")
vim.treesitter.language.register("javascript", "javascriptreact")

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
local function emphasise_matches()
	local paren = vim.api.nvim_get_hl(0, { name = "MatchParen", link = false })
	paren.bold = true
	paren.underline = true
	vim.api.nvim_set_hl(0, "MatchParen", paren)

	-- matchup highlights matched *words* with MatchWord rather than
	-- MatchParen: if/endif, do/done, and the <div>...</div> tag pairs a
	-- Next.js page is mostly made of. moonfly leaves that group a coral
	-- foreground with no background at all, which is easy to lose on a .tsx
	-- line already full of colour, so give it the background MatchParen
	-- carries and keep the coral on top of it.
	local word = vim.api.nvim_get_hl(0, { name = "MatchWord", link = false })
	word.bg = paren.bg
	word.bold = true
	word.underline = true
	vim.api.nvim_set_hl(0, "MatchWord", word)
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("ThNVIMMatchHighlight", { clear = true }),
	callback = emphasise_matches,
})
emphasise_matches()

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
vim.lsp.enable({ "clangd", "asm_lsp", "pyright", "ts_ls", "tailwindcss" })

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
