# /data/workspace — what is here and where to look

This tree holds **working copies, builds and run output**. It carries no notes
and no conclusions: those live in the vault at `/data/cubrid_cv`, and the
vault's documents point back here by path.

> Nothing under here is precious. Build trees, install prefixes and run output
> are remade by running the command again.

## One axis: a topic owns what it produced

```
/data/workspace/
├── repos/<name>                 an upstream clone — not owned by a topic
├── topic/<topic>/
│   ├── wt/<ticket-or-pr>        a checkout for that topic
│   ├── build/<name>             its build tree and install prefix
│   └── runs/<experiment>/<var>  what that build produced
├── harness/                     run scripts shared across topics
└── archive/                     kept but finished
```

The point of the single axis: **a topic is deletable.** When work finishes, the
topic directory takes its checkouts, builds and output with it. Nothing is left
in three other places to find later.

## Where to go, by what you are doing

| You want… | Go to |
|---|---|
| anything about a topic | `topic/<topic>/` — start there, always |
| a specific branch, ticket or PR checked out | `topic/<topic>/wt/<ticket>` |
| an upstream repo to read or update | `repos/<name>/` |
| a runnable CUBRID (`$CUBRID`) | `topic/<topic>/build/<name>/install.out` |
| the output of a measurement | `topic/<topic>/runs/<experiment>/<variant>/` |
| the script that produced that output | `harness/`, or the topic's own `runs/` |

If you do not know which topic something belongs to, **the vault knows**:
`grep -rl '<name>' /data/cubrid_cv/plan /data/cubrid_cv/issue`. If the vault
does not cite it either, it has no owner — do not invent one; ask.

## The topics

The names are the work, not a taxonomy someone imposed. Most pair with a plan
umbrella in the vault; a few live in `cub_sys/roadmap/projects/` instead. Read
the umbrella before the tree — it says what the work is and what has been
decided, and the tree here only holds what it was measured in.

```
aisaq-diskann  async  cas_syscall  cdc  cluster-sandbox  cubrid-ops
cubrid-systems  cub_sys  cubvec  fmt  importdb  lb  legacy  lock  lockfree
log  pl  serial  simd  stream_protocol  stream_split
```

Verified pairings: `async`, `cubvec`, `fmt`, `importdb`, `legacy`, `lockfree`,
`log`, `serial`, `simd`, `stream_protocol` → `/data/cubrid_cv/plan/<same>`.
`lock` → `plan/lock_manager`. `cluster-sandbox` → `roadmap/N65-cluster-sandbox`,
`cubrid-ops` → `roadmap/N64-cubrid-ops`. The rest are named by the work and
their umbrella is worth confirming before you rely on it.

## Putting something new here

- `repos/<upstream-name>` — exactly what the remote calls it.
- `topic/<topic>/wt/<ticket-or-pr>` — `topic/lock/wt/CBRD-27048`.
- `topic/<topic>/build/<name>` — a build belongs to the checkout it came from.
- `topic/<topic>/runs/<experiment>/<variant>` — `runs/oih/aa1`, never
  `oih_aa1` somewhere flat. Ninety-six of those at one level is how the
  previous layout got the way it was.

**Nothing new goes at the root.** If it does not fit a topic, it is either a
clone (`repos/`) or you do not yet know what it is — and that is worth
resolving before making the directory.

## The other machine

`hgryoo-desktop` still has the earlier layout, where `wt/`, `build/` and
`runs/` are siblings of `topic/` at the root, plus 31 compatibility symlinks
for the 1160 old paths the vault cites. Converting it means moving 210 GB and
rewriting those symlinks, for a tree that already works; it is scheduled, not
urgent. Two consequences while both exist:

- **Do not `--emit` a manifest there.** `setup_workspace.sh` refuses, because
  the manifest it would write reverts this layout for every machine built from
  it afterwards.
- A path from a desktop note (`/data/workspace/for-plan/lock/...`) will not
  resolve here. The topic is the same; the path above it is not.

## Reclaiming space

`/data/ops/workspace_reclaim.sh` deletes only what a named command remakes,
and says which command:

```sh
/data/ops/workspace_reclaim.sh --dry-run --all
/data/ops/workspace_reclaim.sh --builds      # cmake build trees
/data/ops/workspace_reclaim.sh --installs    # prefixes, keeps databases/ and log/
```

`--dbs` and `--logs` are never part of `--all`: a `databases/` volume may hold
data that took a load to produce, and an install prefix's `log/` holds server
logs and coredumps that vault documents cite as evidence.

## Recreating this elsewhere

`README.md` here, and `/data/ops/setup_workspace.sh`, which builds the
skeleton from `~/dotfiles/workspace/manifest.txt`.
