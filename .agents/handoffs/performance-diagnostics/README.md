# Branch-local performance diagnostics source

This directory is a temporary, reviewable source bundle, not an external download.
It is committed on `fix/cache-performance-diagnostics`, based on
`f4972eb54119fce98360c4c2303bbce375b8e722`.

The one-time branch workflow applies it in a linked worktree and then removes
this staging directory and itself. It never updates `develop` or `master`.
If automated preparation does not run, a local agent can use the same commands:

```sh
python3 .agents/handoffs/performance-diagnostics/apply.py . --check
python3 .agents/handoffs/performance-diagnostics/apply.py .
```

Run them from a **clean linked task worktree**, not the primary checkout.
The installer allows preparation-only descendant commits, but verifies that
every touched app/package/locale input still has the exact audited base blob.
It also checks every source anchor and new-file destination before writing.
It does not fetch, commit, push, generate translations, or run Flutter.

The source payload has 10 new project files and transformations for 21 existing
files. Python tests are in `tests/` and `files/scripts/tests/`.
Follow `docs/performance_handoff.md` at the repository root for the full task,
verification limitations, cache preservation, and the separate cache fix.
