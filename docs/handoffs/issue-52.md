# Issue #52 — Local acceptance handoff

Branch: `bug/52-realbooru-video-badges`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/52

## Implementation

Realbooru listing titles now recognize the exact `video` token in whitespace-separated as well as comma-separated titles. Comma-separated display phrases remain intact: `video_game` and `video with sound` alone are not treated as the exact marker. Existing poster/thumbnail URL selection is unchanged.

The existing persisted `GelbooruV2PostData.isVideoPreview` opts into a small display-only `VideoPreviewPostData` contract. `PostPreviewBadgeX.showsAnimatedBadge` feeds the shared grid's existing Play/duration overlay, without changing `Post.isVideo`, media selection, playback, codecs, or snapshot versions. `ImageGridItem` already supports Play with unknown duration; no duplicate badge widget was introduced.

The Gelbooru V2 converter now extracts a lowercase extension from the URI path, excluding query/fragment data and safely handling extensionless URLs. This keeps resolved MP4/WebM posts recognizable too.

Extended `test/boorus/gelbooru_v2/realbooru_video_thumbnail_test.dart` covers both title formats, casing/whitespace, false positives, badge metadata, static-poster preservation, resolved video URL queries, and extensionless media.

## Verification status and local work

Source and the parser-to-grid path were reviewed. **No FVM/Dart/Flutter formatting, analysis, tests, or live/device checks ran** in the remote environment. Required technical acceptance is outstanding.

1. Fetch this branch into its own worktree. Follow `AGENTS.md`, initialize dependencies and missing generated output as needed.
2. Format changed Dart files, run `fvm flutter test` on `test/boorus/gelbooru_v2` and `test/core/posts`, and run the complete `packages/booru_clients` suite from that package directory. Use the repository's detected physical-core concurrency. Analyze affected code and fix issues on this branch.
3. Because the shared grid consumes a new opt-in display contract, run `./scripts/run_regression_tests.sh` before declaring integration readiness. Re-run on the eventual combined develop candidate if it changes.
4. Exercise a live Realbooru listing with confirmed videos and ordinary images, in Low and Automatic thumbnail quality. Confirm a single shared Play badge before resolution and after opening/returning, with no duration required. Confirm the thumbnail remains a static image and actual playback still resolves the real media. Check bookmarks/mixed-profile grids, GIF badges, and another Gelbooru V2 site for regressions.
5. Add/extend a rendered grid badge regression if existing widget fixtures make that practical. Check narrow tiles and enlarged text. Follow the emulator lease procedure before device use.
6. Review the whole diff, fix small defects, and record the checked commit, executed commands, results, skips, and remaining limitations.

Independent of the other quick-win branches. No merge, PR, issue closure, or deletion is authorized here. A later approved integration commit must include `#52`; retain `Refs #52` until acceptance passes.

## Local acceptance evidence (2026-10-23)

Checked runtime/test commit: `d5f87aa922efbcc55630106c83a0848a1e783c9d`. Bootstrapped fresh FVM dependencies and missing generated output with `./gen.sh`, formatted changed Dart files, and passed `git diff --check`.

- Added a rendered converter-to-shared-grid regression for the actual Realbooru DTO path at an 80×120 tile size and 2x text. It asserts one shared Play icon without duration and preserves static-poster `Post.isVideo == false` behavior. An initial fixture expectation used the wrong badge class and was corrected to the actual shared Play icon.
- Affected Gelbooru V2/post suites and the complete `packages/booru_clients` suite were exercised. Client suite: **104 passed**.
- Affected Flutter analysis passed with **3 informational lints**, no errors or warnings.
- The first complete runner failed on an unchanged bookmark-service test's 30-second timeout. That test file and service match the branch base; an isolated entire-file repeat passed **33 tests**. No timeout or production bookmark code was changed.
- Repeated `./scripts/run_regression_tests.sh` on the unchanged runtime/test candidate: **passed, exit 0**. Application **4469 passed**, all **13 package/CLI suites passed**, both shell tooling suites passed, and Python tooling **72 passed**. Existing go_router skips: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. Logs: `/tmp/boorusama-acceptance/52-realbooru-video-badges-full-regression-rerun.log` and `52-bookmark-timeout-rerun.log`.

