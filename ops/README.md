# /data/ops — the scripts that manage this machine's /data

Every file here is a **symlink into the repo that owns it**. Edit the target,
commit it there; this directory is only the place you look when you do not
remember which repo a script lives in.

Two owners, and the split is about what may be public:

- `~/dotfiles` (**public**) — machine setup. Nothing in it names a branch, a
  ticket or an internal host; credentials live in the git-ignored `secrets.env`.
- `/data/cubrid_cv/scaffold` (**private**) — the shape of the CUBRID work.
  The workspace manifest carries branch names like `CBRD-27034`, so it does not
  go in a public repo.

| here | owner | what it does |
|---|---|---|
| `bootstrap.sh` | dotfiles | single entry point on a fresh machine: chezmoi apply + install + auth + setup |
| `install.sh` | dotfiles | packages and toolchains (CUBRID build deps, bison 3.0.5, nvm, snip, uv tools) |
| `setup.sh` | dotfiles | interactive personalisation — git config, and every key in `secrets.env` |
| `setup_data_repos.sh` | dotfiles | clone `cubrid_cv`, `cub_sys/*`, `hgryoo/*` into `/data` |
| `sync_repos.sh` | dotfiles | fetch every repo under `/data`, report ahead/behind/dirty, `--pull` to fast-forward |
| `setup_workspace.sh` | scaffold | rebuild the `/data/workspace` skeleton from the manifest |
| `workspace_rearrange.sh` | scaffold | tier `/data/workspace` by what a directory holds |
| `workspace_reclaim.sh` | scaffold | delete what a named command remakes — builds, install prefixes |
| `workspace-manifest.txt` | scaffold | 51 worktrees · 17 clones · 400 directories |

## The order on a new machine

```sh
git clone https://github.com/hgryoo/dotfiles ~/dotfiles
cd ~/dotfiles && cp secrets.env.template secrets.env && $EDITOR secrets.env
bash bootstrap.sh --all --data          # 1–4 above, then clone /data
/data/ops/setup_workspace.sh            # 6 — the workspace skeleton
```

Three things no repo carries, because they are files rather than values. Copy
them from the old machine over tailscale:

```sh
scp -r <old-host>:~/.ssh/ ~/
scp <old-host>:~/cubvec_keypair1.pem ~/ && chmod 400 ~/cubvec_keypair1.pem
scp <old-host>:~/dotfiles/secrets.env ~/dotfiles/
```

## Day to day

```sh
/data/ops/sync_repos.sh                 # where does every repo stand
/data/ops/sync_repos.sh --pull          # fast-forward what can move
/data/ops/workspace_reclaim.sh --dry-run --all   # what is reclaimable
```

`sync_repos.sh` never stashes, never rebases and never touches a dirty tree —
a diverged branch is reported with its ahead count and left alone.

## Connecting out

`~/bin/connect-vpn.sh`, `connect-aws.sh`, `connect-perf.sh` (also reachable
without the `.sh`). They carry no credentials: each reads `~/.secrets.env`,
which is a symlink to `~/dotfiles/secrets.env`, and names the missing variable
if it is not set.

They replace the four scripts that used to sit in `~` with passwords written
into them — `connect_cubrid_vpn.sh`, `connect_server.sh`, `connect_perf08.sh`,
`connect_aws.sh`. The originals are still there and still work; delete them
once you have confirmed the new ones do.

| old | new | note |
|---|---|---|
| `~/connect_cubrid_vpn.sh` | `connect-vpn.sh` | password on stdin, not `--password=` (which showed it in `ps`) |
| `~/connect_server.sh` | `connect-vpn.sh --persistent` | same gateway, reconnects after 10 s |
| `~/connect_perf08.sh` | `connect-perf.sh` | host-key checking is **on** now |
| `~/connect_aws.sh` | `connect-aws.sh` | key path from `CUBVEC_EC2_KEY`, default `~/cubvec_keypair1.pem` |

## Where the rest is

- `/data/workspace/CLAUDE.md` — which folder to go to for a topic, and the
  layout defect that is meant to be fixed on the next machine.
- `/data/workspace/README.md` — tiers, compatibility symlinks, sizes.
- `/data/cubrid_cv/CLAUDE.md` — the vault's own rules.
