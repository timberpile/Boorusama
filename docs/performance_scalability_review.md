# Scalability delivery: executed local review

Reviewed on 2026-10-23 in the isolated sibling worktree
`/home/timber/code/Boorusama-scalability-review`, branch
`maintenance/scalability-delivery-review`. The delivery ZIP was imported through
its verified incremental bundle, preserving the original task ref and all other
worktrees. Imported HEAD was exactly
`ae007e492cffeda1b01d1a88d51737e8d0b04f5b`; prerequisite
`5668a9208d1933614c2ee2dc1cada134f57471dd` is an ancestor. The detached baseline
is `/home/timber/code/Boorusama/.worktrees/scalability-review-baseline` at
`4129eae5d6b4d3947c7d2d878b49e7db9830a97c`. Develop remains at that baseline.
No merge, push, PR, issue update, or deletion of other work was performed.

## Review-fix commits

| Commit | Scope |
|---|---|
| `06c199690` | Delivered Dart formatting/fixture compilation fixes; seeded random group covers |
| `b3aeb4cbd` | Reject losing random ranks before bounded insertion |
| `fbc5276a1`, `ed849f08b` | Opt-in allocation diagnostics with explicit measurement limits |
| `2948cdbfb` | Bounded native benchmark hang guard |
| `836594aa2`, `38191e576` | Share cleanup and keyboard pixel-capture fixture completion |
| `ef490ffea` | Deduplicate each preload plan before cooldown/completion expiry |
| `c3347405d` | Wait for observable bookmark pixel decode in the cache-sharing fixture |

## Source review and fixes

All nine imported commits and the complete baseline-to-candidate diff were
reviewed, including interactions among the five implemented changes. The
original audit's deferred designs are not implementations or measured gains.

- `5668a9208`: Following preview dependencies now select membership, profile,
  preview-list and post-list inputs. Progress preserves these references; real
  content/profile/settings publications still invalidate the future. The shared
  feed index remains scoped to the feed and its posts input. Existing mixed-site
  and inactive-profile guards are retained. This is not a general identity cache
  for mutable snapshot maps and does not fix full-feed materialization.
- `cd658f32e` and `7857c4e33`: reviewed the comparison runner, common-API fixtures,
  probes, serial execution, alternating order, failure/completeness checks,
  matching SDK/lockfile checks and harness-byte copying. Corrected non-constant
  group factory calls in the harness. Extended the same harness with separately
  named tiny/large random-group cases. A five-minute hang guard now covers the
  native filesystem case's complete setup/samples/teardown; no sample is accepted
  from a failed run. The prior baseline timeout is preserved in the raw logs.
- `6d7527105`: deterministic top-four ordering shares the original comparator.
  Indexed groups visit their own members; All still scans the library. Ties,
  missing dates, cross-site IDs, unknown/missing groups, fewer than four members,
  and malformed-row fallback were checked. Full selection and navigation retain
  their ordering/filtering behavior.
- `2aba98c9e`: positive hints expire after 30 seconds, negative hints after five
  seconds; each history is capped at 256. Expiry alone never dispatches work.
  Cancellation removes ownership before late continuations; only the current
  token can publish completion/failure or release its active slot. Disposal and
  automatic-loading disablement stop dispatch. Production opts into transport
  failure propagation; other ImagePreloader callers retain the default. Optional
  storage failure is not proof of durable admission. A cache clear can leave a
  positive hint until expiry; more than 256 failures can evict cooldown hints.
- `1e312d2de`: native byte reads validate and pin within one metadata-queue entry,
  read payloads outside it, check the current generation before publishing RAM,
  and release leases in finally. Clear/eviction may retire a pinned generation
  but cannot remove it until release. Misses linearize at the first lookup,
  intentionally losing the old optional second chance to see a concurrent write.
  Journaling, checkpoint serialization/recovery, clear epochs and quotas remain.
- `6196af5fe`: both publication methods expose only finalized method-local maps
  through read-only views. Initial ownership copies and constructor defenses
  remain; later updates create fresh maps. This is shallow structural immutability,
  not deep freezing of arbitrary stored snapshot payloads. Earlier states, new-ID
  Undo, identity swaps, group-only sharing and caller mutation were covered.
- `038f5753a`: the populated PNG test exercises a real decoded cache image through
  repeated progress and content publication. Corrected delivered test compilation
  and fixture defects: non-constant factories, an invalid missing-group UUID,
  IOOverrides' base-class requirement, and File.delete's return type. Formatted
  all delivered changed Dart files.
