#!/usr/bin/env bash
# bootstrap.sh — Single entry point for hgryoo/dotfiles
#
# Usage:
#   bash bootstrap.sh                # chezmoi apply + base install
#   bash bootstrap.sh --setup        # + interactive personalization (git config, env vars)
#   bash bootstrap.sh --auth         # + service authentication (GitHub, Google, HuggingFace)
#   bash bootstrap.sh --kb           # + knowledge base tools (gcloud, obsidian-cli, qmd, gws)
#   bash bootstrap.sh --local-llm    # + local LLM tools (ollama, llama.cpp, vLLM, gemma4)
#   bash bootstrap.sh --all          # everything
#   bash bootstrap.sh --install-only # skip chezmoi, run install.sh only
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OPT_CHEZMOI=true
OPT_INSTALL=true
OPT_SETUP=false
OPT_AUTH=false
OPT_KB=false
OPT_LLM=false

usage() {
  cat <<EOF
Usage: bash bootstrap.sh [OPTIONS]

Options:
  --setup        Run interactive personalization (git config, env vars)
  --auth         Run service authentication (GitHub, Google, HuggingFace)
  --kb           Install knowledge base tools (gcloud, obsidian-cli, qmd, gws)
  --local-llm    Install local LLM tools (ollama, llama.cpp, vLLM, gemma4)
  --all          Run everything except local LLM (chezmoi + install + auth + setup + kb)
  --install-only Skip chezmoi apply, run install.sh only
  -h, --help     Show this help message

Without options: chezmoi apply + base package install.

First-time full setup:
  bash bootstrap.sh --all

Subsequent runs (packages only):
  bash bootstrap.sh --install-only
  bash bootstrap.sh --install-only --kb --local-llm
EOF
  exit 0
}

if [ $# -eq 0 ]; then
  usage
fi

for arg in "$@"; do
  case "$arg" in
    --setup)        OPT_SETUP=true ;;
    --auth)         OPT_AUTH=true ;;
    --kb)           OPT_KB=true ;;
    --local-llm)    OPT_LLM=true ;;
    --all)          OPT_SETUP=true; OPT_AUTH=true; OPT_KB=true ;;
    --install-only) OPT_CHEZMOI=false ;;
    -h|--help)      usage ;;
    *) echo "Unknown option: $arg"; echo; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# Show what will run
# ---------------------------------------------------------------------------
echo "============================================================"
echo " dotfiles bootstrap"
echo " Source: $DOTFILES_DIR"
echo "============================================================"
echo
echo " Steps:"
$OPT_CHEZMOI && echo "  1. chezmoi apply        (deploy configs to ~)"   \
              || echo "  1. chezmoi apply        SKIP (--install-only)"
echo           "  2. scripts/install.sh   (base packages)"
$OPT_KB      && echo "     + --kb              (gcloud, obsidian-cli, qmd, gws)"
$OPT_LLM    && echo "     + --local-llm       (ollama, llama.cpp, vLLM, gemma4)"
$OPT_AUTH    && echo "  3. scripts/auth.sh      (GitHub, Google, HuggingFace)" \
              || echo "  3. scripts/auth.sh      SKIP (use --auth to enable)"
$OPT_SETUP   && echo "  4. scripts/setup.sh     (git config, secrets, env vars)" \
              || echo "  4. scripts/setup.sh     SKIP (use --setup to enable)"
echo
echo " Tip: bash bootstrap.sh --help   for all options"
echo "      bash bootstrap.sh --all    to run everything"
echo "============================================================"
echo

# ---------------------------------------------------------------------------
# Step 1: chezmoi
# ---------------------------------------------------------------------------
if $OPT_CHEZMOI; then
  if ! command -v chezmoi &>/dev/null; then
    echo ">>> chezmoi not found — installing..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo ">>> chezmoi found: $(chezmoi --version)"
  fi

  echo ">>> Applying dotfiles with chezmoi..."
  chezmoi init --source="$DOTFILES_DIR" --apply
  echo ">>> Dotfiles applied."
fi

# ---------------------------------------------------------------------------
# Step 2: install packages
# ---------------------------------------------------------------------------
if $OPT_INSTALL; then
  echo ">>> Running install.sh..."
  install_args=()
  $OPT_KB  && install_args+=(--kb)
  $OPT_LLM && install_args+=(--local-llm)
  bash "$DOTFILES_DIR/scripts/install.sh" "${install_args[@]}"
fi

# ---------------------------------------------------------------------------
# Step 3: auth (optional)
# ---------------------------------------------------------------------------
if $OPT_AUTH; then
  echo ">>> Running auth.sh..."
  bash "$DOTFILES_DIR/scripts/auth.sh"
fi

# ---------------------------------------------------------------------------
# Step 4: setup (optional)
# ---------------------------------------------------------------------------
if $OPT_SETUP; then
  echo ">>> Running setup.sh..."
  bash "$DOTFILES_DIR/scripts/setup.sh"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo " Bootstrap complete!"
echo " Reload your shell: exec bash"
echo "============================================================"
