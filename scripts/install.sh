#!/usr/bin/env bash
# install.sh — Package installer for hgryoo/dotfiles
# Supports Ubuntu (apt) and Rocky Linux 9 (dnf).
# Run after chezmoi apply — managed configs must already be in place.
#
# Usage:
#   bash install.sh              # base install only
#   bash install.sh --kb         # include knowledge base tools
#   bash install.sh --local-llm  # include local LLM tools
#   bash install.sh --all        # everything
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OPT_KB=false
OPT_LLM=false
OPT_GCLOUD_ONLY=false

usage() {
  cat <<EOF
Usage: bash install.sh [OPTIONS]

Options:
  --kb         Install knowledge base tools (obsidian-cli, qmd, gws, gcloud)
  --local-llm  Install local LLM tools (ollama, llama.cpp, vLLM, gemma4)
  --gcloud     Install ONLY Google Cloud CLI (no base, no kb bundle)
  --all        Install everything (base + kb + local-llm)
  -h, --help   Show this help message

Without options, only the base environment is installed.
EOF
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --kb)         OPT_KB=true ;;
    --local-llm)  OPT_LLM=true ;;
    --gcloud)     OPT_GCLOUD_ONLY=true ;;
    --all)        OPT_KB=true; OPT_LLM=true ;;
    -h|--help)    usage ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

install_gcloud() {
  if command -v gcloud &>/dev/null; then
    echo ">>> gcloud already installed ($(gcloud --version | head -n1)), skipping."
    return
  fi
  if [ -x "$HOME/google-cloud-sdk/bin/gcloud" ]; then
    echo ">>> gcloud found at ~/google-cloud-sdk (not on PATH) — skipping install."
    echo ">>> Run 'source ~/google-cloud-sdk/path.bash.inc' or restart your shell."
    return
  fi
  echo ">>> Installing Google Cloud CLI..."
  curl https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
  echo ">>> gcloud installed. Run 'source ~/.bashrc' or restart your shell to use it."
}

if $OPT_GCLOUD_ONLY; then
  install_gcloud
  exit 0
fi

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
  else
    echo "ERROR: /etc/os-release not found — cannot detect OS." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Ubuntu: base packages
# ---------------------------------------------------------------------------
install_base_ubuntu() {
  echo ">>> [Ubuntu] Updating package index..."
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl wget git build-essential ccache \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev \
    software-properties-common apt-transport-https ca-certificates \
    jq htop unzip zip

  # CUBRID engine build requirements (docs/install_build_requirements.md):
  # C++17 compiler, CMake >= 3.21, JDK >= 8, ant, flex/bison, elf/systemtap
  # headers for the dtrace probes, libtool/autoconf for the 3rdparty tree.
  echo ">>> [Ubuntu] Installing CUBRID build requirements..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    cmake ninja-build pkg-config gettext \
    default-jdk ant \
    flex libncurses-dev \
    libtool libtool-bin autoconf automake \
    libelf-dev systemtap-sdt-dev elfutils \
    rpm gdb cgdb
}

# ---------------------------------------------------------------------------
# Rocky Linux 9: base packages
# ---------------------------------------------------------------------------
install_base_rocky() {
  echo ">>> [Rocky] Updating package index..."
  sudo dnf update -y
  # Enable EPEL and CRB (needed for many dev packages)
  sudo dnf install -y epel-release
  sudo dnf config-manager --set-enabled crb 2>/dev/null || true
  sudo dnf install -y \
    curl wget git ccache \
    openssl-devel zlib-devel bzip2-devel readline-devel sqlite-devel \
    ncurses-devel xz-devel libffi-devel \
    ca-certificates unzip zip \
    jq htop

  # CUBRID engine build requirements (docs/install_build_requirements.md)
  echo ">>> [Rocky] Installing CUBRID build requirements..."
  sudo dnf install -y \
    gcc gcc-c++ make cmake ninja-build pkgconf-pkg-config gettext \
    java-devel ant \
    flex ncurses-devel \
    libtool libtool-ltdl autoconf automake \
    elfutils-libelf-devel systemtap-sdt-devel \
    rpm-build gdb
}

