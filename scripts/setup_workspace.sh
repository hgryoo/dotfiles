#!/usr/bin/env bash
# setup_workspace.sh — Recreate the /data/workspace skeleton on a new machine.
#
# What this does and does not do
# ------------------------------
# /data/workspace is 261 GB, and almost none of it is worth carrying: build
# trees, CUBRID database volumes, benchmark run output. What is worth carrying
# is the *shape* — which directory holds which PR, which branch each worktree
# sits on, where a topic's work tree lives — because that is what the notes in
# cubrid_cv point at.
#
# So this script reads workspace/manifest.txt and:
#
#   CLONE     clones the repo at that path, on that branch
#   WORKTREE  re-adds the worktree from its parent repo, on that branch
#   DIR       creates the directory, empty
#
# Content is not restored. Build, run and measure again on the new machine.
#
# Usage:
#   scripts/setup_workspace.sh --dry-run          # print what would happen
#   scripts/setup_workspace.sh                    # DIR + WORKTREE only
#   scripts/setup_workspace.sh --clones           # + clone the 17 repos (slow)
#   scripts/setup_workspace.sh --root /mnt/work   # somewhere other than /data/workspace
#
# Regenerate the manifest on the machine that still has the tree:
#   scripts/setup_workspace.sh --emit > workspace/manifest.txt
set -euo pipefail

ROOT="${WORKSPACE_ROOT:-/data/workspace}"
# readlink -f so the path still resolves when run through /data/ops's symlink
MANIFEST="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)/workspace/manifest.txt"
DRY=false
DO_CLONES=false

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

emit_manifest() {
  cd "$ROOT"
  echo "# /data/workspace manifest — generated $(date +%Y-%m-%d) on $(hostname)"
  echo "#"
  echo "# The tree is tiered by what a directory holds (see README.md):"
  echo "#   repos/ wt/ build/ runs/ harness/ topic/ archive/"
  echo "# Only the canonical repo of a worktree set is listed as a parent"
  echo "# (repos/cubrid_11_4 would be a worktree of repos/cubrid_dev, not a repo)."
  echo "# Compatibility symlinks at the root are listed in compat.txt, not here."
  echo
  echo "## WORKTREE  <path>|<parent-repo>|<branch>"
  for parent in repos/*/; do
    parent="${parent%/}"
    [ -d "$parent/.git" ] || continue
    git -C "$parent" worktree list --porcelain 2>/dev/null | awk -v p="$parent" -v r="$ROOT" '
      function flush() {
        if (wt != "" && wt != r "/" p && index(wt, r "/") == 1)
          print substr(wt, length(r)+2) "|" p "|" (br != "" ? br : sha)
        wt=""; br=""; sha=""
      }
      /^worktree /{ flush(); wt=$2 }
      /^HEAD /{ sha=$2 }
      /^branch /{ br=$2; sub("refs/heads/","",br) }
      END{ flush() }' \
    | while IFS='|' read -r rel par br; do
        # git recorded the path as it was given, which may have gone through a
        # compatibility symlink (for_issue/… instead of topic/issue/…). Record
        # the canonical one so the manifest does not depend on those links.
        can=$(realpath -m --relative-to="$ROOT" "$ROOT/$rel" 2>/dev/null || echo "$rel")
        echo "WORKTREE $can|$par|$br"
      done
  done | sort -u
  echo
  echo "## CLONE  <path>|<origin-url>|<branch>"
  for d in repos/*/; do
    d="${d%/}"
    [ -d "$d/.git" ] || continue
    url=$(git -C "$d" remote get-url origin 2>/dev/null) || continue
    echo "CLONE $d|$url|$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  done | sort
  echo
  echo "## DIR  <path>   (recreated empty — content is rebuilt, not carried)"
  for tier in build runs topic archive; do
    [ -d "$tier" ] || continue
    echo "DIR $tier"
    find "$tier" -mindepth 1 -maxdepth 2 -type d -not -path "*/.git/*" 2>/dev/null \
      | while read -r d; do [ -e "$d/.git" ] && continue; echo "DIR $d"; done
  done | sort -u
  echo "DIR harness"
  echo "DIR wt"
  echo "DIR repos"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY=true; shift ;;
    --clones)   DO_CLONES=true; shift ;;
    --root)     ROOT="$2"; shift 2 ;;
    --root=*)   ROOT="${1#*=}"; shift ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --emit)     emit_manifest; exit 0 ;;
    -h|--help)  usage ;;
    *) echo "Unknown option: $1" >&2; echo; usage >&2 ;;
  esac