Flutter 3.47.2 / Dart 3.13.2 and six physical-core workers were used with an isolated pinned SDK copy. Native plugin metadata was initialized with `fvm flutter pub get --offline`. `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Installed that dev APK on exclusively leased `emulator-5554` using `adb install -r`, preserving existing data. SHA-256: `29cc94449867b5dc738a31ab0506053c655ff970507255c8047f6e231ba3f99c`.

Created a temporary Realbooru profile and exercised the live search UI with separate `rating:safe` and `video` tokens. No confirmed live video was returned. Public API diagnostics for that query, safe-only and unfiltered requests all returned HTTP 200 XML `response success=false` announcing that the API is disabled indefinitely. Evidence: `/tmp/boorusama-acceptance/realbooru-api-check.json`; UI screenshots: `52-realbooru-structured-query.png` and `52-realbooru-safe-listing.png` in the same directory.

**Live badge acceptance was not completed in that run.** The API-only diagnostics were incorrectly treated as blocking the app's HTML-backed listing path. The follow-up below supersedes that conclusion. Automated converter/rendering coverage is not a substitute for device checks of playback, open/return, mixed bookmarks, GIFs and another Gelbooru V2 site. No merge, push, PR, closure, deletion, or combined-develop qualification occurred.

## User follow-up: missing badges and Medium quality (2026-10-23)

The user supplied post **1013688** (badge present) and **1013686** (badge missing), then requested larger images for ordinary posts at Medium quality as well. Both detail pages contain MP4/WebM video sources. Both listing thumbnails have `style="border: 3px solid #0000ff;"`, but only 1013688 has the exact `video` title tag. A live listing snapshot contained 38 rows and 30 blue-bordered videos, including 21 without that exact title tag.

The listing parser now recognizes the blue solid border, retaining the exact title marker as a fallback. It does not turn a JPEG poster into playable video media. The rendered regression now starts with listing HTML containing a blue border and no video title tag, then passes through the real converter into the shared Play overlay at 80×120 and 2x text.

The quality discrepancy came from URL selection: recognized video rows used the larger JPEG poster, while ordinary rows and missed videos used the small thumbnail. Bounded live image-header requests, with Realbooru's Referer header, confirmed:

| Post | Small thumbnail | Larger image |
| --- | --- | --- |
| 1013688, video | 150×84 | 1280×720 JPEG poster |
| 1013686, previously missed video | 150×84 | 854×480 JPEG poster |
| 1013689, ordinary image | 150×85 | 557×314 `.jpeg` image; guessed `.jpg` returns 404 |

The user explicitly ruled out fetching each post's HTML page just for grid thumbnails and suggested trying other image extensions. Medium now tries `.jpg`, `.jpeg`, `.png`, `.webp`, and `.avif` image URLs in order for ordinary Realbooru listing rows. Each candidate is an actual image request, made only when the preceding candidate fails; there are no HEAD probes, per-post HTML requests, or MP4/WebM downloads for grid quality. A known resolved static-image URL is used directly. Videos retain their JPEG poster path. The small thumbnail stays the loading placeholder and final fallback. Low, and Automatic at tiny/micro sizes, use the small thumbnail; higher resolved qualities use the larger candidates. Unknown formats or unavailable larger files can still fall back to the small image; this does not manufacture a resized Medium derivative on a site without one.

Ordered fallbacks use the existing image/network/cache path, including profile headers and media-host overrides. The fallback list is also preserved by the grid, explore cards, and viewer's initial lower representation. No persisted post schema or migration changed.

Follow-up evidence is under `/tmp/boorusama-52-followup/` (local artifacts, not repository fixtures). `live-parser-evidence.json` records production parsing/conversion/quality selection for the live listing snapshot: 30 video previews, both supplied posts showing badge metadata and larger posters, and ordinary post 1013689 selecting the extension chain. `quality-metadata-with-referer.json` and `still-image-metadata.json` record the image-header measurements. Initial requests without Referer returned HTML rather than images and were not used for these measurements.

Device acceptance remains outstanding for this follow-up: `emulator-5554` was already exclusively leased by the separate scalability review task. No device operation, installation, or setting change was performed, and no lease belonging to that task was changed. Live HTML and image headers work; the disabled public API does not block this HTML-backed path.

Checked follow-up runtime/test commit: `bc40ce4d4`. Flutter 3.47.2 / Dart 3.13.2, six physical-core workers. Verification:

- `fvm dart format` on changed Dart files and `git diff --check`: passed.
- The new blue-border regression failed before the fix (seven positive cases); the complete `packages/booru_clients` Dart test suite passed afterward: **121 tests**.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/boorus/gelbooru_v2 test/core/posts`: **800 passed** after the marker fix, before the subsequent Medium-quality changes.
- Final focused quality/image suite: **24 passed**; viewer suite: **23 passed**. These include actual HTTP 404 responses advancing from `.jpg` to `.jpeg` to decoded PNG, stopping on success, lazy request order, Referer preservation, final small-thumbnail fallback, and viewer lower-image retention. Logs: `quality-tests.log` and `viewer-tests.log` in the follow-up artifact directory.
- Production parser/converter/quality selection against the saved live HTML: **passed**, `live-html-test.log`. This is live-service snapshot evidence, not a device rendering/playback pass.
- `fvm flutter analyze --no-pub` over all 13 changed Dart files: **no issues found**. Log: `analyze-final.log`.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`, SHA-256 `74527feed724507acdec91d38d827cc1c4a7e842b095460f9eb58bfc0cd4a1bf`. Existing Kotlin-version and Android SDK XML-version warnings remain. The APK was not installed during this follow-up.
- Final `./scripts/run_regression_tests.sh` on the unchanged runtime/test candidate `bc40ce4d4`: **passed, exit 0**. Application: **4478 passed**. All **13 package/CLI suites passed**, including the complete client suite (**121 passed**). Router suite: **436 passed, 2 existing skips**. Pull-request policy and Android release shell suites passed; Python tooling: **72 passed**. Log: `/tmp/boorusama-52-followup/full-regression.log`.

The complete local suite qualifies this branch's automated candidate only. Device gates above and verification of any future combined develop candidate remain separate. No merge, push, PR, issue closure, branch deletion, or worktree cleanup was performed.

## GIF badges and retaining the timeline preview (2026-10-23)

Checked runtime/test commit: `baaefb585`.

- Realbooru's live `gif` listing returned 41 rows with an exact `gif` title tag and no special thumbnail border. Post [1013633](https://realbooru.com/index.php?page=post&s=view&id=1013633) resolves to the corresponding `.gif` original. The listing parser now retains that original GIF URL while leaving the JPEG sample/thumbnail static. Existing format detection, shared GIF badge and snapshot storage handle the result without a new persisted flag or schema change. Blue-border or exact video markers take priority over a GIF tag. Similar words and display phrases are not GIF markers. Grid rendering uses the existing GIF loading policy; zero/unknown file size does not cause a full GIF download just for its badge.
- The opening regression was a quality-ordering error: unresolved listing data still identified its small thumbnail as the viewer target. That cached target could overwrite the larger grid preview. When the target is explicitly the grid representation's final fallback/placeholder, the viewer now tries the larger grid representation first and leaves the small image as a fallback. Resolution to the real original still upgrades the displayed image. Missing previews, empty primary URLs, final fallback failure and explicit retry retain working behavior.

Verification used Flutter 3.47.2 / Dart 3.13.2 and six physical-core workers:

- The GIF parser regression failed before the fix (three positive cases). The cached-pixel viewer regression also failed before the fix because the smaller image replaced the larger image.
- Focused Realbooru, viewer, grid, image and codec consumers: **278 passed**. Complete `packages/booru_clients` suite: **131 passed**. Tests cover exact GIF tags and false positives, video precedence, one matching badge at 80×120 and 2x text, snapshot round-trip, cached larger pixels with no thumbnail request, fallback, resolution upgrade and retry.
- `fvm dart format` on changed files; affected Flutter analysis: **no issues found**; `git diff --check`: passed. No generation inputs changed and `./gen.sh` was not needed.
- Final `./scripts/run_regression_tests.sh` on the unchanged runtime/test candidate: **passed, exit 0**. Application **4482 passed**; all **13 package/CLI suites passed** (client **131**, router **436 with 2 existing skips**); both shell tooling suites and Python tooling **72 passed**. The runner emitted Flutter VM finalizer diagnostics during some host tests but reported no test failure. Log: `/tmp/boorusama-52-gif/full-regression.log`.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Existing Kotlin-version warnings remain. Installed with `adb install -r` on exclusively leased `emulator-5554`, preserving data. Installed and local APK SHA-256 both equal `91b61a815b92f90bc0aeb9e241e4855f6a6c5ed73743ef59ee8456af86d0352d`.
- Maestro exercised a temporary Realbooru profile, committed the exact `gif` search token, and loaded the live **41-post** listing. A screenshot and an isolated overlay crop confirmed the existing GIF badge; opening the first GIF and returning to the listing passed. Evidence: `/tmp/boorusama-52-gif/gif-listing.png` and `gif-badge-only.png`. Screenshots were not committed. A subsequent exact-ID image-query attempt was not completed and supplies no device quality evidence. Two navigation flows needed correction (Android Back left the app while dismissing a popup; a later open keyboard hid Menu).
- Deleted only the newly created Realbooru profile, verified its absence, restored the original Default profile, and released the emulator lease. No global display/quality settings, existing profiles, bookmarks or topics were changed. Cleanup evidence: `/tmp/boorusama-52-gif/profiles-cleanup.png`.

The larger-preview retention is proven by controlled pixel tests, not by a frame-level device measurement. The live GIF badge/open-return check does not close the broader video/playback/mixed-grid acceptance gates listed earlier. All changes remain local to this branch; no merge, push, PR, closure or branch/worktree deletion occurred.


## Approved integration and user device acceptance (2026-10-23)

The user reported that the change looks good on their live device and explicitly authorized merging #52. This supersedes the earlier pending manual-acceptance/local-only status for this integration. It is user-provided acceptance; no new agent device run or scenario-by-scenario device report is claimed.

Reviewed issue branch: `443be67fb5a8166ce007b2b42636d942bfda0547`. Current develop base: `68e433613618b32d29b375d937454b4383f67457`. Combined runtime/test candidate: `9e9b8543779443493fa24d14efb962e865beba7e`. Develop was merged into the existing task worktree without conflicts. The 20 issue-scoped paths are identical to their accepted branch versions; all other current-develop work is preserved. Final publication will use one squash commit for #52, retaining the already-separated commits for the other issues.

Refreshed dependencies with `fvm flutter pub get --offline` and ran `./gen.sh` because the newly combined develop includes registry/localization inputs absent from the old branch. Generated outputs remain ignored and no tracked dependency file changed. The physical-core detector reports six workers. Reviewed the complete issue diff, including parser/format handling, lazy image-extension fallbacks, display-only badge contract, shared-grid consumers, progressive viewer retention and controlled regression fixtures.

`fvm flutter analyze --no-pub --no-fatal-infos` on all 19 changed Dart paths: **exit 0, no issues found** (`/tmp/issue52-integration-analysis.log`). Non-Markdown diff whitespace check passed; existing Markdown hard line breaks are retained. Full integration regression and Android build results are recorded below after completion.

- `./scripts/run_regression_tests.sh` on the combined candidate: **passed, exit 0** with six workers. Application **4,769 passed**; all **13 package/CLI suites passed** (including clients **131**, Kurumi **161**, go_router **436 with 2 existing skips**); both shell tooling suites and Python tooling **72 passed**. No concurrency reduction, new skip, timeout increase or unrelated runtime change was used. Log: `/tmp/issue52-integration-full.log`.
- Existing go_router skips: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. Flutter VM finalizer diagnostics appeared during some passing host tests; no test failure was reported.
- Verified generated registry/localization runtime artifacts remained stable and the only subsequent tracked edit is this handoff. The complete pass is retained across this documentation-only update; the final squash must preserve the checked runtime/test tree.

- Final `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed, exit 0** after all tests finished (`/tmp/issue52-integration-build-final.log`). Earlier concurrent builds also exited 0 but printed a modified-build notice; the final unchanged build did not. Existing Kotlin-version warning remains. Accepted APK SHA-256: **7b9d00e4c7cdcd1509913f40bac7e579a7ba03f5010a6dc23dde01cbf4748c47**; preserved at `/tmp/boorusama-issue52-accepted.apk`. No new installation/device action was necessary after the user's live-device approval.

No application/runtime changes were needed during integration. The user's manual acceptance and the successful combined complete suite satisfy this authorized merge's gates; no additional agent-run device matrix or new live-service request trace is claimed. Publication, issue closure and cleanup follow only after verifying the final one-issue squash is on `origin/develop`. The primary checkout and #71 worktree are preserved.