# ---------------------------------------------------------------------------
# Claude settings.json — seed-only (never overwrite existing)
# Source: dot_claude/settings.json (chezmoi ignores .claude/** on purpose;
# this function plants the defaults on first install so plugins/marketplaces
# are auto-wired, but preserves any local customizations — hooks, model, etc.)
# ---------------------------------------------------------------------------
install_claude_settings() {
  local repo_root
  repo_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
  local src="$repo_root/dot_claude/settings.json"
  local dst="$HOME/.claude/settings.json"

  if [ ! -f "$src" ]; then
    echo "WARNING: $src not found — skipping Claude settings seed." >&2
    return
  fi
  if [ -f "$dst" ]; then
    if ! [ -t 0 ]; then
      echo ">>> Claude settings.json exists at $dst; non-interactive shell, keeping existing."
      return
    fi
    local reply
    read -r -p ">>> Claude settings.json already exists at $dst. Overwrite? [y/N] " reply
    case "${reply,,}" in
      y|yes)
        local backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
        cp "$dst" "$backup"
        cp "$src" "$dst"
        echo ">>> Overwrote $dst (previous saved to $backup)."
        ;;
      *)
        echo ">>> Keeping existing $dst."
        ;;
    esac
    return
  fi

  mkdir -p "$HOME/.claude"
  cp "$src" "$dst"
  echo ">>> Seeded $dst from $src."
}

# ---------------------------------------------------------------------------
# Karpathy skills → ~/.claude/CLAUDE.md
# Source: dot_claude/karpathy-skills.md (deployed by chezmoi to ~/.claude/)
# ---------------------------------------------------------------------------
install_karpathy_skills() {
  local repo_root
  repo_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
  local src="$repo_root/dot_claude/karpathy-skills.md"
  local dst="$HOME/.claude/CLAUDE.md"
  local marker="# Andrej Karpathy Skills"

  if grep -qF "$marker" "$dst" 2>/dev/null; then
    echo ">>> Karpathy skills already in $dst, skipping."
    return
  fi

  if [ ! -f "$src" ]; then
    echo "WARNING: $src not found — skipping Karpathy skills." >&2
    return
  fi

  mkdir -p "$HOME/.claude"
  echo "" >> "$dst"
  cat "$src" >> "$dst"
  echo ">>> Karpathy skills appended to $dst."
}

# ---------------------------------------------------------------------------
# Scaffold skills + tools → ~/.claude/skills/ and ~/.local/bin/
# The general-purpose Claude Code skills (dev-*, doc-*, kb-*, common, academic-*)
# and the standalone CLI tools live in the hgryoo/scaffold repo, cloned by
# scripts/setup_data_repos.sh. Its install.sh symlinks each skill into
# ~/.claude/skills/ and each tool into ~/.local/bin/ — idempotent, so re-running
# just refreshes the links. We run it here so a plain `install.sh` on a machine
# that already has /data cloned wires the skills without a manual step.
#
# NOTE: the CUBRID-specific skills are a SEPARATE scaffold (cubrid_cv/scaffold)
# and are intentionally NOT installed here — install those with
# `bash /data/cubrid_cv/scaffold/install.sh`.
# ---------------------------------------------------------------------------
install_scaffold_skills() {
  local candidates=(
    "${DATA_ROOT:-/data}/hgryoo/scaffold"
    "/data/hgryoo/scaffold"
    "$HOME/scaffold"
  )
  local scaffold=""
  local c
  for c in "${candidates[@]}"; do
    if [ -f "$c/install.sh" ]; then scaffold="$c"; break; fi
  done
  if [ -z "$scaffold" ]; then
    echo ">>> hgryoo/scaffold not found (looked in: ${candidates[*]})."
    echo ">>> Skills install skipped — clone it with 'bash bootstrap.sh --data', then re-run install.sh."
    return
  fi
  echo ">>> Installing scaffold skills + tools from $scaffold ..."
  bash "$scaffold/install.sh" || echo "WARNING: scaffold install.sh reported an error (continuing)."
}

# ---------------------------------------------------------------------------
# Claude Code + oh-my-claudecode
# ---------------------------------------------------------------------------
install_claude_code() {
  if command -v claude &>/dev/null; then
    echo ">>> Claude Code already installed ($(claude --version | head -n1)), skipping."
  else
    echo ">>> Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
  fi

  # oh-my-claudecode is auto-installed by Claude Code on first run via
  # extraKnownMarketplaces + enabledPlugins in ~/.claude/settings.json.
  # Install the omc CLI separately so `omc update` is available outside sessions.
  if command -v omc &>/dev/null; then
    echo ">>> omc already installed, skipping."
  elif command -v npm &>/dev/null; then
    echo ">>> Installing oh-my-claudecode CLI (omc)..."
    npm install -g oh-my-claude-sisyphus || echo "WARNING: omc CLI install failed — it will be auto-installed by Claude Code on first run."
  else
    echo ">>> npm not found — omc CLI will be auto-installed by Claude Code on first run."
  fi
}

