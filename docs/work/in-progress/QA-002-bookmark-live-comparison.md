# Compare live bookmark behavior and performance

Priority: Normal
Affected feature: `feature/bookmark-post-behavior-parity`

## Problem

The unified post architecture has deterministic test-suite performance guards,
but its real-device bookmark loading, memory use, mixed-source presentation,
and viewer behavior have not been compared with the simplified `develop`
bookmark model under the same large dataset.

## Expected behavior

A one-time, reproducible comparison uses the same 500 Danbooru and 500
Gelbooru V2 posts on the same emulator. Network/import setup is excluded from
measurements, credentials remain local, and the feature branch retains native
per-booru behavior without a material unexplained regression.

## Acceptance criteria

- A reviewed design and execution plan define the comparison.
- A frozen manifest records exactly 1,000 validated post identities and its
  digest before either measured run.
- `develop` and the feature branch run sequentially from cleared Dev app data
  with recreated authenticated test profiles.
- Cold load, first grid, memory, frame behavior, Hive size, and the agreed
  functional sequence are recorded for both pinned revisions.
- Results distinguish application behavior from backend, network, emulator,
  and tooling effects.
- Temporary import and instrumentation code is not merged.

## Constraints and dependencies

- Follow
  `docs/superpowers/specs/2026-09-24-bookmark-live-comparison-design.md`.
- Use `emulator-5556` unless its availability changes before execution.
- Never log, commit, display, or capture values from `.test_credentials`.
- Do not mutate server favorites or other shared remote account state.
- Do not delete temporary branches or worktrees without explicit approval.

## Progress

Agent: Codex (`/root`)
Work branch: `feature/bookmark-post-behavior-parity`

- 2026-09-24: Conversational design approved. Written specification created
  for review before the executable plan and manifest collection.
