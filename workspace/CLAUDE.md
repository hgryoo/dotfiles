# /data/workspace — what is here and where to look

This tree holds **working copies, builds and run output**. It carries no notes
and no conclusions: those live in the vault at `/data/cubrid_cv`, and the
vault's documents point back here by path.

> Nothing under here is precious. Build trees, install prefixes and run output
> are remade by running the command again. Before deleting, read
> `README.md` §"Compatibility symlinks" — the root symlinks are load-bearing
> for 1160 references in the vault.

## Where to go, by what you are doing

| You want… | Go to |
|---|---|
| the source of a topic you are working on | `topic/<topic>/` |
| a specific branch, ticket or PR checked out | `wt/<ticket-or-pr>/` |
| an upstream repo to read or update | `repos/<name>/` |
| a runnable CUBRID (`$CUBRID`) | `build/<name>/`, or `<checkout>/install.out` |
| the output of a measurement that was run | `runs/<experiment>/<variant>/` |
| the script that produced that output | `harness/` |

## topic/ ↔ the vault

A topic directory pairs with a plan umbrella of the same name. Read the
umbrella first — it says what the work is and what has been decided; the
directory here only holds the trees it was measured in.

| here | vault |
|---|---|
| `topic/async` | `/data/cubrid_cv/plan/async/` |
| `topic/cubvec` | `/data/cubrid_cv/plan/cubvec/` |
| `topic/fmt` | `/data/cubrid_cv/plan/fmt/` |
| `topic/importdb` | `/data/cubrid_cv/plan/importdb/` |
| `topic/legacy` | `/data/cubrid_cv/plan/legacy/` |
| `topic/lockfree` | `/data/cubrid_cv/plan/lockfree/` |
| `topic/log` | `/data/cubrid_cv/plan/log/` |
| `topic/serial` | `/data/cubrid_cv/plan/serial/` |
| `topic/simd` | `/data/cubrid_cv/plan/simd/` |
| `topic/stream_protocol` | `/data/cubrid_cv/plan/stream_protocol/` |

Ten of the 25 pair this way. The other fifteen do not, and that is a known
defect of this layout rather than a category:

- `topic/lock`, `topic/pl`, `topic/cas_syscall`, `topic/cdc`, `topic/lb`,
  `topic/cluster-sandbox`, `topic/cubrid-ops`, `topic/stream_split` —
  real topics whose vault umbrella sits under a different name
  (`plan/lock_manager/` for `topic/lock`) or in
  `/data/cub_sys/roadmap/projects/`.
- `topic/issue`, `topic/review`, `topic/bench` — **not topics**. They are
  purposes, left over from `for_issue/`, `for_review/` and `for-bench/`.
  Do not add to them; put new work under the topic it belongs to.
- `topic/_saved_patches`, `topic/aisaq-diskann`, `topic/cub_sys`,
  `topic/cubrid-systems` — landed here by the fallback rule.

## wt/ — which branch is where

`repos/cubrid_dev` is the canonical clone; 46 of the worktrees hang off it.
The directory name is not always the branch name:

```sh
git -C repos/cubrid_dev worktree list          # every worktree and its branch
grep '^WORKTREE' /data/ops/workspace-manifest.txt
```

Some pairs are deliberate — `wt/CBRD-27034_pr1` sits on `feature/lock_new`,
`wt/dev_base_27048` is detached at a commit used as a measurement baseline.

## Putting something new here

- `repos/<upstream-name>` — exactly what the remote calls it.
- `wt/<ticket-or-pr>` — `wt/CBRD-27048`, `wt/pr7698`.
- `runs/<experiment>/<variant>` — `runs/oih/aa1`. Never `oih_aa1` at the root;
  96 of those is how this tree got into the state it was in.
- `topic/<topic>` — matching the vault umbrella's name.

A build belongs inside the checkout it came from (`<checkout>/build_preset_*`,
`<checkout>/install.out`), not in a directory of its own.

## Reclaiming space

`/data` fills up. `/data/ops/workspace_reclaim.sh` deletes only what a
named command remakes, and says which command:

```sh
/data/ops/workspace_reclaim.sh --dry-run --all
/data/ops/workspace_reclaim.sh --builds      # cmake build trees
/data/ops/workspace_reclaim.sh --installs    # prefixes, keeps databases/
```

`--dbs` is never part of `--all`: a `databases/` volume may hold data that took
a load to produce.

## Known defect: the tiers mix two axes

`repos/` `wt/` `build/` say **how a directory was made** — a clone, a worktree,
an install. `topic/` says **what it is about**. Two axes at one level, and the
consequence is measurable: of 51 worktrees, 29 are in `wt/` and 22 are not
(17 under `topic/`, 3 under `runs/`, 2 under `build/`). To find the CBRD-27048
work you must first know whether it was checked out as a worktree or grew
inside a topic tree.

The target is one axis — **a topic owns everything under it**:

```
topic/lock/
├── wt/CBRD-27048          the checkout
├── build/CBRD-27048       its build and install prefix
└── runs/oih/aa1           what that build produced
repos/                     unchanged — upstream clones are not owned by a topic
```

That pairs 1:1 with `cubrid_cv/plan/<topic>/`, and deleting a finished topic
takes its checkouts, builds and output with it instead of leaving them in three
other tiers.

It is **not** being done on this machine: 210 GB would move and the 31
compatibility symlinks would have to be rewritten, for a tree that is already
far better than the 193-entries-in-one-level it replaced. The next machine
starts empty, so it starts topic-centric — change
`/data/ops/workspace-manifest.txt` and `setup_workspace.sh`
builds the new shape there.

Until then: put new work in the tier that matches, and do not add to
`topic/issue`, `topic/review` or `topic/bench`.

## Full layout and how to recreate it elsewhere

`README.md` in this directory — tier sizes, the compatibility symlinks, and
`setup_workspace.sh`, which rebuilds this skeleton on another machine from
`/data/ops/workspace-manifest.txt`.