# ---------------------------------------------------------------------------
# uv (Python package/project manager — replaces pyenv)
# ---------------------------------------------------------------------------
install_uv() {
  if command -v uv &>/dev/null; then
    echo ">>> uv already installed ($(uv --version)), skipping."
    return
  fi
  echo ">>> Installing uv..."
  curl --proto '=https' --tlsv1.2 -LsSf https://astral.sh/uv/install.sh | sh
}

# ---------------------------------------------------------------------------
# Rust (rustup)
# ---------------------------------------------------------------------------
install_rust() {
  if ! command -v rustup &>/dev/null; then
    echo ">>> Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  else
    echo ">>> Rust already installed ($(rustc --version)), updating..."
    rustup update
  fi
  # --no-modify-path leaves this shell without cargo, and .bashrc's
  # `. ~/.cargo/env` only helps the *next* shell. install_lazydiff runs two
  # steps later and calls cargo, so put it on PATH here.
  # shellcheck disable=SC1091
  [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  export PATH="$HOME/.cargo/bin:$PATH"
}

# ---------------------------------------------------------------------------
# oh-my-bash
# ---------------------------------------------------------------------------
install_ohmybash() {
  if [ -d "$HOME/.oh-my-bash" ]; then
    echo ">>> oh-my-bash already installed, skipping."
    return
  fi
  echo ">>> Installing oh-my-bash..."
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" \
    --unattended
}

# ---------------------------------------------------------------------------
# Set default shell to bash
# ---------------------------------------------------------------------------
set_default_shell_bash() {
  local current_shell
  current_shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
  if [ "$current_shell" = "/bin/bash" ] || [ "$current_shell" = "/usr/bin/bash" ]; then
    echo ">>> Default shell is already bash, skipping."
    return
  fi
  echo ">>> Changing default shell to bash..."
  chsh -s "$(command -v bash)"
  echo ">>> Default shell changed to bash. Log out and back in to take effect."
}

# ---------------------------------------------------------------------------
# Neovim
# ---------------------------------------------------------------------------
install_neovim() {
  if command -v nvim &>/dev/null; then
    echo ">>> Neovim already installed ($(nvim --version | head -n1)), skipping."
    return
  fi
  echo ">>> Installing Neovim..."
  case "$OS_ID" in
    ubuntu)
      sudo add-apt-repository ppa:neovim-ppa/stable -y
      sudo apt-get update -y
      sudo apt-get install -y neovim
      ;;
    rocky)
      sudo dnf install -y neovim
      ;;
  esac
}

# ---------------------------------------------------------------------------
# direnv
# ---------------------------------------------------------------------------
install_direnv() {
  if command -v direnv &>/dev/null; then
    echo ">>> direnv already installed ($(direnv --version)), skipping."
    return
  fi
  echo ">>> Installing direnv..."
  case "$OS_ID" in
    ubuntu) sudo apt-get install -y direnv ;;
    rocky)  sudo dnf install -y direnv ;;
  esac
}

# ---------------------------------------------------------------------------
# fzf
# ---------------------------------------------------------------------------
install_fzf() {
  if command -v fzf &>/dev/null; then
    echo ">>> fzf already installed, skipping."
    return
  fi
  echo ">>> Installing fzf..."
  case "$OS_ID" in
    ubuntu) sudo apt-get install -y fzf ;;
    rocky)  sudo dnf install -y fzf ;;
  esac
}

# ---------------------------------------------------------------------------
# just (command runner) — via pre-built binary
# ---------------------------------------------------------------------------
install_just() {
  if command -v just &>/dev/null; then
    echo ">>> just already installed ($(just --version)), skipping."
    return
  fi
  echo ">>> Installing just..."
  curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
    | bash -s -- --to "$HOME/.local/bin"
}

