# Cache performance diagnostics

The local `fix/cache-performance-diagnostics` branch is based on `develop`
`5b618ddcc`, which includes the incremental LRU cache and accepted viewer swipe
fix. This branch retains its background checkpoint worker and adds cache, bookmark,
grid, feed and export instrumentation to the shared diagnostics framework.
It is no longer a diagnostic-only patch against the original pre-LRU cache.

## Capture manually

Use the **dev flavor**, in debug, profile or release mode. Open
**Settings → Developer options → Performance diagnostics** and tap
**Start new recording**. Recording never starts on launch or merely by opening
the page. The former `BOORUSAMA_PERF` launch flag has no effect. Production
flavors cannot record. Web recording is disabled.

Leave settings, reproduce the workload, then return and tap **Export report**
or **Copy report**. Export stops recording and waits 1.3 seconds for delayed
engine timing batches. On Android, Export writes directly to
`/storage/emulated/0/Download/Dev/diagnostics` with a unique name containing
the build mode, UTC timestamp and source revision. The reusable form is
`boorusama-performance-<mode>-<utc>-<commit>.json`; the comparison variant stays
inside the JSON metadata. No file picker or manual rename is required. Each
recording replaces the previous one;
Clear discards it. Recording stops after five minutes, including background
time. Captures are in memory until explicitly exported and do not survive
process death. Linux uses Copy report because its share plugin cannot export
files.

The recorder retains up to 100,000 detailed events and 1,024 simultaneously
active spans. Capacity is allocated as events arrive rather than reserved up
front. At the event density measured during the cache comparison, retaining
about 31,000 span events used roughly 21 MiB of live Dart heap in a local VM
probe; Android allocation can differ. Export temporarily needs additional
memory while copying the retained maps and encoding JSON.

For a committed build, pass
`--dart-define=BOORUSAMA_REVISION=<actual-commit-sha>` so the report identifies
its source and `--dart-define=BOORUSAMA_PERF_VARIANT=baseline|fixed` so the
report identifies the comparison side. These flags cannot identify dirty changes;
note those separately. Build mode, platform and flavor are recorded automatically.

```sh
python3 scripts/analyze_performance.py /tmp/boorusama/cache-baseline.json
python3 scripts/analyze_performance.py /tmp/boorusama/cache-fixed.json
python3 scripts/compare_cache_performance.py \
  /tmp/boorusama/cache-baseline.json /tmp/boorusama/cache-fixed.json
```

The comparison rejects reports with no accepted frames or no cache operations.
Older reports remain readable; missing measurements say **unavailable**, never
zero cost. The summary includes all instrumented operations, including fast
calls and cache stages outside the ten slowest operations.

## Measurements

| Area | Recorded metrics |
| --- | --- |
| Frames | Build, raster, vsync overhead and total frame latency; count, mean, max and p50/p95/p99 histogram intervals; over-budget and high-latency rates; latency tails above 50/100/250/500 ms |
| Screens | Separate frame distributions, nominal budgets and estimated-budget counts for search, bookmarks, groups, feeds, viewers and diagnostics |
| UI scheduling | Foreground timer delays of at least 50 ms; distribution and count per foreground minute, excluding background time |
| Cache queue | Queue-wait wall time and sampled pending depth |
| Reads | Byte-read and file-lease acquisition wall time; internal lookup hit/miss counts |
| Cache size | Current entries, all retained generations, retired generations, retained bytes and configured byte limit |
| Eviction | Synchronous victim-selection time; actual generations examined and victims selected per call; full asynchronous trim time |
| Persistence | Journal append/flush wall time and recoverable persistence failure count |
| Checkpoints | Total wall time, synchronous snapshot and dispatch, worker wall time, publication/rename and journal truncation wall time; operation failures and input entry counts |
| Flutter decoded cache | Sampled LRU bytes, live-image and pending-image counts |
| Other work | Bookmark decoding/selection/library loading, grid payload/filtering, feed repository reads, viewer/preload work, export encoding/packaging |
| Coverage | Event eviction, unrecorded/interrupted spans, rejected frames and missing historical contexts |

