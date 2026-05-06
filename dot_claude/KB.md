# Personal Knowledge Base

A curated, frontmatter-tagged knowledge tree at `$KB_ROOT`
(default `/data/hgryoo/knowledge-base` on this machine). Two-tree
model: `raw/` is the append-only inbox; `knowledge/` is the curated
side, every doc starts with YAML frontmatter (`title`, `category`,
`sources`, `summary`, `created`, `updated`, optional `tags`).

## When to consult it

Before answering from training data alone, check whether the topic
overlaps with content here. The KB has authored material on:

- **Software engineering history & methodology** —
  `knowledge/software-engineering/` (NATO 1968, Royce, Parnas,
  Brooks, Boehm, SWEBOK; agile/XP/lean; testing-as-design;
  spec-driven and harness engineering).
- **Technical writing references** —
  `knowledge/software-engineering/technical-writing/` (Microsoft
  Writing Style Guide, Google Developer Documentation Style Guide,
  Byrne *Technical Translation*).
- **Methodology playbooks** —
  `knowledge/methodology/` (how to write bug reports, requirements
  specs, design docs, PR descriptions, commit messages,
  code-analysis docs). Bilingual EN+KO. The folder has its own
  `CLAUDE.md` with the "ask the five framing inputs before drafting"
  rule.
- **DBMS internals** —
  `knowledge/research/dbms-general/` (textbook captures from
  *Database System Concepts*, *Database Internals*, etc.).
- **CUBRID code analysis** —
  `knowledge/code-analysis/cubrid/` (per-module deep dives — MVCC,
  lock manager, recovery, etc., with source-walkthrough sections
  and position-hint tables).
- **KO mirror tree** — `knowledge/ko/...` mirrors the EN tree as
  parallel composition (not translation). When the user works in
  Korean, KO mirrors are usually the better starting point.

When in doubt, search before assuming the KB is silent on a topic.

## How to search it

Three modes, pick the lightest that fits:

1. **`/kb-search "<query>"`** — ranked grep across both trees, with
   snippets. Works from any CWD when `KB_ROOT` is exported. Fastest
   first hop.
2. **Direct grep** — `rg "<pattern>" "$KB_ROOT/knowledge"` for a
   targeted lookup when you already know the rough path or term.
3. **`/kb-query-open-notebook`** — RAG-backed semantic query when
   the question is conceptual and the term in the docs may not
   match the user's wording. Requires the local Open Notebook
   instance to be up.

## How to write into it

- New raw drop → append to `$KB_ROOT/raw/<category>/`. No
  frontmatter, no slug rules.
- Promote a raw note → `/kb-curate raw/<path>` from inside the kb,
  or `KB_ROOT=... kb-curate raw/<path>` from anywhere. Edit the
  generated skeleton's body in prose, fill `summary`.
- After adding/renaming a curated doc → `/kb-index <category>` to
  refresh the per-folder `README.md` (it is auto-generated, do not
  hand-edit).
- Bilingual rule: every curated EN doc has a KO mirror at
  `knowledge/ko/<same-path>.md`. Read that file before authoring or
  editing — KO is parallel composition, not translation.
- Methodology playbooks have a "five framing inputs" rule (pain
  point / audience / references / output shape / anti-patterns).
  Ask before drafting if any are missing — see
  `$KB_ROOT/knowledge/methodology/CLAUDE.md`.

## Editing rules summary (so you don't have to re-read CLAUDE.md every time)

- `raw/` is append-only. Never reorganize, rename, or delete files
  under `raw/` autonomously.
- Every file under `knowledge/` starts with YAML frontmatter; bump
  `updated:` on edits.
- `sources:` is informational; broken refs are tolerated.
- Per-folder `README.md` is derived state — regenerate via
  `/kb-index`, do not hand-edit.
- No new top-level directories without updating
  `$KB_ROOT/CLAUDE.md` and `$KB_ROOT/docs/DESIGN.md`.

The full repo-level rules live at `$KB_ROOT/CLAUDE.md` and
`$KB_ROOT/knowledge/CLAUDE.md`. Read those before any structural
change to the kb itself.
