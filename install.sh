#!/usr/bin/env bash
#
# ThNVIM installer
#
# Installs Neovim, the external tools the config expects, deploys this repo to
# $XDG_CONFIG_HOME/nvim and bootstraps the plugin manager headlessly.
#
# Also deploys the matching terminal setup: tmux/tmux.conf (moonfly theme,
# true colour, vim-tmux-navigator bindings) and konsole/Moonfly.colorscheme.
#
# Usage: ./install.sh [options]
#   -l, --link       symlink the repo into place (default)
#   -c, --copy       copy the repo instead of symlinking
#   -n, --no-deps    skip package installation, only deploy the config
#   -L, --no-lsp     skip the language servers fetched outside the package
#                    manager (asm-lsp, pyright)
#   -e, --no-extras  skip the tmux and Konsole config, Neovim only
#   -f, --force      replace an existing config without prompting (a backup is
#                    still taken)
#   -h, --help       show this help
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"

TMUX_CONF="$HOME/.tmux.conf"
KONSOLE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/konsole"

MIN_NVIM_MAJOR=0
MIN_NVIM_MINOR=10

MODE="link"
INSTALL_DEPS=1
INSTALL_EXTRAS=1
INSTALL_LSP=1
FORCE=0

# ---------------------------------------------------------------- output ----

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'
	C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'
else
	C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""
fi

info()  { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf '%s  ok%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%serr%s  %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

usage() {
	# Print the header comment block (skipping the shebang) as the help text.
	awk 'NR > 2 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
	exit 0
}

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------ args ----

while [ $# -gt 0 ]; do
	case "$1" in
		-l|--link)    MODE="link" ;;
		-c|--copy)    MODE="copy" ;;
		-n|--no-deps) INSTALL_DEPS=0 ;;
		-L|--no-lsp)  INSTALL_LSP=0 ;;
		-e|--no-extras) INSTALL_EXTRAS=0 ;;
		-f|--force)   FORCE=1 ;;
		-h|--help)    usage ;;
		*)            die "unknown option: $1 (try --help)" ;;
	esac
	shift
done

# ------------------------------------------------------------ privileges ----

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
	if have sudo; then
		SUDO="sudo"
	elif have doas; then
		SUDO="doas"
	fi
fi

run_root() {
	if [ -n "$SUDO" ]; then
		$SUDO "$@"
	elif [ "$(id -u)" -eq 0 ]; then
		"$@"
	else
		die "need root to run: $* (install sudo, or re-run with --no-deps)"
	fi
}

# --------------------------------------------------------------- distro -----

detect_pm() {
	case "$(uname -s)" in
		Darwin)
			have brew && { echo "brew"; return; }
			die "Homebrew not found. Install it from https://brew.sh, then re-run."
			;;
	esac

	for pm in dnf apt-get pacman zypper apk xbps-install eopkg; do
		have "$pm" && { echo "$pm"; return; }
	done
	echo "unknown"
}

# Package names per manager. Neovim itself is handled separately so we can fall
# back to an upstream build when the distro ships an old version.
pkgs_for() {
	case "$1" in
		dnf)      echo "git curl unzip tar gzip gcc make cmake ripgrep fd-find python3-pip nodejs npm wl-clipboard xclip clang clang-tools-extra tmux nasm" ;;
		apt-get)  echo "git curl unzip tar gzip build-essential cmake ripgrep fd-find python3-pip python3-venv nodejs npm wl-clipboard xclip clang clangd tmux nasm" ;;
		pacman)   echo "git curl unzip tar gzip base-devel cmake ripgrep fd python-pip nodejs npm wl-clipboard xclip clang tmux nasm" ;;
		zypper)   echo "git curl unzip tar gzip gcc make cmake ripgrep fd python3-pip nodejs npm wl-clipboard xclip clang clang-tools tmux nasm" ;;
		apk)      echo "git curl unzip tar gzip build-base cmake ripgrep fd py3-pip nodejs npm xclip clang clang-extra-tools tmux nasm" ;;
		xbps-install) echo "git curl unzip tar gzip base-devel cmake ripgrep fd python3-pip nodejs npm wl-clipboard xclip clang clang-tools-extra tmux nasm" ;;
		eopkg)    echo "git curl unzip tar gzip gcc make cmake ripgrep fd python3-pip nodejs npm xclip llvm-clang tmux nasm" ;;
		brew)     echo "git curl unzip cmake ripgrep fd node llvm tmux nasm" ;;
	esac
}

