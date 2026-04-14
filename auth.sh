#!/usr/bin/env bash
# auth.sh — One-time service authentication for hgryoo/dotfiles
# Sources secrets.env for API keys, then runs interactive OAuth flows.
#
# Usage:
#   cp secrets.env.template secrets.env && $EDITOR secrets.env
#   bash auth.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/secrets.env"

# ---------------------------------------------------------------------------
# Load secrets
# ---------------------------------------------------------------------------
load_secrets() {
  if [ ! -f "$SECRETS_FILE" ]; then
    echo "ERROR: $SECRETS_FILE not found."
    echo "  Run: cp secrets.env.template secrets.env && \$EDITOR secrets.env"
    exit 1
  fi
  # shellcheck source=/dev/null
  set -a; source "$SECRETS_FILE"; set +a
  echo ">>> Loaded secrets from $SECRETS_FILE"
}

# ---------------------------------------------------------------------------
# GitHub
# ---------------------------------------------------------------------------
auth_github() {
  echo
  echo "--- GitHub ---"
  if gh auth status &>/dev/null; then
    echo ">>> Already authenticated: $(gh auth status 2>&1 | grep 'Logged in' || true)"
    return
  fi
  echo ">>> Logging in to GitHub..."
  gh auth login
  # Also export GITHUB_TOKEN if set in secrets
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo ">>> GITHUB_TOKEN is set in secrets.env (will be persisted by setup.sh)"
  fi
}

# ---------------------------------------------------------------------------
# Google Workspace (gws)
# ---------------------------------------------------------------------------
auth_google() {
  echo
  echo "--- Google Workspace (gws) ---"
  if ! command -v gws &>/dev/null; then
    echo ">>> gws not found — run install_kb.sh first."
    return
  fi
  if gws auth status &>/dev/null 2>&1; then
    echo ">>> Already authenticated with Google."
    return
  fi
  if [ -z "${GOOGLE_CLIENT_ID:-}" ] || [ -z "${GOOGLE_CLIENT_SECRET:-}" ]; then
    echo ">>> GOOGLE_CLIENT_ID/SECRET not set — running gws auth setup..."
    gws auth setup
  else
    echo ">>> Logging in to Google (using credentials from secrets.env)..."
    gws auth login
  fi
}

# ---------------------------------------------------------------------------
# rtk
# ---------------------------------------------------------------------------
auth_rtk() {
  echo
  echo "--- rtk ---"
  if ! command -v rtk &>/dev/null; then
    echo ">>> rtk not found — run install.sh first."
    return
  fi
  if rtk status &>/dev/null 2>&1; then
    echo ">>> rtk already authenticated."
    return
  fi
  echo ">>> Logging in to rtk..."
  rtk login
}

# ---------------------------------------------------------------------------
# HuggingFace
# ---------------------------------------------------------------------------
auth_huggingface() {
  echo
  echo "--- HuggingFace ---"
  if [ -z "${HUGGINGFACE_TOKEN:-}" ]; then
    echo ">>> HUGGINGFACE_TOKEN not set in secrets.env — skipping."
    return
  fi
  if command -v huggingface-cli &>/dev/null; then
    echo ">>> Logging in to HuggingFace..."
    echo "$HUGGINGFACE_TOKEN" | huggingface-cli login --token
  else
    echo ">>> huggingface-cli not found — token will be available as env var after setup.sh."
  fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  echo "============================================================"
  echo " Auth summary"
  echo "============================================================"
  gh auth status 2>/dev/null | grep -E "Logged in|account" | head -n2 || echo "GitHub     : not authenticated"
  command -v gws &>/dev/null && { gws auth status 2>/dev/null | head -n1 || echo "Google     : not authenticated"; } || echo "Google (gws): not installed"
  command -v rtk &>/dev/null && { rtk status 2>/dev/null | head -n1 || echo "rtk        : not authenticated"; } || echo "rtk        : not installed"
  [ -n "${HUGGINGFACE_TOKEN:-}" ] && echo "HuggingFace: token set" || echo "HuggingFace: token not set"
  echo "============================================================"
  echo "Run 'bash setup.sh' to persist env vars to your shell."
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  load_secrets
  auth_github
  auth_google
  auth_rtk
  auth_huggingface
  print_summary
}

main "$@"
