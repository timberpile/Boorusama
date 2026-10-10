# Performance diagnostics

This is a diagnostic-only patch against `f4972eb54119fce98360c4c2303bbce375b8e722`.
It does not change cache eviction, GIF playback, bookmark mutation, or feed logic.
Use it to identify the fork regression before applying optimizations.

## Record on a device

Open **Settings → Data and Storage → Advanced → Performance diagnostics**.
Start a new recording, leave settings, reproduce the stutter, then return and
choose **Export report** or **Copy report**. Export automatically stops recording
and waits briefly for the final engine timing batch. A new recording replaces
the previous capture. Clear explicitly discards it. Captures stop after five
minutes of wall time, including any time spent in the background.

This works in native debug, profile, and release builds without a debugger.
Use profile/release for meaningful regression comparisons. Web recording is
intentionally disabled; its timing and rendering model needs separate handling.
Linux uses Copy report because the existing share plugin cannot share files there.

To capture immediately after application-shell creation, append this flag to
your usual Flutter run/build command:

```sh
--dart-define=BOORUSAMA_PERF=true
```

Optionally include `--dart-define=BOORUSAMA_REVISION=<7-to-40-character-commit-sha>`
for a committed build. This value is not discovered automatically and does not
identify uncommitted edits. Normal builds are off by default. The launch option
starts after bootstrap, not at native process entry; it is not a cold-start timer.

Analyze a captured JSON file with:

```sh
python3 scripts/analyze_performance.py boorusama-performance.json
```

## What the report means

The report contains frame build, raster, vsync-overhead and total-span timings;
frame-budget violations; foreground UI-isolate scheduling delays; safe screen
categories; named operation spans; inexpensive decoded-image-cache counters;
and fixed user markers. Summary histograms include fast frames and operations.
Percentiles are reported as histogram intervals, not fabricated exact values.

Build/raster budget violations and high pipeline latency are distinct. Total
span can be high without either build or raster independently exceeding budget.
No dropped/presented-frame count or FPS is inferred from idle frame gaps. The
budget uses the nominal refresh rate reported by the first Flutter display
(with a marked 60 Hz fallback), not a measured presentation cadence. Multi-view
applications would need per-view collection.

Operation spans describe either **synchronous elapsed time** or **asynchronous
wall time**. Neither is a sampled CPU stack. Async wall time includes database,
queue and I/O waiting. Nested or concurrent spans must not be summed. Overlap
with a slow frame or timer delay is a lead, not proof of the cause. A timer can
also be delayed by a debugger or OS scheduling. The timer reports a delay only
after execution resumes; a permanent hang or killed process cannot export it.

Frame timestamps, operation spans and route-context history use the native
monotonic clock. A late release callback is matched to the context at the actual
frame time, not the context when the callback arrives. Background/resume gaps
are excluded; spans crossing lifecycle/stop boundaries are discarded and counted.
Frames outside recording windows or with incompatible timestamps are excluded.
The stop drain lasts 1.3 seconds; unusually delayed final batches may still be lost.

Screen labels are enum categories, not route names/arguments. Root navigation
and the instrumented search, bookmark, feed and mixed-viewer screens are covered.
Uninstrumented pages/nested navigators appear as `other`; popups as `dialog`.
This is route-level attribution, not per-widget rebuild counts or per-post tracing.
Spans cover the UI isolate; worker isolates have separate recorder instances and
are not automatically forwarded into this report.

`image_cache.bytes` is the Flutter decoded LRU cache size, not total process,
GPU, or live-image memory. No heap walking, widget-tree scanning, disk-directory
scanning, stack capture or HTTP interception is performed by the recorder.

## Instrumented boundaries

| Operation | Boundary |
| --- | --- |
| `cacheQueueWait` | `DefaultImageCacheManager._run`: enqueue until execution starts |
| `cacheInitialize` | `_initialize`, including ordinary directory verification |
| `cacheRead` | `getCachedFileBytes`, including cache metadata and lease cleanup |
| `cacheTrim` | Whole `_trim`, including asynchronous retirement |
| `cacheEvictionScan` | Synchronous sort/occupancy-scan segments; ends before each retirement await |
| `cacheCheckpoint` / `cacheIndexEncode` | Full checkpoint versus its synchronous JSON creation |
| `bookmarkDecodeAll` | Stored bookmark-row decoding |
| `bookmarkSelect` | View selection/filtering/sorting |
| `bookmarkLibraryLoad` | Library load, repair and index construction |
| `gridCountPayload` / `gridFilter` | Main-isolate blacklist payload preparation and filtering |
| `feedRepositoryRead` | Feed reconstruction and cached-snapshot validation |
| `mixedPreloadResolve` | Resolving the collection for adjacent-media preload planning |
| `exportEncode` / `exportPackage` | Current JSON capture encoding and `.bsexport` package writing |

No URLs, search terms, tags, post IDs, profile/group names, credentials, exception
messages or stack traces enter this report. Do not extend the enum-based API
with arbitrary strings. Numeric `items` values are cardinalities only.

## Overhead and retention

Disabled recording installs no frame callback, observer, heartbeat or periodic
I/O. Instrumented calls still have a small disabled-path check; screen scopes
still track safe navigation categories. Enabled recording uses a 100 ms heartbeat,
one inexpensive cache sample per second, fixed-size aggregate histograms and a
2,048-event rolling buffer. Only operations lasting at least 2 ms (or failures)
receive detail entries; shorter operations still contribute to aggregates.

Active spans and route/window history are bounded. Evicted events, lost context,
rejected frames and interrupted/unrecorded spans are reported in `coverage`.
A clean-looking retained tail is not evidence that the whole session was smooth.
There are no per-frame console prints or disk writes. JSON encoding and sharing
happen only after collection stops. Reports are local and in-memory until the
user explicitly exports/copies them; they do not survive process death. Sharing
can create an OS-managed temporary file through the existing share plugin.

## Verification required before integration

The implementation was prepared in an environment without FVM/Flutter or a full
checkout. The Python analyzer and integration-transformer tests were executed;
the Dart tests, code generation, formatting, analyzer, full repository suite,
release build and device checks were not executed. Do not treat this as verified
release-ready code until those checks pass in the task worktree.

Resolve dependencies, regenerate the changed translations, and format the changes:

```sh
fvm flutter pub get
(cd packages/boorusama_cli && fvm dart pub get)
./gen.sh
git ls-files -m -o --exclude-standard '*.dart' | xargs fvm dart format
fvm flutter analyze --no-pub
```

Focused checks during development:

```sh
(cd packages/foundation && fvm flutter test --no-pub test/performance_recorder_test.dart)
fvm flutter test --no-pub test/foundation/performance_navigation_test.dart
python3 -m unittest discover -s scripts/tests -p 'test_analyze_performance.py'
```

After the last edit, run the entire suite in `docs/engineering_guidelines.md`:
root application tests, every package's complete tests including the CLI, both
repository shell-test suites, and all Python tooling tests. Focused passes do not
replace this requirement. Also test native debug and release captures, pause/resume,
route changes during delayed frame delivery, export/copy, and the diagnostics
page at narrow width and enlarged text. Check the report has nonzero frame counts
when scrolling; pervasive rejected frames require investigating timestamp domains.

For regression comparisons, use the same device, source data, grid/GIF settings,
refresh rate and warm/cold-cache conditions. Compare diagnostic-enabled and disabled
runs as an overhead check. Separate normal search, bookmark-group overview,
individual bookmark grids, viewer swipes, due/not-due auto-backup, and enabled/
disabled automatic search refresh. The upstream comparison narrows suspects;
only measured A/B changes or a bisect establish the introducing change.
