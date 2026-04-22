#!/usr/bin/env bash
# install_kb.sh — Knowledge Base tools for Claude Code
# Requires: npm (Node.js 18+), install.sh already run.
set -euo pipefail

# ---------------------------------------------------------------------------
# npm check
# ---------------------------------------------------------------------------
_check_npm() {
  if ! command -v npm &>/dev/null; then
    echo "ERROR: npm not found. Install Node.js 18+ first." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Google Cloud CLI (required by gws)
# ---------------------------------------------------------------------------
install_gcloud() {
  if command -v gcloud &>/dev/null; then
    echo ">>> gcloud already installed, skipping."
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

# ---------------------------------------------------------------------------
# obsidian-cli — official Obsidian CLI
# ---------------------------------------------------------------------------
install_obsidian_cli() {
  # Check npm global list — 'command -v obsidian' may find the GUI desktop app
  if npm list -g obsidian-cli &>/dev/null; then
    echo ">>> obsidian-cli already installed, skipping."
    return
  fi
  echo ">>> Installing obsidian-cli..."
  npm install -g obsidian-cli --ignore-scripts
}

# ---------------------------------------------------------------------------
# qmd — local AI search engine for markdown (notebooklm alternative)
# ---------------------------------------------------------------------------
install_qmd() {
  if command -v qmd &>/dev/null; then
    echo ">>> qmd already installed, skipping."
    return
  fi
  echo ">>> Installing qmd (@tobilu/qmd)..."
  npm install -g @tobilu/qmd
}

# ---------------------------------------------------------------------------
# gws — Google Workspace CLI (Drive, Gmail, Calendar, ...)
# Requires: Google Cloud CLI (gcloud)
# ---------------------------------------------------------------------------
install_gws() {
  if command -v gws &>/dev/null; then
    echo ">>> gws already installed, skipping."
    return
  fi
  if ! command -v gcloud &>/dev/null; then
    echo "WARNING: gcloud not found — gws requires Google Cloud CLI."
    echo "  Install gcloud first, then re-run."
    return
  fi
  echo ">>> Installing Google Workspace CLI (gws)..."
  npm install -g @googleworkspace/cli
}

# ---------------------------------------------------------------------------
# qmd collections — index ~/obsidian/ and ~/knowledge/
# ---------------------------------------------------------------------------
setup_qmd_collections() {
  if ! command -v qmd &>/dev/null; then
    echo ">>> qmd not found — skipping collection setup."
    return
  fi

  mkdir -p "$HOME/obsidian" "$HOME/knowledge"

  if qmd collection list 2>/dev/null | grep -q "obsidian"; then
    echo ">>> qmd collections already configured, skipping."
    return
  fi

  echo ">>> Configuring qmd collections..."
  qmd collection add "$HOME/obsidian"  --name obsidian  || true
  qmd collection add "$HOME/knowledge" --name knowledge || true
  qmd context add qmd://obsidian  "Obsidian vault — primary knowledge base and Claude-generated documents"
  qmd context add qmd://knowledge "Local knowledge snapshot — staged and reference documents for Claude Code"
  echo ">>> qmd collections configured. Run 'qmd embed' to generate embeddings."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  echo "============================================================"
  echo " KB install summary"
  echo "============================================================"
  command -v gcloud   &>/dev/null && echo "gcloud       : installed" || echo "gcloud       : not found"
  npm list -g obsidian-cli &>/dev/null && echo "obsidian-cli : installed" || echo "obsidian-cli : not found"
  command -v qmd      &>/dev/null && echo "qmd          : installed"                                    || echo "qmd          : not found"
  command -v gws      &>/dev/null && echo "gws          : installed"                                    || echo "gws          : not found"
  echo "============================================================"
  echo "Next steps:"
  echo "  1. bash scripts/auth.sh          — log in to GitHub, Google"
  echo "  2. gws auth setup        — create Google Cloud project (first time)"
  echo "  3. qmd embed             — generate search embeddings"
  echo "  4. bash scripts/sync_knowledge.sh pull  — pull Obsidian vault to ~/knowledge/"
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  _check_npm
  install_gcloud
  install_obsidian_cli
  install_qmd
  install_gws
  setup_qmd_collections
  print_summary
}

main "$@"
