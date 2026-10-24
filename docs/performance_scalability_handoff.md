# Local Handoff — Static Scalability Audit and Prepared Optimizations

## Executed local review

This document records the original preparation and import instructions. The
subsequent [executed local review](performance_scalability_review.md) records
fixes, the full regression, paired measurements and remaining device/platform
limits for tested candidate `c3347405d32fafe8a3c6d638559aaced12fc9bb9` on
`maintenance/scalability-delivery-review`. The user separately authorized bounded,
seed-stable random group covers; that supersedes the preparation's exact random
cover compatibility requirement. No integration or publication occurred.

## Start here

Continue the existing `maintenance/repository-scalability-optimizations` task,
not a replacement implementation. Read current `AGENTS.md`, relevant local
skills/workflows, [the updated audit](performance_scalability_audit.md), and
[the benchmark protocol](../benchmark/scalability/README.md). Review the source
and tests before running workloads. No integration into `develop`, PR, issue
closure or release is authorized by this preparation.

**Everything added here is untested.** No Dart formatter/analyzer, test suite,
application build, benchmark, emulator or runtime profile ran in the preparation
environment. Python runner syntax, Git/source hashes and diff whitespace were
checked; those are not application verification. Do not label this ready to merge.

## Repository and delivery state

- Original and rechecked develop baseline:
  `4129eae5d6b4d3947c7d2d878b49e7db9830a97c`.
- Existing remote task branch/head preserved:
  `maintenance/repository-scalability-optimizations` at
  `5668a9208d1933614c2ee2dc1cada134f57471dd`.
- Final code/test/benchmark candidate before documentation:
  `7857c4e33ef0593313cba8b49762d551c40a06b7`.
- The delivery tip adds this handoff and the report. Obtain its exact SHA with
  `git bundle list-heads <bundle>` or `git rev-parse HEAD` after import; it is
  recorded in the external delivery manifest rather than self-embedded here.
- Issues #58 (history exhaustion) and #75 (GIF covers) remain open, unimplemented
  here, and must have their own issue-specific branches if pursued.
- No new commit was pushed. The session's available GitHub actions were reads;
  shell access had no usable authenticated Git transport. Prior conversation
  claims that commit-creation tools were available were incorrect for this work.

The preparation used an isolated, partial-source Git worktree at
`/mnt/data/boorusama-audit/worktree`, not a runnable clone. Exact original blobs,
commit and relevant ancestor trees were hash-checked. New commits preserve all
untouched repository tree entries by their original hashes. The incremental
bundle contains the new objects and requires existing commit 5668a920; it is not
an independent full-repository backup. Do not try to run Flutter in a copy of the
partial preparation directory.

### Safe import into a full local repository

Keep existing task worktrees and uncommitted changes. First inspect:

```sh
git status --short
git worktree list
git fetch origin maintenance/repository-scalability-optimizations
git cat-file -e 5668a9208d1933614c2ee2dc1cada134f57471dd^{commit}
git bundle verify /absolute/path/boorusama-scalability.bundle
git bundle list-heads /absolute/path/boorusama-scalability.bundle
```

Fetch into an **unused review ref**, never force an existing branch:

```sh
git fetch /absolute/path/boorusama-scalability.bundle \
  refs/heads/maintenance/repository-scalability-optimizations:refs/heads/review/scalability-static-audit
git merge-base --is-ancestor 5668a9208d1933614c2ee2dc1cada134f57471dd review/scalability-static-audit
git diff --stat 5668a9208d1933614c2ee2dc1cada134f57471dd review/scalability-static-audit
git log --oneline 5668a9208d1933614c2ee2dc1cada134f57471dd..review/scalability-static-audit
```

If the existing isolated task branch still points exactly to 5668a920 and is
clean, fast-forward it to the review ref there. If it has advanced or contains
other work, stop before modifying it, compare divergence, and deliberately port
these focused commits. Do not reset it, force-push, discard changes, or attach a
branch already checked out elsewhere. A temporary detached review worktree is
also safe. The delivery includes a patch series for inspection/recovery; apply
it only once and only against the matching base. Prefer the bundle to preserve
exact commit ancestry.

## Changes and review order