# ---------------------------------------------------------------------------
# CUBRID tools — moved out of dotfiles.
#
# CUBRID-related skills (cubrid-analyze-ci-failures, cubrid-create-testcases,
# cubrid-build, cubrid-code-style, cubrid-org-jira-fetch, cubrid-rnd-jira-fetch)
# and their helper scripts (cubindent, indent_all, setcubrid.sh, build_cubrid.sh)
# are now installed from the cubrid_cv repo:
#
#   bash /data/cubrid_cv/scaffold/install.sh --list
#   bash /data/cubrid_cv/scaffold/install.sh --skills=cubrid-build,cubrid-org-jira-fetch
#   bash /data/cubrid_cv/scaffold/install.sh --all
#
# That installer also handles cubrid-jira-fetcher (`uv tool install`).
# Submodules cubrid/tools/{cubrid-jira-fetcher,my-cubrid-skills} have been
# removed from this repo's .gitmodules; run `git submodule deinit` and
# `git rm` on the old paths if they are still on disk.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# markitdown (Microsoft — file-to-Markdown converter)
# ---------------------------------------------------------------------------
install_markitdown() {
  if command -v markitdown &>/dev/null; then
    echo ">>> markitdown already installed, skipping."
    return
  fi
  echo ">>> Installing markitdown..."
  uv tool install 'markitdown[all]'
}

# ---------------------------------------------------------------------------
# lazydiff (TUI diff viewer — Rust)
# ---------------------------------------------------------------------------
install_lazydiff() {
  if command -v lazydiff &>/dev/null; then
    echo ">>> lazydiff already installed, skipping."
    return
  fi
  if ! command -v cargo &>/dev/null; then
    echo "WARNING: cargo not found, cannot install lazydiff." >&2
    return
  fi
  echo ">>> Installing lazydiff..."
  cargo install lazydiff
}

# ---------------------------------------------------------------------------
# lazygit (TUI for git)
# ---------------------------------------------------------------------------
install_lazygit() {
  if command -v lazygit &>/dev/null; then
    echo ">>> lazygit already installed ($(lazygit --version | head -n1)), skipping."
    return
  fi
  echo ">>> Installing lazygit..."
  local version
  version=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" RETURN
  curl -Lo "$tmpdir/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_x86_64.tar.gz"
  tar xf "$tmpdir/lazygit.tar.gz" -C "$tmpdir" lazygit
  sudo install "$tmpdir/lazygit" /usr/local/bin/lazygit
  echo "lazygit: $(lazygit --version | head -n1)"
}

# ---------------------------------------------------------------------------
# rtk (AI CLI)
# ---------------------------------------------------------------------------
install_rtk() {
  if command -v rtk &>/dev/null; then
    echo ">>> rtk already installed ($(rtk --version 2>/dev/null | head -n1)), skipping."
    return
  fi
  echo ">>> Installing rtk..."
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  rtk init -g
}

# ---------------------------------------------------------------------------
# abtop (btop-like TUI for Claude Code / Codex CLI sessions)
# https://github.com/graykode/abtop
# ---------------------------------------------------------------------------
install_abtop() {
  if command -v abtop &>/dev/null; then
    echo ">>> abtop already installed ($(abtop --version 2>/dev/null | head -n1)), skipping."
    return
  fi
  echo ">>> Installing abtop..."
  curl --proto '=https' --tlsv1.2 -LsSf \
    https://github.com/graykode/abtop/releases/latest/download/abtop-installer.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
}

# ---------------------------------------------------------------------------
# Code Review Graph (uv tool, binary install only)
# https://github.com/tirth8205/code-review-graph
# Per-project setup is intentional: run 'code-review-graph install --platform
# claude-code' inside each project where you want it active. We do NOT run it
# globally because it (a) clobbers existing user-scope hooks and (b) drops
# CLAUDE.md / .mcp.json into whatever directory it's invoked from.
# ---------------------------------------------------------------------------
install_code_review_graph() {
  if ! command -v uv &>/dev/null; then
    echo "WARNING: uv not found, cannot install code-review-graph." >&2
    return
  fi
  if command -v code-review-graph &>/dev/null; then
    echo ">>> code-review-graph already installed ($(code-review-graph --version 2>/dev/null | head -n1)), skipping."
    return
  fi
  echo ">>> Installing code-review-graph via uv tool..."
  uv tool install code-review-graph
  export PATH="$HOME/.local/bin:$PATH"
  echo ">>> Binary installed. Per-project setup: cd <project> && code-review-graph install --platform claude-code"
}

