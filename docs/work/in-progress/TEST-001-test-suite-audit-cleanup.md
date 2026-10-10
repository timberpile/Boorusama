# TEST-001 — Audit and streamline the automated test suite

Priority: Normal  
Affected features: Root Flutter tests, package/CLI tests, Android tests, repository tooling, CI, agent verification  
Base branch: `develop` (starting commit `f4972eb54119fce98360c4c2303bbce375b8e722`)  
Work branch: `feature/test-001-test-suite-cleanup`  
Implementer/session: ChatGPT, 2026-10-10 (GitHub-only implementation)  
Worktree: No local checkout/worktree available in this execution environment; continue in an isolated local worktree on this branch.

## Problem

The fork currently contains **406** test source files across `test/`, package
`test/` directories, Android unit tests, and `scripts/tests/`.
`AGENTS.md` currently mandates the complete application, package, CLI, and
repository-tooling suites after the final edit of *every* task. This provides
strong coverage but can increase agent iteration time, especially when tests
do repeated expensive setup or when diagnostics run as regular regression tests.

Do **not** delete tests merely because they are small, numerous, or appear
trivial: small deterministic tests are often nearly free. Keep regression
coverage for import/export data integrity, legacy migrations, cache recovery,
authentication, privacy, profile identity, and concurrency.

## Goals

1. Preserve meaningful regression coverage while removing proven duplicate or
   obsolete checks.
2. Keep diagnostic performance workloads separate from normal test discovery.
3. Determine which test files actually dominate wall-clock time and fix
   avoidable setup, real-time waiting, and test-environment overhead.
4. Establish clear **targeted**, **full**, and **opt-in diagnostic** test runs,
   without silently weakening required release verification.

## Source review findings

- `test/core/search/subscriptions/feed_cache_profile_uuid_performance_test.dart`
  prints a timing sample with no performance assertion; it is a benchmark.
- `test/core/bookmarks/bookmark_pipeline_performance_test.dart` generates,
  stores, and cold-loads 1,000 Hive bookmarks with a broad ten-second limit.
- `test/core/posts/post/post_pipeline_performance_test.dart` serializes 1,000
  posts three times and resolves 5,000 post origins in repeated rounds.
- `test/core/posts/post/post_presentation_provider_performance_test.dart`
  is *not* a timed performance test: it checks provider identity/cache state;
  retain it as a functional contract test under a more accurate filename.
- `share_payload_selection_test.dart` overlaps with
  `share_payloads_test.dart` (image/original row IDs and the lazy video case).
  Preserve distinct checks for sample-only images, deferred originals and
  preview-only video while consolidating them.
- `share_payload_description_test.dart` exercises the same widget as
  `share_payload_tile_test.dart`; consolidate without losing the hidden-URL
  assertion.
- Simple `settings/*_test.dart` files often preserve old serialized-setting
  defaults. Do not remove these based on file length.
- Some complex tests in backups/import, feed refresh, or post viewing appear
  large, but cover substantive recovery and edge cases. Do not drop them just
  for having a large fixture or many assertions.

These are static review findings, **not measured performance data**.

## Implemented in this branch (pending execution verification)

- [x] Move the three workload benchmarks above to `benchmark/` without
  removing their diagnostic assertions or output.
- [x] Add `scripts/run_test_benchmarks.sh` for explicit opt-in execution.
- [x] Keep normal functional tests for snapshot round-trips, bookmark storage,
  and feed persistence in `test/`.
- [x] Consolidate the share payload selection/description cases into nearby
  tests, dropping only overlapping assertions.
- [x] Rename the mislabeled provider-cache test, keeping its behavior checks.
- [x] Document the opt-in benchmark convention in engineering guidelines.

## Remaining audit and local verification

- [ ] Create/use a dedicated **local worktree** for this remote branch; do not
  alter the developer's main checkout.
- [ ] With the pinned FVM SDK, format/check changed Dart sources; run targeted
  share payload tests, the relocated benchmark runner, and all required suites
  from `docs/engineering_guidelines.md#complete-local-test-suite`.
- [ ] Benchmark the test suite by **file** from the parent `develop` commit
  and the updated branch under comparable conditions; record actual elapsed
  times, test counts, skipped tests, and slowest cases. Avoid assuming that
  removing three workloads yields a meaningful overall speedup.
- [ ] Inspect genuinely slow tests for real delays, excessive
  `pumpAndSettle`, repeated database initialization, and unnecessary fixtures.
  Prefer optimization/parameterization to excluding behavior tests.
- [ ] Review duplicate assertions and obsolete feature tests against current
  implementation, not just similar test names.
- [ ] Investigate existing `skip:` cases (including migration/export and GIF
  tests) before deciding whether to fix, remove, or move them.
- [ ] Propose an evidence-based fast feedback loop for agents (affected tests
  while developing; full suite at the existing required verification point).
  Adjust `AGENTS.md` or CI only after timings demonstrate a safe benefit.
- [ ] Capture before/after timings, notable coverage tradeoffs, and executed
  commands in this ticket before moving it to `done/`.

## Acceptance criteria

- No unique behavioral assertions are discarded without a documented
  replacement or an explicit obsolete-feature justification.
- The default root Flutter suite does not discover `benchmark/`; diagnostics
  remain runnable on demand and keep their original high-volume workloads.
- All test-file moves and imports compile, targeted tests pass, and the complete
  local suite required by current repository rules passes.
- A reproducible baseline identifies true slow-test candidates; any
  exclusions from default runs are justified and documented.
- No test-only change introduces altered app behavior or production dependencies.

## Verification / status

Remote-source review and implementation only. No Flutter/Dart SDK or checkout
is available in the current execution environment, so **no tests, formatting,
or performance measurements have been run**. Do not mark this item done or
merge it until local verification and the remaining audit are complete.
