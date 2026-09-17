#!/usr/bin/env bash
# cl-tabs / clc-tabs — Gather all `claude` tmux sessions launched under a path
# (or its subdirs) into a single session as tabs (windows), using link-window.
#
# Two views, by account (mirrors the cl / clc launchers):
#   cl-tabs   → personal-account sessions  (names like  claude-<slug>-<pid>)
#   clc-tabs  → cubrid-account sessions     (names like  claudec-<slug>-<pid>)
# clc-tabs is a symlink to this script; the mode is read from argv[0].
#
# Why link-window (not move-window): the source sessions stay alive and own
# their windows, so killing the aggregator session never kills the Claude
# panes. Re-run any time to rebuild the view.
#
# Usage:
#   cl-tabs  [base-dir] [name]       # personal-account view
#   clc-tabs [base-dir] [name]       # cubrid-account view
#   cl-tabs                          # base = $PWD;  name = cltabs-<basename>
#   clc-tabs /data/cubrid_cv         # -> session 'clctabs-cubrid_cv'
#   cl-tabs /data/cub_sys cub        # explicit name override
#
# Each path gets its own aggregator by default, so run it from several
# locations and keep them all. Re-running a path rebuilds that one. Sessions
# match tmux #{session_path} == base or under base/, with the account's prefix.
set -uo pipefail

# Mode from invocation name: clc-tabs → cubrid account, else personal.
case "$(basename -- "$0")" in
  clc-tabs|clctabs|clc-tabs.sh) mode=cubrid;   name_re='^claudec-'; agg_pre=clctabs ;;
  *)                            mode=personal; name_re='^claude-';  agg_pre=cltabs  ;;
esac

case "${1:-}" in
  -h|--help)
    awk 'NR>1 && /^#/{sub(/^# ?/,"");print;next} NR>1{exit}' "$0"
    exit 0
    ;;
esac

command -v tmux >/dev/null 2>&1 || { echo "${0##*/}: tmux not found" >&2; exit 1; }

base="${1:-$PWD}"
base="$(realpath -m -- "$base" 2>/dev/null || echo "$base")"
# Default name derived from the base dir so different paths coexist as
# separate sessions (e.g. /data/cubrid_cv -> clctabs-cubrid_cv). Override via $2.
agg="${2:-${agg_pre}-$(basename -- "$base" | tr -c 'A-Za-z0-9_-' '-' | sed 's/-\{1,\}$//')}"

# Note: the personal regex ^claude- does NOT match ^claudec- (7th char differs),
# so the two views never overlap. Legacy sessions named claude-* (created before
# clc gained its own prefix) still show under cl-tabs until they are restarted.
mapfile -t sessions < <(
  tmux list-sessions -F '#{session_name}	#{session_path}' 2>/dev/null \
  | awk -F'\t' -v b="$base/" -v be="$base" -v re="$name_re" \
      '$1 ~ re && ($2 == be || index($2, b) == 1) { print $1 }'
)

if ((${#sessions[@]} == 0)); then
  echo "${0##*/}: no ${mode} claude sessions under $base" >&2
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
    || echo "${0##*/}: warn: could not link $s" >&2
done

tmux kill-window -t "$ph"            # remove placeholder
tmux select-window -t "$agg"         # focus first real tab

echo "${0##*/}: ${#sessions[@]} ${mode} session(s) under $base -> '$agg'" >&2
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$agg"
else
  tmux attach -t "$agg"
fi
