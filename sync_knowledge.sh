#!/usr/bin/env bash
# sync_knowledge.sh — rsync between ~/obsidian/ (vault) and ~/knowledge/ (local snapshot)
#
# Usage:
#   bash sync_knowledge.sh pull   # ~/obsidian/ → ~/knowledge/
#   bash sync_knowledge.sh push   # ~/knowledge/ → ~/obsidian/
set -euo pipefail

VAULT="$HOME/obsidian"
SNAPSHOT="$HOME/knowledge"

_ensure_dirs() {
  mkdir -p "$VAULT" "$SNAPSHOT"
}

pull() {
  echo ">>> Pulling: $VAULT → $SNAPSHOT"
  rsync -av --delete "$VAULT/" "$SNAPSHOT/"
  echo ">>> Pull complete."
}

push() {
  echo ">>> Pushing: $SNAPSHOT → $VAULT"
  rsync -av --delete "$SNAPSHOT/" "$VAULT/"
  echo ">>> Push complete."
}

_ensure_dirs
case "${1:-}" in
  pull) pull ;;
  push) push ;;
  *)
    echo "Usage: $(basename "$0") pull|push"
    echo "  pull  ~/obsidian/ → ~/knowledge/  (update local snapshot from vault)"
    echo "  push  ~/knowledge/ → ~/obsidian/  (write local changes back to vault)"
    exit 1
    ;;
esac
