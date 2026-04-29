#!/usr/bin/env bash
# install_mcp.sh — Idempotent Claude Code MCP server registration (user scope).
#
# Run AFTER scripts/install.sh has installed any MCP-providing tools
# (e.g. install_token_savior). Re-running is safe; already-registered
# servers are skipped.
#
# Usage:
#   bash scripts/install_mcp.sh              # register all known servers
#   bash scripts/install_mcp.sh token-savior # register a specific one

set -euo pipefail

if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH. Install Claude Code first (scripts/install.sh)." >&2
  exit 1
fi

# Cache claude mcp list once (it makes a network call for cloud servers).
MCP_LIST="$(claude mcp list 2>/dev/null || true)"

mcp_already_registered() {
  # $1 = server name (matches start of line in `claude mcp list` output)
  echo "$MCP_LIST" | grep -q "^$1[[:space:]]\|^$1:"
}

register_token_savior() {
  if mcp_already_registered "token-savior"; then
    echo ">>> token-savior MCP already registered (user scope), skipping."
    return
  fi
  if ! command -v token-savior &>/dev/null; then
    echo "WARNING: 'token-savior' binary not in PATH. Install via:" >&2
    echo "         uv tool install 'token-savior-recall[mcp]'" >&2
    return
  fi
  local bin
  bin="$(command -v token-savior)"
  echo ">>> Registering token-savior MCP (user scope) → $bin"
  claude mcp add --scope user token-savior -- "$bin"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  register_token_savior
else
  for name in "$@"; do
    case "$name" in
      token-savior) register_token_savior ;;
      *) echo "Unknown MCP server: $name" >&2; exit 1 ;;
    esac
  done
fi

echo
echo ">>> MCP registration pass complete. Verify with: claude mcp list"