Numeric samples include count, total, first, last, min and max. Gauge means are
sample-weighted, not time-weighted. Cache state comes from maintained scalar
values and map lengths, sampled at queue boundaries: no `getStats()` polling,
file-stat traversal, extra directory scan or per-entry logging is added.
Eviction examination counts are loop visits (including pinned/skipped entries);
constant-time replacement-priority checks are excluded. These counts are separate
from the full cache cardinality attached to a span. Lookup counts include internal validation and are not HTTP hit rates.
Multiple manager instances contribute samples to the same fixed categories.

Complete distributions, operation failures/input sizes, decoded-cache samples
and numeric counters for admitted spans survive eviction from the bounded detail
ring. Spans rejected at the separate active-span limit are absent from operation
aggregates. Slow-frame and operation overlap details can also be lost; inspect
coverage before drawing conclusions. Both new and old viewer metrics remain
available in schema 1; cache capability is advertised separately as `cacheV1`.

## Interpretation limits

A build/raster budget violation differs from high total pipeline latency. Global
frame totals include the diagnostics page: compare the relevant screen separately.
Percentiles are histogram intervals, not exact samples. Budgets use nominal display
refresh rate with an explicitly marked 60 Hz fallback. FPS, presentation counts
and dropped frames are not inferred from idle frame gaps.

Synchronous spans measure elapsed caller work; asynchronous spans include queue,
filesystem and scheduling waits. Nested or concurrent durations must not be summed.
`cacheCheckpointWorker` includes isolate startup, encoding, writing and response
delivery. It does not measure worker CPU time or imply UI blocking. The old
`cacheIndexEncode` metric measures caller JSON encoding only in the older baseline;
it is unavailable for the background implementation. Worker encoding and write
CPU/I/O are not separately profiled. Snapshot/dispatch time can improve while queue
wait stays similar because the owning queue remains held through publication.

Frame timestamps are attributed to the historical screen at frame time, including
late release callbacks. Frames outside recording windows or with incompatible
clocks are rejected; spans crossing stop/background boundaries are discarded and
counted. An unusually late timing batch may outlive the drain. UI timer delays can
include OS scheduling, thermal contention or debugger pauses. An unexportable
permanent hang is not measured by this in-memory recorder.

Decoded-cache bytes exclude total process, GPU and live-image memory. No native
stacks, network throughput, CPU sampling, heap walking, URLs, tags, queries, post
IDs, names, credentials, exception text or stack traces enter the report. Overlap
hints narrow an investigation; they do not establish causation.

## Repeatable device comparison

1. Use matching dev-flavor **release** builds on the same device and refresh rate.
   Use a diagnostic baseline with the same recorder and counters. To isolate the
   checkpoint worker, both builds must already contain current develop's LRU and
   viewer fixes. An old pre-LRU cache baseline answers a different question.
2. Preserve the populated problematic cache, application ID, signing and app data.
   Update in place; do not uninstall, clear app data or clear only one cache.
   Match entry count **and bytes**, image settings, source data, automatic refresh
   and backup settings. Record these conditions alongside the exports.
3. Restart each app before its run. Once ready, start recording manually. Run
   separate equal-duration captures for cached-image revisits, ordinary search,
   bookmark-group overview, GIF-heavy bookmark grids, and viewer swipes. Use the
   same starting item and gestures. For queue/checkpoint testing, perform at least
   128 cache recency/write operations; confirm checkpoint samples exist.
4. Export each capture. Check accepted frames, historical screen attribution,
   cache entries/bytes, nominal budgets and coverage. Missing checkpoint samples
   mean the workload did not exercise that stage, not that it was free. Background
   recording gaps are excluded; this procedure does not measure native cold start.
5. Repeat at least three paired runs, alternating order. Compare per-screen frame
   rates/tails, UI delays, synchronous snapshot/dispatch/eviction work, journal
   time, queue waits and worker/publication time separately. Check recording on/off
   once to assess instrumentation overhead. One pair cannot prove causation.

The new analysis tools do not install apps, alter device caches or operate a phone.
Device smoothness and capture/export acceptance require the requester's run.

## Local checks

Use the pinned FVM SDK. Generate translations/registry outputs only when missing
or changed inputs require them. Focused checks include recorder, cache-manager,
navigation and diagnostics-page tests plus Python tooling. Before handoff, run
all application tests, every package/CLI suite and repository shell/Python tests
listed in `docs/engineering_guidelines.md`. Historical preparation receipts are
not current verification or device evidence.
