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
# obsidian-cli — official Obsidian CLI
# ---------------------------------------------------------------------------
install_obsidian_cli() {
  if command -v obsidian &>/dev/null; then
    echo ">>> obsidian-cli already installed ($(obsidian --version 2>/dev/null | head -n1)), skipping."
    return
  fi
  echo ">>> Installing obsidian-cli..."
  npm install -g obsidian-cli
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
# ---------------------------------------------------------------------------
install_gws() {
  if command -v gws &>/dev/null; then
    echo ">>> gws already installed, skipping."
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
  command -v obsidian &>/dev/null && echo "obsidian-cli : $(obsidian --version 2>/dev/null | head -n1)" || echo "obsidian-cli : not found"
  command -v qmd      &>/dev/null && echo "qmd          : installed"                                    || echo "qmd          : not found"
  command -v gws      &>/dev/null && echo "gws          : installed"                                    || echo "gws          : not found"
  echo "============================================================"
  echo "Next steps:"
  echo "  1. bash auth.sh          — log in to GitHub, Google, rtk"
  echo "  2. gws auth setup        — create Google Cloud project (first time)"
  echo "  3. qmd embed             — generate search embeddings"
  echo "  4. bash sync_knowledge.sh pull  — pull Obsidian vault to ~/knowledge/"
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  _check_npm
  install_obsidian_cli
  install_qmd
  install_gws
  setup_qmd_collections
  print_summary
}

main "$@"