# ---------------------------------------------------------------------------
# Token Savior (uv tool, MCP server)
# https://github.com/Mibayy/token-savior
# Binary install only — MCP registration is handled by scripts/install_mcp.sh.
# ---------------------------------------------------------------------------
install_token_savior() {
  if ! command -v uv &>/dev/null; then
    echo "WARNING: uv not found, cannot install token-savior." >&2
    return
  fi
  if command -v token-savior &>/dev/null; then
    echo ">>> token-savior already installed, skipping."
    return
  fi
  echo ">>> Installing token-savior-recall[mcp] via uv tool..."
  uv tool install 'token-savior-recall[mcp]'
  export PATH="$HOME/.local/bin:$PATH"
  echo ">>> Token Savior installed. Register MCP via: bash scripts/install_mcp.sh"
}

# ---------------------------------------------------------------------------
# tmux + oh-my-tmux (gpakosz/.tmux)
# chezmoi deploys ~/.tmux.conf.local with user overrides.
# This step installs tmux itself and wires ~/.tmux.conf → ~/.tmux/.tmux.conf.
# ---------------------------------------------------------------------------
install_tmux() {
  # 1) tmux binary
  if command -v tmux &>/dev/null; then
    echo ">>> tmux already installed ($(tmux -V)), skipping package install."
  else
    echo ">>> Installing tmux..."
    case "$OS_ID" in
      ubuntu) sudo apt-get install -y tmux ;;
      rocky)  sudo dnf install -y tmux ;;
    esac
  fi

  # 2) oh-my-tmux repo
  if [ -d "$HOME/.tmux/.git" ]; then
    echo ">>> oh-my-tmux already cloned at ~/.tmux, pulling latest..."
    git -C "$HOME/.tmux" pull --ff-only || echo "WARNING: oh-my-tmux pull failed, continuing."
  else
    echo ">>> Cloning oh-my-tmux to ~/.tmux..."
    git clone --depth=1 https://github.com/gpakosz/.tmux.git "$HOME/.tmux"
  fi

  # 3) ~/.tmux.conf symlink → ~/.tmux/.tmux.conf (oh-my-tmux entrypoint)
  local target="$HOME/.tmux/.tmux.conf"
  local link="$HOME/.tmux.conf"
  if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$(readlink -f "$target")" ]; then
    echo ">>> ~/.tmux.conf already points to oh-my-tmux, skipping."
  else
    [ -e "$link" ] && mv -v "$link" "$link.bak.$(date +%Y%m%d%H%M%S)"
    ln -sfn "$target" "$link"
    echo ">>> Linked $link → $target"
  fi

  # Note: ~/.tmux.conf.local is managed by chezmoi — do not touch it here.
}

# ---------------------------------------------------------------------------
# Alacritty (GPU-accelerated terminal emulator)
# Config is deployed by chezmoi to ~/.config/alacritty/alacritty.toml
# ---------------------------------------------------------------------------
install_alacritty() {
  if command -v alacritty &>/dev/null; then
    echo ">>> alacritty already installed ($(alacritty --version | head -n1)), skipping."
    return
  fi
  echo ">>> Installing alacritty..."
  case "$OS_ID" in
    ubuntu)
      sudo apt-get install -y alacritty
      ;;
    rocky)
      # Alacritty isn't in EPEL for Rocky 9 — fall back to cargo.
      if command -v cargo &>/dev/null; then
        sudo dnf install -y cmake freetype-devel fontconfig-devel \
          libxcb-devel libxkbcommon-devel g++
        cargo install alacritty
      else
        echo "WARNING: cargo not found — skipping alacritty install on Rocky." >&2
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Tailscale
# ---------------------------------------------------------------------------
install_tailscale() {
  if command -v tailscale &>/dev/null; then
    echo ">>> Tailscale already installed ($(tailscale --version | head -n1)), skipping install."
  else
    echo ">>> Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  # Joining is the part that matters on a fresh machine, and it is the part
  # that wants a browser. An auth key in secrets.env removes that round trip.
  if tailscale status &>/dev/null; then
    echo ">>> Tailscale already on the tailnet ($(tailscale status --self --peers=false 2>/dev/null | awk '{print $2}' | head -n1))."
    return
  fi
  local secrets="$SCRIPT_DIR/../secrets.env"
  # shellcheck disable=SC1090
  [ -f "$secrets" ] && . "$secrets"
  if [ -n "${TAILSCALE_AUTH_KEY:-}" ]; then
    echo ">>> Joining the tailnet with the key from secrets.env..."
    sudo tailscale up --auth-key="$TAILSCALE_AUTH_KEY" --ssh \
      || echo "!!! tailscale up failed — the key may be expired. Run 'sudo tailscale up' by hand." >&2
  else
    echo ">>> TAILSCALE_AUTH_KEY not set — run 'sudo tailscale up' to join."
  fi
}

