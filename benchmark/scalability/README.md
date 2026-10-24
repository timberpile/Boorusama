# Baseline/candidate scalability workloads

The [executed local review](../../docs/performance_scalability_review.md) now
records baseline/candidate runs, actual work reductions, separate random-group
measurements and remaining limits. Preparation-era statements below describe
the original audit environment. Current results apply to the exact tested code
SHA recorded in that report; no Android frame-time gain is claimed.

**Prepared by static inspection; not executed in the audit environment.** These
are opt-in diagnostic workloads, not performance budgets or Android frame-time
claims. Functional regression tests are under `test/performance_scalability/`.

## Prerequisites and isolation

Use two clean, fully prepared worktrees from the same repository, the pinned FVM
SDK, identical dependency lockfiles, and the same host. Read `AGENTS.md` first.
The original baseline is `4129eae5d6b4d3947c7d2d878b49e7db9830a97c`. The audit
continues `maintenance/repository-scalability-optimizations`, preserving its
existing `5668a9208d1933614c2ee2dc1cada134f57471dd` preview-isolation commit.
Candidate-only tests must not be copied to the baseline.

Example preparation from the primary checkout (choose unused paths; reuse
existing worktrees rather than resetting or overwriting them):

```sh
git worktree list
git worktree add --detach ../boorusama-perf-baseline 4129eae5d6b4d3947c7d2d878b49e7db9830a97c
# The candidate must contain the delivered commits. See the local handoff.
git worktree add --detach ../boorusama-perf-candidate <candidate-sha>
```

Resolve pinned dependencies in each tree with `fvm flutter pub get`. Follow
`docs/engineering_guidelines.md` for generation only where outputs are missing:
resolve the CLI with `(cd packages/boorusama_cli && fvm dart pub get)` before
`./gen.sh`. Do not alter the baseline lockfile, adopt unrelated upgrades, or
copy a candidate `.dart_tool` directory to the baseline. Inspect any tracked
changes. Fix setup deliberately; the comparison runner rejects dirty tracked
files. It does not install, fetch, generate, format, or commit anything.

## Run the same harness against both revisions

Run the runner **from the candidate**, passing a new output directory outside
both trees:

```sh
python3 benchmark/scalability/compare.py \
  --baseline ../boorusama-perf-baseline \
  --candidate ../boorusama-perf-candidate \
  --output ../scalability-results-01 \
  --scales small medium large --rounds 3 --warmups 2 --iterations 7
```

On Windows, use `python` and PowerShell argument continuation or one line. Keep
FVM available on PATH. First run the runner's own checks locally:

```sh
python3 -m unittest discover -s benchmark/scalability -p test_compare.py
```

The runner checks the exact baseline, clean tracked state, pinned SDK and
lockfile equality. It copies **identical bytes** of `fixtures.dart` and
`workloads_test.dart` into a uniquely owned temporary subdirectory of each
`benchmark/` directory. Relative fixture imports work at that depth on both
revisions. It invokes `fvm flutter test --no-pub --concurrency=1 --reporter=json`
with the same Dart defines on both sides. Round order alternates; only its own
scratch directories are removed. It never switches a branch or clears user
application data. Keep both worktrees unchanged and otherwise idle during a run.

Each process runs the eight cases below. Fixtures are built outside timed sections;
work-count probes run separately from uninstrumented timings where relevant.
The fake preloader still measures fake-async dispatch overhead, which is shared
by both sides. No real server is contacted by these workloads.

| Workload | Small / medium / large | Measures | Important limit |
|---|---|---|---|
| `cover_group` | 250 / 5,000 / 25,000 library rows; three group members | Selection time; ID/date/post property reads | Not widget layout or image decoding |
| `cover_random_group` | Same library sizes; three members | Seed-stable sample selection and property reads | Random output may differ from baseline |
| `cover_random_large_group` | Same library sizes; half the library in a group | Bounded sample selection over indexed members | Still traverses the group |
| `cover_all` | Same library sizes | Full-library top-four selection and property reads | Still visits the complete All view |
| `bookmark_publication` | Same library sizes; one replaced row | `applyCommittedChanges` elapsed time and output cardinality | Output rows are **not allocation counts**; profile map allocation separately |
| `feed_materialization` | 3×50 / 10×250 / 25×1,000 cached posts | Real repository snapshot decoding; visits to stored post list | In-memory Hive boundary; not a complete refresh or disk-I/O measurement |
| `preload_history` | 128 / 1,000 / 10,000 distinct URLs | Completion-history retention; dispatch time | Synthetic transport, not network throughput |
| `cache_byte_reads` | 32 / 256 / 1,024 files, 128 bytes each | 64 disk hits + 64 misses; lookup, queue, journal/checkpoint counters | Native filesystem; OS page-cache state is uncontrolled; no RAM/decoded cache |

