# Issue #57 continuation — October 25, 2026

The isolated task starts from published develop `907962fd4`. Local merge commits preserve #76's parser history (`09662220c`) and #53's bounded metadata/preload history (`a57f29a6f`). These are dependency reconciliation on the task branch, not acceptance or publication. The later #53 bounded-read fast path is carried identically into this worktree and must remain associated with that issue when integrating the three-task combination.

Original uses new persisted scalar 5. Existing scalars 0–4 and legacy string meanings, including old `original` mapping to High, are preserved. The setting reuses existing Original localization. Global/profile settings select source Original URLs with safe stored-rendition fallback; explicit source resolution overrides and video/download quality remain independent. Realbooru uses #76's parsed Original and falls back to its displayed sample when no Original is verified.

The existing progressive image pipeline stages a distinct High sample beside the Original request. Decoding determines replacement; lower/High pixels remain on failure, late intermediates cannot downgrade a completed Original, retry retains High without downloading it again, and missing/identical URLs are skipped. The retained image/controller and known full-post geometry preserve zoom and edge-gesture state. No separate loader/parser was introduced.

Both ordinary and mixed neighbor preload paths exclude Original, including an Original-alias grid fallback. The new setting can warm a distinct High sample, while legacy profile overrides retain their behavior. Metadata admission/cancellation and source isolation continue to use #53. A broader consumer exposed extra collection reads in #53 even for ordinary engines; that defect was reproduced on #53 itself and fixed there without changing queue concurrency.

The final dependency candidate includes published develop `a7cdaaff3a285b3ae6e87c9755a28301af02c0e6`, #53 through `5433cada1`, and #76 through `9ce9054bd`. Runtime/test HEAD is `fb8a910657d5b015d8340992a8d49445cef37c60`. Internal merges preserve the task histories; no ordinary develop merge or publication has occurred.

Current verification:

