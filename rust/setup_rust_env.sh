#!/usr/bin/env bash
set -e

echo ">>> Installing Rust via rustup..."
if ! command -v rustup &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

source $HOME/.cargo/env
rustup update
rustup default stable

echo ">>> Installing useful cargo tools..."
cargo install cargo-edit cargo-outdated cargo-watch cargo-audit cargo-expand

echo "✅ Rust toolchain ready."

