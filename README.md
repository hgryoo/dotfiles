# hgryoo/dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Supports Ubuntu and Rocky Linux 9.

## Quick Start

### Fresh machine

```sh
git clone https://github.com/hgryoo/dotfiles ~/dotfiles
~/dotfiles/bootstrap.sh
```

`bootstrap.sh` will:
1. Install chezmoi (if not present)
2. Apply dotfiles to `~` via `chezmoi apply`
3. Install all packages via `install.sh`

### Packages only (on an existing setup)

```sh
~/dotfiles/install.sh
```

### Local LLM environment (optional, heavy)

```sh
bash ~/dotfiles/install_local_llm.sh
```

### Knowledge base tools (optional)

```sh
bash ~/dotfiles/install_kb.sh
```

### First-time personalization

```sh
cp secrets.env.template secrets.env
$EDITOR secrets.env          # fill in API keys

bash auth.sh                 # GitHub, Google, rtk OAuth login
bash setup.sh                # git config + env vars + full summary
```

---

## Scripts

| Script | Purpose |
|---|---|
| `bootstrap.sh` | Full setup on a fresh machine (chezmoi apply + install.sh) |
| `install.sh` | Base packages, dev tools, AI CLI |
| `install_local_llm.sh` | Local LLM: Ollama, llama.cpp, vLLM, Gemma 4 |
| `install_kb.sh` | Knowledge base tools: obsidian-cli, qmd, gws |
| `auth.sh` | Interactive OAuth login for all services |
| `setup.sh` | One-time personalization: git config, env vars, env summary |
| `sync_knowledge.sh` | rsync `~/obsidian/ ↔ ~/knowledge/` (`pull`/`push`) |

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

## Packages Installed (`install.sh`)

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

### Local LLM (`install_local_llm.sh`)

| Tool | Method |
|---|---|
| [Ollama](https://ollama.com) | curl installer |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | build from source (CUDA auto-detected) |
| [vLLM](https://github.com/vllm-project/vllm) | uv venv at `~/.local/share/vllm-env` |
| Gemma 4 (4b) | `ollama pull gemma4:4b` |

### Knowledge Base (`install_kb.sh`)

| Tool | Purpose |
|---|---|
| [obsidian-cli](https://obsidian.md/cli) | Obsidian vault CLI control |
| [qmd](https://github.com/tobi/qmd) | Local AI search over markdown (NotebookLM alternative) |
| [gws](https://github.com/googleworkspace/cli) | Google Workspace CLI (Drive, Gmail, Calendar) |

---

## Knowledge Base Architecture

```
External sources (Google Drive, JIRA)
    ↓
~/knowledge/       ← local snapshot, Claude Code reference
    ↕  sync_knowledge.sh pull/push
~/obsidian/        ← Obsidian vault (source of truth + Claude-generated docs)
```

```sh
bash sync_knowledge.sh pull   # ~/obsidian/ → ~/knowledge/
bash sync_knowledge.sh push   # ~/knowledge/ → ~/obsidian/
qmd embed                     # regenerate search embeddings
qmd query "your question"     # semantic search across knowledge base
```

---

## Claude Code Integration

`~/.claude/karpathy-skills.md` is appended to `~/.claude/CLAUDE.md` by `install.sh`,
adding Andrej Karpathy's behavioral guidelines (think before coding, simplicity first,
surgical changes, goal-driven execution).

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
`JIRA_URL/USERNAME/API_TOKEN`, `RTK_API_KEY`, `GOOGLE_CLIENT_ID/SECRET`.
