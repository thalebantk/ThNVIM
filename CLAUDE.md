# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ThNVIM is a personal Neovim configuration, not an application. There is no build
system, no test suite and no linter. The repo *is* the config: `install.sh`
symlinks it to `$XDG_CONFIG_HOME/nvim`, so an edit here is live at the next
`nvim` start.

The target workload is Linux kernel work — kernel C style, GAS `.S` and NASM
`.asm` — plus Python. Several decisions only make sense in that light (8-column
hard tabs, `--header-insertion=never` for clangd, `.asm` remapped to NASM).

## Commands

```bash
./install.sh                # symlink the repo to ~/.config/nvim, install deps, sync plugins
./install.sh --no-deps      # deploy config only, skip package installation
./install.sh --no-extras    # skip the tmux and Konsole config
./install.sh --copy         # copy instead of symlinking (edits then need redeploying)
```

```bash
nvim --headless "+Lazy! sync" +qa   # install/update plugins and rewrite lazy-lock.json
```

```bash
nvim --headless +qa                 # smoke test: any config error is printed here
```

Use `:checkhealth` inside an interactive `nvim` for provider/LSP diagnosis;
`:Lazy` for the plugin UI. `lazy-lock.json` is committed — a `sync` that changes
it is a deliberate dependency bump, so commit or revert it consciously.

## Layout and how the pieces resolve

- `init.lua` — global options, filetype overrides, lazy.nvim bootstrap,
  `vim.lsp.enable`, diagnostics. Anything not per-plugin, per-server or
  per-filetype belongs here.
- `lua/plugins/<name>.lua` — one plugin per file, returning a lazy.nvim spec
  table. `init.lua` imports the whole directory (`{ import = "plugins" }`), so a
  new file is picked up with no registration step.
- `lsp/<server>.lua` — server settings resolved by Neovim's *native* LSP loader
  (`vim.lsp.config`), not lspconfig. A file here is inert until its name is added
  to the `vim.lsp.enable({...})` list in `init.lua`.
- `after/ftplugin/<ft>.lua` — per-language settings. Deliberately `after/`, so
  they are sourced after `$VIMRUNTIME/ftplugin/<ft>.vim` and win any conflict.
- `tmux/tmux.conf`, `konsole/Moonfly.colorscheme` — terminal side, deployed by
  `install.sh`.

## Cross-file couplings worth knowing before editing

**Filetype split for assembly.** `init.lua` remaps `.asm` to filetype `nasm`
(Intel syntax); `.s`/`.S` stay `asm` (GAS, what the kernel uses). That single
`vim.filetype.add` is why there are two ftplugins:
`after/ftplugin/asm.lua` uses C comments (`.S` goes through cpp) and
`after/ftplugin/nasm.lua` uses `;`. Changing the mapping breaks both.

**LSP ↔ completion.** Each `lsp/*.lua` file pulls blink.cmp's capabilities via a
`pcall`, so a missing blink degrades to stock capabilities instead of erroring.
This is also why `lua/plugins/blink.lua` loads eagerly rather than on
`InsertEnter` — servers ask for capabilities before the first insert.

**asm-lsp diagnostics.** `lsp/asm_lsp.lua` overrides the
`textDocument/publishDiagnostics` handler to discard diagnostics for `nasm`
buffers only: asm-lsp always diagnoses with GAS regardless of its config, so
every NASM line is falsely flagged. Hover and completion are kept. Do not
"simplify" this to `vim.diagnostic.enable(false)` — the server can publish
before `LspAttach`, and marks already drawn are not retracted.

**Pair highlighting has two owners.** `init.lua` emphasises the built-in
matchparen highlight (re-applied on `ColorScheme`, since loading a scheme resets
highlights); `lua/plugins/matchup.lua` adds enclosing-pair highlighting and
disables the built-in itself. `lua/plugins/pairs.lua` is auto-*closing* only,
unrelated to highlighting.

**Indent guides read `listchars`.** `lua/plugins/indent.lua` owns the guides;
the ftplugins render tabs as plain blanks so nothing draws twice. The trap is
ibl's `indent.tab_char`, which *defaults to the `tab` value in `listchars`* — so
leaving it implicit makes every tab-indented buffer (all the C and assembly
ones) draw its guides in blanks and show nothing. It is set explicitly for that
reason; changing `listchars` in an ftplugin is not as isolated as it looks.

**tmux navigation is two halves.** `lua/plugins/tmux.lua` binds `<C-hjkl>` in
Neovim; `tmux/tmux.conf` needs the matching `is_vim` bindings or the keys stop
working the moment focus leaves Neovim. Change one, change the other. The tmux
config also sources moonfly's theme out of the plugin directory
(`~/.local/share/nvim/lazy/moonfly/extras/`), which is why `install.sh` syncs
plugins before deploying tmux.

## Conventions

Comments are prose explaining *why*, in the Linux-kernel block-comment style —
what a setting defends against, what breaks without it, what was measured or
verified. This is the dominant style throughout; match it rather than adding
label comments that restate the code. Every ftplugin ends by appending to
`vim.b.undo_ftplugin`.

Lua source uses hard tabs. `install.sh` uses hard tabs and is `set -euo pipefail`
with `info`/`ok`/`warn`/`die` helpers for all output — no bare `echo` for user
messages.