done

[ -f "$MANIFEST" ] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

run() { if $DRY; then echo "    would: $*"; else "$@"; fi; }

DIRS=0; WTS=0; CLONES=0; SKIPPED=0; FAILED=()

echo "============================================================"
echo " setup_workspace — recreating the /data/workspace skeleton"
echo " Root:     $ROOT"
echo " Manifest: $MANIFEST"
$DRY && echo " MODE:     dry run (nothing is created)"
echo "============================================================"

mkdir -p "$ROOT"

# --- 1. plain directories -------------------------------------------------
while IFS= read -r line; do
  path="${line#DIR }"
  if [ -d "$ROOT/$path" ]; then SKIPPED=$((SKIPPED+1)); continue; fi
  run mkdir -p "$ROOT/$path"; DIRS=$((DIRS+1))
done < <(grep '^DIR ' "$MANIFEST")
echo ">>> directories: $DIRS created, $SKIPPED already present"

# --- 2. clones (opt-in: 17 repos, tens of GB) ------------------------------
if $DO_CLONES; then
  while IFS= read -r line; do
    IFS='|' read -r path url branch <<<"${line#CLONE }"
    if [ -e "$ROOT/$path/.git" ]; then SKIPPED=$((SKIPPED+1)); continue; fi
    case "$url" in
      /*|file:*) echo "!!! $path: origin is a local path ($url) that will not exist here — clone it by hand." >&2
                 FAILED+=("$path (local origin $url)"); continue ;;
    esac
    echo ">>> clone $path <- $url [$branch]"
    run git clone --branch "$branch" "$url" "$ROOT/$path" \
      || { FAILED+=("$path ($url)"); continue; }
    CLONES=$((CLONES+1))
  done < <(grep '^CLONE ' "$MANIFEST")
  echo ">>> clones: $CLONES"
else
  echo ">>> clones: skipped (pass --clones to fetch them)"
fi

# --- 3. worktrees ---------------------------------------------------------
# A worktree needs its parent repo on disk and its branch to exist there.
while IFS= read -r line; do
  IFS='|' read -r path parent branch <<<"${line#WORKTREE }"
  if [ -e "$ROOT/$path/.git" ]; then SKIPPED=$((SKIPPED+1)); continue; fi
  if [ ! -d "$ROOT/$parent/.git" ]; then
    FAILED+=("$path (parent $parent not cloned)"); continue
  fi
  if ! git -C "$ROOT/$parent" rev-parse --verify --quiet "$branch" >/dev/null; then
    FAILED+=("$path (branch $branch missing in $parent)"); continue
  fi
  echo ">>> worktree $path <- $parent [$branch]"
  run git -C "$ROOT/$parent" worktree add "$ROOT/$path" "$branch" \
    || { FAILED+=("$path (worktree add failed)"); continue; }
  WTS=$((WTS+1))
done < <(grep '^WORKTREE ' "$MANIFEST")
echo ">>> worktrees: $WTS"

echo
echo "============================================================"
echo " Done.  dirs=$DIRS clones=$CLONES worktrees=$WTS skipped=$SKIPPED"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo " Not created (${#FAILED[@]}):"
  printf '   - %s\n' "${FAILED[@]}"
fi
echo "============================================================"
