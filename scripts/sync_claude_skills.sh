#!/usr/bin/env bash
# Keep every Claude Code account's skill set identical.
#
#   bash sync_claude_skills.sh            # sync all accounts to the union
#   bash sync_claude_skills.sh --dry-run  # say what would change
#   bash sync_claude_skills.sh --from ~/.claude   # treat one account as the source
#
# There are three accounts on this machine — cl (~/.claude), clc
# (~/.claude-cubrid) and clt (~/.cubrid-cubrid1) — and a skill installed into
# only one of them is a skill you cannot call from the other two. That drift is
# easy to create: most installers write to ~/.claude and stop, and the CUBRID
# scaffold hardcodes it outright.
#
# An account is a directory holding settings.json; that is what separates the
# three from the sessions and scratch directories sitting beside them. Entries
# are replicated the way they already exist — a symlink is recreated pointing at
# the same target, a real directory is copied — so this works whichever
# installer produced it. Dangling symlinks (a skill renamed or removed upstream)
# are cleaned out rather than propagated.
set -uo pipefail

DRY=0
SOURCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY=1; shift ;;
    --from) SOURCE="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- accounts
ACCOUNTS=()
for d in "$HOME"/.claude "$HOME"/.claude-* "$HOME"/.cubrid-*; do
  [ -d "$d" ] && [ -f "$d/settings.json" ] || continue
  ACCOUNTS+=("$d")
done
if [ ${#ACCOUNTS[@]} -lt 2 ]; then
  echo "only ${#ACCOUNTS[@]} Claude account(s) found — nothing to sync."
  exit 0
fi
echo ">>> accounts: ${ACCOUNTS[*]}"

# ------------------------------------------------------- prune dangling links
pruned=0
for acct in "${ACCOUNTS[@]}"; do
  [ -d "$acct/skills" ] || continue
  for link in "$acct/skills"/*; do
    [ -L "$link" ] && [ ! -e "$link" ] || continue
    echo "    prune  $(basename "$acct")/$(basename "$link")  (target gone)"
    [ "$DRY" -eq 1 ] || rm -f "$link"
    pruned=$((pruned + 1))
  done
done

# --------------------------------------------------------------- the union
# Without --from, every account contributes: the union is what all of them get.
declare -A SRC_OF=()
for acct in "${ACCOUNTS[@]}"; do
  [ -n "$SOURCE" ] && [ "$acct" != "$SOURCE" ] && continue
  [ -d "$acct/skills" ] || continue
  for entry in "$acct/skills"/*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    [ -n "${SRC_OF[$name]:-}" ] || SRC_OF[$name]="$entry"
  done
done
echo ">>> union: ${#SRC_OF[@]} skill(s)"

# ------------------------------------------------------------------- apply
added=0
for acct in "${ACCOUNTS[@]}"; do
  mkdir -p "$acct/skills"
  for name in "${!SRC_OF[@]}"; do
    dest="$acct/skills/$name"
    [ -e "$dest" ] && continue
    src="${SRC_OF[$name]}"
    if [ -L "$src" ]; then
      echo "    link   $(basename "$acct")/$name"
      [ "$DRY" -eq 1 ] || ln -s "$(readlink -f "$src")" "$dest"
    else
      echo "    copy   $(basename "$acct")/$name"
      [ "$DRY" -eq 1 ] || cp -r "$src" "$dest"
    fi
    added=$((added + 1))
  done
done

echo
if [ "$DRY" -eq 1 ]; then
  echo ">>> dry run — would prune $pruned, add $added"
else
  echo ">>> pruned $pruned, added $added"
  for acct in "${ACCOUNTS[@]}"; do
    printf '    %-32s %s skills\n' "$(basename "$acct")" "$(ls "$acct/skills" | wc -l)"
  done
  echo ">>> restart Claude Code (or reload skills) to pick them up."
fi
