# Viewer swipe before/after diagnostics

This viewer-only tool reuses the bounded recorder, Settings controls, frame adapter,
and analyzer from `fix/cache-performance-diagnostics` at `b8bc57d93`. It imports
no cache optimization or cache/bookmark/feed/export instrumentation. Both variants
use `viewerSwipeV1`; the baseline retains its original full-collection resolution,
completed-history copies, listeners, and rebuild behavior.

The fixed checkout is `.worktrees/post-viewer-swipe-performance`. A baseline
checkout is prepared at `.worktrees/viewer-swipe-before`, on
`diagnostics/viewer-swipe-before`, with a diagnostic overlay over the common `develop` revision
`a46521eced78ae2f31a5c2517a43fc2e4e4a6072`. Both variants include the same current cache behavior from `develop`. The overlay is deliberately uncommitted
so its difference from the original implementation can be inspected. Neither
checkout is merged or published by preparing this tool.

## Permanent development tools

In the fixed app, open **Settings → Developer options → Performance diagnostics**.
**Hydrate bookmark metadata** is available in the same Developer options menu.
Both entries are restricted to the `dev` flavor. Recording starts only by tapping
**Start new recording**, in both debug and release builds of that flavor. It never
auto-starts on app launch or when opening the tool; the former `BOORUSAMA_PERF`
launch flag is no longer supported. Production builds cannot start recording.
No recording timers or frame callbacks are attached outside an explicit recording.

The already prepared comparison APKs below predate this menu move and still use
**Settings → Data and Storage → Advanced → Performance diagnostics**, as does the
historical baseline overlay. Rebuild the fixed app to use the new menu location.

## Prepared development APKs

The debug builds use the `dev` flavor and Android version codes 2191 (baseline)
and 2192 (fixed). They update `com.timberpile.boorusama.dev`. Build numbers are
command-line overrides; the source version remains unchanged. Prepared artifacts
are placed under `/tmp/boorusama`. Release builds of the same flavor use codes
2193 (baseline) and 2194 (fixed). The prepared release APKs also use the local
Android debug signing key for compatibility with the dev app; source signing
configuration is unchanged. Use matching modes for comparisons; debug timing
includes framework overhead. Installing an older version code after a newer one
may require a downgrade-capable installer; alternating fresh pairs can instead
use progressively higher `--build-number` values.

To recreate the debug pair, run in each respective checkout:

```bash
# Baseline checkout
fvm flutter build apk --debug --flavor dev --build-number=2191 \
  --dart-define=BOORUSAMA_REVISION=a46521eced78ae2f31a5c2517a43fc2e4e4a6072
# Fixed checkout
fvm flutter build apk --debug --flavor dev --build-number=2192 \
  --dart-define=BOORUSAMA_REVISION=f3ce8bc4cc3900f577a2f2e6dd88004201ff594f
```

## Build and install manually

Use the same physical Android device and the same `dev` flavor for both builds.
The commands below build APKs; they do not install or operate a device. Install
and open them yourself. Updating the same flavor preserves its application data;
do not uninstall between measurements.

From the repository root, build the baseline:

```bash
cd .worktrees/viewer-swipe-before
fvm flutter build apk --profile --flavor dev \
  --dart-define=BOORUSAMA_REVISION=a46521eced78ae2f31a5c2517a43fc2e4e4a6072
cp build/app/outputs/flutter-apk/app-dev-profile.apk /tmp/viewer-before.apk
```

Then build the fixed version:

```bash
cd ../post-viewer-swipe-performance
fvm flutter build apk --profile --flavor dev \
  --dart-define=BOORUSAMA_REVISION=f3ce8bc4cc3900f577a2f2e6dd88004201ff594f
cp build/app/outputs/flutter-apk/app-dev-profile.apk /tmp/viewer-after.apk
```

Those revision labels identify the original source under the diagnostic overlay,
not an unmodified build. Keep the APKs and source diffs with the reports. Do not
compare either capture to the cache-optimized branch: that would change a second
variable. Release mode can also be used, but use the same mode on both sides.
Debug timings include extra framework overhead.

## Record a paired run

1. Install the before APK. Choose a stable bookmark collection with at least 100
   posts; use the same collection and initial post in both builds. A mixed-origin
   collection exercises the full-collection resolution fix. Ensure its profiles
   still exist. A normal search viewer exercises the standard preloader and the
   shared settlement/build fixes; record it separately.
2. Fix device refresh rate, preload setting, viewer quality, animations, grid
   settings, and network conditions. Keep the device cool and avoid competing
   downloads, automatic backup, or feed refresh. Record these conditions alongside
   the JSON; they are not all collected automatically.
3. Warm the exact test sequence once, then fully close and reopen the app. Disk
   cache stays warm while process-local decoded images and completed-preload
   history start fresh. Use this same preparation for each paired run. Do not
   clear just one variant's cache. Cold-cache testing is a separate experiment.
