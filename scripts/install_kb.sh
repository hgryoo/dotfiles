#!/usr/bin/env bash
# install_kb.sh — Knowledge Base tools for Claude Code
# Requires: npm (Node.js 18+), install.sh already run.
set -euo pipefail

# ---------------------------------------------------------------------------
# npm check
# ---------------------------------------------------------------------------
_check_npm() {
  if ! command -v npm &>/dev/null; then
    echo "ERROR: npm not found. Install Node.js 18+ first." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Docker + compose plugin (required by open-notebook)
# ---------------------------------------------------------------------------
install_docker() {
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    echo ">>> docker + compose plugin already installed, skipping."
  elif command -v docker &>/dev/null; then
    echo "WARNING: docker installed but 'docker compose' plugin missing."
    echo "  Install with: sudo apt-get install -y docker-compose-plugin"
    return
  else
    echo ">>> Installing Docker via official convenience script..."
    curl -fsSL https://get.docker.com | sh
  fi
  if ! id -nG "$USER" | grep -qw docker; then
    echo ">>> Adding $USER to docker group (sudo required)..."
    sudo usermod -aG docker "$USER"
    echo ">>> Log out / back in (or run 'newgrp docker') to use docker without sudo."
  fi
}

# ---------------------------------------------------------------------------
# Google Cloud CLI (required by gws)
# ---------------------------------------------------------------------------
install_gcloud() {
  if command -v gcloud &>/dev/null; then
    echo ">>> gcloud already installed, skipping."
    return
  fi
  if [ -x "$HOME/google-cloud-sdk/bin/gcloud" ]; then
    echo ">>> gcloud found at ~/google-cloud-sdk (not on PATH) — skipping install."
    echo ">>> Run 'source ~/google-cloud-sdk/path.bash.inc' or restart your shell."
    return
  fi
  echo ">>> Installing Google Cloud CLI..."
  curl https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="$HOME"
  echo ">>> gcloud installed. Run 'source ~/.bashrc' or restart your shell to use it."
}

# ---------------------------------------------------------------------------
# obsidian-cli — official Obsidian CLI
# ---------------------------------------------------------------------------
install_obsidian_cli() {
  # Check npm global list — 'command -v obsidian' may find the GUI desktop app
  if npm list -g obsidian-cli &>/dev/null; then
    echo ">>> obsidian-cli already installed, skipping."
    return
  fi
  echo ">>> Installing obsidian-cli..."
  npm install -g obsidian-cli --ignore-scripts
}

# ---------------------------------------------------------------------------
# qmd — lightweight local markdown AI search (ad-hoc / temp KB).
# Heavyweight NotebookLM-equivalent integration lives in open-notebook below.
# ---------------------------------------------------------------------------
install_qmd() {
  if command -v qmd &>/dev/null; then
    echo ">>> qmd already installed, skipping."
    return
  fi
  echo ">>> Installing qmd (@tobilu/qmd)..."
  npm install -g @tobilu/qmd
}

# ---------------------------------------------------------------------------
# gws — Google Workspace CLI (Drive, Gmail, Calendar, ...)
# Requires: Google Cloud CLI (gcloud)
# ---------------------------------------------------------------------------
install_gws() {
  if command -v gws &>/dev/null; then
    echo ">>> gws already installed, skipping."
    return
  fi
  if ! command -v gcloud &>/dev/null; then
    echo "WARNING: gcloud not found — gws requires Google Cloud CLI."
    echo "  Install gcloud first, then re-run."
    return
  fi
  echo ">>> Installing Google Workspace CLI (gws)..."
  npm install -g @googleworkspace/cli
}

# ---------------------------------------------------------------------------
# open-notebook — self-hosted NotebookLM alternative (Docker compose).
# Stage only: write docker-compose.yml + .env symlink. User brings it up
# manually with `docker compose up -d`. https://github.com/lfnovo/open-notebook
# ---------------------------------------------------------------------------
install_open_notebook() {
  local dir="$HOME/open-notebook"
  local secrets="$HOME/dotfiles/secrets.env"
  local compose_file="$dir/docker-compose.yml"

  mkdir -p "$dir"

  if [ -f "$compose_file" ]; then
    echo ">>> open-notebook already staged at $dir, skipping compose write."
  else
    echo ">>> Writing $compose_file..."
    cat > "$compose_file" <<'EOF'
services:
  surrealdb:
    image: surrealdb/surrealdb:v2
    command: start --log info --user root --pass root rocksdb:/mydata/mydatabase.db
    user: root
    ports:
      - "8000:8000"
    volumes:
      - ./surreal_data:/mydata
    restart: always

  open_notebook:
    image: lfnovo/open_notebook:v1-latest
    ports:
      - "8502:8502"
      - "5055:5055"
    environment:
      - OPEN_NOTEBOOK_ENCRYPTION_KEY=${OPEN_NOTEBOOK_ENCRYPTION_KEY}
      - SURREAL_URL=ws://surrealdb:8000/rpc
      - SURREAL_USER=root
      - SURREAL_PASSWORD=root
      - SURREAL_NAMESPACE=open_notebook
      - SURREAL_DATABASE=open_notebook
    volumes:
      - ./notebook_data:/app/data
    depends_on:
      - surrealdb
    restart: always
EOF
  fi

  # Symlink .env -> dotfiles/secrets.env so compose interpolates
  # ${OPEN_NOTEBOOK_ENCRYPTION_KEY} (only referenced vars reach the container).
  if [ ! -e "$dir/.env" ] && [ -f "$secrets" ]; then
    ln -s "$secrets" "$dir/.env"
    echo ">>> Linked $dir/.env -> $secrets"
  fi

  # Ensure encryption key exists in secrets.env (generate if missing or empty)
  if [ -f "$secrets" ]; then
    if ! grep -qE '^OPEN_NOTEBOOK_ENCRYPTION_KEY=.+' "$secrets"; then
      local key
      key=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 64)
      # Replace empty assignment if present, else append.
      if grep -q '^OPEN_NOTEBOOK_ENCRYPTION_KEY=$' "$secrets"; then
        sed -i "s|^OPEN_NOTEBOOK_ENCRYPTION_KEY=$|OPEN_NOTEBOOK_ENCRYPTION_KEY=${key}|" "$secrets"
      else
        {
          printf '\n# Open Notebook (auto-generated by install_kb.sh)\n'
          printf 'OPEN_NOTEBOOK_ENCRYPTION_KEY=%s\n' "$key"
        } >> "$secrets"
      fi
      echo ">>> Generated OPEN_NOTEBOOK_ENCRYPTION_KEY into $secrets"
    fi
  else
    echo "WARNING: $secrets not found — skipping encryption key setup."
    echo "  Copy secrets.env.template to secrets.env and re-run."
  fi
}