## Output and interpretation

`manifest.json` records revisions, harness hashes, SDK output, host, command
arguments, and completion status. Each process has a JSON-reporter log and
stderr file. `records.json` preserves samples and counters; `comparison.json`
contains medians, nearest-rank p95, per-round medians, and raw work counters.
`candidate_over_baseline_median < 1` means a lower observed median only; it does
not establish statistical significance, causality, or an Android improvement.
Seven samples give a coarse p95; increase iterations for serious decisions.
Do not compare failed or incomplete manifests. A timeout is a generous hang
guard, not a latency target. The native cache workload explicitly permits five
minutes for setup, all samples, and teardown; its durable fixture creation can
exceed the Dart test runner's default 30-second timeout on this host. Logs are retained when a subprocess fails.

Expected **structural** changes to check, not measured results:

- Tiny-group cover reads should no longer grow with unrelated library rows.
  Deterministic cover results must exactly match full selection and its tie
  breakers; random All-view ordering retains the original implementation. Random group covers use bounded seed-stable sampling, independently measured below.
- Completion history should be at most 256 entries, rather than all distinct
  successful URLs. Completion expires after 30 seconds; failure suppression
  lasts five seconds and only a later plan retries. These policies have separate
  controlled-clock regression tests.
- Per native disk hit, lookups fall from two to one and queue entries from four
  to three; per miss, both fall from two to one. For the 64+64 probe this implies
  lookup totals of 64 hits/64 misses and 256 queue entries in the candidate,
  versus 128/128 and 384 on the original baseline, excluding setup. Journal
  appends remain 64. Checkpoint phase should match because durability policy is
  unchanged. Recorder lookup counts are **not HTTP hit rates**.
- Bookmark publication removes two redundant whole-map copies, but still scans
  and shallow-copies library data. Compare allocation traces separately; do not
  turn output-cardinality counters into invented allocation measurements.
- Full feed materialization is intentionally still expensive. This workload is
  a retained diagnostic/control for the deferred coordinated refresh redesign,
  not a claim that the current candidate fixes the whole feed library.

## Additional local measurements

For the existing preview-isolation commit, run both its original tests and
`test/performance_scalability/feed_preview_populated_test.dart`. The added case
uses a real cached PNG and asserts that refresh progress does not issue more
cache reads or transport. It also checks real publication invalidation.

Use DevTools allocation profiling around bookmark publication, cover selection,
and large export. Capture peak heap and garbage-collection behavior, not just
process RSS or live decoded-cache bytes. For feed-history replay, record actual
source page requests before the first genuinely older visible result, then
repeat after reopening and query changes. Those higher-level cases remain
manual/instrumentation work; the synthetic feed-materialization workload does
not substitute for them.

For Android use matching dev-flavor release builds, the same refresh rate,
profiles/media/settings/cache state, and the existing manual recorder described
in `docs/performance_diagnostics.md`. Compare image-cache queue and journal wall
time separately from UI/raster frames. Exercise in both directions: grids,
large bookmark groups, Following refresh, failed-media recovery, clear while
reading, and a long viewer session. Follow the emulator lease procedure before
Maestro operations. Use disposable data for destructive clear/restore scenarios;
preserve a populated cache for paired cache-performance comparisons.

No harness or regression test in this directory was run during preparation.

## Local review additions

Random group covers now rank indexed members by a seed and local storage ID,
retaining at most four candidates. Membership iteration order and unrelated
library rows do not affect a seeded sample. Unseeded covers use one session seed.
The full selector used for ordinary group navigation, random All covers, and
malformed-row fallbacks retains its historical ordering. The two random workload
rows are measured separately from the six originally delivered workloads.

`publication_allocations_test.dart` is a separate opt-in VM-service probe for
30 retained one-row publications over 25,000 bookmarks after ten warmup publications.
Run it with `fvm flutter test --no-pub --concurrency=1 --enable-vmservice
benchmark/scalability/publication_allocations_test.dart`. For a paired run,
copy identical bytes of it and `fixtures.dart` into a uniquely owned temporary
subdirectory under each tree's `benchmark/`, alternate order, and retain stdout.
The JSON records before/after structural-container allocation counters from the same isolate. A helper isolate handles VM-service response decoding to keep that instrumentation outside the measured heap.
Inspect accumulator support and garbage collection before interpreting them;
current heap is not total allocation work. Time-bounded class allocation trace samples are also retained; sparse samples do not establish exact allocation counts or bytes. This probe is outside the ordinary
suite and the eight-scenario timing runner.
