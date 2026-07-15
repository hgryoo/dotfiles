# hgryoo/dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports Ubuntu and Rocky Linux 9.

## Setup Flow

```
bootstrap.sh [OPTIONS]           ← single entry point
│
├─ chezmoi apply                 (deploy configs to ~)
│
├─ scripts/install.sh            (base packages, dev tools, Claude Code)
│   ├─ --kb:        scripts/install_kb.sh   (gcloud, obsidian-cli, qmd, gws)
│   └─ --local-llm: scripts/install_local_llm.sh (ollama, llama.cpp, vLLM, gemma4)
│
├─ --auth → scripts/auth.sh     (GitHub, Google, HuggingFace OAuth)
│
├─ --setup → scripts/setup.sh   (git config, env vars → ~/.config/personal/env)
│
└─ --data → scripts/setup_data_repos.sh  (clone /data knowledge repos)
```

## Quick Start

### Fresh machine (full setup)

```sh
git clone https://github.com/hgryoo/dotfiles ~/dotfiles
cd ~/dotfiles
cp secrets.env.template secrets.env
$EDITOR secrets.env              # fill in API keys

bash bootstrap.sh --all          # chezmoi + install + auth + setup + kb + llm
```

### Fresh machine (base only)

```sh
git clone https://github.com/hgryoo/dotfiles ~/dotfiles
bash ~/dotfiles/bootstrap.sh
```

### Packages only (skip chezmoi)

```sh
bash bootstrap.sh --install-only                  # base only
bash bootstrap.sh --install-only --kb             # base + knowledge base
bash bootstrap.sh --install-only --local-llm      # base + local LLM
bash bootstrap.sh --install-only --kb --local-llm # base + kb + llm
```

### Options

| Flag | What it does |
|---|---|
| *(none)* | chezmoi apply + base install |
| `--setup` | + interactive git config, env vars → `~/.config/personal/env` |
| `--auth` | + service OAuth (GitHub, Google, HuggingFace) |
| `--kb` | + knowledge base tools (gcloud, obsidian-cli, qmd, gws) |
| `--local-llm` | + local LLM (ollama, llama.cpp, vLLM, gemma4) |
| `--all` | everything above |
| `--install-only` | skip chezmoi, run install.sh only |

---

## Scripts (in `scripts/`)

| Script | Purpose |
|---|---|
| `scripts/install.sh` | Base packages, dev tools, AI CLI |
| `scripts/install_kb.sh` | Knowledge base tools: gcloud, obsidian-cli, qmd, gws |
| `scripts/install_local_llm.sh` | Local LLM: Ollama, llama.cpp, vLLM, Gemma 4 |
| `scripts/auth.sh` | Interactive OAuth login for services |
| `scripts/setup.sh` | One-time personalization: git config, env vars, summary |
| `scripts/setup_data_repos.sh` | Clone Claude knowledge repos into `/data` (cubrid_cv, cub_sys, hgryoo, references) |
| `scripts/sync_knowledge.sh` | rsync `~/obsidian/ ↔ ~/knowledge/` (`pull`/`push`) |

---

## What's Managed (chezmoi)

| Source file | Deployed to |
|---|---|
| `dot_bashrc.tmpl` | `~/.bashrc` |
| `dot_bash_aliases` | `~/.bash_aliases` |
| `dot_bash_exports` | `~/.bash_exports` |
| `dot_gitconfig.tmpl` | `~/.gitconfig` |
| `dot_vimrc` | `~/.vimrc` |
| `dot_config/nvim/init.lua` | `~/.config/nvim/init.lua` |
| `dot_config/direnv/` | `~/.config/direnv/` |
| `dot_config/htop/htoprc` | `~/.config/htop/htoprc` |
| `dot_config/Code/User/settings.json` | `~/.config/Code/User/settings.json` |
| `dot_claude/settings.json` | `~/.claude/settings.json` |
| `dot_claude/karpathy-skills.md` | `~/.claude/karpathy-skills.md` |

---

## Packages Installed

### Base (`scripts/install.sh`)

| Tool | Method |
|---|---|
| Base build tools (gcc, cmake, ninja, bison) | apt / dnf + source |
| CUBRID build deps (GCC 10, Java, systemtap) | PPA / toolset |
| [uv](https://docs.astral.sh/uv/) | curl installer |
| Rust / rustup | curl installer |
| oh-my-bash | curl installer |
| Neovim | PPA / dnf |
| direnv | apt / dnf |
| fzf | apt / dnf |
| just | curl installer |
| gh (GitHub CLI) | apt repo / dnf repo |
| [rtk](https://github.com/rtk-ai/rtk) | curl installer |
| markitdown | `uv tool install` |
| lazydiff | `cargo install` |
| lazygit | GitHub release binary |
| [Claude Code](https://claude.ai) | curl installer |
| oh-my-claudecode (omc) | npm |

### CUBRID tools (`cubrid/tools/`, git submodules)

| Tool | Purpose |
|---|---|
| [cubrid-jira-fetcher](https://github.com/vimkim/cubrid-jira-fetcher) | Fetch CUBRID JIRA issues → Markdown |
| [my-cubrid-skills](https://github.com/vimkim/my-cubrid-skills) | Claude Code skills for CUBRID dev |
| pandoc | Jira wiki → Markdown conversion |

### Knowledge Base (`--kb`)

| Tool | Method |
|---|---|
| [Google Cloud CLI](https://cloud.google.com/sdk) | curl installer (required by gws) |
| [obsidian-cli](https://obsidian.md/cli) | npm |
| [qmd](https://github.com/tobi/qmd) | npm |
| [gws](https://github.com/googleworkspace/cli) | npm (requires gcloud) |

### Local LLM (`--local-llm`)

| Tool | Method |
|---|---|
| [Ollama](https://ollama.com) | curl installer |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | build from source (CUDA auto-detected) |
| [vLLM](https://github.com/vllm-project/vllm) | uv venv at `~/.local/share/vllm-env` |
| Gemma 4 (4b) | `ollama pull gemma4:4b` |

---

## Knowledge Base Architecture

```
External sources (Google Drive, JIRA)
    ↓
~/knowledge/       ← local snapshot, Claude Code reference
    ↕  scripts/sync_knowledge.sh pull/push
~/obsidian/        ← Obsidian vault (source of truth + Claude-generated docs)
```

```sh
bash scripts/sync_knowledge.sh pull   # ~/obsidian/ → ~/knowledge/
bash scripts/sync_knowledge.sh push   # ~/knowledge/ → ~/obsidian/
qmd embed                             # regenerate search embeddings
qmd query "your question"             # semantic search across knowledge base
```

---

## Day-to-Day Usage

```sh
# Edit a dotfile and preview the diff
chezmoi edit ~/.bashrc
chezmoi diff

# Apply changes
chezmoi apply

# Pull upstream changes and apply
git -C ~/dotfiles pull --ff-only
chezmoi init --source=~/dotfiles --apply
```

## CUBRID Environment

Switch between CUBRID builds without restarting your shell:

```sh
use-cubrid                          # default: ~/cubrid/install.out
use-cubrid /path/to/other/build     # custom path
```

A direnv template for per-directory automatic activation is at `~/.config/direnv/templates/envrc-cubrid`.

## Secrets

`secrets.env` is git-ignored. Use `secrets.env.template` as the starting point:

```sh
cp secrets.env.template secrets.env
$EDITOR secrets.env
```

Keys managed: `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `HUGGINGFACE_TOKEN`,
`JIRA_URL/USERNAME/PASSWORD`, `GOOGLE_CLIENT_ID/SECRET`.
