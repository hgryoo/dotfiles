#!/usr/bin/env bash
# workspace_reclaim.sh — Delete what /data/workspace can remake.
#
# Nothing here is a source, a result or a log. Each tier is output of a command
# that can be run again, and the command is named so you know the cost.
#
#   --builds    cmake build trees (build_preset_*, build_x86_64*, build_dbg)
#               Remade by: scripts/build_cubrid.sh <preset>
#               Cost: a full compile. ccache makes the second one much cheaper.
#
#   --installs  install prefixes (install.out, _CUBRID, _CUBRID_DBG)
#               Remade by: cmake --install <build dir>
#               KEEPS two children of each prefix:
#                 databases/  data, not output — a reinstall writes around it
#                 log/        the server's own logs and coredumps. Not remade
#                             by anything, and seven vault documents cite paths
#                             inside them (…/install.out/log/coredump…).
#               Those two are ~11 GB and 13 GB of what looks reclaimable here
#               and is not.
#
#   --logs      the log/ directory of an install prefix — server error logs,
#               broker logs and coredumps. Read the citation warning above
#               before using it. Never part of --all.
#
#   --dbs       the databases/ volumes themselves, inside a prefix or not.
#               Remade by: whatever created the database (cubrid createdb,
#               a repro script, a loaddb). NOT free — some carry loaded data.
#               Off by default and never part of --all.
#
#   --caches    vscode-server CLI versions older than the newest.
#               Remade by: reconnecting the IDE (re-downloads).
#
#   --all       --builds --installs --caches   (never --dbs)
#
# Usage:
#   scripts/workspace_reclaim.sh --dry-run --all   # list every path and size
#   scripts/workspace_reclaim.sh --builds
set -euo pipefail

ROOT="${WORKSPACE_ROOT:-/data/workspace}"
DRY=false
DO_BUILDS=false DO_INSTALLS=false DO_DBS=false DO_CACHES=false DO_LOGS=false

[ $# -eq 0 ] && { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY=true ;;
    --builds)   DO_BUILDS=true ;;
    --installs) DO_INSTALLS=true ;;
    --dbs)      DO_DBS=true ;;
    --logs)     DO_LOGS=true ;;
    --caches)   DO_CACHES=true ;;
    --all)      DO_BUILDS=true; DO_INSTALLS=true; DO_CACHES=true ;;
    --root)     ROOT="$2"; shift ;;
    -h|--help)  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

cd "$ROOT"

# Refuse to delete under a tree something is actively using.
busy() {
  local d="$1" p exe cwd
  for p in /proc/[0-9]*; do
    exe=$(readlink "$p/exe" 2>/dev/null) || true
    cwd=$(readlink "$p/cwd" 2>/dev/null) || true
    case "$exe$cwd" in "$ROOT/$d"*) return 0 ;; esac
  done
  return 1
}

FREED=0
kill_dir() {
  local d="${1#./}"
  [ -d "$d" ] || return 0
  local sz; sz=$(du -sm "$d" 2>/dev/null | cut -f1)
  if busy "$d"; then echo "    SKIP (in use) $d"; return 0; fi
  if $DRY; then printf '    would rm %6s MB  %s\n' "$sz" "$d"
  else rm -rf -- "$d"; printf '    rm %6s MB  %s\n' "$sz" "$d"; fi
  FREED=$((FREED + sz))
}

echo "============================================================"
echo " workspace_reclaim   root=$ROOT"
$DRY && echo " MODE: dry run"
df -h "$ROOT" | tail -1 | sed 's/^/ before: /'
echo "============================================================"

if $DO_BUILDS; then
  echo ">>> build trees"
  while IFS= read -r d; do kill_dir "$d"; done < <(
    find . -type d \( -name "build_preset_*" -o -name "build_x86_64*" -o -name "build_dbg" \) -prune 2>/dev/null)
fi

if $DO_INSTALLS; then
  echo ">>> install prefixes (databases/ kept)"
  while IFS= read -r p; do
    p="${p#./}"
    [ -d "$p" ] || continue
    for child in "$p"/* "$p"/.[!.]*; do
      [ -e "$child" ] || continue
      case "$(basename "$child")" in databases|log) continue ;; esac
      kill_dir "$child"
    done
  done < <(find . -type d \( -name "install.out" -o -name "_CUBRID" -o -name "_CUBRID_DBG" \) -prune 2>/dev/null)
fi

if $DO_LOGS; then
  echo ">>> install-prefix log/ dirs  (server logs and coredumps — cited by the vault)"
  while IFS= read -r p; do
    p="${p#./}"; [ -d "$p/log" ] && kill_dir "$p/log"
  done < <(find . -type d \( -name "install.out" -o -name "_CUBRID" -o -name "_CUBRID_DBG" \) -prune 2>/dev/null)
fi

if $DO_DBS; then
  echo ">>> database volumes  (these hold loaded data — you asked for it)"
  while IFS= read -r d; do kill_dir "$d"; done < <(
    find . -type d -name databases -prune 2>/dev/null)
fi

if $DO_CACHES; then
  echo ">>> vscode-server CLI versions except the newest"
  local_dir=.cache/vscode-server/cli/servers
  if [ -d "$local_dir" ]; then
    find "$local_dir" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null \
      | sort -rn | tail -n +2 | cut -d' ' -f2- | while IFS= read -r d; do kill_dir "$d"; done
  fi
fi

echo
echo "============================================================"
printf ' freed: %s MB (%.1f GB)\n' "$FREED" "$(echo "$FREED" | awk '{print $1/1024}')"
df -h "$ROOT" | tail -1 | sed 's/^/ after:  /'
echo "============================================================"
