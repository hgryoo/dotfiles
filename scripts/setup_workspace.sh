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

EMIT_FORCE=false

# The canonical manifest is topic-centric: a topic owns its checkouts, builds
# and run output. A tree still in the older shape — wt/, build/ and runs/ as
# siblings of topic/ at the root — emits a manifest in that older shape, and
# writing it over the canonical one silently reverts the layout for every
# machine built from it afterwards. Refuse unless asked twice.
emit_guard() {
  if [ -d "$ROOT/wt" ] || [ -d "$ROOT/build" ] || [ -d "$ROOT/runs" ]; then
    $EMIT_FORCE && { echo "# WARNING: emitted from a pre-topic-centric tree." >&2; return 0; }
    cat >&2 <<'MSG'
ERROR: this tree is not topic-centric — it has wt/, build/ or runs/ at the root.

Emitting from it produces a manifest in that older shape, and writing that over
workspace/manifest.txt reverts the canonical layout for every machine set up
from it later.

If you meant to capture this tree anyway, pass --emit-force and send the output
somewhere other than workspace/manifest.txt.
MSG
    exit 1
  fi
}

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
  echo "## DIR  <path>   (created empty)"
  # Only the axis: the tiers and one entry per topic. A per-run or per-build
  # directory is a byproduct whose value was its contents, and nothing carries
  # those — listing them just makes a new machine full of empty shells.
  {
    echo "DIR repos"
    echo "DIR harness"
    echo "DIR archive"
    [ -d topic ] && find topic -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
      | while read -r d; do echo "DIR $d"; done
  } | sort -u
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY=true; shift ;;
    --clones)   DO_CLONES=true; shift ;;
    --root)     ROOT="$2"; shift 2 ;;
    --root=*)   ROOT="${1#*=}"; shift ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --emit)     emit_guard; emit_manifest; exit 0 ;;
    --emit-force) EMIT_FORCE=true; emit_guard; emit_manifest; exit 0 ;;
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

# --- 2b. the two documents that tell an agent where to go -----------------
# workspace/CLAUDE.md is read by Claude Code when it works under this tree, and
# README.md is the human-facing layout. Both are symlinks into this repo so
# there is one copy: editing either edits the source, and a `git pull` moves
# them on every machine at once.
DOCS_SRC="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)/workspace"
for doc in CLAUDE.md README.md; do
  if [ ! -f "$DOCS_SRC/$doc" ]; then
    echo "!!! $DOCS_SRC/$doc missing — skipping the link." >&2
    continue
  fi
  if [ -e "$ROOT/$doc" ] && [ ! -L "$ROOT/$doc" ]; then
    echo ">>> $doc exists and is not a symlink — leaving it alone."
    continue
  fi
  run ln -sfn "$DOCS_SRC/$doc" "$ROOT/$doc"
  echo ">>> link   $doc -> $DOCS_SRC/$doc"
done

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