install_packages() {
	local pm="$1"; shift
	local pkgs="$*"
	# shellcheck disable=SC2086  # word splitting of the package list is intended
	case "$pm" in
		dnf)          run_root dnf install -y $pkgs ;;
		apt-get)      run_root apt-get update -qq && run_root apt-get install -y $pkgs ;;
		pacman)       run_root pacman -Sy --needed --noconfirm $pkgs ;;
		zypper)       run_root zypper --non-interactive install $pkgs ;;
		apk)          run_root apk add --no-cache $pkgs ;;
		xbps-install) run_root xbps-install -Sy $pkgs ;;
		eopkg)        run_root eopkg install -y $pkgs ;;
		brew)         brew install $pkgs ;;
	esac
}

# --------------------------------------------------------------- neovim -----

nvim_version_ok() {
	have nvim || return 1
	local v major minor
	v="$(nvim --version | head -1 | sed 's/^NVIM v//; s/[-+].*//')"
	major="${v%%.*}"; minor="$(echo "$v" | cut -d. -f2)"
	[ "${major:-0}" -gt "$MIN_NVIM_MAJOR" ] && return 0
	[ "${major:-0}" -eq "$MIN_NVIM_MAJOR" ] && [ "${minor:-0}" -ge "$MIN_NVIM_MINOR" ]
}

# Upstream release tarball into ~/.local — used when the distro package is too
# old or when no supported package manager is present.
install_nvim_upstream() {
	local arch tarball url prefix="$HOME/.local"
	case "$(uname -m)" in
		x86_64|amd64) arch="x86_64" ;;
		aarch64|arm64) arch="arm64" ;;
		*) die "no upstream Neovim build for $(uname -m); install Neovim >= $MIN_NVIM_MAJOR.$MIN_NVIM_MINOR manually" ;;
	esac

	case "$(uname -s)" in
		Linux)  tarball="nvim-linux-${arch}.tar.gz" ;;
		Darwin) tarball="nvim-macos-${arch}.tar.gz" ;;
		*) die "unsupported platform: $(uname -s)" ;;
	esac

	url="https://github.com/neovim/neovim/releases/latest/download/${tarball}"
	info "installing Neovim from $url"

	local tmp
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' RETURN

	curl -fsSL "$url" -o "$tmp/$tarball" || die "download failed: $url"
	tar -xzf "$tmp/$tarball" -C "$tmp"

	local src
	src="$(find "$tmp" -maxdepth 1 -type d -name 'nvim-*' | head -1)"
	[ -n "$src" ] || die "unexpected tarball layout"

	mkdir -p "$prefix"
	cp -a "$src"/. "$prefix"/
	ok "Neovim installed to $prefix/bin/nvim"

	case ":$PATH:" in
		*":$prefix/bin:"*) ;;
		*) warn "$prefix/bin is not on your PATH — add it to your shell rc:"
		   printf '      export PATH="%s/bin:$PATH"\n' "$prefix" >&2 ;;
	esac
	export PATH="$prefix/bin:$PATH"
}

# -------------------------------------------------------------- asm-lsp -----

