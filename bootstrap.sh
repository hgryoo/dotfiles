#!/usr/bin/env bash
# bootstrap.sh — Single entry point for setting up dotfiles on a fresh machine.
# Usage: git clone <repo> ~/dotfiles && ~/dotfiles/bootstrap.sh
#
# What it does:
#   1. Installs chezmoi (if not already installed)
#   2. Applies dotfiles via chezmoi (configs → home directory)
#   3. Runs install.sh (packages → system)
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " dotfiles bootstrap"
echo " Source: $DOTFILES_DIR"
echo "============================================================"

# ---------------------------------------------------------------------------
# Step 1: Install chezmoi if not present
# ---------------------------------------------------------------------------
if ! command -v chezmoi &>/dev/null; then
  echo ">>> chezmoi not found — installing..."
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
else
  echo ">>> chezmoi found: $(chezmoi --version)"
fi

# ---------------------------------------------------------------------------
# Step 2: Apply dotfiles
# ---------------------------------------------------------------------------
echo ">>> Applying dotfiles with chezmoi..."
chezmoi init --source="$DOTFILES_DIR" --apply

echo ">>> Dotfiles applied."

# ---------------------------------------------------------------------------
# Step 3: Install packages
# ---------------------------------------------------------------------------
echo ">>> Running install.sh..."
bash "$DOTFILES_DIR/install.sh"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo " Bootstrap complete!"
echo " Reload your shell: exec bash"
echo "============================================================"
