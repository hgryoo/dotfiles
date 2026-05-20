#!/usr/bin/env bash
# cubrid-clone.sh — Clone cubrid/cubrid (develop only) and register hgryoo + cub_sys remotes.
#
# Usage:
#   cubrid-clone.sh <proj_name>
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $(basename "$0") <proj_name>" >&2
  exit 1
fi

PROJ=$1

git clone -b develop --single-branch https://github.com/cubrid/cubrid "$PROJ"

cd "$PROJ"
git remote add hgryoo  https://github.com/hgryoo/cubrid.git
git remote add cub_sys https://github.com/cubrid-systems/cubrid.git

git remote -v