| Commit | Files/components | What changed |
|---|---|---|
| Existing `5668a920` | Following preview provider and its activity test | Semantic provider dependencies and shared feed index; preserved, not newly authored |
| `cd658f32` | `benchmark/scalability/{fixtures.dart,workloads_test.dart,compare.py,test_compare.py,README.md}` | Six common-API workloads; identical-harness paired runner and parser tests |
| `6d752710` | `lib/core/bookmarks/src/providers/bookmark_group_selectors.dart`; `test/performance_scalability/bookmark_preview_selection_test.dart` | Indexed group candidates and bounded deterministic top-four selection |
| `2aba98c9` | `lib/core/posts/media_preload/{providers.dart,src/preload_manager.dart}`; `packages/extended_image/lib/src/image_preloader.dart`; `preload_history_test.dart` | Bounded TTL completion/failure hints and opt-in transport-error propagation |
| `1e312d2d` | `packages/cache_manager/lib/src/image_cache_manager.dart`; `cache_byte_read_test.dart` | Single validation/pin boundary for native byte reads |
| `6196af5f` | `lib/core/bookmarks/src/types/bookmark_library_state.dart`; `bookmark_state_publication_test.dart` | No second copy of privately owned lookup maps |
| `038f5753` | `test/performance_scalability/feed_preview_populated_test.dart` | Real cached PNG remains stable through progress and invalidates on content change |
| `7857c4e3` | Comparison runner and preload test | Explicit prepared SDK prerequisite and explicit two-slot concurrency fixture |

There are no dependency, schema, backup format, localization, engine query,
thumbnail-quality or UI-layout changes. Full report sections F1–F12 distinguish
implemented work from proposals. In particular, broad feed refresh publication,
cache journal batching, history cursors, incremental grid counting, group
persistence redesign, cold-cache reconciliation and streaming export are not
implemented. A metadata-first feed-write draft was rejected during review rather
than shipped with inconsistent corruption/publication semantics.

### Critical review assumptions

**Covers:** compare bounded results against the full selector for every deterministic
sort, missing upload dates, same timestamps, cross-site IDs, unknown group IDs,
and fewer than four members. Local-ID tie-breakers make group-set iteration order
irrelevant for indexed unique rows. Duplicate/unindexed rows and seeded random
mode retain the original full path. No #75 autoplay policy is included.

**Bookmark state:** views wrap only finalized method-local maps; no writer may
escape or mutate them later. The first defensive copy and constructor defenses
remain. Check both `applyCommittedChanges` and `withAddedGroupMembers`, earlier
state retention, identity swaps, Undo with replacement storage IDs, no-op/group-only
sharing, and caller input mutation. Run existing service/provider rollback and
import tests: the new state-level test is not proof of full Undo semantics.

**Preloading:** 256 completion hints expire after 30 seconds, 256 negative hints
after five seconds, measured with monotonic time. Retry happens only when another
normal plan occurs. Capacity eviction may remove an old negative hint before its
five seconds; this is not a global network rate limiter. More than 256 distinct
failed candidates should be considered in stress review. Late cancelled operations
must never mark a replacement complete, suppress it, or free its slot. Failed
transport is propagated only for the scheduling owner; other callers keep the
old best-effort default. Optional cache write failure/disabled retention still
is not a reported durable-cache success guarantee. A cache clear can leave a
completion hint for up to 30 seconds. Documented behavior is eventual eligibility,
not immediate clear-epoch invalidation.

**Cache reads:** validate and pin while holding metadata serialization; keep actual
payload reading outside it. Clear/eviction may retire but must not delete the
leased generation. RAM publication checks the current path and release runs in
`finally`. A miss is now linearized at the first lookup rather than a second probe
that might catch a concurrent write. An already-pinned read can finish after clear.
Do not weaken journal flushes, checkpoint revision ordering, failed-worker recovery,
clear epochs, transient files or retained-byte accounting to improve a benchmark.
The public acquire span is no longer emitted for internal byte reads; compare
lookup/read/queue counters instead.

**Following:** the inherited shared preview index selects by feed posts list and
preview semantic inputs; progress-only state should preserve these references.
The new populated test asserts real image data, not only an empty result. Existing
mixed-origin guards are preserved, not redesigned. Do not extend this to identity-
only caching of mutable `StoredPostSnapshot.common/custom` maps.

## Local preparation, analysis and tests

Use the task worktree's pinned FVM SDK. Resolve dependencies and generate missing
outputs following `docs/engineering_guidelines.md`; do not upgrade dependencies.
Record any setup failures separately from code failures. First format only new or
changed Dart files, inspect the diff and commit formatting/review fixes before
recording the final candidate SHA:

```sh
fvm dart format \
  benchmark/scalability test/performance_scalability \
  lib/core/bookmarks/src/providers/bookmark_group_selectors.dart \
  lib/core/bookmarks/src/types/bookmark_library_state.dart \
  lib/core/posts/media_preload/providers.dart \
  lib/core/posts/media_preload/src/preload_manager.dart \
  packages/cache_manager/lib/src/image_cache_manager.dart \
  packages/extended_image/lib/src/image_preloader.dart
fvm flutter analyze --no-pub
```

