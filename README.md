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
| `scripts/sync_repos.sh` | Fetch every git repo under `/data`, report ahead/behind/dirty; `--pull` fast-forwards what can move |
| `scripts/setup_workspace.sh` | Rebuild the `/data/workspace` skeleton from `workspace/manifest.txt`; `--emit` regenerates it |
| `scripts/workspace_rearrange.sh` | Tier `/data/workspace` by what a directory holds (`repos/ wt/ build/ runs/ harness/ topic/ archive/`) |
| `scripts/workspace_reclaim.sh` | Delete what a named command remakes — build trees, install prefixes |
| `scripts/sync_knowledge.sh` | rsync `~/obsidian/ ↔ ~/knowledge/` (`pull`/`push`) |

`workspace/` holds what those three read and write: `manifest.txt` (51
worktrees · 17 clones · 400 directories), plus `CLAUDE.md` and `README.md`,
which are symlinked into `/data/workspace/` so an agent working there finds
them.

`scripts/` is **not** deployed to `$HOME`. Run a script from `/data/ops/` or
from this repo; a third copy under `~/scripts` had gone five months stale
without anyone noticing, so it is in `.chezmoiignore` now.

`setup_data_repos.sh` also builds **`/data/ops`**, a directory of symlinks to
every script above. It is the answer to "which repo was that script in" — the
answer is always this one. `cubrid_cv/scaffold` is deliberately not linked
there: it is tooling for the vault and its siblings, not for `/data`'s shape.
See `ops/README.md` for the table and the fresh-machine order.

---

## What's Managed (chezmoi)

| Source file | Deployed to |
|---|---|
| `dot_bashrc.tmpl` | `~/.bashrc` |
| `dot_bash_aliases` | `~/.bash_aliases` |
| `dot_bash_exports` | `~/.bash_exports` |
| `dot_gitconfig.tmpl` | `~/.gitconfig` |
| `dot_vimrc` | `~/.vimrc` |
| `dot_config/nvim/` | `~/.config/nvim/` (init.lua + `lua/config/`, `lua/plugins/`) |
| `dot_config/ripgrep/config` | `~/.config/ripgrep/config` (via `RIPGREP_CONFIG_PATH`) |
| `dot_config/direnv/` | `~/.config/direnv/` |
| `dot_config/htop/private_htoprc` | `~/.config/htop/htoprc` (mode 600) |
| `dot_config/Code/User/settings.json` | `~/.config/Code/User/settings.json` |
| `dot_claude/settings.json` | `~/.claude/settings.json` |
| `dot_claude/karpathy-skills.md` | `~/.claude/karpathy-skills.md` |
| `dot_config/alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` |
| `dot_config/lazygit/config.yml` | `~/.config/lazygit/config.yml` |
| `dot_config/git/ignore` | `~/.config/git/ignore` |
| `dot_config/gh/config.yml` | `~/.config/gh/config.yml` (no token — `gh auth login` writes `hosts.yml`) |
| `dot_config/snip/config.toml` | `~/.config/snip/config.toml` |
| `dot_config/abtop/config.toml` | `~/.config/abtop/config.toml` |
| `dot_tmux.conf.local` | `~/.tmux.conf.local` |
| `bin/` | `~/bin/` |

---

## `~/bin` Scripts

chezmoi copies `bin/` to `~/bin` (already on `PATH` via `.bashrc`).
`install.sh` then adds the extensionless name each one is actually typed with —
`cl-tabs`, not `cl-tabs.sh`.

The source files carry chezmoi's `executable_` prefix, which is how chezmoi
decides the deployed mode — it reads the prefix, not the file's mode on disk.
Without it every script deploys as 0644, `install.sh` chmods it, and
`chezmoi status` then reports permanent drift on all nine. The prefix is
stripped on deploy, so `bin/executable_connect-vpn.sh` lands as
`~/bin/connect-vpn.sh`.