- `ae007e492`: treated the audit/handoff as preparation evidence, not execution.

Per the additional review request, random group covers now rank direct indexed
members by a bounded, deterministic seed/local-ID mix and retain at most four
candidates. Explicit shuffle seeds change the sample; an unseeded browser uses
one session seed. Member iteration order and unrelated library rows do not alter
an existing seeded sample. Missing IDs are skipped, duplicates/unindexed library
rows keep the conservative full-selector fallback, and random All covers retain
the old path. Historical random cover output is intentionally not preserved.
The full list used for group navigation is unchanged. Measurement exposed a
medium-group cost in the first sampler; checking the worst retained rank before
walking the four entries improved that path.

Full regression exposed cache-consumer fixture races. The share
error is published before asynchronous temporary-file release, so its fixture now
awaits the share directory becoming empty before deleting the root. Keyboard
pixel capture yields to native image I/O; a late Dio zero-duration timer could
outlive the test body. The pixel-check driver now flushes the zero-duration clock inside the body,
before Flutter's invariant check. An addTearDown-only wait ran too late, and a
global image-cache completion wait was too broad because it could include work
from earlier tests; both were rejected during verification. Contrast checks, navigation assertions,
production code, and timing/cancellation contracts were not weakened.

A late controlled-clock review reproduced one runtime scheduler defect in the
delivery: a lower-priority duplicate could remain behind a blocked URL, outlive
its first attempt's five-second failure cooldown or 30-second completion hint,
and dispatch again from the same plan. Both cases failed before the fix with
requests A, B, A instead of A, B. Each plan now deduplicates URL entries, retaining
the highest priority even when that occurrence appears later in the input. The
two new regressions also prove that a subsequent normal plan restores eligibility.
All 15 directly related preload tests passed after this fix; the complete gate
and timing run were repeated on the resulting candidate.

The bookmark cache-sharing widget test also assumed decoded pixels would arrive
within ten fixed 60 ms sleeps. That failed during full concurrency. It now waits
for an actual decoded image with a ten-second hang guard, retaining its exact
pixel-content and no-download assertions. Its complete consumer file and the
preload files passed together (33 tests) before the final full gate.

## Why retain the changes

Deterministic/indexed covers remove whole-library work for tiny groups and avoid
full sorts for All. Random sampling now has the same bounded-result objective
without changing full navigation. Cache reads remove validation and queue work
while keeping the persistence boundary intact. Owned-map views remove redundant
copies with a small, explicit ownership contract. Following's dependency narrowing
avoids progress-only preview rebuilds while retaining semantic invalidation.

Preload histories are a correctness/memory tradeoff, not a throughput win: the
synthetic dispatch workload can be slower because expiry/capacity/cooldown work
is now performed. Permanent failed-media suppression and unlimited completion
retention justify that bounded overhead. No real-network speedup is claimed.

Allocation profiling was attempted using native VM service class counters and
trace samples, including a helper isolate to avoid counting response decoding
inside the measured isolate. Early exploratory profiles were polluted by probe
allocation and/or garbage collection. Retaining snapshots prevents dead-state
elimination, but trace samples remain sparse and heap counters remain GC-sensitive.
No exact allocation-byte reduction or Android heap improvement is claimed.
`benchmark/scalability/publication_allocations_test.dart` preserves the opt-in
probe and its limitations for further investigation.

## Final verification

The checked runtime/test candidate is `c3347405d32fafe8a3c6d638559aaced12fc9bb9`.
The closing report commit changes documentation only; its final SHA is provided
in the task response. FVM used Flutter 3.47.2 and Dart 3.13.2. Dependencies and
missing ignored generated outputs were prepared independently in both trees,
including CLI dependency resolution before `./gen.sh`. The root dependency lockfile and SDK
matched; no dependency upgrade or tracked generation change was introduced.

`./scripts/run_regression_tests.sh` exited 0 on this candidate, using six detected
physical cores. Application: **4,614 passed**. Every package/CLI suite ran:

| Package | Passed | Existing individual skips |
|---|---:|---:|
| booru_clients | 104 | 0 |
| boorusama_cli | 254 | 0 |
| cache_manager | 59 | 0 |
| coreutils | 191 | 0 |
| dtext | 59 | 0 |
| extended_image | 47 | 0 |
| filename_generator | 31 | 0 |
| flutter_sqlite3_migration | 45 | 0 |
| foundation | 65 | 0 |
| go_router | 436 | 2 |
| i18n_cli | 32 | 0 |
| kurumi | 139 | 0 |
| retriable | 16 | 0 |