# The assembly language server. Not packaged by any distro, so take the
# prebuilt release binary; fall back to cargo where no build is published.
install_asm_lsp() {
	have asm-lsp && { ok "asm-lsp already installed"; return; }

	local prefix="$HOME/.local" tarball="" url arch os
	arch="$(uname -m)"; os="$(uname -s)"

	case "$os:$arch" in
		Linux:x86_64|Linux:amd64)   tarball="asm-lsp-x86_64-unknown-linux-gnu.tar.gz" ;;
		Darwin:arm64|Darwin:aarch64) tarball="asm-lsp-aarch64-apple-darwin.tar.gz" ;;
		Darwin:x86_64)              tarball="asm-lsp-x86_64-apple-darwin.tar.gz" ;;
	esac

	if [ -z "$tarball" ]; then
		# No published build for this platform (e.g. linux aarch64).
		if have cargo; then
			info "no prebuilt asm-lsp for $os/$arch; building with cargo"
			cargo install asm-lsp && { ok "asm-lsp installed via cargo"; return; }
		fi
		warn "no asm-lsp build for $os/$arch and cargo is unavailable; assembly LSP disabled"
		return
	fi

	url="https://github.com/bergercookie/asm-lsp/releases/latest/download/${tarball}"
	info "installing asm-lsp from $url"

	local tmp
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' RETURN

	if ! curl -fsSL "$url" -o "$tmp/$tarball"; then
		warn "asm-lsp download failed; assembly LSP disabled"
		return
	fi
	tar -xzf "$tmp/$tarball" -C "$tmp" || { warn "asm-lsp archive is unreadable"; return; }

	local bin
	bin="$(find "$tmp" -type f -name asm-lsp -perm -u+x | head -1)"
	[ -n "$bin" ] || { warn "asm-lsp binary not found in archive"; return; }

	mkdir -p "$prefix/bin"
	install -m 0755 "$bin" "$prefix/bin/asm-lsp"
	ok "asm-lsp installed to $prefix/bin/asm-lsp"

	case ":$PATH:" in
		*":$prefix/bin:"*) ;;
		*) warn "$prefix/bin is not on your PATH — add it to your shell rc:"
		   printf '      export PATH="%s/bin:$PATH"\n' "$prefix" >&2 ;;
	esac
	export PATH="$prefix/bin:$PATH"
}

# -------------------------------------------------------------- pyright -----

# Python language server. Distributed on npm only, so it is installed into
# ~/.local rather than npm's default global prefix, which is usually
# /usr/local and would need root.
install_pyright() {
	have pyright-langserver && { ok "pyright already installed"; return; }

	if ! have npm; then
		warn "npm not available; Python LSP disabled"
		return
	fi

	local prefix="$HOME/.local"
	info "installing pyright with npm into $prefix"
	if ! npm install -g --prefix "$prefix" pyright >/dev/null 2>&1; then
		warn "pyright install failed; Python LSP disabled"
		return
	fi
	ok "pyright installed to $prefix/bin/pyright-langserver"

	case ":$PATH:" in
		*":$prefix/bin:"*) ;;
		*) warn "$prefix/bin is not on your PATH — add it to your shell rc:"
		   printf '      export PATH="%s/bin:$PATH"\n' "$prefix" >&2 ;;
	esac
	export PATH="$prefix/bin:$PATH"
}

# --------------------------------------------------------------- deploy -----

backup_path() {
	local path="$1"
	[ -e "$path" ] || [ -L "$path" ] || return 0
	local dest="${path}.bak.$(date +%Y%m%d%H%M%S)"
	mv "$path" "$dest"
	ok "backed up $path -> $dest"
}

deploy_config() {
	# Already pointing at this repo? Nothing to do.
	if [ -L "$CONFIG_DIR" ] && [ "$(readlink -f "$CONFIG_DIR")" = "$REPO_DIR" ]; then
		ok "$CONFIG_DIR already links to $REPO_DIR"
		return
	fi

	if [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
		if [ "$FORCE" -ne 1 ]; then
			printf '%s%s already exists. Back it up and replace it? [y/N] %s' \
				"$C_BOLD" "$CONFIG_DIR" "$C_RESET"
			local reply
			read -r reply </dev/tty || reply=""
			case "$reply" in
				[yY]|[yY][eE][sS]) ;;
				*) die "aborted; existing config left untouched" ;;
			esac
		fi
		backup_path "$CONFIG_DIR"
		# Stale plugin/state trees confuse a fresh config; move them aside too.
		backup_path "$DATA_DIR"
		backup_path "$STATE_DIR"
		backup_path "$CACHE_DIR"
	fi

	mkdir -p "$(dirname "$CONFIG_DIR")"

	if [ "$MODE" = "link" ]; then
		ln -s "$REPO_DIR" "$CONFIG_DIR"
		ok "linked $CONFIG_DIR -> $REPO_DIR"
	else
		mkdir -p "$CONFIG_DIR"
		if have rsync; then
			rsync -a --exclude '.git' --exclude 'install.sh' "$REPO_DIR"/ "$CONFIG_DIR"/
		else
			cp -a "$REPO_DIR"/. "$CONFIG_DIR"/
			rm -rf "$CONFIG_DIR/.git" "$CONFIG_DIR/install.sh"
		fi
		ok "copied config to $CONFIG_DIR"
	fi
}