# ---------------------------------------------------------------------------
# gh (GitHub CLI)
# ---------------------------------------------------------------------------
install_gh() {
  if command -v gh &>/dev/null; then
    echo ">>> gh already installed ($(gh --version | head -n1)), skipping."
    return
  fi
  echo ">>> Installing GitHub CLI..."
  case "$OS_ID" in
    ubuntu)
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -y && sudo apt-get install -y gh
      ;;
    rocky)
      sudo dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
      sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo dnf install -y gh
      ;;
  esac
}

# ---------------------------------------------------------------------------
# nvm + Node.js
# The agent tooling (codex, openclaw, sisyphus) and the slide pipeline
# (marp-cli, mermaid-cli, slides-grab) all run on a user-owned Node, not the
# distro one. nvm keeps that Node out of /usr and lets the version move.
# obsidian-cli and qmd are deliberately left to install_kb.sh.
# ---------------------------------------------------------------------------
NVM_DIR_DEFAULT="$HOME/.nvm"
NODE_VERSION="${NODE_VERSION:-24}"

NPM_GLOBALS=(
  "@openai/codex"
  "oh-my-claude-sisyphus"
  "openclaw"
  "@marp-team/marp-cli"
  "@mermaid-js/mermaid-cli"
  "slides-grab"
)

install_nvm() {
  export NVM_DIR="${NVM_DIR:-$NVM_DIR_DEFAULT}"

  if [ -s "$NVM_DIR/nvm.sh" ]; then
    echo ">>> nvm already installed at $NVM_DIR, skipping install."
  else
    echo ">>> Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi

  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"

  if nvm ls "$NODE_VERSION" &>/dev/null; then
    echo ">>> Node $NODE_VERSION already installed, skipping."
  else
    echo ">>> Installing Node $NODE_VERSION..."
    nvm install "$NODE_VERSION"
  fi
  nvm alias default "$NODE_VERSION" >/dev/null
  nvm use default >/dev/null
  echo ">>> Node: $(node --version)  npm: $(npm --version)"

  echo ">>> Installing global npm packages..."
  for pkg in "${NPM_GLOBALS[@]}"; do
    if npm ls -g --depth=0 "$pkg" &>/dev/null; then
      echo "    - $pkg already installed, skipping."
    else
      echo "    - $pkg"
      npm install -g "$pkg" || echo "    !!! $pkg failed — install by hand." >&2
    fi
  done
}

# ---------------------------------------------------------------------------
# snip (CLI token killer — replaces rtk)
# https://github.com/edouard-claude/snip
# `snip init` installs the Claude Code PreToolUse hook that rewrites shell
# commands through the filter pipeline. Documented in dot_claude/SNIP.md.
# ---------------------------------------------------------------------------
install_snip() {
  if command -v snip &>/dev/null; then
    echo ">>> snip already installed ($(snip --version 2>/dev/null | head -n1)), skipping."
    return
  fi
  echo ">>> Installing snip..."
  curl -fsSL https://raw.githubusercontent.com/edouard-claude/snip/main/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  command -v snip &>/dev/null && snip init \
    || echo "!!! snip not on PATH after install — run 'snip init' by hand." >&2
}

# ---------------------------------------------------------------------------
# uv tools
# Standalone Python CLIs kept out of any project venv. markitdown,
# code-review-graph and token-savior have their own functions above because
# they carry extra setup; these are plain installs.
# ---------------------------------------------------------------------------
UV_TOOLS=(
  "git+https://github.com/vimkim/cubrid-jira-fetcher|cubrid-jira-fetch"
  "copyparty|copyparty"
  "openai-whisper|whisper"
)

install_uv_tools() {
  if ! command -v uv &>/dev/null; then
    echo "WARNING: uv not found, cannot install uv tools." >&2
    return
  fi
  for entry in "${UV_TOOLS[@]}"; do
    IFS='|' read -r spec bin <<<"$entry"
    if command -v "$bin" &>/dev/null; then
      echo ">>> $bin already installed, skipping."
      continue
    fi
    echo ">>> Installing $spec via uv tool..."
    uv tool install "$spec" || echo "!!! $spec failed — install by hand." >&2
  done
  export PATH="$HOME/.local/bin:$PATH"
}