That is **1,478 passing package tests**, or **6,092 passing Dart tests** with the
application. The two existing go_router skips are `routing config works with
shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after
route configuration change`; both already carry upstream bug TODOs and
`skip: true`. No skips or exclusions were added.

PR-policy shell checks, Android release-script checks and all **72 repository
Python tests** passed. The comparison runner's **three Python tests** passed
separately. Additional executed checks included the initial 1,217-test affected
application run, the 79-case cover file, 303 share tests, the complete 178-test
keyboard-flow file, 15 preload tests after the queue fix, and the final 33-test
bookmark/preload consumer run. The final full pass supersedes earlier failed or
terminated attempts; those were not counted as passes.

`fvm flutter analyze --no-pub --no-fatal-infos` exited 0 with **zero errors,
zero warnings and 3,056 informational diagnostics**. Baseline analysis had 3,038
informationals and no errors/warnings. This is not lint-clean. Final formatting
checked all 19 changed Dart files and found no changes. Diff whitespace and the
baseline/prerequisite/imported-tip ancestry were checked.

Existing native-hook rebuild warnings and Flutter/native-finalizer stderr also
appeared on the baseline. They are not newly diagnosed or certified harmless by
this review. Earlier failures were preserved in logs: the share cleanup race,
keyboard timer leaks, the rejected global-image-wait experiment, the fixed-wait
bookmark pixel check, and the two scheduler regressions before their fix.

## Reproduction commands

From the prepared review worktree, the principal checks were:

```sh
./scripts/run_regression_tests.sh
fvm flutter analyze --no-pub --no-fatal-infos
python3 -m unittest discover -s benchmark/scalability -p test_compare.py
python3 benchmark/scalability/compare.py \
  --baseline /home/timber/code/Boorusama/.worktrees/scalability-review-baseline \
  --candidate /home/timber/code/Boorusama-scalability-review \
  --output /tmp/scalability-paired-new-run \
  --scales small medium large --rounds 3 --warmups 2 --iterations 7
```

Choose an unused output directory for a repeat. Both tracked trees must be clean.
The baseline is intentionally retained for reproduction. Existing viewer/grid
workloads used `benchmark/bookmark_mutation_latency_test.dart` with respectively
`--dart-define=BOOKMARK_GROUP_TOGGLE_BENCHMARK=true` and
`--dart-define=BOOKMARK_GRID_MUTATION_BENCHMARK=true`. Favorite projection used
`benchmark/server_favorite_projection_performance_test.dart`. All were invoked
with `fvm flutter test --no-pub --concurrency=1 --reporter=json`.
The evidence archive includes the isolated-cache and chained-publication driver
scripts and copied harness bytes; they create unique temporary benchmark
subdirectories and remove only those directories after execution.

## Final identical-harness measurements

Candidate C3347405d was compared with exact baseline 4129eae5. The runner verified
clean tracked trees, equal SDK/lockfile versions and identical fixture/workload
bytes; all **18 processes** passed. Parameters: small/medium/large, three
alternating rounds, two warmups, seven timed iterations, concurrency one. Each
row has **21 samples per variant**. Times are microseconds; p95 is nearest rank.
A ratio below one means a lower observed median, not statistical significance or
Android frame improvement. Work probes ran separately from uninstrumented timing.