# --------------------------------------------------------------- extras -----

# tmux: moonfly theme, true colour + undercurl passthrough, and the tmux half
# of the vim-tmux-navigator bindings. Without this the <C-hjkl> keys move
# between Neovim splits but will not cross into a tmux pane.
deploy_tmux() {
	local src="$REPO_DIR/tmux/tmux.conf"
	[ -r "$src" ] || { warn "$src missing — skipping tmux config"; return; }

	if [ -L "$TMUX_CONF" ] && [ "$(readlink -f "$TMUX_CONF")" = "$src" ]; then
		ok "$TMUX_CONF already links to the repo"
		return
	fi

	# An existing tmux.conf is someone's own work; never silently replace it.
	if [ -e "$TMUX_CONF" ] || [ -L "$TMUX_CONF" ]; then
		if [ "$FORCE" -ne 1 ]; then
			printf '%s%s already exists. Back it up and replace it? [y/N] %s' \
				"$C_BOLD" "$TMUX_CONF" "$C_RESET"
			local reply
			read -r reply </dev/tty || reply=""
			case "$reply" in
				[yY]|[yY][eE][sS]) ;;
				*) warn "kept existing $TMUX_CONF"; return ;;
			esac
		fi
		backup_path "$TMUX_CONF"
	fi

	if [ "$MODE" = "link" ]; then
		ln -s "$src" "$TMUX_CONF"
		ok "linked $TMUX_CONF -> $src"
	else
		cp "$src" "$TMUX_CONF"
		ok "copied tmux config to $TMUX_CONF"
	fi

	# Pick up the new config in any already-running server.
	if have tmux && tmux info >/dev/null 2>&1; then
		tmux source-file "$TMUX_CONF" >/dev/null 2>&1 \
			&& ok "reloaded the running tmux server"
	fi
}

# Konsole: the moonfly palette as a colour scheme. Installed as a plain file;
# the active profile is only repointed if one exists, and it is backed up
# first. Konsole reads these at startup, so a new window is needed.
deploy_konsole() {
	local src="$REPO_DIR/konsole/Moonfly.colorscheme"
	[ -r "$src" ] || { warn "$src missing — skipping Konsole theme"; return; }

	# Only meaningful where Konsole is actually used.
	if ! have konsole && [ ! -d "$KONSOLE_DIR" ]; then
		info "Konsole not detected — skipping its colour scheme"
		return
	fi

	mkdir -p "$KONSOLE_DIR"
	cp "$src" "$KONSOLE_DIR/Moonfly.colorscheme"
	ok "installed Konsole scheme to $KONSOLE_DIR/Moonfly.colorscheme"

	local profile="$KONSOLE_DIR/Default.profile"
	if [ ! -f "$profile" ]; then
		info "no Default.profile — select 'Moonfly' in Konsole's profile settings"
		return
	fi

	if grep -q '^ColorScheme=Moonfly$' "$profile"; then
		ok "Konsole profile already uses Moonfly"
		return
	fi

	cp "$profile" "${profile}.bak.$(date +%Y%m%d%H%M%S)"
	if grep -q '^ColorScheme=' "$profile"; then
		sed -i 's/^ColorScheme=.*/ColorScheme=Moonfly/' "$profile"
	else
		# No Appearance key yet; add one.
		sed -i '1i [Appearance]\nColorScheme=Moonfly' "$profile"
	fi
	ok "pointed Konsole's Default profile at Moonfly (open a new window to see it)"
}

# -------------------------------------------------------------- plugins -----

