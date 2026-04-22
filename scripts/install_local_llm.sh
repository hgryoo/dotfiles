#!/usr/bin/env bash
# install_local_llm.sh — Local LLM environment setup for hgryoo/dotfiles
# Supports Ubuntu (apt) and Rocky Linux 9 (dnf).
# Run after install.sh — uv, Rust, and cmake must already be in place.
set -euo pipefail

LLAMA_CPP_DIR="$HOME/.local/share/llama.cpp"
VLLM_VENV="$HOME/.local/share/vllm-env"

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
  else
    echo "ERROR: /etc/os-release not found — cannot detect OS." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Ollama
# ---------------------------------------------------------------------------
install_ollama() {
  if command -v ollama &>/dev/null; then
    echo ">>> Ollama already installed ($(ollama --version 2>/dev/null | head -n1)), skipping."
    return
  fi
  echo ">>> Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
}

# ---------------------------------------------------------------------------
# llama.cpp — build from source with CUDA if available
# ---------------------------------------------------------------------------
install_llamacpp() {
  if [ -x "$LLAMA_CPP_DIR/build/bin/llama-cli" ]; then
    echo ">>> llama.cpp already built, skipping."
    return
  fi

  echo ">>> Installing llama.cpp build dependencies..."
  case "$OS_ID" in
    ubuntu) sudo apt-get install -y build-essential cmake git libssl-dev ;;
    rocky)  sudo dnf install -y gcc-c++ cmake git openssl-devel ;;
  esac

  echo ">>> Cloning llama.cpp..."
  if [ -d "$LLAMA_CPP_DIR" ]; then
    git -C "$LLAMA_CPP_DIR" pull --ff-only
  else
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_CPP_DIR"
  fi

  echo ">>> Building llama.cpp..."
  local cmake_flags=()
  if command -v nvcc &>/dev/null; then
    echo ">>> CUDA detected — enabling GGML_CUDA."
    cmake_flags+=("-DGGML_CUDA=ON")
  fi

  cmake -B "$LLAMA_CPP_DIR/build" "${cmake_flags[@]}" "$LLAMA_CPP_DIR"
  cmake --build "$LLAMA_CPP_DIR/build" --config Release -j "$(nproc)"

  # Symlink main binaries to ~/.local/bin
  mkdir -p "$HOME/.local/bin"
  for bin in llama-cli llama-server llama-quantize; do
    local bin_path="$LLAMA_CPP_DIR/build/bin/$bin"
    if [ -x "$bin_path" ]; then
      ln -sf "$bin_path" "$HOME/.local/bin/$bin"
    fi
  done

  echo ">>> llama.cpp built and linked to ~/.local/bin."
}

# ---------------------------------------------------------------------------
# vLLM — installed in a dedicated uv venv
# ---------------------------------------------------------------------------
install_vllm() {
  if [ -x "$VLLM_VENV/bin/vllm" ]; then
    echo ">>> vLLM already installed, skipping."
    return
  fi

  if ! command -v uv &>/dev/null; then
    echo "ERROR: uv not found — run install.sh first." >&2
    return 1
  fi

  echo ">>> Creating vLLM venv at $VLLM_VENV..."
  uv venv "$VLLM_VENV" --python 3.12

  echo ">>> Installing vLLM (requires CUDA)..."
  uv pip install --python "$VLLM_VENV/bin/python" vllm

  # Wrapper so `vllm` is accessible from PATH without activating the venv
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/vllm" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/share/vllm-env/bin/vllm" "$@"
EOF
  chmod +x "$HOME/.local/bin/vllm"

  echo ">>> vLLM installed. Wrapper at ~/.local/bin/vllm."
}

# ---------------------------------------------------------------------------
# Google Gemma 4 — pulled via Ollama
# Defaults to gemma4:4b. Override with GEMMA4_TAG env var.
# ---------------------------------------------------------------------------
install_gemma4() {
  if ! command -v ollama &>/dev/null; then
    echo "ERROR: Ollama not found — install Ollama first." >&2
    return 1
  fi

  local tag="${GEMMA4_TAG:-4b}"
  local model="gemma4:${tag}"

  if ollama list 2>/dev/null | grep -q "gemma4"; then
    echo ">>> Gemma 4 model already pulled, skipping."
    echo "    Run 'ollama pull $model' to update."
    return
  fi

  echo ">>> Pulling $model via Ollama..."
  echo "    (Override size with: GEMMA4_TAG=26b bash install_local_llm.sh)"
  ollama pull "$model"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  echo "============================================================"
  echo " Local LLM install summary"
  echo "============================================================"
  command -v ollama   &>/dev/null && echo "Ollama     : $(ollama --version 2>/dev/null | head -n1)"       || echo "Ollama     : not found"
  [ -x "$LLAMA_CPP_DIR/build/bin/llama-cli" ]    && echo "llama.cpp  : built at $LLAMA_CPP_DIR"           || echo "llama.cpp  : not found"
  [ -x "$VLLM_VENV/bin/vllm" ]                   && echo "vLLM       : installed at $VLLM_VENV"           || echo "vLLM       : not found"
  ollama list 2>/dev/null | grep -q "gemma4"      && echo "Gemma 4    : pulled"                            || echo "Gemma 4    : not pulled"
  echo "============================================================"
  echo "Tips:"
  echo "  ollama run gemma4:4b       — interactive chat"
  echo "  llama-server --help        — start llama.cpp HTTP server"
  echo "  vllm serve google/gemma-4  — start vLLM OpenAI-compatible server"
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  detect_os
  echo ">>> Detected OS: $OS_ID"

  install_ollama
  install_llamacpp
  install_vllm
  install_gemma4

  print_summary
}

main "$@"
