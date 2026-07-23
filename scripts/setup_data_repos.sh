#!/usr/bin/env bash
# setup_data_repos.sh — Recreate the Claude knowledge repositories under $DATA_ROOT
#                       (default /data) on a fresh machine.
#
# What this clones (idempotent — existing repos are skipped, never overwritten):
#
#   cubrid_cv/   single repo — carries its own issue/ plan/ history/ ... content
#   cub_sys/     container of the cubrid-systems working repos
#   hgryoo/      container of personal + knowledge-base repos
#   hgryoo/references/  upstream source mirrors (cubrid, postgres) — read-only
#
# Deliberately NOT handled here (large / machine-local, provision separately):
#   /data/workspace     build/scratch worktrees (symlink targets below)
#   /data/bench_data    ~14G TPC-C datasets
#   /data/dev           ~16G build tree
#   /data/.omc          Claude session state (per-machine)
#
# Requires: git, and GitHub auth for private repos (run `gh auth login` first,
# or have a git credential helper configured). Failed clones are reported at the
# end and do not abort the rest of the run.
#
# Usage:
#   scripts/setup_data_repos.sh                 # clone everything into /data
#   scripts/setup_data_repos.sh --root ~/data   # clone into a different root
#   scripts/setup_data_repos.sh --only hgryoo   # one group only
#   scripts/setup_data_repos.sh --full          # full clone of reference mirrors
#   scripts/setup_data_repos.sh --list          # print the manifest and exit
set -euo pipefail

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
DATA_ROOT="${DATA_ROOT:-/data}"
ONLY=""
FULL_REFS=false

usage() {
  sed -n '2,27p' "$0"
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --root)  DATA_ROOT="$2"; shift 2 ;;
    --root=*) DATA_ROOT="${1#*=}"; shift ;;
    --only)  ONLY="$2"; shift 2 ;;
    --only=*) ONLY="${1#*=}"; shift ;;
    --full)  FULL_REFS=true; shift ;;
    --list)  ONLY="__list__"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; echo; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# Manifest — one entry per repo:  group|dest(relative to root)|branch|url|flags
#   branch empty  -> clone the remote's default branch
#   flags "big"   -> shallow single-branch clone unless --full is given
# ---------------------------------------------------------------------------
MANIFEST=(
  # --- cubrid_cv : one repo, brings its own issue/ plan/ ... subtrees ---
  "cubrid_cv|cubrid_cv|main|https://github.com/hgryoo/cubrid-cv.git|"

  # --- cub_sys : cubrid-systems working repos ---
  "cub_sys|cub_sys/cubrid||https://github.com/cubrid-systems/cubrid|"
  "cub_sys|cub_sys/benchbase|cubrid-p1|https://github.com/cubrid-systems/benchbase.git|"
  "cub_sys|cub_sys/cubrid-dev-docs|main|https://github.com/cubrid-systems/cubrid-dev-docs|"
  "cub_sys|cub_sys/cubrid-engine-suite|main|https://github.com/cubrid-systems/cubrid-engine-suite|"
  "cub_sys|cub_sys/cubrid-testkit|main|https://github.com/cubrid-systems/cubrid-testkit.git|"
  "cub_sys|cub_sys/cubrid-testtools|feature/ai_support|https://github.com/cubrid-systems/cubrid-testtools|"
  "cub_sys|cub_sys/.github|main|https://github.com/cubrid-systems/.github|"
  "cub_sys|cub_sys/HammerDB|cubrid-p1|https://github.com/cubrid-systems/HammerDB.git|"
  "cub_sys|cub_sys/roadmap|main|https://github.com/cubrid-systems/roadmap.git|"

  # --- hgryoo : personal + knowledge-base repos ---
  "hgryoo|hgryoo/cubrid-doxygen|main|https://github.com/hgryoo/cubrid-doxygen|"
  "hgryoo|hgryoo/hgryoo|main|https://github.com/hgryoo/hgryoo|"
  "hgryoo|hgryoo/hgryoo.github.io|main|https://github.com/hgryoo/hgryoo.github.io|"
  "hgryoo|hgryoo/knowledge-base|main|https://github.com/hgryoo/knowledge-base.git|"
  "hgryoo|hgryoo/knowledge-base-site|main|https://github.com/hgryoo/knowledge-base-site.git|"
  "hgryoo|hgryoo/knowledge-docs-site|main|https://github.com/hgryoo/knowledge-docs-site.git|"
  "hgryoo|hgryoo/knowledge-slides|main|https://github.com/hgryoo/knowledge-slides.git|"
  "hgryoo|hgryoo/knowledge-slides-site|main|https://github.com/hgryoo/knowledge-slides-site.git|"
  "hgryoo|hgryoo/scaffold|main|https://github.com/hgryoo/scaffold.git|"

  # --- upstream source mirrors (read-only reference reading) ---
  "references|hgryoo/references/cubrid|develop|https://github.com/cubrid/cubrid|big"
  "references|hgryoo/references/postgres|REL_18_STABLE|https://github.com/postgres/postgres.git|big"
)

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
CLONED=(); SKIPPED=(); FAILED=()

