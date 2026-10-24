# Bookmark timeline removal and empty selection

Continues `fix/bookmark-mutation-latency` in its existing worktree. Verified runtime: `ad7886be9` (full hash below). The user confirms the previous viewer fix removes the physical-device freeze; this follow-up addresses removal directly in the timeline and a selection bar that remains open after its last selected bookmark disappears. It follows the [viewer verification](2026-10-22-bookmark-viewer-group-latency.md).

## Cause and changes

The visible bookmark search index still rebuilt all scoped tags after every library publication. Pausing it under the viewer did not help the visible grid. The search now keeps an auto-disposed, scope-local accumulator and reconciles immutable bookmark snapshots by storage ID and object identity. Only removed, inserted or replaced rows contribute tag work. Per-source and per-category reference counts preserve canonical tag frequencies and classification after removal. Published search results remain immutable, and unchanged tag entries are reused.

Autocomplete does not need date ordering, so its group scope now resolves group storage IDs through the library's existing ID map without sorting the entire group. Source filtering retains its previous substring semantics. Profile changes recreate the accumulator; source changes reconcile its scope. Superseded asynchronous library loads cannot update the retained accumulator. The viewer gate remains in place.

A separate 20,000-row grid probe found repeated URL normalization in both group selection and selection-identity reconciliation. Group selection now tests stored IDs against the group and valid-row index while retaining library order, including the input to seeded shuffle. Selection reconciliation weakly caches each immutable post snapshot's normalized identity; removed posts are not retained by that cache. New/replaced snapshots still resolve independently, and unknown rows retain their previous append/reorder behavior. A differential regression checks every sort mode, source and positive/negative tag filter against the previous membership-based selection; another checks snapshot reuse and replacement.

Bookmark grids opt into exiting selection when reconciliation removes all previously selected identities. Partial removal retains the remaining selection. Explicitly entering an empty selection mode and other consumers' existing controller defaults are unchanged. Undo does not reopen a closed selection.

## Repeated host comparison

Before path: the exact index and selector sources from `bc8fde1fcd2a98ba3fcae9cd0d1e35db027b49f9`; corrected runtime: `ad7886be9`. Run serially, alternating three before/after processes with identical fixtures and SDK:

```bash
fvm flutter test --no-pub --concurrency=1 \
  --dart-define=BOOKMARK_GRID_MUTATION_BENCHMARK=true \
  benchmark/bookmark_mutation_latency_test.dart
```

The real Hive fixture has 30 tags per post and another populated group retaining each row. Each process discards three warm-up toggles and measures twenty. Each table entry aggregates 60 samples. These are host Flutter test/debug timings for persistence, publication and settling the subscribed visible search index. They exclude rendered grid refresh, input latency and Android frame timing.

| Library / target rows | Before p50 / p95 ms | Corrected p50 / p95 ms |
| --- | ---: | ---: |
| 9,000 / 200 | 46.170 / 59.311 | 10.610 / 14.667 |
| 9,000 / 8,500 | 326.080 / 463.262 | 21.917 / 30.853 |
| 20,000 / 200 | 72.053 / 113.917 | 29.148 / 48.945 |
| 20,000 / 19,500 | 704.691 / 1138.651 | 64.981 / 145.531 |

No-index controls varied between processes: large-group p50 was 15.366 versus 15.982 ms at 9,000 rows, and 43.971 versus 64.526 ms at 20,000. No persistence-only speedup is claimed; absolute timings are noisy, and the removed tag work/operation counts are the stronger evidence. Every measured warm mutation made zero whole-library reads and repairs. The indexed before cases each selected/sorted the full group once; the corrected index performs zero `bookmarkSelect` calls. This does not remove the grid's own content selection and refresh work.

Raw logs: `/tmp/bookmark-timeline-{before,after}-{1,2,3}.log`. Aggregate: `.tmp/android-latency/timeline-host-summary.json`. Other application sources remain those of the candidate; the new post-identity cache and selection UI are not exercised by this host harness. The ignored comparison helper temporarily substitutes only the exact index and group-selector production files and restores the corrected bytes in `finally`; it has finished.

## Verification

