#!/usr/bin/env bash
# install_local_llm.sh — Local LLM environment setup for hgryoo/dotfiles
# Supports Ubuntu (apt) and Rocky Linux 9 (dnf).
# Run after install.sh — uv, Rust, and cmake must already be in place.
set -euo pipefail

LLAMA_CPP_DIR="$HOME/.local/share/llama.cpp"
VLLM_VENV="$HOME/.local/share/vllm-env"
OLLAMA_MODELS_DIR="${OLLAMA_MODELS_DIR:-/data/local_llm/models}"
OLLAMA_BIND_HOST="${OLLAMA_BIND_HOST:-0.0.0.0:11434}"
OLLAMA_OVERRIDE_FILE="/etc/systemd/system/ollama.service.d/override.conf"

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
    echo ">>> Ollama already installed ($(ollama --version 2>/dev/null | head -n1)), skipping install."
  else
    echo ">>> Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  configure_ollama_storage
}

# ---------------------------------------------------------------------------
# Ollama storage + bind address (systemd drop-in)
# Redirects model storage to $OLLAMA_MODELS_DIR (default /data/local_llm/models)
# and binds the API on $OLLAMA_BIND_HOST so containers on the host network
# (e.g. Open Notebook) can reach it.
# ---------------------------------------------------------------------------
configure_ollama_storage() {
  if ! systemctl list-unit-files ollama.service &>/dev/null; then
    echo ">>> ollama.service not found — skipping storage config (manual ollama install?)."
    return
  fi

  local desired
  desired=$(printf '[Service]\nEnvironment="OLLAMA_MODELS=%s"\nEnvironment="OLLAMA_HOST=%s"\n' \
              "$OLLAMA_MODELS_DIR" "$OLLAMA_BIND_HOST")

  if [ -f "$OLLAMA_OVERRIDE_FILE" ] && [ "$(sudo cat "$OLLAMA_OVERRIDE_FILE")" = "$desired" ]; then
    echo ">>> Ollama systemd override already up to date, skipping."
    return
  fi

  echo ">>> Configuring Ollama: models -> $OLLAMA_MODELS_DIR, bind -> $OLLAMA_BIND_HOST"

  sudo mkdir -p "$OLLAMA_MODELS_DIR"
  if id ollama &>/dev/null; then
    sudo chown -R ollama:ollama "$OLLAMA_MODELS_DIR"
  fi

  sudo mkdir -p "$(dirname "$OLLAMA_OVERRIDE_FILE")"
  echo "$desired" | sudo tee "$OLLAMA_OVERRIDE_FILE" >/dev/null

  sudo systemctl daemon-reload
  sudo systemctl restart ollama
  echo ">>> Ollama restarted with new storage + bind config."
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
# Defaults to gemma4:26b (MoE, 3.8B active). Override with GEMMA4_TAG env var.
# ---------------------------------------------------------------------------
install_gemma4() {
  if ! command -v ollama &>/dev/null; then
    echo "ERROR: Ollama not found — install Ollama first." >&2
    return 1
  fi

  # Default to 26B MoE (3.8B active params, fits on 24GB GPU).
  # Override with GEMMA4_TAG=4b or GEMMA4_TAG=26b-a4b-it-q4_K_M etc.
  local tag="${GEMMA4_TAG:-26b}"
  local model="gemma4:${tag}"

  if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$model"; then
    echo ">>> $model already pulled, skipping."
    echo "    Run 'ollama pull $model' to update."
    return
  fi

  echo ">>> Pulling $model via Ollama..."
  echo "    (Override tag with: GEMMA4_TAG=<tag> bash install_local_llm.sh)"
  ollama pull "$model"
}

# ---------------------------------------------------------------------------
# EmbeddingGemma — Google's 308M on-device embedding model (Gemma 3 based).
# Used by Open Notebook / RAG pipelines for vector retrieval.
# Override default tag with EMBEDDINGGEMMA_TAG env var.
# ---------------------------------------------------------------------------
install_embeddinggemma() {
  if ! command -v ollama &>/dev/null; then
    echo "ERROR: Ollama not found — install Ollama first." >&2
    return 1
  fi

  local tag="${EMBEDDINGGEMMA_TAG:-latest}"
  local model="embeddinggemma:${tag}"

  if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$model"; then
    echo ">>> $model already pulled, skipping."
    return
  fi

  echo ">>> Pulling $model via Ollama..."
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
  [ -f "$OLLAMA_OVERRIDE_FILE" ]                  && echo "Ollama cfg : models=$OLLAMA_MODELS_DIR host=$OLLAMA_BIND_HOST" || echo "Ollama cfg : default (no override)"
  [ -x "$LLAMA_CPP_DIR/build/bin/llama-cli" ]    && echo "llama.cpp  : built at $LLAMA_CPP_DIR"           || echo "llama.cpp  : not found"
  [ -x "$VLLM_VENV/bin/vllm" ]                   && echo "vLLM       : installed at $VLLM_VENV"           || echo "vLLM       : not found"
  ollama list 2>/dev/null | grep -q "gemma4"      && echo "Gemma 4    : pulled"                            || echo "Gemma 4    : not pulled"
  ollama list 2>/dev/null | grep -q "embeddinggemma" && echo "EmbeddingGemma : pulled"                      || echo "EmbeddingGemma : not pulled"
  echo "============================================================"
  echo "Tips:"
  echo "  ollama run gemma4:26b      — interactive chat (MoE, 3.8B active)"
  echo "  llama-server --help        — start llama.cpp HTTP server"
  echo "  vllm serve google/gemma-4  — start vLLM OpenAI-compatible server"
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# openclaw (npm global, optional Claude-compatible CLI)
# ---------------------------------------------------------------------------
install_openclaw() {
  if ! command -v npm &>/dev/null; then
    echo "WARNING: npm not found, cannot install openclaw." >&2
    return
  fi
  if npm list -g openclaw &>/dev/null; then
    echo ">>> openclaw already installed, skipping."
    return
  fi
  echo ">>> Installing openclaw (npm global)..."
  npm install -g openclaw
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
  install_embeddinggemma
  install_openclaw

  print_summary
}

main "$@"
