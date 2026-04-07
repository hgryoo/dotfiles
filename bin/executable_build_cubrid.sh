#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Error: preset is required"
  echo "Usage: $0 <preset>"
  exit 1
fi

PRESET=$1
BUILD_DIR=build_preset_$PRESET

cmake --preset "$PRESET" && \
cmake --build --preset "$PRESET" -j"$(nproc)" && \
cmake --install "$BUILD_DIR"