Focused tests pass for a 20,000-row update processing only changed snapshots, immutable older results, cold-versus-incremental category/source counts, replacement, reload, Undo, scoped membership and source changes. Application-flow tests exercise real multi-selection popup removal, partial selection retention and automatic closure, including a 360-pixel view at double text scale.

- `./scripts/run_regression_tests.sh`: exit 0 on final runtime `ad7886be9a45a5d495f456cfa67c599a0a100348`; **4,505 application tests**, every package/CLI suite and repository tooling checks passed. This includes 72 Python tooling tests; the two existing GoRouter skips remain.
- `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks test/core/selection test/core/posts/post_grid_controller_selection_test.dart test/application/bookmark_collection_selection_flow_test.dart test/application/post_selection_flow_test.dart`: **529 passed** before the complete gate.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings; 3,038 existing informational diagnostics remain. Default fatal-info analysis is not a clean lint pass.
- Native debug and profile builds: passed on the exact final runtime, with only the disposable dev application-ID suffix overridden.
- Changed Dart files formatted; `git diff --check` passed.

Logs: `/tmp/bookmark-timeline-final-focused.log`, `/tmp/bookmark-timeline-final-regression.log`, `/tmp/bookmark-timeline-final-analyze.log`, `/tmp/bookmark-timeline-final-build.log`.

The final debug APK passed **37 Maestro commands** in one flow on exclusively leased `emulator-5556`, 720×1600, using the disposable `com.timberpile.boorusama.latencyqa` package. The fixture has 20,000 anonymous native snapshots; group sizes are 19,500 and 200, with all 20,000 in Default. All five seeded Hive files were SHA-256 checked before launch. The flow verifies ordinary quick-action removal, removal of the only selected row while 19,498 other group rows remain, closure of both picker and selection UI, a committed viewer off/on pair in the small group, and final-membership deletion in Default. Expected ending counts are 19,498 / 199 / 19,999 respectively. Screenshots and flow: `.tmp/android-latency/timeline-debug-final-{selection-closed,default-19999}.png`, `timeline_debug_final.yaml`.

Final APK SHA-256:

- Debug: `ddb3eb92f26f31b999aa62083565c73c6690dcc081246bb2d5b00d92b773c485`.
- Profile: `ee33ca8def4e714d3a520c00487ed6d94fc79ee8be51c1950c447ebcc6077f9c`.

Build provenance: `.tmp/android-latency/timeline-build.json`; artifacts: `qa-{debug,profile}-timeline-fixed.apk`.

An isolated host phase probe (three warm-ups, twenty samples, no thresholds) on 20,000 snapshots measured group selection median 68.691 → 11.321 ms and identity resolution 65.546 → 18.775 ms. Controller registration medians varied 16.829 → 26.041 ms. This diagnostic is one process per revision, not a repeated end-to-end claim. Logs: `/tmp/bookmark-timeline-grid-probe{,-after}.log`; ignored harness: `.tmp/android-latency/grid_refresh_probe_test.dart`.

## Android profile comparison

Three alternating before/after pairs ran on the same leased serial with no parallel host builds or tests. Each run restores the same five-file seed and verifies every SHA-256 before launch. Baseline APK runtime `be7942ae3e6306ce2e91de60da4c1c9e971dd0ae` has identical application/package/Android sources to previous task tip `bc8fde1fc`; the intervening changes are documentation/workflow only. Corrected APK runtime is `ad7886be9a45a5d495f456cfa67c599a0a100348`. Exported revision stamps and profile build mode match each artifact. The corrected report's variant label is `unspecified` because the build used `timeline-fixed`, outside the recorder's accepted labels; that value affects report metadata only, and the full revision stamp supplies source identity.

Every recording passes all **33 Maestro commands**: start diagnostics, open the large group, remove five successive first-row bookmarks with assertions for each count from 19,500 through 19,495, then stop/export. The analysis requires exactly six grid-filter spans with those row counts. The warm region starts after the initial 19,500-row grid filter completes, separating initial group entry from removal. UI delays are the existing 100 ms heartbeat's scheduling lateness above its 50 ms threshold; these are not direct tap-latency measurements or CPU profiles.

