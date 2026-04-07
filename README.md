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

### Dotfiles only (no package install)

```sh
git clone https://github.com/hgryoo/dotfiles ~/dotfiles
chezmoi init --source=~/dotfiles --apply
```

You will be prompted for your Git email address on first run.

### Packages only (on an existing setup)

```sh
~/dotfiles/install.sh
```

---

## What's Managed

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
| `dot_config/claude/settings.json` | `~/.config/claude/settings.json` |
| `bin/executable_*` | `~/bin/` (executable) |

## Packages Installed

| Tool | Ubuntu | Rocky 9 |
|---|---|---|
| Base build tools | `apt` | `dnf` |
| CUBRID build deps (GCC 10, CMake, Ninja, Bison) | from source / PPA | from source / toolset |
| [uv](https://docs.astral.sh/uv/) (Python) | curl installer | curl installer |
| Rust / rustup | curl installer | curl installer |
| oh-my-bash | curl installer | curl installer |
| Neovim | PPA | `dnf` |
| direnv | `apt` | `dnf` |
| fzf | `apt` | `dnf` |
| just | curl installer | curl installer |
| gh (GitHub CLI) | apt repo | dnf repo |

## Day-to-Day Usage

```sh
# Edit a dotfile and preview the diff
chezmoi edit ~/.bashrc
chezmoi diff

# Apply changes
chezmoi apply

# Pull upstream changes and apply
chezmoi update
```

## CUBRID Environment

Switch between CUBRID builds without restarting your shell:

```sh
use-cubrid                          # default: ~/cubrid/install.out
use-cubrid /path/to/other/build     # custom path
```

A direnv template for per-directory automatic activation is at `~/.config/direnv/templates/envrc-cubrid`.