| Script | Purpose |
|---|---|
| `cl-tabs.sh` | Gather the Claude tmux sessions under a path into one tabbed session (`clc-tabs` = `.claude-cubrid` variant) |
| `cubrid-clone.sh` | Clone cubrid/cubrid and register the origin / hgryoo / cub_sys remotes |
| `clean-cores` | Delete core **dump files** only — never a directory named `core` |
| `data-usage` | Per-directory disk usage for a path, largest first |
| `disk-reclaim.sh` | Reclaim space losslessly: shrink ext4 reserved blocks, drop regenerable caches |
| `oom-fix.sh` | Post-OOM hardening: earlyoom, systemd-oomd, swappiness, swap resize |
| `connect-vpn.sh` | CUBRID openfortivpn — credentials from `~/.secrets.env` |
| `connect-aws.sh` | cubvec EC2 SSH — host from `~/.secrets.env`, key file copied by hand |
| `connect-perf.sh` | Perf server SSH — host/password from `~/.secrets.env` |
| `connect-ts.sh` | ssh to a tailnet machine by name fragment; no argument lists them |

> The `connect-*` scripts carry **no** credentials. They read `~/.secrets.env`,
> which is a symlink to the git-ignored `secrets.env`. `scripts/setup.sh`
> prompts for the values and creates the link.

---

## Neovim

`dot_config/nvim/` is a small hand-written config, not a distribution: options
and keymaps in `lua/config/`, plugin specs in `lua/plugins/`. It needs
**Neovim 0.12** — it uses `vim.lsp.config`/`vim.lsp.enable` instead of
nvim-lspconfig, and nvim-treesitter is pinned to `main` because master states
it does not support 0.12.

| Plugin | What it is for |
|---|---|
| `snacks.nvim` | picker (files / grep / buffers / recent / zoxide) and explorer |
| `oil.nvim` | edit a directory as a buffer |
| `harpoon` (harpoon2) | pin the few files one issue touches |
| `persistence.nvim` | one session per cwd |
| `which-key.nvim` | the leader menu, while the keys are still new |
| `nvim-treesitter` (main) | c, cpp, java, lua, bash, python, markdown, json, yaml, sql |
| `trouble.nvim` | diagnostics and references as a list |
| `render-markdown.nvim` | markdown rendered in the buffer |
| `claudecode.nvim` | Claude Code over the IDE protocol (selection, diffs) |

Keys — leader is `<Space>`:

| Key | Action |
|---|---|
| `<leader><space>` | smart find (buffers + recent + files) |
| `<leader>ff` / `fg` / `fb` / `fr` | files / grep / buffers / recent |
| `<leader>fp` | project by zoxide |
| `<leader>e` / `-` | explorer / parent directory (oil) |
| `<leader>ma` / `mm` / `m1..4` | harpoon add / menu / jump |
| `<leader>qs` / `ql` / `qS` | restore session for cwd / last / pick |
| `<leader>fk` / `fK` / `fv` | knowledge-base grep / by frontmatter title / cubrid_cv grep |
| `<leader>cf` | format the current file with `cubindent` |
| `<leader>y` | copy `file:line` (to paste into a Claude pane) |
| `<leader>ac` / `af` / `ao` | Claude: toggle terminal / focus / status |
| `<leader>as` (visual) / `ab` | send the selection / add this file to the context |
| `<leader>aa` / `ad` | accept / deny a Claude diff |
| `<leader>xx` / `xb` / `xr` | trouble: diagnostics / this file / references |
| `gd` / `gD` / `<leader>cs` | definition / declaration / document symbols |

Tools it expects, none of which this repo can install without sudo:

```sh
sudo apt install clangd ripgrep fd-find wl-clipboard
npm install -g tree-sitter-cli     # already in NPM_GLOBALS; parsers will not build without it
```

Without `clangd` the LSP is simply not registered (guarded), and without
`wl-copy`/`xclip` the config falls back to OSC 52, which is what makes yanks
work over ssh anyway.