Added tests remain unexecuted. The intended first pass is:

```sh
test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" \
  test/performance_scalability \
  test/preload_test.dart test/core/bookmarks test/core/search/following_topics
(cd packages/cache_manager && fvm flutter test --no-pub "--concurrency=$test_workers")
(cd packages/extended_image && fvm flutter test --no-pub "--concurrency=$test_workers")
python3 -m unittest discover -s benchmark/scalability -p test_compare.py
```

Also analyze changed packages if the root analysis configuration excludes them.
The cached-file tests deliberately use native `dart:io` and controlled file-read
gates, not fixed wall-clock sleeps; do not run those on Chrome. Exercise the
maintained Web configuration for shared cover/state/preload behavior separately.
No native cache change is claimed for Web. Resolve any analyzer/compilation issues
before interpreting benchmark output; static preparation cannot guarantee those
checks pass.

Existing tests to inspect include cache publication/checkpoint failure and
performance diagnostics, extended-image preloading/cache use, bookmark mutation
provider/service/group selectors, and Following preview/member tests. Preserve
legacy snapshots, backup/import round trips, profile ownership and cancellation
cases. Do not delete timing/ownership assertions merely to make a new test pass.

Before this task can be integrated into develop, run the complete final-candidate
regression, including every package/CLI and repository tooling, as AGENTS requires:

```sh
./scripts/run_regression_tests.sh
```

The benchmark-runner Python tests above live outside `scripts/tests`, so run them
explicitly as well. Record exact SHA, commands, actual results/skips and any
remaining failure. Targeted checks do not satisfy the integration gate. Changes
made during review or rebasing onto a newer develop require re-verification of
the combined candidate. Publication/integration authorization is separate.

## Benchmark execution and acceptance

Follow `benchmark/scalability/README.md` exactly. Create/reuse isolated baseline
and candidate worktrees; never benchmark against a dirty current checkout or a
baseline accidentally containing production patches. The runner copies identical
harness bytes, checks SDK/lockfile equality, uses serial FVM execution, and
alternates three rounds with two warmups/seven timed iterations by default.
Use small/medium/large cases. Outputs preserve raw JSON-reporter logs, samples,
work counters, SHAs and completeness status. No output results were fabricated
or supplied by the preparer.

The main expected structural signatures are reduced cover property reads for a
small group in a large library, bounded preload URL history, fewer native cache
lookup/queue operations, and fewer bookmark map allocations (profile separately).
Feed materialization intentionally remains a control/diagnostic for the deferred
redesign. Do not mistake list lengths for allocations or synthetic preload
completion for real network throughput. Repeated p95/median differences require
consistent host conditions; JIT/workload tests do not establish Android smoothness.

Extend existing device diagnostics rather than introducing permanent production
logging. Compare matching dev-flavor release builds on the same Android device
and refresh rate. Keep cache bytes **and** file count, profiles, queries, media,
quality, automatic refresh and backup settings equivalent. Record uninstrumented
versus instrumented runs once to understand recorder overhead. Do not sum nested
wall-time spans or attribute worker time directly to UI CPU.

### Android / Maestro scenarios

Acquire the emulator lease and follow `docs/android_emulator.md`. Use real services
and predefined safe posts. Reset disposable data between destructive scenarios;
for paired cache measurements preserve the same populated cache on both builds.

1. Open a large bookmark library with small and large groups. Compare covers,
   sorts, random order and return navigation against baseline. Add/remove/Undo
   a post in multiple groups; verify counts, Default and restored identity.
2. Swipe through a long image sequence in both directions, with rapid reversals.
   Introduce a controlled media failure, wait past the retry delay, then revisit.
   Verify recovery, bounded request concurrency, absence of retry loops, and no
   changed image quality/profile credentials.
3. Clear image cache during an active image read/preload on disposable data.
   Visible decoded content may remain; old writes must not repopulate cleared
   retained data. Revisit after hint expiry. Restart with the existing populated
   cache and confirm journal/index recovery and quota enforcement.
4. Open populated Following member previews, refresh progress, then change actual
   preview data and profile/listing settings. Progress must not initiate transport
   or repeated cached-image decode; content changes must still invalidate it.

Large exports, feed-history request replay, Nozomi multi-tag pagination and download
progress are follow-up profiling scenarios, not features fixed by this candidate.
The updated audit gives their exact next code boundaries and invariants.

Accept only when functional behavior is preserved except for the documented
preload/lookup timing changes; package and complete regression pass; data and
backup compatibility remain intact; operation-count reductions reproduce; and
actual workload/device benefits justify the added state. Revert an individual
optimization if it cannot meet those criteria. Report unresolved failures and
unmeasured impact explicitly.
