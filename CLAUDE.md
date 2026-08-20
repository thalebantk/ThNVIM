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
- `lua/<name>.lua` — plain modules, not plugin specs. Only `webstyle.lua` so
  far, shared by the four Next.js ftplugins. Do not put these in `lua/plugins/`;
  lazy imports that directory and would read them as specs.
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
unrelated to highlighting. The same `init.lua` function also styles `MatchWord`,
which is matchup's group for matched *words* and JSX tag pairs — a different
group from `MatchParen`, and one moonfly ships with no background.

**Treesitter language names are registered by hand.** `init.lua` maps
`typescriptreact` → `tsx` and `javascriptreact` → `javascript`. Without that,
`vim.treesitter.get_parser()` returns *nil* rather than erroring on those
buffers, so anything treesitter-backed — ibl's scope highlighting and
nvim-ts-autotag — silently does nothing there while working in C.
nvim-treesitter would register these; this config does not use it. The parsers
themselves live in `~/.local/share/nvim/site/parser/` and are *not* installed or
managed by this repo, so both features can disappear if that directory is
cleaned. Failure is silent in each case: `vim.treesitter.get_parser()` returns
nil, and the feature simply stops.

**Indent guides read `listchars`.** `lua/plugins/indent.lua` owns the guides;
the ftplugins render tabs as plain blanks so nothing draws twice. The trap is
ibl's `indent.tab_char`, which *defaults to the `tab` value in `listchars`* — so
leaving it implicit makes every tab-indented buffer (all the C and assembly
ones) draw its guides in blanks and show nothing. It is set explicitly for that
reason; changing `listchars` in an ftplugin is not as isolated as it looks.

**Format on save is doubly gated, on purpose.** `lua/plugins/format.lua` runs
Prettier, and it must never touch kernel C — reformatting would rewrite lines a
patch never meant to include. Two things prevent that: `formatters_by_ft` lists
only the four web filetypes (conform is a no-op for a filetype with no
formatter), and `format_on_save` additionally returns `nil` unless the file sits
in a Next.js tree, detected by `next.config.*` or a `next` dependency in
`package.json` and cached per directory. Widening either one widens what gets
rewritten on `:w`.

**Two servers on a .tsx buffer, gated the same way.** `lsp/ts_ls.lua` and
`lsp/tailwindcss.lua` both attach to TSX, and both use a `root_dir` *function*
rather than `root_markers` — Neovim starts a server only once `on_dir` is
called, so declining to call it is what leaves a buffer with no server. Both
route through `lua/nextjs.lua`, and tailwindcss adds a second condition of its
own (a `tailwind.config.*` or a `tailwindcss` dependency) so it does not start
in a Next.js app that has no Tailwind. A buffer can therefore legitimately have
two clients, one client, or none.

**One formatter, not two.** `lsp/ts_ls.lua` switches
`documentFormattingProvider` off in `on_attach` because the server formats
differently from Prettier; leaving both on means the two overwrite each other
depending on which finishes first. If Prettier is ever dropped, that override has
to go too or TS/JS ends up with no formatter at all.

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
