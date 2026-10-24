# Bookmark mutation latency: verification results

The [large-group viewer follow-up](2026-10-22-bookmark-viewer-group-latency.md)
records the subsequent physical-device report, residual autocomplete cause and
20,000-bookmark verification.

Verified runtime: `4e2553c81c64647eba40ce3b9bb4dba2d5e89ed0` on `fix/bookmark-mutation-latency`. The final delivery adds this report, a link from the original handoff and a benchmark-comment clarification after that runtime commit. Runtime and test behavior are unchanged.

The automated functional integration gate passed. Warm mutation latency improved substantially in real Hive measurements and Android profile traces, but the full responsiveness acceptance remains open because filtering/sorting and UI-delay tails remain. No PR, develop merge, issue closure, or branch/worktree deletion was performed.

## Corrections and reconciliation

- Corrected the unexecuted fixtures: missing post-link-generator import, callback/animation completion, cancellation contracts and publication fault injection. Behavioral assertions were retained.
- Kept standalone hydration's existing in-flight persistence behavior; application hydration skips cancelled or superseded responses. Added successful-response races for deletion, deletion plus re-add, newer snapshots, cancellation, import and restore.
- Replaced quadratic group membership comparisons in delta/bulk publication with hashed set equality. Snapshot-only upgrades retain identity and membership indexes.
- Bounded hydration publication to 32 committed snapshots or a 16 ms scheduled flush. Interactive mutations and exports flush first; finalization flushes outstanding rows. The timer registers outside the commit zone so it acquires the global coordinator afresh. Controlled-clock regressions cover batch size, timed publication, deletion and global exclusion.
- Deferred covered group-browser subscriptions/previews and compared immutable preview inputs by identity. A widget regression verifies no hidden filtering and current data on reveal.
- Corrected the viewer pagination fixture to wait for its cooldown-driven next request. Production pagination and the original expected-post assertion were unchanged.

The actual local feature-44 tree at `2c90227e2` was inspected before its upstream integration appeared during verification. The task branch was then reconciled with `origin/develop` at `fb1a5e3711c81f35a7f308d8f368dcfcfb97a801` through task-branch merge `e79ffae71`. The optimized `addPostsToGroup` bulk publisher remains, including authoritative recovery after an ambiguous write. Automatic Favorites-to-Bookmarks projections and manual fetches use that notifier boundary; destructive settings operations retain conservative serialized reloads. This task did not modify the separate feature worktree or merge anything into develop.

The review covered repository writers, external/import/restore reload boundaries, commit-then-throw recovery, rollback/publication failures, stale Undo, shared membership, collection duplication/movement/deletion and stale previews. Added regressions verify that a failed reconciliation retains the previous UI snapshot and requires storage reconciliation before another write, and that global deletion invalidates stale Undo. Controlled-button regressions cover target replacement, late completion, disposal, rapid input and unchanged default server-favorite locks.

## Verification

All results below apply to runtime `4e2553c81c64647eba40ce3b9bb4dba2d5e89ed0`, which includes `origin/develop` at `fb1a5e371`.

- `./scripts/run_regression_tests.sh`: exit 0. Application: **4,495 passed**. Every package/CLI suite passed, including Kurumi (139). Repository PR policy, Android release tooling and 72 Python tooling tests passed. The runner used the repository's detected-core concurrency policy.
- Two existing GoRouter skips remain: obsolete stateful-shell branches after configuration changes (`go_router_test.dart:4743`) and routing configuration with a shell route (`routing_config_test.dart:142`).
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0; no errors or warnings. There are 3,032 informational repository diagnostics. This is not a clean pass under default fatal-info analysis.
- Final formatter check across all Dart files changed from the exact base: 88 files checked, zero changes. `git diff --check` passed.
- Focused checks passed for real-Hive recovery/Undo, hydration races and batching, mutation sessions, delta state, collection flows, controlled input, hidden-preview reveal and viewer pagination. The complete runner above subsumes these checks.

The first completed application run had one viewer pagination fixture failure: a duplicate-only response completed before the existing cooldown timer fired. It also failed in isolation on the combined candidate; the unchanged exact base passed. After the controlled-clock fixture correction, all 45 viewer-file tests and the subsequent complete runner passed. Superseded/interrupted runs are not counted as full passes.

Local logs: `/tmp/bookmark-latency-regression-qualified.log` and `/tmp/bookmark-latency-analyze-qualified.log`. Documentation/comment-only delivery changes reuse the complete pass on the unchanged runtime.

## Real Hive measurements