# ---------------------------------------------------------------------------
# qmd collections — index ~/obsidian/ and ~/knowledge/
# ---------------------------------------------------------------------------
setup_qmd_collections() {
  if ! command -v qmd &>/dev/null; then
    echo ">>> qmd not found — skipping collection setup."
    return
  fi

  mkdir -p "$HOME/obsidian" "$HOME/knowledge"

  if qmd collection list 2>/dev/null | grep -q "obsidian"; then
    echo ">>> qmd collections already configured, skipping."
    return
  fi

  echo ">>> Configuring qmd collections..."
  qmd collection add "$HOME/obsidian"  --name obsidian  || true
  qmd collection add "$HOME/knowledge" --name knowledge || true
  qmd context add qmd://obsidian  "Obsidian vault — primary knowledge base and Claude-generated documents"
  qmd context add qmd://knowledge "Local knowledge snapshot — staged and reference documents for Claude Code"
  echo ">>> qmd collections configured. Run 'qmd embed' to generate embeddings."
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  echo
  echo "============================================================"
  echo " KB install summary"
  echo "============================================================"
  command -v docker   &>/dev/null && echo "docker       : installed" || echo "docker       : not found"
  command -v gcloud   &>/dev/null && echo "gcloud       : installed" || echo "gcloud       : not found"
  npm list -g obsidian-cli &>/dev/null && echo "obsidian-cli : installed" || echo "obsidian-cli : not found"
  command -v qmd      &>/dev/null && echo "qmd          : installed" || echo "qmd          : not found"
  command -v gws      &>/dev/null && echo "gws          : installed" || echo "gws          : not found"
  [ -f "$HOME/open-notebook/docker-compose.yml" ] \
    && echo "open-notebook: staged at ~/open-notebook (not running)" \
    || echo "open-notebook: not staged"
  echo "============================================================"
  echo "Next steps:"
  echo "  1. bash scripts/auth.sh          — log in to GitHub, Google"
  echo "  2. gws auth setup        — create Google Cloud project (first time)"
  echo "  3. qmd embed             — generate search embeddings (lightweight ad-hoc KB)"
  echo "  4. cd ~/open-notebook && docker compose up -d   — start open-notebook (UI: http://localhost:8502)"
  echo "  5. bash scripts/sync_knowledge.sh pull  — pull Obsidian vault to ~/knowledge/"
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  _check_npm
  install_docker
  install_gcloud
  install_obsidian_cli
  install_qmd
  install_gws
  setup_qmd_collections
  install_open_notebook
  print_summary
}

main "$@"