clone_one() {
  local group="$1" dest="$2" branch="$3" url="$4" flags="$5"
  local abs="$DATA_ROOT/$dest"

  if [ -n "$ONLY" ] && [ "$ONLY" != "$group" ]; then
    return 0
  fi

  if [ -d "$abs/.git" ]; then
    echo ">>> skip   $dest (already present)"
    SKIPPED+=("$dest"); return 0
  fi
  if [ -e "$abs" ]; then
    echo "!!! skip   $dest (path exists but is not a git repo) — leaving untouched" >&2
    FAILED+=("$dest (path exists, not a repo)"); return 0
  fi

  local args=(clone)
  [ -n "$branch" ] && args+=(--branch "$branch")
  if [[ "$flags" == *big* ]] && ! $FULL_REFS; then
    args+=(--depth 1 --single-branch)
  fi
  args+=("$url" "$abs")

  echo ">>> clone  $dest  <-  $url${branch:+  [$branch]}"
  mkdir -p "$(dirname "$abs")"
  if git "${args[@]}"; then
    CLONED+=("$dest")
  else
    echo "!!! FAILED $dest" >&2
    FAILED+=("$dest ($url)")
  fi
}

# ---------------------------------------------------------------------------
# --list mode
# ---------------------------------------------------------------------------
if [ "$ONLY" = "__list__" ]; then
  printf '%-42s %-18s %s\n' "DEST" "BRANCH" "URL"
  for e in "${MANIFEST[@]}"; do
    IFS='|' read -r g d b u f <<<"$e"
    printf '%-42s %-18s %s\n' "$DATA_ROOT/$d" "${b:-<default>}" "$u"
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
echo "============================================================"
echo " setup_data_repos — cloning Claude knowledge repos"
echo " Root: $DATA_ROOT"
[ -n "$ONLY" ] && echo " Group filter: $ONLY"
echo "============================================================"

command -v git >/dev/null || { echo "ERROR: git not found." >&2; exit 1; }
mkdir -p "$DATA_ROOT"

for e in "${MANIFEST[@]}"; do
  IFS='|' read -r g d b u f <<<"$e"
  clone_one "$g" "$d" "$b" "$u" "$f"
done

# ---------------------------------------------------------------------------
# Post-clone: structural symlinks, project env file, empty dirs
# (only when the relevant group was cloned)
# ---------------------------------------------------------------------------
in_group() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

if in_group cubrid_cv && [ -d "$DATA_ROOT/cubrid_cv" ]; then
  # cubrid_cv/workspace -> /data/workspace  (target provisioned separately)
  ln -sfn "$DATA_ROOT/workspace" "$DATA_ROOT/cubrid_cv/workspace"
  echo ">>> link   cubrid_cv/workspace -> $DATA_ROOT/workspace"
fi

if in_group cub_sys && [ -d "$DATA_ROOT/cub_sys" ]; then
  ln -sfn "$DATA_ROOT/workspace/cubrid-systems" "$DATA_ROOT/cub_sys/workspace"
  echo ">>> link   cub_sys/workspace -> $DATA_ROOT/workspace/cubrid-systems"
  mkdir -p "$DATA_ROOT/cub_sys/lob"

  # Project-local CUBRID env (not tracked in any repo — regenerate it here)
  cat > "$DATA_ROOT/cub_sys/.cubrid.sh" <<EOF
# Project-local CUBRID environment for $DATA_ROOT/cub_sys/
#
# Source this file (not execute): \`. $DATA_ROOT/cub_sys/.cubrid.sh\`
#
# Points \$CUBRID at the build output of $DATA_ROOT/cub_sys/cubrid (the source
# tree cloned into this project), using the conventional \`install.out/\` prefix.
# Build CUBRID first (cmake + make install into the prefix below) before the
# server commands resolve.

CUBRID=$DATA_ROOT/cub_sys/cubrid/install.out
CUBRID_DATABASES=\$CUBRID/databases
export CUBRID CUBRID_DATABASES

LD_LIBRARY_PATH=\$CUBRID/lib:\$CUBRID/cci/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
PATH=\$CUBRID/bin:/usr/sbin\${PATH:+:\$PATH}
export LD_LIBRARY_PATH PATH
EOF
  echo ">>> write  cub_sys/.cubrid.sh"
fi

if in_group hgryoo && [ -f "$DATA_ROOT/hgryoo/scaffold/install.sh" ]; then
  # Wire the general-purpose Claude Code skills + CLI tools into the user
  # environment now that the scaffold repo is on disk. install.sh symlinks each
  # skill into ~/.claude/skills/ and each tool into ~/.local/bin/ (idempotent).
  # bootstrap.sh runs scripts/install.sh BEFORE this data-clone step, so on a
  # fresh machine the scaffold isn't present yet when install.sh's
  # install_scaffold_skills() runs — this post-clone hook is what actually wires
  # it the first time. (The CUBRID skills are a separate scaffold, not touched.)
  echo ">>> install scaffold skills + tools (-> ~/.claude/skills, ~/.local/bin)"
  bash "$DATA_ROOT/hgryoo/scaffold/install.sh" \
    || echo "!!! scaffold install.sh reported an error — run it by hand." >&2
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo " Done.  cloned=${#CLONED[@]}  skipped=${#SKIPPED[@]}  failed=${#FAILED[@]}"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo " Failed:"
  printf '   - %s\n' "${FAILED[@]}"
  echo " (private repo? run 'gh auth login' or configure a git credential helper, then re-run)"
fi
echo "============================================================"
[ ${#FAILED[@]} -eq 0 ]