Exact base: `03b1cb422fad84402103ee1f9544910a4d92ef77`. The committed [benchmark](../../benchmark/bookmark_mutation_latency_test.dart) uses real Hive-backed notifier operations with 100 and 5,000 native GelbooruV2 snapshots, 30 tags per post, two populated shared groups and a large target. Network access is replaced with controlled responses. The identical benchmark was copied to the exact-base worktree (SHA-256 `202a8dc5b9cd6c7472975248791551e6ffe9b8ec22148c0ce2123b992bb08bd3`).

Each process discards three warm-up cycles and measures twenty cycles. Three alternating serial processes per revision, after other host suites/builds finished, produce **60 samples per operation and size**. Each invocation passed:

```bash
fvm flutter test --no-pub --concurrency=1 benchmark/bookmark_mutation_latency_test.dart
```

p50 is the sample median; p95 is nearest rank. Values are milliseconds of API completion wall time.

| Operation, 100 bookmarks | Base p50 / p95 | Candidate p50 / p95 |
| --- | ---: | ---: |
| New addition | 3.424 / 5.075 | 1.096 / 2.842 |
| Existing post added to group | 2.900 / 3.956 | 0.627 / 0.954 |
| Removal with another membership | 4.179 / 5.485 | 0.717 / 0.976 |
| Final-membership removal | 4.175 / 5.447 | 1.107 / 1.793 |
| Undo | 4.268 / 5.962 | 1.150 / 2.713 |
| No-op membership assignment | 0.166 / 0.311 | 0.172 / 0.408 |
| Bulk add 20 | 11.104 / 13.391 | 8.399 / 10.927 |
| Bulk remove 20 | 5.088 / 9.208 | 2.185 / 6.725 |
| Ten queued toggles | 36.342 / 41.438 | 10.726 / 13.503 |

| Operation, 5,000 bookmarks | Base p50 / p95 | Candidate p50 / p95 |
| --- | ---: | ---: |
| New addition | 123.431 / 149.155 | 8.382 / 11.354 |
| Existing post added to group | 142.347 / 166.089 | 6.448 / 8.132 |
| Removal with another membership | 196.775 / 222.451 | 5.895 / 8.053 |
| Final-membership removal | 210.401 / 233.918 | 12.220 / 20.653 |
| Undo | 200.262 / 240.239 | 10.377 / 14.995 |
| No-op membership assignment | 0.259 / 0.338 | 0.235 / 0.456 |
| Bulk add 20 | 143.024 / 164.208 | 14.337 / 19.963 |
| Bulk remove 20 | 199.858 / 226.623 | 35.011 / 44.078 |
| Ten queued toggles | 1676.721 / 1747.170 | 98.588 / 130.922 |

All measured warm candidate operations had **zero whole-library reads, decodes and repairs**. No-op results are small and noisy; they do not demonstrate an improvement.

For new additions at 5,000 rows, storage-write p50/p95 was 0.528/0.715 ms on the base and 0.581/0.829 ms on the candidate. Whole-library decoding fell from 59.117/64.439 ms to zero; provider publication fell from 123.347/149.065 ms to 8.338/11.306 ms. Shared removal previously performed two whole reads and one repair; ten queued toggles performed fifteen reads and ten repairs. Both now perform zero. Ten-toggle write time remained comparable (base 5.239/9.886 ms, candidate 5.282/9.345 ms), so the improvement is primarily outside storage writes.

Hydration with immediately successful controlled fetches is **slower** on the candidate, while interactive mutations can interleave between responses. These are three independent throughput runs per revision; the table gives median and observed range in seconds.

| Rows hydrated | Base median (range) | Candidate median (range) |
| --- | ---: | ---: |
| 100 | 0.0454 (0.0454–0.0462) | 0.0656 (0.0637–0.0666) |
| 5,000 | 1.817 (1.799–1.825) | 3.004 (2.972–3.051) |

The harness measures API completion, Hive write wall time, synchronous whole-library decoding and provider publication. Provider notification is not rendered display. Queue wait and synchronous indexing are not separately isolated; the ten-toggle batch includes queueing. There are no host timing thresholds in unit tests. Raw logs are `/tmp/bookmark-latency-final-hive-{base,candidate}-{1,2,3}.log`; summaries are retained under `.tmp/android-latency/host-summary.{json,md}` in the task worktree.

## Android evidence

Used leased Android x64 emulator `emulator-5554` with Maestro MCP. A separate `com.timberpile.boorusama.latencyqa` package preserved the existing app and accounts. Its disposable Hive fixtures contain 100 or 5,000 native snapshots, 30 tags per row, two memberships per row and an anonymous Safebooru profile. One safe public image is reused to control image-content differences. No credentials were read or exposed and no physical phone was operated.