### Claude Code, and which account sees the editor

The official IDE extensions are VS Code and JetBrains only; `claudecode.nvim`
implements the same WebSocket protocol. nvim writes a lock file to
`$CLAUDE_CONFIG_DIR/ide/<port>.lock` and the CLI only scans its own account's
directory — so the account the lock lands in decides which Claude sessions can
see this editor.

There are two accounts here (`cl` -> `~/.claude`, `clc` -> `~/.claude-cubrid`),
so the config defaults `CLAUDE_CONFIG_DIR` to the cubrid one, which is what
/data/cub_sys and /data/cubrid_cv work runs under. To attach the personal
account instead, set it in the shell that starts the editor:

```sh
CLAUDE_CONFIG_DIR=$HOME/.claude nvim
```

`<leader>ac` opens Claude in a split inside nvim. For the usual layout — Claude
already running in another tmux pane — run `/ide` there and it will find the
editor, as long as both are on the same account.

`vcl` / `vclc` / `vclt` (in `dot_bash_aliases`) start that layout in one step:
the same account as `cl` / `clc` / `clt`, a tmux window with `nvim .` on the
left and Claude on the right, both in the current directory, and already
connected to each other. They read the port out of the lock file the editor
just wrote and pass it as `CLAUDE_CODE_SSE_PORT`, rather than relying on
`--ide` alone — `--ide` only auto-connects when exactly one editor is running,
which stops being true the moment a second project is open. Arguments go to
Claude, and the session name follows the `claude-` / `claudec-` convention so
`cl-tabs` and `clc-tabs` still collect them.

### clangd and compile_commands.json

CUBRID builds outside the source tree, so clangd cannot find the database on
its own. Link it once per checkout and keep the link out of git:

```sh
ln -sfn ../devbuild/compile_commands.json /data/cub_sys/cubrid/compile_commands.json
echo compile_commands.json >> /data/cub_sys/cubrid/.git/info/exclude
```

Formatting is **not** wired to clangd on purpose: the project formats with
`cubindent` (`indent -l120` for .c/.h, `astyle --style=gnu --indent=spaces=2`
for .cpp, google-java-format for .java), so nothing formats on save and
`<leader>cf` calls cubindent instead.

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
| [snip](https://github.com/edouard-claude/snip) | curl installer + `snip init` |
| nvm + Node (`NODE_VERSION`, default 24) | curl installer |
| npm globals: codex, openclaw, sisyphus, marp-cli, mermaid-cli, slides-grab | npm |
| bison 3.0.5 → `~/bin` (CUBRID; distro 3.8 does not build it) | source build |
| markitdown | `uv tool install` |
| cubrid-jira-fetcher, copyparty, openai-whisper | `uv tool install` |
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

Or let `scripts/setup.sh` prompt for each value; it writes `secrets.env`,
chmods it 600, and links it as `~/.secrets.env` so `.bashrc` picks it up.

Keys managed:

| Group | Keys |
|---|---|
| API | `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `HUGGINGFACE_TOKEN` |
| JIRA | `JIRA_URL`, `JIRA_USERNAME`, `JIRA_PASSWORD` |
| Google | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| Open Notebook | `OPEN_NOTEBOOK_ENCRYPTION_KEY` |
| CUBRID VPN | `CUBRID_VPN_GATEWAY`, `CUBRID_VPN_USERNAME`, `CUBRID_VPN_CERT`, `CUBRID_VPN_PASSWORD` |
| Remote hosts | `CUBVEC_EC2_HOST`, `CUBVEC_EC2_KEY`, `PERF_HOST`, `PERF_PASSWORD` |

Two things `secrets.env` cannot carry, because they are files rather than
values — copy them from the old machine by hand:

```sh
scp <old-host>:~/cubvec_keypair1.pem ~/ && chmod 400 ~/cubvec_keypair1.pem
scp -r <old-host>:~/.ssh/ ~/            # keys, known_hosts, config
```