- The earlier focused settings/resolver/progressive/preload run passed 76 tests; the broader details/page-view/preload/Gelbooru V2/settings/navigation run passed 296 tests. Controlled tests cover the actual 320px/2x selector, compatibility/overrides, intermediate and Original decoding/failure/retry, geometry/zoom continuity, source identity and cancellation.
- Live UI exposed Retry behind the action footer when original dimensions are unknown. A new headless production-viewer test failed at 320px and 1x/2x text with unknown dimensions. The fix puts Retry below the standard top controls. `fvm flutter test --no-pub --concurrency=6 test/application/original_upgrade_retry_flow_test.dart test/core/posts/details/progressive_post_image_test.dart` passed 31 tests. It checks real footer hit testing, retained decoded sample pixels, two Original requests and no sample refetch.
- Final `./scripts/run_regression_tests.sh` on `fb8a91065` completed with exit 0: 5,001 application tests, 1,566 package/CLI tests, both shell suites and 72 Python tests. Two existing go_router tests were skipped. `/tmp/boorusama-viewer-retry-regression-final.log`. Earlier complete passes are superseded by this candidate.
- Changed-scope analysis reports one existing informational diagnostic and no warnings/errors; the earlier complete changed-file analysis reported nine informational diagnostics. `/tmp/boorusama-57-retry-analysis.log`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --target-platform android-x64` passed unchanged on repeat without the earlier file-modified-during-build message. `/tmp/boorusama-57-retry-dev-build-repeat.log`.
- API 37 emulator installation SHA-256 equals local APK `ec5c3848e3a29b620590649f19d9cf06c13c6d0d52513310c259ba5e519fcaa0`. No data reset.

Android/live evidence:

- Ordinary source public three-post search on the earlier combined build: opening the first post requested its sample and Original once; unvisited neighbors requested no Original. Forward/reverse swipes and reopening reused all three successful Originals without duplicate requests. VM observation confirmed decoded Original display. These counts predate the final retry placement and #76 URL canonicalization; they are not claimed as fresh counts from the final APK. The unchanged ordinary pipeline is also covered by the final complete suite.
- Final APK Realbooru: five viewed pages plus two ahead produced seven unique HTML detail requests, one per ID. Grid loading never requests per-post detail. Realbooru's existing grid does try static original guesses for original-only posts; this is separate from neighbor prefetch and is not misreported as a zero-Original grid.
- Current original-only posts reuse the canonical grid cache without a second Original request. The VM verified actual successful Original display on the preceding canonicalization build. For distinct-rendition posts, unvisited neighbors `580874`/`571346` made zero Original requests; the viewed `588549` made one and received HTTP 404. Its decoded High sample stayed visible.
- On the final APK, actual Maestro Retry on `588549` advanced generation 2 to 3, added exactly one Original request (another 404), made no sample request and retained decoded sample pixels/geometry. `/tmp/boorusama-57-live-retry-{before,after}-{counts,render}.jsonl`; screenshot `/tmp/boorusama-acceptance-evidence/57-retry-above-footer.jpg`. Successful retry decode is controlled-test evidence, not a live-host success claim.
- Rapid forward/reverse, Back/reopen and global loading disabled/re-enabled were exercised on the canonicalization build: seven unique details stayed bounded; successful cache keys were reused, failed Originals were retryable, disabled loading issued no media/detail requests and resumed loading restored media. Route/profile cancellation and credential isolation have controlled automated coverage; exhaustive device profile combinations remain unperformed.

The source still advertises distinct Original endpoints that return 404 (nine older safe posts checked); no full Original body was fetched merely to discover size. This prevents claiming a successful live distinct-Original upgrade on those posts. Do not replace missing source facts or successful live acceptance with guesses.

Cleanup: global Post quality restored to High, automatic loading enabled as initially, temporary anonymous `Issue57-Realbooru-QA` profile removed, Browse restored to Default profile, HTTP profiling disabled, forward 8189 removed and exact emulator lease released. Existing user profiles/data and backups were preserved.

Remaining gates: resolve the live-host limits and outstanding #53/#76 acceptance before publishing the dependent combination. #57/#53/#76 remain open and local. Any changed runtime/dependency integration candidate needs complete re-verification; documentation-only updates reuse the exact pass above.

## User acceptance follow-up: Original controls

The user confirmed Danbooru behavior and requested hiding Load original when
Original is selected, and making Load original on zoom inert in that case.
Runtime correction `715f72ede` uses the effective page/profile viewer settings
for both gates. Two failures were reproduced before repair. No preference is
cleared; selecting a lower quality restores the existing manual/zoom behavior.

Actual Realbooru post 1011263, identified from the user's exact image hash,
advertises the identical URL for the displayed image and Original. Its public
HEAD response was 200, image/jpeg, 6,389,881 bytes. No media body was downloaded
for this check. There is no separate higher rendition for that particular post.
This does not imply all Realbooru posts lack distinct renditions.

Actual production viewer-menu tests at width 320 and 2x text prove that a distinct
resolved sample upgrades to the decoded Original, while an identical URL reuses
one download. A real pinch with Original already selected leaves the manual
Original override empty and adds no Original request. The focused 8-test command
and broader 257-test viewer/Realbooru/preload/retry command passed. Analysis of
all five changed Dart files reported no issues. The requested independent
GPT-6.1 Sol XHigh reviewer found no confirmed defect in this correction.

The branch now includes published develop `88536ed64` (#84), and the preceding
#81/#62 follow-up repairs. Combined runtime/test candidate:
`1b20a8547319d807e1fc09bf3d443844f3d400c0`. The reviewed correction files are
identical across that reconciliation.

`./scripts/run_regression_tests.sh` passed on that exact candidate: 5,020
application tests, all 1,566 package/CLI tests, both shell suites and 72 Python
tests. Two existing go_router skips remain. Log:
`/tmp/boorusama-57-controls-current-develop-full.log`.

The ARM64 Dev APK built and built unchanged again successfully:
`build/qa/issue57-original-controls-arm64-debug.apk`.
SHA-256: `9d34cad701247dcd41733cfc149e5d022ed4b678ea39362f684428eb0ab0a282`.
The native-hook dependency-directory warning is the documented toolchain
classification issue; it did not change tracked runtime/generated inputs.
This is a phone retest artifact, not a new device acceptance claim. This branch
remains local and open; no #57/#53/#76 publication or issue closure occurred.