| Metric, runs 1 / 2 / 3 | Before | Corrected |
| --- | --- | --- |
| Warm removal UI delays | 5 / 5 / 5 | 2 / 1 / 1 |
| Maximum warm UI delay, ms | 990.577 / 966.355 / 995.915 | 92.389 / 54.416 / 64.474 |
| Warm group selection calls | 10 / 10 / 10 | 5 / 5 / 5 |
| Captured bookmark-screen frames | 123 / 118 / 132 | 122 / 136 / 129 |
| Bookmark-screen frame-latency p95 interval, ms | 50–100 / 50–100 / 50–100 | 50–100 / 50–100 / 50–100 |

The repeated severe removal stalls are eliminated in this workload; occasional shorter delays remain. The frame-latency p95 interval is unchanged, so this is not a general rendering/FPS improvement claim. Initial group entry still produced corrected bookmark-screen delays of 826.580 / 857.433 / 847.775 ms before the warm region.

All six recordings have zero evicted events, unrecorded/interrupted spans, or frames without context. Rejected frames were 10 / 7 / 10 before and 9 / 9 / 7 corrected. A preliminary unrecorded Undo experiment missed the short-lived toast; later measurements use five committed removals without Undo. An early debug fixture assertion expected two memberships on a post actually shared by three groups; the corrected final 37-command debug flow passes in full.

Artifacts under `.tmp/android-latency/`: `timeline-profile-{before,after}-{1,2,3}.json`, matching `*-summary.txt` and screenshots, `timeline-native-summary.json`, `timeline_profile.yaml`, `timeline_seed.py`, `pull_timeline_report.py`, and `summarize_timeline_native.py`. The fixture archive, five-file hash manifest, APKs and diagnostics remain ignored local evidence.


A higher-cardinality host probe also passes with 20,000 bookmarks, 30 tags per row, and **20,029 distinct tags** (one unique tag per post plus 29 shared tags). Each warm toggle processes exactly one snapshot. Twenty measured index-only updates after three warm-ups had p50 21.424 ms / p95 30.832 ms. This excludes persistence and rendering and is a single-process diagnostic. Harness/log: `.tmp/android-latency/index_cardinality_probe_test.dart`, `/tmp/bookmark-timeline-cardinality.log`.

## Physical-device comparison

Rebuild the task branch for the phone and keep its existing data, sort and cache condition. Compare debug builds for the reported development experience and profile builds for optimized behavior. Start Performance diagnostics, open the large group, then remove five successive bookmarks directly in the grid while checking each count. Stop/export the recording; distinguish initial group entry from the five warm removals. Repeat the before/after pair three times and compare the small group separately. Test Undo separately from the timing workload.

For selection, long-press one bookmark in a nonempty group, choose Bookmarks → Remove from group and select that group. The picker and selection bar must close, while other rows remain. Undo should restore the row without reopening selection. Removing only part of a multi-selection must retain the remaining selected rows.

## Limits

Initial indexing, large scope/profile replacements, library publication, group serialization and grid refresh still scale with data size. The fix removes repeated whole-library tag processing for ordinary changes; 20,000 is a tested workload, not a guarantee of constant-time behavior for arbitrary libraries. No physical phone is operated during this follow-up; final physical-device responsiveness remains unverified. No release-mode APK is measured.

The disposable QA package was uninstalled, its absence checked, and the emulator lease released after all recordings were copied. No emulator process was started or stopped by this follow-up.

The verification handoff initially authorized task-branch publication only.

## Approved integration

On 2026-10-22 the user accepted the result and authorized integration into
`develop`, publication and completed-task cleanup. This is issue-free work; no
unrelated Bookmark issue is closed by this integration.

The squash starts from `origin/develop` at
`565a504cf714fa9de19053b22f5f761561a35f54`, already an ancestor of the approved
task tip `f118c1cb3fe0875cbdcd37b6ee4b5b998bf3dadd`. Before this report update,
the staged squash tree exactly matched that task tip. Its runtime, tests,
dependencies and tooling are unchanged from the fully checked runtime
`ad7886be9a45a5d495f456cfa67c599a0a100348`; the later changes are this report
only. The complete gate and native measurements above therefore apply to the
integration candidate and are reused under the development workflow.

Local diagnostic evidence is preserved outside the removed task worktree.
The primary checkout and unrelated task worktrees remain unchanged.
