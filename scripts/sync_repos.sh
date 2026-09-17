#!/usr/bin/env bash
# sync_repos.sh — Bring every git repo under $DATA_ROOT up to date with its
# upstream, and say what it could not do.
#
# Default is read-only: fetch, then a table of where each repo stands. Nothing
# in a working tree changes until you pass --pull, and even then:
#
#   - a dirty repo is skipped (never stashed);
#   - a detached HEAD is skipped;
#   - a branch with no upstream is skipped;
#   - the merge is --ff-only, so a diverged branch is reported, not rebased.
#
# Worktrees are followed, but the fetch happens once per repository — twenty
# worktrees of one clone do not fetch twenty times.
#
# Scope. By default every checkout under $DATA_ROOT, which includes the CUBRID
# source trees and the worktrees in workspace/. `--base` narrows it to the
# **foundation repos** — the ones that carry configuration, notes and tooling
# rather than a project's source:
#
#   ~/dotfiles              this repo
#   /data/cubrid_cv         the CUBRID work vault
#   /data/cub_sys/roadmap   the roadmap projects
#   /data/hgryoo/*          personal + knowledge-base repos
#
# `/data/hgryoo/references/*` is left out of --base: those are upstream source
# mirrors (cubrid, postgres) kept for reading, and pulling them is a large
# transfer nobody is waiting on. `--refs` adds them.
#
# Usage:
#   scripts/sync_repos.sh                 # fetch + report, everything
#   scripts/sync_repos.sh --base --pull   # foundation repos, fast-forward
#   scripts/sync_repos.sh --base --refs   # + the upstream mirrors
#   scripts/sync_repos.sh --no-fetch      # report from what is already local
#   scripts/sync_repos.sh --root /data    # default
set -euo pipefail

DATA_ROOT="${DATA_ROOT:-/data}"
DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
DO_FETCH=true
DO_PULL=false
SCOPE=all
WITH_REFS=false

while [ $# -gt 0 ]; do
  case "$1" in
    --pull)     DO_PULL=true ;;
    --base)     SCOPE=base ;;
    --refs)     WITH_REFS=true ;;
    --no-fetch) DO_FETCH=false ;;
    --root)     DATA_ROOT="$2"; shift ;;
    --root=*)   DATA_ROOT="${1#*=}" ;;
    -h|--help)  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# --- find every repository and every worktree -----------------------------
# A .git directory is a repository; a .git file is a worktree (or a submodule,
# which we leave to its parent).
if [ "$SCOPE" = base ]; then
  mapfile -t CHECKOUTS < <(
    {
      echo "$DOTFILES_DIR"
      echo "$DATA_ROOT/cubrid_cv"
      echo "$DATA_ROOT/cub_sys/roadmap"
      find "$DATA_ROOT/hgryoo" -maxdepth 1 -mindepth 1 -type d \
           -not -name references 2>/dev/null
      $WITH_REFS && find "$DATA_ROOT/hgryoo/references" -maxdepth 1 -mindepth 1 -type d 2>/dev/null
    } | while read -r d; do [ -d "$d/.git" ] && echo "$d"; done | sort -u
  )
else
  mapfile -t CHECKOUTS < <(
    find "$DATA_ROOT" -maxdepth 4 -name .git \
         -not -path "*/.cache/*" -not -path "*/node_modules/*" 2>/dev/null \
    | while read -r g; do
        if [ -d "$g" ]; then dirname "$g"
        elif grep -q "/worktrees/" "$g" 2>/dev/null; then dirname "$g"
        fi
      done | sort -u
  )
fi

# One fetch per repository, not per worktree: group by the common git dir.
declare -A FETCHED=()
FETCH_FAIL=()

printf '%-44s %-30s %-6s %-7s %-6s %-5s %s\n' REPO BRANCH AHEAD BEHIND TRACKED UNTR NOTE
printf '%.0s-' {1..128}; echo

MOVED=0; SKIPPED=0

for c in "${CHECKOUTS[@]}"; do
  common=$(git -C "$c" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue

  if $DO_FETCH && [ -z "${FETCHED[$common]:-}" ]; then
    FETCHED[$common]=1
    git -C "$c" fetch --all --prune --quiet 2>/dev/null || FETCH_FAIL+=("$c")
  fi

  branch=$(git -C "$c" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
  # Only tracked changes block a fast-forward. An untracked file cannot be
  # overwritten silently — git refuses the merge itself and says which path —
  # and counting them here meant one scratch directory (a stray notes/ dir)
  # stopped a repo 140 commits behind from ever moving.
  dirty=$(git -C "$c" status --porcelain --untracked-files=no 2>/dev/null | wc -l)
  untracked=$(git -C "$c" ls-files --others --exclude-standard 2>/dev/null | wc -l)
  note=""; ahead="-"; behind="-"

  if [ "$branch" = "HEAD" ]; then
    note="detached"
  elif ! git -C "$c" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    note="no upstream"
  else
    ahead=$(git -C "$c" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')
    behind=$(git -C "$c" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo '?')
    if $DO_PULL; then
      if [ "$dirty" -ne 0 ]; then
        note="skipped: $dirty tracked change(s)"; SKIPPED=$((SKIPPED+1))
      elif [ "$behind" = "0" ]; then
        note="up to date"
      elif [ "$ahead" != "0" ]; then
        note="skipped: diverged ($ahead ahead)"; SKIPPED=$((SKIPPED+1))
      elif git -C "$c" merge --ff-only '@{u}' --quiet 2>/dev/null; then
        note="fast-forwarded $behind"; behind=0; MOVED=$((MOVED+1))
      else
        # The usual cause is an incoming file whose path an untracked file
        # already occupies; git named it on stderr.
        note="ff refused (untracked=$untracked)"; SKIPPED=$((SKIPPED+1))
      fi
    fi
  fi

  printf '%-44s %-30s %-6s %-7s %-6s %-5s %s\n' \
    "$(printf %s "$c" | sed -e "s|^$DATA_ROOT/||" -e "s|^$HOME|~|")" \
    "${branch:0:30}" "$ahead" "$behind" "$dirty" "$untracked" "$note"
done

echo
echo "scope=$SCOPE  checkouts=${#CHECKOUTS[@]}  repositories fetched=${#FETCHED[@]}"
$DO_PULL && echo "fast-forwarded=$MOVED  skipped=$SKIPPED"
if [ ${#FETCH_FAIL[@]} -gt 0 ]; then
  echo "fetch failed (${#FETCH_FAIL[@]}):"
  printf '  - %s\n' "${FETCH_FAIL[@]}"
fi
