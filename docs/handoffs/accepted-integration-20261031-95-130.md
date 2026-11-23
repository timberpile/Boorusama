# Accepted integration — artist links and adaptive titles

The user accepted `feature/95-artist-links` and `feature/130-adaptive-titles` for integration. They were combined on `origin/develop` baseline `eb4560127526bd3e348ce5e8311a9b8bafd19031` in an isolated integration worktree, preserving the primary checkout and other issue branches.

- #95 reviewed task tip: `950eda5b06769adf43ba79b8925477b1cf34164a`. Integration: `f8df2e944` (`feat: share portable artist links from the artist header (#95)`). All 14 task paths match their reviewed branch blobs.
- #130 reviewed task tip: `e2416b54ce2e75b67f21564c5663492fab623688`. Integration: `dd4cd3f1c` (`fix: adapt titles and dialog actions to constrained layouts (#130)`). Thirteen task paths match directly. The Info/Warning title-host conflict combines the adaptive fitted title with develop's existing accessible expand/collapse control; neither behavior is discarded.

The complete integration candidate `dd4cd3f1cc547f6b0c63be713f604e015b722e43` passed `./scripts/run_regression_tests.sh` using normal physical-core concurrency 6. Application: 5709 passed. Every tested package/CLI, repository policy/release checks and 72 Python tooling tests completed successfully. Existing skipped cases and native-hook/Dart VM diagnostic output are retained in the durable logs; this is not a claim of zero diagnostic output. The complete run took 1100.662 seconds. Earlier session-bound attempts without a durable overall exit were retained as interrupted and are not counted as passes.

This handoff is documentation-only after the qualified candidate. No runtime, tests, dependencies or generated runtime inputs were changed after qualification. Existing branch handoffs describe their earlier local acceptance and remain historical evidence. No PR or release was requested.

The approved workflow includes publishing the two integrations to origin/develop, verifying publication, closing #95/#130, removing their obsolete status labels and deleting only their completed remote/local branches and worktrees after equivalence and clean-state checks. Detailed current execution results and artifact provenance are in the local acceptance follow-up report.