| Scale | Workload | Baseline median / p95 | Candidate median / p95 | Median ratio |
|---|---|---:|---:|---:|
| small | `bookmark_publication` | 270 / 423 | 207 / 317 | 0.767 |
| small | `cache_byte_reads` | 467,180 / 1,491,122 | 410,921 / 961,075 | 0.880 |
| small | `cover_all` | 432 / 1,046 | 111 / 127 | 0.257 |
| small | `cover_group` | 68 / 90 | 5 / 15 | 0.074 |
| small | `cover_random_group` | 59 / 104 | 5 / 11 | 0.085 |
| small | `cover_random_large_group` | 111 / 224 | 125 / 1,563 | 1.126 |
| small | `feed_materialization` | 4,080 / 5,676 | 2,908 / 4,620 | 0.713 |
| small | `preload_history` | 3,314 / 5,315 | 3,711 / 6,578 | 1.120 |
| medium | `bookmark_publication` | 2,134 / 3,915 | 1,209 / 2,542 | 0.567 |
| medium | `cache_byte_reads` | 318,615 / 354,903 | 296,524 / 317,599 | 0.931 |
| medium | `cover_all` | 1,156 / 3,496 | 648 / 1,667 | 0.561 |
| medium | `cover_group` | 167 / 258 | 3 / 11 | 0.018 |
| medium | `cover_random_group` | 136 / 198 | 2 / 2 | 0.015 |
| medium | `cover_random_large_group` | 360 / 654 | 242 / 427 | 0.672 |
| medium | `feed_materialization` | 11,517 / 23,432 | 11,352 / 22,989 | 0.986 |
| medium | `preload_history` | 10,944 / 17,534 | 12,747 / 21,044 | 1.165 |
| large | `bookmark_publication` | 13,482 / 14,959 | 9,319 / 19,256 | 0.691 |
| large | `cache_byte_reads` | 305,212 / 313,405 | 286,715 / 298,718 | 0.939 |
| large | `cover_all` | 6,480 / 7,029 | 846 / 4,862 | 0.131 |
| large | `cover_group` | 400 / 447 | 3 / 9 | 0.007 |
| large | `cover_random_group` | 329 / 349 | 2 / 2 | 0.006 |
| large | `cover_random_large_group` | 970 / 1,125 | 621 / 1,183 | 0.640 |
| large | `feed_materialization` | 122,696 / 139,742 | 122,414 / 136,516 | 0.998 |
| large | `preload_history` | 67,558 / 72,291 | 82,857 / 93,445 | 1.226 |

Large-scale probes confirmed actual work changes:

| Work | Baseline | Candidate |
|---|---:|---:|
| Tiny-group cover ID-property reads | 25,003 | 0 |
| Tiny-group cover date-property reads | 6 | 4 |
| All-cover date-property reads | 873,108 | 194,980 |
| Random tiny-group ID-property reads | 25,003 | 3 |
| Random 12,500-member group ID-property reads | 37,500 | 12,500 |
| Native cache lookups: hits / misses | 128 / 128 | 64 / 64 |
| Native cache queue entries for 64 hits + 64 misses | 384 | 256 |
| Journal appends / checkpoints in this probe | 64 / 1 | 64 / 1 |
| Completion hints after 10,000 distinct URLs | 10,000 | 256 |
| Synthetic preloader calls | 10,000 | 10,000 |
| Stored-post visits in full feed materialization | 25,000 | 25,000 |
| Published rows / lookup entries after one replacement | 25,000 / 25,000 | 25,000 / 25,000 |

Zero bookmark ID-property reads does not mean zero candidates: the fast group
path resolves three primitive member IDs from the existing index, and reads a
bookmark's ID only when comparator ties require it. Property reads and output
cardinalities are not allocation counts. All still scans the library, and large
random groups still scan their membership. Cache figures count real validation
and queue boundaries; the missing internal public-acquire span was not treated
as saved queue work. Journal/checkpoint policy and returned data were preserved.

The final feed control has essentially the same large median and unchanged
work. Its small/medium variation is not credited as a feed improvement. The
small half-library random case was slightly slower; large fixtures improved.
Publication and large random groups have worse large-scale p95 despite lower
medians. These results support narrower work reductions and component medians,
not a universal tail-latency or app-wide claim. Preload dispatch is slower in the
synthetic workload; bounded hints, failed-media recovery and single-plan
deduplication justify that cost. It is not a network-throughput optimization.

## Cache timing investigation

An earlier combined 20-warmup/31-iteration diagnostic on candidate 38191e576 showed
substantial variation, including the unchanged feed decoder. It predates the
last preload fix and is not presented as final preload performance. An earlier
repeat was incomplete after a baseline filesystem case hit Dart's default
30-second timeout under another worktree's full test load. Its partial results
were rejected. The native filesystem case now has an explicit five-minute hang
guard for setup, samples and teardown; no functional timing contract was removed.

The cache case was then isolated from the other workloads, with identical probe
bytes on both trees: medium scale, four alternating rounds, five warmups and
11 samples, concurrency one. All eight processes passed, giving 44 samples per
variant. This ran at 38191e576; the cache-manager source blob is identical to the
final candidate. Existing recorder phase summaries were captured separately from
uninstrumented timings.

| Isolated native cache batch | Baseline | Candidate |
|---|---:|---:|
| Median, microseconds | 319,715.5 | 288,987 |
| p95, microseconds | 345,632 | 313,980 |
| Queue entries | 384 | 256 |
| Journal records | 64 | 64 |

