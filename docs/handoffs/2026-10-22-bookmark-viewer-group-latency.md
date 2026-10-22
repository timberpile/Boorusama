# Large bookmark groups: residual viewer latency

Runtime checked: `be7942ae3e6306ce2e91de60da4c1c9e971dd0ae`, continuing `fix/bookmark-mutation-latency`. Workflow-only merge `24527c1fbe6578df709792f739e7a741b0d48b5c` incorporates `origin/develop` at `565a504cf`; its only change after the checked runtime is ten lines in `AGENTS.md`. Application, package, test, benchmark and Android sources are identical across that merge.

The user reproduced a residual freeze in the post viewer in a debug build: about 9,000 bookmarks overall, 8,500 in the active group, with much less delay in a 200-row group. This follows the [initial verification report](2026-10-21-bookmark-mutation-verification.md).

## Established cause and fix

`BookmarkSearchBar` retains its scoped autocomplete index while mounted. The index watched every library publication and rebuilt the selected group's tags even while the viewer covered the search bar. At 30 tags per snapshot, the 19,500-row case processed about 585,000 tag occurrences after every toggle. The previous hidden group-browser fix did not stop this separate subscriber.

The index now retains its current result while `bookmarkDetailsMutationProvider.isVisible` is true and detaches its library/source/profile dependencies. Closing the viewer reconnects to current inputs and refreshes the index. Membership persistence, the viewer's committed button state, queued input and Undo semantics are unchanged. Regressions cover retained identity, zero hidden selection calls, correct membership on reveal, and opening the viewer during an unfinished library load.

A separate measured allocation cost was the second full membership-map copy made solely to freeze a locally owned map. Publication now wraps that owned map in `UnmodifiableMapView`; no mutable reference escapes. Existing delta/reconstruction tests and explicit mutation rejection verify immutability and preservation of older snapshots. The no-index timing controls overlap, so this report makes no separate end-to-end speedup claim for the map change.

## Host debug/test measurements

Baseline: exact previous task tip `74971226260b3d4ca33beba70ff5ae78a9b8af02`. The same [real Hive harness](../../benchmark/bookmark_mutation_latency_test.dart) runs against baseline and corrected sources:

```bash
fvm flutter test --no-pub --concurrency=1 \
  --dart-define=BOOKMARK_GROUP_TOGGLE_BENCHMARK=true \
  benchmark/bookmark_mutation_latency_test.dart
```

The matrix keeps 9,000 or 20,000 native snapshots in the library, with 30 tags per post and either 200 or almost all rows in the target group. Another populated group retains each row, isolating membership changes from final-row deletion. Each process discards three warm-up toggles and measures twenty. Three analyzed alternating pairs (runs 2–4) provide 60 samples per case and revision; the initial overlapping/warm-up pair is excluded. Each measured case also asserts the final library/group counts.

These are host Flutter test/debug wall times including provider publication and settlement of the subscribed index, not release APK or rendered-frame timings. Absolute timings varied across processes; the group-size controls and operation counts are the stronger evidence. p50 is the median and p95 is nearest rank.

| Total / target rows, index subscribed | Previous p50 / p95 ms | Corrected p50 / p95 ms | Samples each |
| --- | ---: | ---: | ---: |
| 9,000 / 200 | 53.439 / 86.012 | 7.221 / 15.554 | 60 |
| 9,000 / 8,500 | 391.776 / 543.171 | 15.914 / 20.856 | 60 |
| 20,000 / 200 | 110.472 / 269.968 | 25.267 / 77.335 | 60 |
| 20,000 / 19,500 | 1092.858 / 1634.576 | 61.906 / 153.276 | 60 |

Without the autocomplete subscriber, large-group median controls were 18.081 versus 18.029 ms at 9,000 rows and 60.355 versus 59.681 ms at 20,000. With the subscriber present, each old toggle triggered one `bookmarkSelect`; corrected viewer toggles triggered zero. Whole-library reads and repairs remained zero in every measured warm case.

The phase probe measured roughly 6–9 ms to copy a 20,000-entry map just to freeze it, versus an effectively zero-time wrapper. This isolated result does not establish an independent total-latency improvement. Membership publication and whole-group Hive serialization still scale with data size. Refreshing the search index on returning to the group also remains substantial work. No bookmark limit or new persistence schema was introduced; 20,000 is a tested workload, not proof of arbitrary-size responsiveness.

Raw host logs: `/tmp/bookmark-group-toggle-paired-{before,after}-{2,3,4}.log`. Aggregate: `.tmp/android-latency/group-toggle-summary.json`.

## Automated verification

- `fvm flutter test --no-pub --concurrency=6 test/core/bookmarks`: **493 passed**.
- `./scripts/run_regression_tests.sh`: exit 0 on runtime `be7942ae3`; **4,497 application tests** passed, plus every package/CLI suite, PR-policy and Android-release tooling, and 72 Python tooling tests. The two existing GoRouter skips remain.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings; 3,038 informational diagnostics remain. Default fatal-info analysis is not a clean lint pass.
- Changed Dart files formatted; `git diff --check` passed. The later workflow merge changes only documentation and reuses the unchanged runtime's complete pass.

