# Accepted integrations: #97, #98, #116 and durable agent files

Date: 2026-10-31. The user approved integrating exactly these four branches,
including publication, issue completion and completed-branch cleanup under the
repository workflow. This report supersedes their earlier technical-readiness
status; historical handoffs retain their pinned evidence.

Base develop: `894ab270693cdb054a5d527c96182e21e2b14ffc`.
Checked combined runtime/test candidate: `da4e868dc8f5d43bb162d5a831fbb76796fd76dc`.
The containing report commit changes documentation only and reuses that exact
runtime/test qualification.

| Scope | Approved source | Squash integration |
| --- | --- | --- |
| `bug/97-follow-destination-identity` | `c9c8c649f19027f60ed3e59d208127e5a1ca2830` | `990062dc7ded40fffdec2d71faaa90e3910561be` |
| `bug/98-search-overlay-surface` | `864166877fdc49fbba0a9a4be7e7ef86439e4e39` | `fd4651cc8e41e7191536b7d7d9645d7c13806a90` |
| `feature/116-compact-follow-button` | `8ed94ba25c738da6327db7124c6d7b8e3c338438` | `55c1c174b3be5b6a28d4b944ff6e0f3df6f21a29` |
| `maintenance/durable-agent-artifacts` | `5c15b27fdd00dcf681ddc8f53d2701ff3840b116` | `da4e868dc8f5d43bb162d5a831fbb76796fd76dc` |

## Result

- #97 gives Home and folder destinations stable row identities, preserving the
  correct first-frame checkbox state and pending selections across navigation.
- #98 paints an opaque surface beneath the entire active Search editor and keeps
  the Search bar reachable in Options as well as Suggestions.
- #116 reduces the compact Follow fill while preserving padded accessible input
  targets, state-stable icon placement and existing noncompact controls.
- AGENTS.md now requires important development logs, evidence, recovery state
  and handoffs in durable workspace storage; `/tmp` is disposable scratch only.

All four squashes applied without conflicts. Every approved changed file is
preserved exactly except compact_follow_pill_test.dart, which is exactly the
pinned Dart formatter's output of its approved source. The final scope contains
no unrelated changes or merge commits. Issue IDs are preserved in each task's
Conventional Commit subject.

## Final-candidate verification

- Pinned FVM Flutter 3.47.2; ordinary concurrency: six physical cores.
- Fresh-worktree setup: CLI `fvm dart pub get`, root `fvm flutter pub get`,
  `fvm install`, then `./gen.sh` for missing generated output. Tracked source
  remained clean. The initial generation attempt required the missing FVM link;
  it was corrected before qualification.
- `./scripts/run_regression_tests.sh`: exit 0. **5,565 application tests**,
  **1,608 tests across all 13 package/CLI suites**, both repository shell suites
  and **72 Python tests** passed. No suite was omitted.
- Two existing router cases remain declared skips: `routing config works with
  shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after
  route configuration change`.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos` on all seven changed
  Dart source/test paths: exit 0, **zero errors, zero warnings, one informational
  prefer_int_literals finding** in search_editor_surface_test.dart.
- Changed Dart formatting, approved-file equivalence, exact scope and
  `git diff --check`: passed. Repeated native-hook build notices are documented
  in build_troubleshooting.md and did not change source or command outcomes.

No new device or authenticated live-service acceptance was performed in this
integration pass. Earlier per-branch build/device evidence remains limited to
its recorded source and scenarios; the user supplied merge approval.

## Publication and preservation

Publication target: `origin/develop`, using fast-forward local integration and a
normal push. Issue completion follows verified publication; completion receipts
and the report link are recorded in the issue comments. Only the four approved
local task branches/worktrees and the three existing remote task branches are
eligible for cleanup. No PR or release is part of this integration.

Durable local evidence is retained under
`.worktrees/_artifacts/merge-97-98-116-agent-storage-20261031/`, including the
complete log, analysis, source-equivalence proof, an approved-source Git bundle,
and hash-verified copies of all three review APKs. The unrelated primary review
checkout and all other task branches are preserved.