Instrumented batch journal wall time was roughly 205–287 ms, dominating the work.
Queue-wait totals were roughly 8.5–9.2 ms on baseline and 5.2–6.7 ms on candidate.
These asynchronous spans overlap; they were not summed or called UI CPU time.
The isolated result and final standard run support a modest host cache benefit;
other combined-run variability remains visible in the retained raw data. No
Android cache latency or FPS gain is claimed.

## Existing mutation and favorite workloads

The handoff's existing workloads also ran on both revisions. Source bytes and
support-fixture hashes were checked identical before execution. Viewer order was
baseline then candidate; grid order was candidate then baseline. Each matrix case
has three warmups and 20 samples. Library size and group size varied separately,
with the tag index both absent and observed. All four mutation processes and
both favorite processes passed. Every one of the 640 measured toggle records
reported zero whole-library reads and zero repairs.

Times below are microseconds, median / nearest-rank p95. These are local
repository/provider workflows, not UI frame times.

| Mode | Rows | Target members | Tag index | Baseline | Candidate |
|---|---:|---:|---|---:|---:|
| grid | 9,000 | 200 | absent | 3,990 / 5,019 | 3,948 / 5,185 |
| grid | 9,000 | 200 | observed | 5,414 / 7,220 | 6,236.5 / 7,673 |
| grid | 9,000 | 8,500 | absent | 11,318.5 / 18,548 | 12,369 / 21,209 |
| grid | 9,000 | 8,500 | observed | 14,037 / 16,629 | 14,046.5 / 16,443 |
| grid | 20,000 | 200 | absent | 16,292 / 32,513 | 20,669.5 / 29,228 |
| grid | 20,000 | 200 | observed | 18,149.5 / 31,434 | 18,119.5 / 28,837 |
| grid | 20,000 | 19,500 | absent | 38,795.5 / 79,848 | 41,243 / 81,288 |
| grid | 20,000 | 19,500 | observed | 38,887.5 / 79,080 | 51,747 / 111,756 |
| viewer | 9,000 | 200 | absent | 3,720 / 4,818 | 3,806 / 5,308 |
| viewer | 9,000 | 200 | observed | 5,016.5 / 5,934 | 5,076 / 6,000 |
| viewer | 9,000 | 8,500 | absent | 10,966 / 19,703 | 13,874 / 16,366 |
| viewer | 9,000 | 8,500 | observed | 9,860 / 11,576 | 13,220 / 17,890 |
| viewer | 20,000 | 200 | absent | 20,233 / 30,836 | 15,392 / 26,744 |
| viewer | 20,000 | 200 | observed | 17,336 / 26,838 | 14,657.5 / 31,522 |
| viewer | 20,000 | 19,500 | absent | 40,315 / 88,419 | 37,947.5 / 79,696 |
| viewer | 20,000 | 19,500 | observed | 39,027 / 93,172 | 36,360.5 / 78,736 |

These membership-only fixtures retain every row in a separate Shared group.
Membership persistence and index work remain; the results are mixed and do not
establish a general group-toggle improvement.

Favorite projection uses one warmup and only three samples per library size:

| Existing bookmarks | Baseline median / min–max | Candidate median / min–max |
|---|---:|---:|
| 1,000 | 3,437 / 2,769–3,609 | 3,989 / 3,766–7,441 |
| 5,000 | 6,613 / 5,549–7,644 | 5,141 / 4,667–8,817 |

Projection results are mixed as well: the larger fixture has a lower candidate
median, but these three-sample results do not establish broad end-to-end latency
or tail improvements. The retained map-view change is justified by its limited
ownership contract, removed copies and measured publication component; group
persistence and other surrounding work are explicitly not fixed by it.

## Repeated-publication check

The prepared publication case starts each update from the same initial state.
A separate identical-harness check chained each result into the next update,
alternating two prebuilt replacements of the same row. Fixtures were outside
timing, and each update checked the replacement, row count and prior snapshot.
Both sizes ran in every process, with three alternating baseline/candidate rounds,
20 warmups and 31 timed updates per size: six successful processes and **93 samples
per variant per size**. Concurrency remained one.

| Chained rows | Baseline median / p95, µs | Candidate median / p95, µs |
|---|---:|---:|
| 5,000 | 2,046 / 3,353 | 1,049 / 1,857 |
| 25,000 | 17,979 / 38,693 | 8,978 / 16,288 |

