#!/usr/bin/env bash
# workspace_rearrange.sh — Tier /data/workspace by what a directory holds.
#
# Before: 193 directories and 48 loose scripts at one level, where a git
# worktree, a benchmark's log dump and a 107 GB topic tree were siblings.
# 107 of the 193 were run output of two experiments (oih_*, bharness_*), each
# with the same nine files in it.
#
# After:
#   repos/     a git clone tracking an upstream
#   wt/        a git worktree
#   build/     an installed CUBRID prefix (bin/ cci/ conf/)
#   runs/      output of a measurement run — logs, .class, result dirs
#   harness/   the scripts that drive those runs
#   topic/     a topic's working tree (what for-plan/ held)
#   archive/   kept but finished
#
# Leaf names are NOT renamed. `cubrid_dev` does not become `cubrid-dev`: the
# tier is the convention, and a mass separator change would break 1160
# references in cubrid_cv for nothing. Only genuine duplicates are resolved
# (for-issue + for_issue -> topic/issue).
#
# Compatibility. cubrid_cv's notes reference old paths 1160 times, inside
# records of where something was measured. Those sentences were true when
# written, so the script does not rewrite them — it leaves a symlink at each
# old top-level name that is actually referenced. Drop them with --no-compat
# once the references are rewritten (they are listed in compat.txt).
#
# Usage:
#   scripts/workspace_rearrange.sh --dry-run     # print every move, do nothing
#   scripts/workspace_rearrange.sh               # move, then link
#   scripts/workspace_rearrange.sh --no-compat   # move without the symlinks
set -euo pipefail

ROOT="${WORKSPACE_ROOT:-/data/workspace}"
VAULT="${VAULT_ROOT:-/data/cubrid_cv}"
DRY=false
COMPAT=true

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY=true; shift ;;
    --no-compat) COMPAT=false; shift ;;
    --root)      ROOT="$2"; shift 2 ;;
    -h|--help)   sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

cd "$ROOT"
run() { if $DRY; then echo "    would: $*"; else "$@"; fi; }

# --- where does this directory belong? ------------------------------------
tier_of() {
  local d="$1"
  case "$d" in
    oih_*)                     echo "runs/oih/${d#oih_}"; return ;;
    bharness_*)                echo "runs/bharness/${d#bharness_}"; return ;;
    v7698_*)                   echo "runs/v7698/${d#v7698_}"; return ;;
    for-plan)                  echo ""; return ;;          # children handled separately
    for-bench)                 echo "topic/bench"; return ;;
    for-issue|for_issue)       echo "topic/issue"; return ;;
    for_review)                echo "topic/review"; return ;;
    backport_27218)            echo "wt/backport_27218"; return ;;
    _cleanup_backup_20260831)  echo "archive/cleanup_backup_20260831"; return ;;
    *_install|old110|old110s|old114) echo "build/$d"; return ;;
    *_repro|*_run|fix_repro|oi_variants|i30_bench|cubrid-crash-*) echo "runs/$d"; return ;;
  esac
  if   [ -d "$d/.git" ]; then echo "repos/$d"
  elif [ -f "$d/.git" ]; then echo "wt/$d"
  else                        echo "topic/$d"
  fi
}

echo "============================================================"
echo " workspace_rearrange   root=$ROOT"
$DRY && echo " MODE: dry run"
echo "============================================================"

run mkdir -p repos wt build runs harness topic archive
MOVED=0

# --- 1. for-plan children become the topic tier ---------------------------
if [ -d for-plan ]; then
  for c in for-plan/*/; do
    c="${c%/}"; name="$(basename "$c")"
    [ -e "topic/$name" ] && { echo "!!! topic/$name exists — leaving $c alone" >&2; continue; }
    run mv "$c" "topic/$name"; MOVED=$((MOVED+1))
  done
  $DRY || rmdir for-plan 2>/dev/null || true
fi

# --- 2. every other top-level directory -----------------------------------
for d in */; do
  d="${d%/}"
  case "$d" in repos|wt|build|runs|harness|topic|archive|.cache|.omc) continue ;; esac
  # A compatibility symlink from an earlier run also matches */ — leave it.
  [ -L "$d" ] && continue
  dest="$(tier_of "$d")"
  [ -z "$dest" ] && continue
  if [ -e "$dest" ]; then
    # for-issue and for_issue both land on topic/issue — merge, do not clobber
    echo ">>> merge $d -> $dest"
    run bash -c "cp -a '$d/.' '$dest/' && rm -rf '$d'"
  else
    run mkdir -p "$(dirname "$dest")"
    run mv "$d" "$dest"
  fi
  MOVED=$((MOVED+1))
done

