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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    curl wget git build-essential \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev \
    software-properties-common apt-transport-https ca-certificates \
    jq htop unzip zip
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
    curl wget git \
    openssl-devel zlib-devel bzip2-devel readline-devel sqlite-devel \
    ncurses-devel xz-devel libffi-devel \
    ca-certificates unzip zip \
    jq htop
}

# ---------------------------------------------------------------------------
# Claude settings.json — seed-only (never overwrite existing)
# Source: dot_claude/settings.json (chezmoi ignores .claude/** on purpose;
# this function plants the defaults on first install so plugins/marketplaces
# are auto-wired, but preserves any local customizations — hooks, model, etc.)
# ---------------------------------------------------------------------------
install_claude_settings() {
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  if command -v rustup &>/dev/null; then
    echo ">>> Rust already installed ($(rustc --version)), updating..."
    rustup update
    return
  fi
  echo ">>> Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
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
    echo ">>> Tailscale already installed ($(tailscale --version | head -n1)), skipping."
    return
  fi
  echo ">>> Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
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
  install_tmux
  install_alacritty
  install_tailscale
  install_gh
  install_rtk
  install_claude_settings
  install_karpathy_skills
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
