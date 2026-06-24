#!/usr/bin/env bash
# cl-tabs.sh — Gather all `claude` tmux sessions launched under a path (or its
# subdirs) into a single session as tabs (windows), using link-window.
#
# Why link-window (not move-window): the source sessions stay alive and own
# their windows, so killing the aggregator session never kills the Claude
# panes. Re-run any time to rebuild the view.
#
# Usage:
#   cl-tabs [base-dir] [name]
#   cl-tabs                  # base = $PWD;   name = cltabs-<basename>
#   cl-tabs /data/cub_sys    # -> session 'cltabs-cub_sys'
#   cl-tabs /data/cubrid_cv  # -> session 'cltabs-cubrid_cv'  (coexists)
#   cl-tabs /data/cub_sys cub   # explicit name override
#
# Each path gets its own aggregator by default, so run it from several
# locations and keep them all. Re-running a path rebuilds that one. Sessions
# match tmux #{session_path} == base or under base/, names starting `claude-`.
set -uo pipefail

case "${1:-}" in
  -h|--help)
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

command -v tmux >/dev/null 2>&1 || { echo "cl-tabs: tmux not found" >&2; exit 1; }

base="${1:-$PWD}"
base="$(realpath -m -- "$base" 2>/dev/null || echo "$base")"
# Default name derived from the base dir so different paths coexist as
# separate sessions (e.g. /data/cub_sys -> cltabs-cub_sys). Override via $2.
agg="${2:-cltabs-$(basename -- "$base" | tr -c 'A-Za-z0-9_-' '-' | sed 's/-\{1,\}$//')}"

mapfile -t sessions < <(
  tmux list-sessions -F '#{session_name}	#{session_path}' 2>/dev/null \
  | awk -F'\t' -v b="$base/" -v be="$base" \
      '$1 ~ /^claude-/ && ($2 == be || index($2, b) == 1) { print $1 }'
)

if ((${#sessions[@]} == 0)); then
  echo "cl-tabs: no claude-* sessions under $base" >&2
  exit 1
fi

# Fresh aggregator each run (killing it only unlinks; source sessions persist).
tmux has-session -t "$agg" 2>/dev/null && tmux kill-session -t "$agg"

# Placeholder window so the session exists; remember its id to drop it later.
# base-index may be 1, so link starting after the current max index.
ph="$(tmux new-session -d -P -F '#{window_id}' -s "$agg" -c "$base")"
i=$(( "$(tmux list-windows -t "$agg" -F '#{window_index}' | sort -n | tail -1)" + 1 ))

for s in "${sessions[@]}"; do
  tmux link-window -d -s "$s" -t "${agg}:${i}" \
    && i=$((i + 1)) \
    || echo "cl-tabs: warn: could not link $s" >&2
done

tmux kill-window -t "$ph"            # remove placeholder
tmux select-window -t "$agg"         # focus first real tab

echo "cl-tabs: ${#sessions[@]} session(s) under $base -> '$agg'" >&2
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$agg"
else
  tmux attach -t "$agg"
fi