sync_plugins() {
	if [ ! -e "$CONFIG_DIR/init.lua" ] && [ ! -e "$CONFIG_DIR/init.vim" ]; then
		warn "no init.lua/init.vim in $CONFIG_DIR — skipping plugin sync"
		return
	fi

	info "syncing plugins (this may take a minute)"

	# lazy.nvim and packer expose different headless entry points; vim-plug is
	# driven by :PlugInstall. Anything else just gets a plain headless start,
	# which is enough for managers that bootstrap themselves from init.lua.
	if grep -rqs "lazy.nvim\|folke/lazy" "$CONFIG_DIR" --include='*.lua' --include='*.vim'; then
		nvim --headless "+Lazy! sync" +qa
	elif grep -rqs "packer.nvim\|wbthomason/packer" "$CONFIG_DIR" --include='*.lua' --include='*.vim'; then
		nvim --headless "+autocmd User PackerComplete quitall" "+PackerSync"
	elif grep -rqs "plug#begin\|vim-plug" "$CONFIG_DIR" --include='*.lua' --include='*.vim'; then
		nvim --headless "+PlugInstall --sync" +qa
	else
		nvim --headless +qa
	fi

	# TSUpdate is a no-op (and errors harmlessly) when treesitter isn't used.
	if grep -rqs "nvim-treesitter" "$CONFIG_DIR" --include='*.lua' --include='*.vim'; then
		nvim --headless "+TSUpdateSync" +qa || warn "treesitter update reported errors"
	fi

	ok "plugins synced"
}

# ----------------------------------------------------------------- main -----

main() {
	info "ThNVIM installer"
	printf '     repo:   %s\n     target: %s\n     mode:   %s\n\n' \
		"$REPO_DIR" "$CONFIG_DIR" "$MODE"

	if [ "$INSTALL_DEPS" -eq 1 ]; then
		local pm
		pm="$(detect_pm)"

		if [ "$pm" = "unknown" ]; then
			warn "no supported package manager found; skipping dependency install"
		else
			info "installing dependencies with $pm"
			install_packages "$pm" "$(pkgs_for "$pm")" \
				|| warn "some packages failed to install; continuing"

			if ! nvim_version_ok; then
				info "installing Neovim via $pm"
				install_packages "$pm" neovim || true
			fi
		fi
	else
		info "skipping dependency install (--no-deps)"
	fi

	# Fetched outside the package manager. Deliberately NOT tied to
	# --no-deps: both install user-local and need no root, and --no-deps
	# exists to avoid the sudo package step. Gating them there meant they
	# were silently skipped and the servers never appeared.
	if [ "$INSTALL_LSP" -eq 1 ]; then
		install_asm_lsp
		install_pyright
	else
		info "skipping language servers (--no-lsp)"
	fi

	if ! nvim_version_ok; then
		if have nvim; then
			warn "Neovim $(nvim --version | head -1 | awk '{print $2}') is older than v${MIN_NVIM_MAJOR}.${MIN_NVIM_MINOR}"
		else
			warn "Neovim not found"
		fi
		install_nvim_upstream
		nvim_version_ok || die "Neovim >= ${MIN_NVIM_MAJOR}.${MIN_NVIM_MINOR} still not available"
	fi
	ok "$(nvim --version | head -1)"

	deploy_config
	sync_plugins

	# Plugins are synced first: the tmux theme sources moonfly straight out of
	# the plugin directory, so it needs to exist by now.
	if [ "$INSTALL_EXTRAS" -eq 1 ]; then
		info "deploying terminal config"
		deploy_tmux
		deploy_konsole
	else
		info "skipping tmux and Konsole config (--no-extras)"
	fi

	# Report which servers are actually present. A server that failed to
	# install only shows up as "no completion" much later otherwise.
	info "language servers"
	local name
	for name in clangd asm-lsp pyright-langserver; do
		if have "$name"; then
			ok "$name -> $(command -v "$name")"
		else
			warn "$name not found — its language will have no LSP"
		fi
	done

	printf '\n%sDone.%s Start it with: nvim\n' "$C_GREEN$C_BOLD" "$C_RESET"
}

main "$@"