A possible loss of VM fast copying from the new views was investigated rather
than assumed: the pinned Dart VM's `vm_shared/lib/map_patch.dart` already
implements `Map.unmodifiable` as `UnmodifiableMapView(Map.from(other))`. Both
paths therefore expose the same wrapper type. This source evidence and the
chained measurements support retaining the owned-map change. They do not
quantify allocation bytes, Android latency or browser behavior.

## Android evidence and restoration

The complete populated-cover/Undo flow ran on clean 38191e576: six real viewer
bookmarks, horizontal swipes, Random sorting, four populated group covers, group
entry/return retaining six rows, bulk removal 6→0, Undo 0→6 and cleanup 6→0.
Original Newest sort was restored. The Default card crop (x=372, y=184, width=324,
height=324) was pixel-identical before and after group entry/return, SHA-256:
`17ab5d2da4cf53b85718d89fa48950de232c59094f7111c31cfcd138651a13b5`.

After the scheduler fix, the only changed runtime file was preload_manager.dart;
bookmark selection, state and cache code remained identical. The final candidate
was rebuilt and installed without data reset, then exercised with two viewer
swipes in each direction. It also confirmed zero bookmarks and Newest after
reinstallation. The final debug dev build exited 0 with:

```sh
fvm flutter build apk --debug --flavor dev --target-platform android-x64   --dart-define=BOORUSAMA_REVISION=c3347405d32fafe8a3c6d638559aaced12fc9bb9
```

Local and installed final APK SHA-256 both matched:
`67c14218d95fb58518da4f3c1a439e5f16550fde79837c40583d5e7744d216c4`.
This is evidence from the final code for normal viewer behavior, and unchanged
bookmark implementation for the populated-cover flow. The controlled duplicate
expiry cases were executed on the host, not manufactured on a real server.

All UI control used Maestro on exclusively leased emulator-5554, with renewal
before calls. The app was stopped and the lease released; availability was
verified. The temporary bookmarks were removed, the original sort restored, and
account/profile data retained. No credentials were read or changed. The previous
APK remains backed up at `/tmp/scalability-android/previous.apk`.

Screenshots under `/tmp/scalability-android`: `groups-before.png`,
`default-contents.png`, `default-six.png`, `random-groups-first.png`,
`random-groups-return.png`, `cleanup-empty-newest.png`, `cleanup-groups.png`,
`final-viewer.png` and `final-empty-newest.png`. Initial cold-launch navigation
needed a readiness wait; bulk cleanup used the membership menu appropriate to
multi-selection. Corrected flows completed successfully.

## Limits and remaining acceptance work

- No paired Android profile/release frame-time, end-to-end latency, peak-heap,
  or recorder-overhead comparison was performed. Device QA used six temporary
  bookmarks; large collections were measured on the host.
- Real Android failure/cooldown/request-count stress, long reversal sessions,
  clear during active reads, and populated-cache restart/quota scenarios remain
  unrun on-device. Host/package tests cover related cancellation, leases, clear,
  persistence/recovery and ownership; that is separate evidence.
- No browser runtime suite ran. No Chrome executable was found on PATH. The
  separate Web cache manager is unchanged; bounded selector arithmetic is source
  reasoning rather than executed browser acceptance.
- Hint expiry permits later revalidation, not immediate cache-clear invalidation.
  Capacity eviction can shorten failure suppression. These are retained policies,
  not a global rate limiter or durable-cache guarantee.
- Allocation bytes remain unquantified. Journal batching, full-feed publication,
  history replay, group persistence redesign and the other deferred architecture
  findings remain outside this delivery. Issues #58 and #75 were not implemented
  or updated.

All retained changes have scoped correctness evidence and the final local
regression gate passed. Work reductions were executed and reproduced. No
unresolved functional defect in the optimized paths was found by these checks.
This is not an all-platform or Android performance acceptance sign-off; the
unrun cases above remain open. No merge, push, PR or issue mutation is authorized
or performed by this review.

Raw evidence locations:

- `/tmp/scalability-regression-final-05.log`
- `/tmp/scalability-analysis-final-03.log`
- `/tmp/scalability-runner-tests-final-02.log`
- `/tmp/scalability-preload-duplicate-red-02.log`
- `/tmp/scalability-cache-consumers-final.log`
- `/tmp/scalability-paired-c3347405d`
- `/tmp/scalability-existing-workloads-c3347405d`
- `/tmp/scalability-chained-publication-c3347405d`
- `/tmp/scalability-cache-isolated-38191e576`
- `/tmp/scalability-confirmation-38191e576` (earlier diagnostic)
- `/tmp/scalability-android-final-build.log`
- `/tmp/scalability-android`
