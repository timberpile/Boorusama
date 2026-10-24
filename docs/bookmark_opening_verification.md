# Bookmark All opening: local diagnosis and verification

## Scope and source

Local branch: `bug/bookmark-opening-freeze`.
Original measurement base: `afc04f4933aa0e442b9f80b2662f0fc5ad277379`.
Diagnostic baseline: `1955ce59bd8efc02c21dca6fa4f6cf82d3daf2b9`.
Phone-measured runtime candidate: `09370488ba320032c402dc09c75f2e41ee512398`.
No merge, push, PR, issue change, cache batching or persistence migration occurred.

The phone recording was not included with the supplied brief. Its original
selection-to-filter gap is still an unattributed interval. The physical phone's
library/cache were not copied, cleared or modified. The measurements below
establish the generated workload's lifecycle defect, not the exact cause or
duration of the phone's recorded stalls.

## Established mechanism and changes

The search bar eagerly subscribes to an auto-disposed view family. Previously,
popping All destroyed its incremental builder, so every subsequent open processed
every bookmark/tag again. The generated host workload reproduces this behavior,
and a route-lifecycle regression fails before the ownership change.

One unfiltered All builder now lives in the provider container alongside the
library. It is created on demand and invalidated by profile configuration changes.
An immutable `library.items` revision skips all comparison/aggregation/publication
on unchanged navigation and group/active-target-only changes. Added, removed or
replaced snapshots reconcile their contributions on the next necessary update.
Group and source-filtered builders remain disposable; they cannot overwrite the
retained unfiltered All builder.

Necessary updates yield to the event loop during ID projection, aggregation,
immutable-entry publication, sort-buffer preparation and merge sorting. Each
builder serializes asynchronous updates. Superseded generations discard partial
mutable state and cannot publish stale results, including when the next library
is empty. Older published indexes retain their immutable contents. Riverpod,
Hive and source resolution remain on their existing owning isolate.

This trades cold wall time for scheduling opportunities. Chunks are bounded by
work count, not a guaranteed frame-time deadline; a single unusually large row,
GC or host/device scheduling can still lengthen a chunk.

The separate duplicate check confirmed that numeric-ID-only grid ingestion drops
distinct origins sharing an ID. Bookmark grids now use `BookmarkIdentity`,
including Pixiv work/page and Sankaku upstream string keys. Unknown identities
remain visible. Other grids retain their default duplicate policy. This proves
the correctness defect in fixtures; it does not identify the missing row in the
original recording.

## Attribution and diagnostic A/B

The recorder adds fixed-vocabulary synchronous measurements for ID-map
preparation, tag aggregation, source resolution, entry publication, sorting,
bookmark projection, grid deduplication, item-listener publication and selection
synchronization. Complete bookmark fetch, grid ingestion and cooperative index
updates use **asynchronous wall-time** spans. Nested spans must not be summed.
Source-resolution samples aggregate one call per adjusted row; normal sub-2 ms
details are not retained individually. Counters cover builder creation/disposal,
attempted full/incremental updates, added/removed contributions, canonical tag
references, distinct published tags, yields and accepted/candidate grid rows.
Replacement removes the old contribution and adds the new one. Cancellation can
leave an attempted build without a completed publication. No tag, URL, ID,
credential or snapshot content is recorded.

For a diagnostic-only comparison, build with
`--dart-define=BOORUSAMA_PERF_SKIP_IDLE_BOOKMARK_INDEX=true`. It suppresses only the
inactive empty search bar's eager subscription. Focus or a committed query still
subscribes. Reports advertise `bookmarkOpeningV1` and record the flag as
`environment.bookmark_idle_index_suppressed`. The default build keeps eager
preparation. A widget test verifies no idle subscription from another search
consumer and verifies suggestions appear after first focus with the flag set.

## Host workload evidence

Command, run serially on the instrumented baseline and final runtime candidate:

```sh
fvm flutter test --no-pub --concurrency=1 --reporter=json \
  benchmark/bookmark_opening_test.dart
```

Each of three runs creates a fresh provider container and opens/closes All nine
times without search. The fixture contains 9,000 generated rows, 60 tags per row,
54,000 distinct tags, empty category sets and no configured source profiles.
It does not exercise cache I/O, decoding, HTTP, Android frames or the phone's
actual source/tag distribution. Baseline and candidate harness bytes match.

| Per run | Baseline | Candidate |
| --- | --- | --- |
| Full builds across nine entries | 9 | 1 |
| Adjusted added rows | 81,000 | 9,000 |
| Canonical tag references processed | 4,860,000 | 540,000 |
| Warm entry median, run 1 | 742.409 ms | 0.427 ms |
| Warm entry median, run 2 | 717.124 ms | 0.609 ms |
| Warm entry median, run 3 | 695.191 ms | 0.357 ms |
| Cold entry, runs 1/2/3 | 773/704/816 ms | 1,427/1,096/1,301 ms |

The candidate yielded 1,481 times during each cold build. Its largest measured
aggregation chunks were 19.271/12.817/21.054 ms, publication chunks
5.446/8.035/4.756 ms, and sort chunks 2.853/0.657/0.429 ms. These are elapsed
host measurements under concurrent host load, not CPU self-time, stable budgets
or Android responsiveness evidence. The paired sides were not interleaved;
work-count reductions are stronger evidence than the absolute timing ratio.

An external copy of the same workload harness additionally enabled VM sampling
(`--enable-vmservice`), cleared samples before each run and fetched `getCpuSamples`
afterward. Of 1,178/1,227/1,184 samples, 564/618/621 included this candidate's
`BookmarkTagIndexBuilder._adjust` on the stack. Canonicalization appeared in
82/97/92 samples; hash combination, map lookup/insertion and set iteration were
prominent leaf functions. This supports attribution of generated-library work to
tag aggregation; it is neither a phone CPU profile nor an exact percentage of
phone stall time. Sampling captures also include assertion and harness work.

Raw host logs and CPU samples are under `/tmp/bookmark-opening-*` on the execution
host; they are local artifacts, not repository fixtures.

A recording-disabled external copy of the harness also completed three runs
(cold 2,164/1,952/1,883 ms; warm medians 0.615/0.461/0.487 ms). These controls ran
while native builds and the full suite competed for host resources, and were
slower even with recording disabled. They cannot quantify recorder overhead.
An isolated, interleaved phone recording-on/off comparison remains necessary.

## Verification and remaining acceptance

The 1,149 bookmark/grid/backup/application consumer tests passed. The final focused
25-test pass covers lifecycle retention, source/profile invalidation, replacement
and restore, group disposal, cooperative ordering across merge boundaries,
cancellation during multiple phases, empty replacement, failure recovery,
engine-specific duplicate identities and search controls. Existing index tests
cover removal, Undo, immutable results and incremental contribution counts.
Search widget checks include 320-pixel width, enlarged text and an open keyboard.
The diagnostic suppression test also passed with its compile-time flag enabled.

Affected-scope analysis reported three informational diagnostics: two existing
style notes in grid widgets and one nullable-cast note in a new test; no analyzer
errors or warnings. The analyzer exited 1 because informational diagnostics are
fatal by default. `git diff --check` passed.

`./scripts/run_regression_tests.sh` completed with exit 0 on the unchanged runtime
candidate, using six physical-core workers: 4,626 application tests and 1,478
package/CLI tests passed (6,104 total). Two existing `go_router` tests were skipped.
Both repository shell-test scripts and all 72 repository Python tests passed.
The known unchanged-input `libavif` native-hook warning occurred; see
[build troubleshooting](build_troubleshooting.md). Generation was completed
before these checks, and no tracked generated/runtime inputs changed afterward.

The dev profile APK built successfully with:

```sh
fvm flutter build apk --profile --flavor dev \
  --target-platform android-arm64,android-x64 --no-pub \
  --dart-define=BOORUSAMA_REVISION=09370488ba320032c402dc09c75f2e41ee512398 \
  --dart-define=BOORUSAMA_PERF_VARIANT=fixed
```

Artifact: `build/app/outputs/flutter-apk/app-dev-profile.apk` (298.4 MB).
SHA-256: `3d78c931d4bf580b9ba5a115deaae046320ba67f77d3acff4e93119ae4dbd62b`.
Both ARM64 and x86_64 AOT libraries contain the exact embedded revision. The
APK was installed in place on exclusively leased `emulator-5556`; no data/cache
reset occurred. The emulator's existing library contained zero bookmarks, so its
UI checks are functional/diagnostic checks only, not large-library acceptance.

The installed APK's SHA-256 matches the local artifact. A current-source profile
capture exported through the app records nine All selections/fetches/grid
ingestions/index requests, one builder creation and one full build. The report
identifies the exact candidate revision, `profile`/`dev`/`fixed`, and idle
suppression disabled. During its 174.975 seconds it accepted 1,262 frames,
including 825 bookmark-screen frames (31 over budget), with zero recorded UI
scheduling delays of at least 50 ms. Coverage: zero evicted events, unrecorded
or interrupted spans, five rejected frames and zero missing frame contexts.
No cache operations were exercised by this empty-library capture.

Maestro performed nine no-search All open/close cycles and checked the empty
count, then separately exercised first focus, typing and the open keyboard.
The draft was cleared; final hierarchy inspection showed Bookmark Groups with
the keyboard closed. Two exploratory navigation/cleanup flows stopped on stale
selectors after returning to an already-restored route; subsequent hierarchy
inspection established the actual state. No application failure was observed in
these limited checks. The emulator lease was released after verification.

Local artifacts in `artifacts/bookmark-opening/` include `emulator-profile.json`,
`diagnostics.png` and `search-keyboard.png`. Screenshots show only the empty
library and aggregate diagnostics. These ignored artifacts are not committed.

## Physical-phone recordings, 2026-10-23

The user performed the two requested scenarios in order. Both reports were pulled
directly over ADB from the connected physical phone's diagnostics folder. No UI,
application data or cache was changed through ADB. Both identify profile/dev/fixed
revision `09370488ba320032c402dc09c75f2e41ee512398`, with idle suppression disabled.
The original debug report was also retrieved: its SHA-256 exactly matches the
supplied brief (`3aa238f8e68a504ef3a78b38549a13ebbb598dea77bdc0103acacd624180defc`).

| Measurement | Repeated All opens | Immediate search after restart |
| --- | --- | --- |
| Export UTC timestamp | 2026-10-23 17:51:03 | 2026-10-23 17:51:52 |
| Duration | 34.781 s | 20.312 s |
| All fetches/index requests | 9 | 1 |
| Builder creations/full builds | 1/1 | 1/1 |
| Added rows processed | 8,986 | 8,986 |
| Canonical tag references processed | 405,621 | 405,621 |
| Distinct tags published | 29,462 | 29,462 |
| Initial index wall time | 1,025.697 ms | 890.658 ms |
| Maximum aggregation chunk | 9.235 ms | 6.738 ms |
| Maximum publication chunk | 6.143 ms | 8.005 ms |
| Maximum sort chunk | 0.168 ms | 1.479 ms |
| UI scheduling delays >=50 ms while on All | 3; max 85.191 ms | 0 |
| Over-budget bookmark frames | 3/489 | 36/194 |
| Rejected frames | 6 | 8 |