# ---------------------------------------------------------------------------
# bison 3.0.5 (CUBRID)
# Ubuntu 24.04 ships bison 3.8, whose generated parsers do not build against
# CUBRID's grammar. docs/install_build_requirements.md pins 3.0.5, so build it
# from source into ~/bin and shadow the distro one via the ~/bin PATH entry
# that .bashrc already prepends. Also plants the `yacc` wrapper CUBRID expects.
# ---------------------------------------------------------------------------
BISON_VERSION="3.0.5"

install_bison_cubrid() {
  if [ -x "$HOME/bin/bison" ] && "$HOME/bin/bison" --version 2>/dev/null | head -n1 | grep -q "$BISON_VERSION"; then
    echo ">>> bison $BISON_VERSION already in ~/bin, skipping."
    return
  fi
  echo ">>> Building bison $BISON_VERSION from source (CUBRID needs it, not the distro 3.8)..."
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "$tmp"
    curl -fsSL "https://ftp.gnu.org/gnu/bison/bison-$BISON_VERSION.tar.gz" | tar xz
    cd "bison-$BISON_VERSION"
    ./configure --prefix="$HOME" >/dev/null
    make -j"$(nproc)" >/dev/null
    make install >/dev/null
  ) || { echo "!!! bison build failed — build it by hand." >&2; rm -rf "$tmp"; return; }
  rm -rf "$tmp"

  # CUBRID's build invokes `yacc`; GNU bison provides it via -y.
  cat > "$HOME/bin/yacc" <<'YACC'
#! /bin/sh
exec "$HOME/bin/bison" -y "$@"
YACC
  chmod +x "$HOME/bin/yacc"
  echo ">>> bison installed: $("$HOME/bin/bison" --version | head -n1)"
}