The debug smoke exercised real search/image display, ordinary quick actions and viewer/group-picker/Undo behavior; disposable debug fixtures passed grid removal and Undo at 100 and 5,000 rows. On final runtime `4e2553c8`, profile UI flows passed grid removal/Undo at both sizes, rapid viewer alternation and Undo, ten rapid All-grid quick-action taps with unchanged final membership, selection removal/Undo and context-menu presentation. A group-creation dialog was exercised with text scale 2.0 and the keyboard open; Save and Cancel remained accessible, and the temporary creation was cancelled. Targeted widgets also cover constrained width and enlarged text.

For the paired profile comparison, installed exact-base and final profile APKs, reset only the disposable package's five Hive fixture files to the same 5,000-row seed, and used the same Maestro begin/end flows. Recording begins in Performance diagnostics, then covers grid removal/Undo, opening the viewer, ten rapid bookmark taps, one removal/Undo, returning to the grid, and stopping/exporting the report. Both paired runs occurred with host tests and builds idle. Each is one recorded workload; frame counts differ with the application's animation/update behavior. Histogram quantiles are intervals, not exact samples.

| 5,000-row profile workload | Exact base | Final candidate |
| --- | ---: | ---: |
| Captured frames | 355 | 410 |
| Build p50 / p95 | 1–2 / 25–34 ms | 1–2 / 4–8 ms |
| Frame latency p50 / p95 | 17–25 / 100–250 ms | 17–25 / 34–50 ms |
| Maximum frame latency | 589.978 ms | 95.039 ms |
| Over-budget frames | 57 / 355 | 46 / 410 |
| Frames above 100 ms | 18 | 0 |
| Foreground UI delays | 34, max 571.645 ms | 16, max 292.459 ms |
| Warm whole-library load / decode calls | 15 / 29 | 0 / 0 |
| Bookmark filtering/sorting calls | 64 | 22 |
| Viewer frame latency p95 | 250–500 ms (100 frames) | 34–50 ms (152 frames) |
| Viewer foreground UI delays | 27, max 531.123 ms | 12, max 235.298 ms |

The final trace still spends 19.087 ms on average per `bookmarkSelect` call (maximum 32.220 ms). Synchronous overlap with filtering/sorting appears in several retained delays, but overlap is not a causal stack trace; OS scheduling and other work may contribute. Cache queue/read spans also remain. The profile is evidence of improvement, not a claim of uniformly smooth input or isolated mutation-to-display latency.

An additional final-runtime 100-row profile captured 454 frames: build p50/p95 1–2/4–8 ms, frame latency p50/p95 17–25/34–50 ms, maximum 124.273 ms, and no recorded foreground UI delay. It was not a paired small-library base comparison. A 5,000-row run under concurrent host verification was retained separately and has worse tails; it is not used as the paired result above.

Profile APK provenance (only the dev application-ID suffix was overridden; encoded revision/variant metadata matches the sources):

- Candidate `qa-profile-qualified.apk`, revision `4e2553c8`, SHA-256 `1e08efbee62f5ceab1252d85e29cfbb00ccfa4aeb8c109d34078b21ac257cf40`.
- Base `qa-profile-base.apk`, revision `03b1cb42`, SHA-256 `8686541132a9ab0a4401de66f1511ec66bbdd054f784762ea420faa0eae055c9`.

Retained local evidence is under `.tmp/android-latency/`: `profile5000-base.json`, `profile5000-final-idle.json`, `profile100-final.json`, their `*-summary.txt` analyses, APKs, fixture generator/seeds, `profile_begin.yaml`, `profile_end.yaml`, and screenshots (`debug100-grid.png`, `debug5000-grid.png`, `final-idle-profile5000-viewer.png`, `picker-text2-keyboard.png`, `selection-remove-undo.png`, `selection-context-menu.png`, `all-grid-rapid.png`). These disposable artifacts are ignored rather than committed. Analyze reports with `python3 scripts/analyze_performance.py <report.json>`.

After verification, the disposable QA package was uninstalled successfully, font scale was confirmed restored to 1.0, and the emulator lease was released. The original app's temporary smoke-test bookmark was removed.

## Remaining acceptance and integration decision

The automated functional integration gate is satisfied on the checked combined candidate. The performance acceptance is **not fully closed**: residual 5,000-row filtering/sorting and UI-delay tails remain, and the Android held/rate-limited hydration interaction was not reproduced. Deterministic notifier/service tests cover held fetches, exclusion and cancellation, but do not substitute for that device scenario. Not every queue, storage, synchronous-index and rendered-display phase was separately isolated. There is no physical-device validation or repeated paired Android distribution.

Integration is therefore not yet justified as satisfying every responsiveness criterion in the assignment. The measured changes are ready for review with the functional evidence above; this report does not authorize a merge. Retain the task and exact-base worktrees and use only the authorized task-branch push for delivery. No PR, develop integration or issue-44 closure is part of this task.
