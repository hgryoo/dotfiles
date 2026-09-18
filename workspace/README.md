# /data/workspace — layout

The canonical layout is **topic-centric**: a topic owns its checkouts,
builds and run output. `CLAUDE.md` beside this file has the tree, the topic
list and where to put new things; it is the one to read.

This file records how the layout got here and what the numbers were.

A directory goes in the tier that matches **what it holds**, not what it is for.

| Tier | Holds | Count / size on 2026-09-17 |
|---|---|---|
| `repos/` | a git clone tracking an upstream | 17 · 17 G |
| `wt/` | a git worktree | 27 · 29 G |
| `build/` | an installed CUBRID prefix (`bin/ cci/ conf/`) | 6 · 2.2 G |
| `runs/` | output of a measurement run — logs, `.class`, result dirs | 10 · 1.9 G |
| `harness/` | the scripts that drive those runs | 48 files · 204 K |
| `topic/` | a topic's working tree (what `for-plan/` held) | 25 · 210 G |
| `archive/` | kept but finished | 1 · 348 K |

## Why

Before this, 193 directories and 48 loose scripts sat at one level, where a git
worktree, a benchmark's log dump and a 107 GB topic tree were siblings. 107 of
the 193 were run output from two experiments — `oih_*` (96) and `bharness_*`
(11) — each holding the same nine files. The 48 scripts at the root referenced
session scratchpad paths that no longer exist.

## Naming

**The tier is the convention; leaf names are left alone.** `cubrid_dev` does not
become `cubrid-dev`. A mass separator change would break 1160 references in
cubrid_cv and buy nothing — the mixing (`CBRD-26983-ha-writeback` beside
`CBRD-27034_pr1`, `dev-e6ed61e8` beside `dev_base_27048`) is cosmetic once the
tier says what a directory is.

Only a genuine duplicate was resolved: `for-issue` and `for_issue` were two
names for one purpose and are now `topic/issue`.

For new directories:

- `repos/<upstream-name>` — exactly what the remote calls it.
- `wt/<branch-or-ticket>` — `wt/CBRD-27048`, `wt/pr7698`.
- `runs/<experiment>/<variant>` — `runs/oih/aa1`, not `oih_aa1` at the root.
- `topic/<topic>` — one per plan topic, matching `cubrid_cv/plan/<topic>/`.

## Compatibility symlinks

cubrid_cv cites old top-level paths 1160 times, inside records of **where
something was measured**. Those sentences were true when written, so the paths
are kept resolvable rather than rewritten: `compat.txt` lists 31 symlinks at the
root, one per cited old name.

They are removable once the references are rewritten:

```sh
grep ' -> ' compat.txt | cut -d' ' -f1 | xargs rm
```

170 of those references were already dead before the move (`lk_I7`,
`cubrid-tta`, `CBRD-26826`, …) and no symlink brings them back.

## Carrying this to another machine

Content is not carried — 261 GB of build trees, database volumes and run output
are remade. The shape is, because the vault's notes point at these paths:

```sh
/data/ops/setup_workspace.sh --dry-run    # what it would create
/data/ops/setup_workspace.sh              # dirs + worktrees
/data/ops/setup_workspace.sh --clones     # + the 17 clones (tens of GB)
```

`manifest.txt` holds 51 worktrees, 17 clones and 400 directories.
Regenerate it on the machine that still has the tree with `--emit`.

Two worktrees are deliberately absent: `cubrid-cci` and `cubrid-jdbc` each have
one under a session scratchpad outside the root, which is not a thing to
recreate. And `repos/cubrid_11_3`'s origin is a local path
(`/home/hgryoo/dev/cubrid_11_4`), so its clone is reported and skipped.