4. Open **Settings → Developer options → Performance diagnostics** in the current
   fixed app. For the historical baseline and the prepared comparison APKs, use
   **Settings → Data and Storage → Advanced → Performance diagnostics**.
   Tap **Start new recording**, return to the collection, open the chosen post,
   then swipe 20 posts forward and 20 back at approximately one swipe per second.
   Pause two seconds after each group. Use the same gestures and starting point
   every time. Include a second, separately recorded pass with rapid reversals
   if that is where the stutter occurs.
5. Return to diagnostics and tap **Export report** or **Copy report**. Export
   stops collection and drains engine frame timings for 1.3 seconds. Save as
   `before-mixed-100-run1.json`. A new recording replaces the old in-memory report;
   export it before starting another. Captures expire after five minutes.
6. Install the after APK and repeat steps 2–5 exactly, saving
   `after-mixed-100-run1.json`. Do at least three pairs; alternate which build you
   measure first to reduce warming/thermal bias. Keep each scenario in its own
   capture. Idle frame gaps are not treated as dropped frames or FPS.

Repeat with a larger collection (ideally thousands of already loaded posts),
normal search, and automatic preloading disabled. Do not create or fetch a new
large library during the recording. The collection-size counter reveals how many
posts the viewer actually held, rather than how many exist remotely. For a
long-history scenario, perform the same longer browsing sequence before recording
on each build; `preloadCompletedHistory` shows the history size encountered. Repeat
with recording off as a subjective overhead check.

Also check visible behavior: still images, GIF/video thumbnail navigation,
original-quality previews, rapid reversal, zoom/pan then swipe, exit/reopen viewer,
and background/resume. In a separate listener check, change theme while a viewer
is open and return to swiping; keep the same number of changes in each variant.
Counter differences are useful evidence, but verify that navigation and previews
still work normally. No device acceptance is implied by automated checks.

## Compare reports

From the fixed checkout, run:

```bash
python3 scripts/compare_viewer_performance.py /path/to/before.json /path/to/after.json
python3 scripts/analyze_performance.py /path/to/before.json
python3 scripts/analyze_performance.py /path/to/after.json
```

The comparison uses all accepted **viewer** frames, excluding Settings and other
screens. It prints build/raster/latency distributions, over-budget percentages,
UI scheduling delays, and these work measurements:

| Measurement | Meaning |
| --- | --- |
| `mixedCollectionSize` | Posts held by the mixed viewer, sampled each preload pass |
| `mixedResolvedPosts` | Origin/media resolutions attempted per mixed pass, including unresolved profiles |
| `preloadMediaBuilds` | Strategy builder calls per manager planning call; mixed groups may query already-resolved entries |
| `preloadCompletedHistory` | Completed URL count per manager call, without copying or exporting URLs |
| `mixedPreloadResolve` | Entire synchronous mixed preload dispatch, including resolution and nested manager calls |
| `viewerPreloadDispatch` | Entire synchronous standard-viewer dispatch |
| `viewerPreloadPlan` | Manager context preparation, strategy calculation and synchronous preload dispatch; includes history-copy cost on baseline |
| `viewerPrecisePageCallback` / `viewerSettlement` | Callback count and synchronous time; cadence and theme changes affect these counts |
| `viewerItemBuild` / `viewerScaffoldBuild` | Calls/time for those widget build methods, excluding descendant layout/raster work |

Expect baseline mixed resolution counts to grow with collection length, while
fixed counts stay within the adjacent window. Zero resolutions with preloading
disabled are expected. Manager timings may improve as completed history grows.
For smoothness, look for repeatable reductions in build/raster budget violations
and UI delays across paired runs. A single lower maximum is weak evidence.
Histograms give percentile **intervals**, not exact percentiles. Nested spans
must not be summed, async/network completion time is not measured here, and
operation overlap is a clue rather than a causal stack trace.

Check coverage before interpreting a clean report. No viewer frames, pervasive
rejected frames, estimated/different refresh budgets, lost context, interrupted
spans, or event eviction limit conclusions. Aggregates survive detail-buffer
eviction, but lost frames/spans cannot be reconstructed. The generic analyzer's
headline includes all screens; use the comparison command for viewer-only rates.
Reports contain safe enum labels/cardinalities, no URLs, tags, searches, post IDs,
credentials, profile names or arbitrary error messages. They stay in memory until
explicitly copied/shared, and disappear if the process dies. Web recording is
disabled. Recording off installs no frame callback, heartbeat, lifecycle observer
or timer; call sites retain small disabled checks and screen scopes.

## Recreate the baseline overlay

The installer accepts only clean, separate checkouts at the documented original
revision or the corrected implementation revision. It validates every transform
before writing, refuses unknown/dirty targets, and never copies optimized source
files. To recreate elsewhere, from the instrumented fixed checkout:

```bash
git worktree add -b diagnostics/viewer-before-repeat ../viewer-before-repeat \
  a46521eced78ae2f31a5c2517a43fc2e4e4a6072
python3 scripts/apply_viewer_diagnostics.py ../viewer-before-repeat
cd ../viewer-before-repeat
fvm flutter pub get
(cd packages/boorusama_cli && fvm dart pub get)
./gen.sh
```

Then build with the same flags above. Do not run the installer over a checkout
with other work. No compile-time legacy-mode switch exists in the fixed app;
the before APK really runs the original implementation with measurement hooks.