Logs: `/tmp/bookmark-viewer-group-bookmarks-tests.log`, `/tmp/bookmark-viewer-group-regression.log`, `/tmp/bookmark-viewer-group-analyze.log`, and `/tmp/bookmark-viewer-group-build.log`.

## Android verification

Used separately leased Android x64 `emulator-5556` with a 720×1600 display. The disposable `com.timberpile.boorusama.latencyqa` package contains an anonymous profile and 20,000 native snapshots, one reused safe public image and 30 tags per row. Default contains all 20,000 rows; named groups contain 19,500 and 200. Operations targeted this package on the leased serial; existing app data/accounts were preserved.

The corrected **debug APK** passed 33 Maestro commands covering rapid viewer alternation, an additional removal and Undo, route exit and exact final counts in all three groups. The 20,000-row Default case includes final-membership deletion and restoration; the named-group cases retain other memberships.

Both debug and profile APK builds passed. Only the dev application-ID suffix is overridden for the disposable package:

- Debug, runtime `be7942ae3`: SHA-256 `879a915004202a6b896d7fcbd21457adcb2f406bab2c8f2c6344ede2da46c7d9`.
- Profile, runtime `be7942ae3`: SHA-256 `406f8dc869b49c0f46b137b481eb2b684912baf421f0042aeb594b8b004374ac`.
- Previous profile, runtime `4e2553c8`: SHA-256 `1e08efbee62f5ceab1252d85e29cfbb00ccfa4aeb8c109d34078b21ac257cf40`. Its application/package/Android sources are identical to previous tip `749712262`; the intervening change was documentation and a benchmark comment.

Three alternating **profile-mode** pairs use the same emulator and five-file Hive seed, with all five SHA-256 hashes checked after transfer and before launch. Host verification and builds had finished. Each recording opens the 19,500-row group, enters its viewer, performs five off/on pairs with committed badge checks after every tap, exits and verifies the original count. Rapid taps and Undo are tested separately in the debug flow above.

| Viewer metric, runs 1 / 2 / 3 | Previous profile | Corrected profile |
| --- | --- | --- |
| Captured viewer frames | 337 / 302 / 360 | 412 / 445 / 464 |
| Group selection/index rebuild calls | 10 / 10 / 10 | 0 / 0 / 0 |
| Foreground UI delays | 10 / 11 / 10 | 0 / 0 / 1 |
| Maximum viewer UI delay | 856.855 / 816.376 / 952.018 ms | none / none / 57.523 ms |
| Viewer frame-latency p95 intervals | 34–50 / 100–250 / 50–100 ms | 100–250 / 50–100 / 34–50 ms |

The severe repeated viewer stalls are removed in these recordings. This does **not** demonstrate a consistent frame/raster speedup: rendering tails remain variable. Entry/return work outside the viewer still produces three delays per corrected recording, with overall maxima of 928–992 ms; the large tag index still rebuilds on reveal. There were no event evictions, unrecorded/interrupted spans or frames without context. Each recording reported 5–9 rejected frames.

Two preliminary profile attempts are excluded: a rapid-toggle/Undo flow did not return its expected count, and a subsequent transfer mistakenly archived `favorites.hive` twice, leaving the disposable copy empty after extraction. The latter was a harness error. The final six recordings use a unique-entry tar archive, hash verification and explicit committed-state checks; all passed their final count assertions.

Local evidence under `.tmp/android-latency/`: `group-profile-{before,after}-{1,2,3}.json`, matching `*-summary.txt` analyses and viewer screenshots, `group-profile-summary.json`, `group_profile_begin.yaml`, `group_profile_end.yaml`, `seed20000_test.dart`, the seed/archive/hash manifest, `group-build.json`, both corrected APKs and `debug20000-default-viewer.png`. These disposable data/APK artifacts remain ignored rather than committed.

## Limits and physical-device comparison

No physical phone was operated. The targeted viewer cost is removed, but large initial/reveal index builds, library-map publication, whole-group serialization and rendering still need consideration. The automated functional integration gate passes; full responsiveness acceptance remains open for those costs and a physical-device retest. Do not interpret this as a guarantee for every library size, uniformly smooth rendering or approval to merge.

For a repeatable phone comparison, rebuild this branch and keep the same data, device, sort order and cache condition. In Developer options → Performance diagnostics, start a recording, enter the large group, open the viewer, perform five ordinary off/on pairs while checking the badge, return to the group and stop/export. Repeat for the small group, then repeat the pair three times. Test rapid taps and Undo separately, checking final membership/counts after leaving the viewer. Compare debug builds for the reported development experience and profile builds for representative optimized behavior. Leave the device's app data intact.

The disposable QA app was uninstalled and the serial's lease was released after the recordings. The additional read-only `Phone3` emulator process started by this task was stopped; other emulator processes were retained. The task branch and existing worktrees are retained. Delivery is limited to the authorized task-branch push: no PR, merge into develop, issue closure or worktree/branch deletion is performed.