# --- 3. loose scripts at the root become the harness ----------------------
LOOSE=0
for f in *; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  case "$f" in compat.txt|README.md|CLAUDE.md) continue ;; esac
  run mv "$f" "harness/$f"; LOOSE=$((LOOSE+1))
done

# --- 3b. repair the worktrees the moves just unlinked ---------------------
# A worktree has two pointers and the move invalidated both: the worktree's own
# .git file names the parent's admin dir (and the parent moved too), and
# .git/worktrees/<name>/gitdir names the worktree (which moved).
#
# Two things `git worktree repair` alone does not handle here:
#   - it cannot find the parent when the worktree's .git still names the old
#     parent path, so that side is rewritten first, by substitution;
#   - a submodule's .git file also lives at <dir>/.git, and handing one to
#     repair makes it error out. Worktrees point into .../worktrees/, submodules
#     into .../modules/ — filter on that.
echo ">>> repairing git worktrees"
if ! $DRY; then
  find wt build runs topic archive -maxdepth 3 -name .git -type f 2>/dev/null \
    | xargs -r grep -l "gitdir: $ROOT/[A-Za-z0-9_.-]*/\.git/worktrees/" 2>/dev/null \
    | xargs -r sed -i "s|gitdir: $ROOT/\([A-Za-z0-9_.-]*\)/\.git/worktrees/|gitdir: $ROOT/repos/\1/.git/worktrees/|"
fi

WTS=()
while IFS= read -r g; do
  grep -q "/worktrees/" "$g" 2>/dev/null && WTS+=("$ROOT/$(dirname "$g")")
done < <(find wt build runs topic archive -maxdepth 3 -name .git -type f 2>/dev/null)

for parent in repos/*/; do
  parent="${parent%/}"
  [ -d "$parent/.git" ] || continue
  git -C "$parent" worktree list >/dev/null 2>&1 || continue
  [ ${#WTS[@]} -eq 0 ] && continue
  # Paths belonging to another parent make repair print an error; that is
  # expected and not a failure of this run.
  run bash -c "git -C '$parent' worktree repair $(printf '%q ' "${WTS[@]}") 2>&1 | grep -v '^error:' || true"
done

if ! $DRY; then
  left=0
  for parent in repos/*/; do
    parent="${parent%/}"; [ -d "$parent/.git" ] || continue
    left=$((left + $(git -C "$parent" worktree list 2>/dev/null | grep -c prunable || true)))
  done
  echo ">>> worktrees still unresolved: $left"
fi

# --- 4. compatibility symlinks for the names the vault actually cites ------
LINKED=0
if $COMPAT; then
  : > /tmp/ws_compat.$$ || true
  while read -r old; do
    [ -z "$old" ] && continue
    [ -e "$old" ] && continue
    new=""
    for cand in "repos/$old" "wt/$old" "build/$old" "runs/$old" "topic/$old" "archive/$old"; do
      [ -e "$cand" ] && { new="$cand"; break; }
    done
    # On a dry run nothing has moved yet, so ask the classifier instead — but
    # only for a name that is really there. The reference scan is a regex over
    # prose and yields fragments ("CBR", "fo") from paths broken across lines.
    [ -z "$new" ] && $DRY && [ -e "$old" ] && new="$(tier_of "$old")"
    # for-plan children moved to topic/, and the for-* names were renamed
    case "$old" in
      for-plan)   new="topic" ;;
      for-bench)  new="topic/bench" ;;
      for-issue|for_issue) new="topic/issue" ;;
      for_review) new="topic/review" ;;
    esac
    # loose scripts the vault cites by bare name now live in harness/
    [ -z "$new" ] && [ -e "harness/$old" ] && new="harness/$old"
    [ -z "$new" ] && continue
    run ln -s "$new" "$old"
    echo "$old -> $new" >> /tmp/ws_compat.$$
    LINKED=$((LINKED+1))
  done < <(grep -rhoE "/data/workspace/[A-Za-z0-9._-]+" "$VAULT" \
             --exclude-dir=.git --exclude-dir=.omc 2>/dev/null \
           | sed 's|/data/workspace/||' | sort -u)
  if ! $DRY; then
    { echo "# Compatibility symlinks left by workspace_rearrange.sh on $(date +%Y-%m-%d)."
      echo "# Each is an old top-level name that cubrid_cv still cites. Remove them"
      echo "# once those references are rewritten: xargs rm < this file's first column."
      echo
      sort /tmp/ws_compat.$$ 2>/dev/null
    } > compat.txt
    rm -f /tmp/ws_compat.$$
  fi
fi

echo
echo "============================================================"
echo " moved=$MOVED  loose-scripts=$LOOSE  compat-links=$LINKED"
$DRY || echo " compat list: $ROOT/compat.txt"
echo "============================================================"