# ---------------------------------------------------------------------------
# ~/bin — extensionless aliases
# chezmoi already deploys bin/ to ~/bin as real files, so nothing here installs
# the scripts themselves. It only adds the names they are actually typed with:
# `cl-tabs`, not `cl-tabs.sh`. Anything already sitting at the alias name is
# left alone.
# ---------------------------------------------------------------------------
install_local_bin() {
  [ -d "$HOME/bin" ] || { echo ">>> ~/bin missing (run chezmoi apply first), skipping."; return; }
  echo ">>> Adding extensionless aliases in ~/bin..."
  local f base alias_name
  for f in "$HOME"/bin/*.sh; do
    [ -f "$f" ] || continue
    chmod +x "$f"
    base="$(basename "$f")"
    alias_name="${base%.sh}"
    if [ -e "$HOME/bin/$alias_name" ]; then
      continue
    fi
    ln -s "$base" "$HOME/bin/$alias_name"
    echo "    - $alias_name -> $base"
  done
  # cl-tabs also answers to clc-tabs (the claude-cubrid config dir variant).
  [ -f "$HOME/bin/cl-tabs.sh" ] && [ ! -e "$HOME/bin/clc-tabs" ] \
    && ln -s cl-tabs.sh "$HOME/bin/clc-tabs"
  return 0
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  echo "============================================================"
  echo " Install summary"
  echo "============================================================"
  command -v gcc    &>/dev/null && echo "GCC    : $(gcc --version | head -n1)"   || echo "GCC    : not found"
  command -v cmake  &>/dev/null && echo "CMake  : $(cmake --version | head -n1)" || echo "CMake  : not found"
  command -v ninja  &>/dev/null && echo "Ninja  : $(ninja --version)"             || echo "Ninja  : not found"
  command -v bison  &>/dev/null && echo "Bison  : $(bison --version | head -n1)" || echo "Bison  : not found"
  command -v ccache &>/dev/null && echo "ccache : $(ccache --version | head -n1)" || echo "ccache : not found"
  command -v java   &>/dev/null && echo "Java   : $(java -version 2>&1 | head -n1)" || echo "Java   : not found"
  command -v uv     &>/dev/null && echo "uv     : $(uv --version)"                || echo "uv     : not found"
  command -v rustc  &>/dev/null && echo "Rust   : $(rustc --version)"             || echo "Rust   : not found"
  command -v nvim   &>/dev/null && echo "Neovim : $(nvim --version | head -n1)"  || echo "Neovim : not found"
  command -v direnv &>/dev/null && echo "direnv : $(direnv --version)"            || echo "direnv : not found"
  command -v fzf    &>/dev/null && echo "fzf    : $(fzf --version)"               || echo "fzf    : not found"
  command -v just   &>/dev/null && echo "just   : $(just --version)"              || echo "just   : not found"
  command -v markitdown &>/dev/null && echo "markitdown: $(markitdown --version 2>/dev/null | head -n1)" || echo "markitdown: not found"
  command -v lazydiff   &>/dev/null && echo "lazydiff  : installed"                                       || echo "lazydiff  : not found"
  command -v lazygit    &>/dev/null && echo "lazygit   : $(lazygit --version | head -n1)"                 || echo "lazygit   : not found"
  command -v tmux       &>/dev/null && echo "tmux      : $(tmux -V)"                                        || echo "tmux      : not found"
  command -v alacritty  &>/dev/null && echo "alacritty : $(alacritty --version | head -n1)"                || echo "alacritty : not found"
  command -v tailscale  &>/dev/null && echo "tailscale : $(tailscale --version | head -n1)"                || echo "tailscale : not found"
  command -v gh         &>/dev/null && echo "gh        : $(gh --version | head -n1)"                      || echo "gh        : not found"
  command -v rtk        &>/dev/null && echo "rtk       : $(rtk --version 2>/dev/null | head -n1)"         || echo "rtk       : not found"
  command -v snip       &>/dev/null && echo "snip      : $(snip --version 2>/dev/null | head -n1)"        || echo "snip      : not found"
  command -v node       &>/dev/null && echo "node      : $(node --version)"                               || echo "node      : not found"
  command -v codex      &>/dev/null && echo "codex     : $(codex --version 2>/dev/null | head -n1)"       || echo "codex     : not found"
  [ -x "$HOME/bin/bison" ] && echo "bison     : $("$HOME/bin/bison" --version | head -n1) (~/bin)" || echo "bison     : not in ~/bin"
  command -v ant        &>/dev/null && echo "ant       : $(ant -version 2>/dev/null | head -n1)"          || echo "ant       : not found"
  command -v cubrid-jira-fetch &>/dev/null && echo "jira-fetch: installed"                                || echo "jira-fetch: not found"
  command -v abtop      &>/dev/null && echo "abtop     : $(abtop --version 2>/dev/null | head -n1)"       || echo "abtop     : not found"
  command -v claude &>/dev/null && echo "claude : $(claude --version | head -n1)" || echo "claude : not found"
  command -v omc    &>/dev/null && echo "omc    : $(omc --version 2>/dev/null || echo 'installed')" || echo "omc    : not found"
  command -v code-review-graph &>/dev/null && echo "code-review-graph: $(code-review-graph --version 2>/dev/null | head -n1 || echo installed)" || echo "code-review-graph: not found"
  command -v token-savior      &>/dev/null && echo "token-savior     : $(token-savior --version 2>/dev/null | head -n1 || echo installed)"      || echo "token-savior     : not found"
  echo "============================================================"
  echo "Done! Run 'source ~/.bashrc' to reload your shell."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  detect_os
  echo ">>> Detected OS: $OS_ID"

  case "$OS_ID" in
    ubuntu)
      install_base_ubuntu
      ;;
    rocky)
      install_base_rocky
      ;;
    *)
      echo "ERROR: Unsupported OS '$OS_ID'. Supported: ubuntu, rocky." >&2
      exit 1
      ;;
  esac

  install_uv
  install_rust
  install_markitdown
  install_lazydiff
  install_lazygit
  install_ohmybash
  set_default_shell_bash
  install_neovim
  install_direnv
  install_fzf
  install_just
  install_nvm
  install_tmux
  install_alacritty
  install_tailscale
  install_gh
  install_rtk
  install_snip
  install_abtop
  install_uv_tools
  install_bison_cubrid
  install_local_bin
  install_claude_settings
  install_karpathy_skills
  install_scaffold_skills
  install_claude_code
  install_code_review_graph
  install_token_savior

  # Optional modules
  if $OPT_KB; then
    echo
    echo ">>> Installing knowledge base tools..."
    source "$SCRIPT_DIR/install_kb.sh"
  fi

  if $OPT_LLM; then
    echo
    echo ">>> Installing local LLM tools..."
    source "$SCRIPT_DIR/install_local_llm.sh"
  fi

  print_summary
}

main