The first recording contains exactly one full build across nine route entries.
Retained detailed warm-index calls take 2.024-5.407 ms; one further call is below
the recorder's 2 ms detail threshold. Every grid ingestion accepts all 8,986
candidates; the old report's 8,986-selected/8,985-filtered discrepancy does not
recur. The reports contain no identities to establish which old row was omitted.
Selection-end to grid-ingestion-end takes 31.759-38.958 ms per visit.
The eight retained selection-end to filter-start gaps are 29.475-36.398 ms.
The remaining filter call is below the detail threshold: pairing its selection
with the next visit's filter would incorrectly invent a 2.8-second delay.

The original recording's eight recurring All delays of roughly 1.43-1.76 seconds
do not recur in either new recording. Cold index preparation remains about one
second of asynchronous wall time but is split across 954 yields. No individual
index chunk in these captures exceeds 10 ms. The search recording contains no
>=50 ms UI scheduling delay on All, though 36 over-budget frames remain; the
capture cannot distinguish keyboard animation/typing frames from other All frames.
These results support merging the scoped navigation/index-lifecycle correction,
without claiming that all frame jank or startup delay is resolved.

Both recordings still show delays on the group browser before entering All:
550.799/368.382 ms in the first, 484.156/325.609 ms in the second. Initial
synchronous library decoding takes 266.636/244.832 ms there. Attribution of the
whole startup interval remains incomplete; these are separate from repeated All
indexing. The old report is debug mode with unspecified revision, while the new
reports are profile mode, so elapsed-time ratios are not a controlled same-mode
speedup measurement. There are no evicted events, unrecorded/interrupted spans or
missing frame contexts in either new capture. Phone CPU samples and interleaved
recording-on/off comparisons were not collected; the functional performance
recommendation rests on observed work counts and the two requested scenarios.

Raw files and analyzer output are retained locally under
`artifacts/bookmark-opening/phone/` (ignored, not committed). New report SHA-256s:

- Repeated opens: `8f87c2f3c98de24eaa480e810545062807a8aedc55d324c5df6afa360110e15c`.
- Immediate search: `f844e695626f15e404bb31b143e6bd4a82564c4093eebeb25acff64f0a537047`.

Cache same-key touch amplification remains a separate follow-up; no cache
persistence guarantees were changed here.

## Check against current develop

After retrieving the phone recordings, `origin/develop` had advanced to
`f3962b1ce9daf6e67278a2a9ebc698d2b59caf35`. The same isolated task branch was
rebased onto it without conflicts, preserving the new tag-color behavior and
its updated widget tests. No develop integration or publication occurred.
The combined candidate is `7a55dcf8b107e619fe8dfd06bc6511629411d1db`
(runtime commit `4556dec8f83cb9f7187e3e7e961986ffe6137501`). The phone recordings
remain evidence for the earlier identified APK; the index builder, bookmark
projection and duplicate-identity implementation have identical file contents in
the combined candidate. No newer APK was installed on the phone.

`./gen.sh` successfully regenerated outputs for develop's changed inputs before
verification; no tracked generated files changed. The identical 9,000-row
benchmark passed all three runs again, retaining one full build and 540,000
processed tag references across each set of nine entries.

Affected-scope analysis has no errors or warnings and four informational
diagnostics (the earlier three plus an existing redundant import introduced by
develop's theme test changes). It exits 1 because infos are fatal by default.
`./scripts/run_regression_tests.sh` completed with exit 0 on that unchanged
runtime candidate, with six workers: 4,746 application tests and 1,500 package/CLI
tests passed (6,246 total), with the same two existing `go_router` skips. Both
shell-test scripts and all 72 repository Python tests passed. A fresh remote
read confirmed `origin/develop` was still `f3962b1ce` after the run.

The combined candidate is recommended for integration. The phone recordings
demonstrate the intended one-build lifecycle on the real 8,986-row library and
no recurrence of the long All-view pauses in the requested scenarios. Initial
group loading and the remaining over-budget search frames are documented limits,
not claims of completely smooth behavior. No additional phone recordings are
requested for this scoped fix. Actual merge/publication remains separately
authorized; this verification did not perform either action.
