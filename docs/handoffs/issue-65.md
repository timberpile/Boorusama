# Issue #65 — Local acceptance handoff

Branch: `feature/65-untracked-topic-previews`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/65

## Implementation

The shared Topic card now has a separate preview presentation component. If the source/query adapter cannot track new posts, or a previous tracking attempt determined timestamps are unsupported, it requests one current search page through the owning profile's origin-aware post repository. The existing query composer/authentication is retained; typed query structure is forwarded when available. `PostFetchOptions.raw` suppresses cascading requests. There is no history scan, detail hydration, sort substitution, or fabricated timestamp.

At most four unique valid HTTP(S) thumbnail URLs are displayed. A shared existing `SearchRefreshRequestGate` limits preview fetches to two concurrently. The API request context marks them as low-priority preload safe reads, honors cancellation and quota admission, and forbids cooldown retry. Queued work rechecks ownership/disposal before starting and after completing. Automatic-media-loading restrictions are observed.

The provider retains successful results in memory for five minutes and failures for 30 seconds from completion. A still-observed card remains stable after that retention expires; manual Refresh changes its key. The cache is not persisted across process restarts. Keys include the complete originating profile, query/structure, runtime revision, and last tracking attempt; edits, credentials/content-policy changes, and manual Refresh therefore do not reuse the wrong result. The existing image cache remains responsible for media bytes.

Preview errors appear in the preview region with an image-error icon and localized failure text, independently of the existing unsupported-tracking notice. A locally followed unsupported query shows that notice even before its first tracking attempt, without duplicating an existing persisted notice. Preview requests do not disable Following or modify `lastSuccessfulCheckAt`, unread/NEW counts, checkpoints, recent identities, or repository data. Tracked Topics and existing feed-member cache previews keep their normal fallback behavior. The preview failure uses its own localized `following_topics.preview_error` text so it does not suggest that a tracking refresh failed.

## Tests and status

Added `topic_preview_loader_test.dart` for the four-item/unique/URL bound without any timestamp model, concurrency, stale/queued cancellation, and request-slot recovery after errors. Tests use Completers rather than sleeps.

**Formatting, analysis, Flutter/provider/device tests have not run.** This environment lacks FVM/Flutter and cannot clone GitHub. This branch is not accepted or integration-ready.

## Required local acceptance

1. Fetch into an isolated worktree; follow `AGENTS.md` and bootstrap normally. Format changed files, analyze the affected scope, and run `test/core/search/following_topics` plus relevant post-repository/provider tests with physical-core concurrency.
2. Add provider/widget coverage using existing profile fixtures for success and negative cache retention, no repeated fetch on rebuild, profile/query changes, manual Refresh, media-loading disabled, disposal while queued/in flight, rate-limit admission, and failures. Override network transport; assert tracking repository methods are not called and persisted Topic state is unchanged.
3. Exercise a live manually followed Realbooru query with missing post timestamps. Confirm up to four current thumbnails, the unsupported-tracking status remaining visible, no NEW/checkpoint fabrication, working Open/Edit/Remove, and thumbnail failures isolated from Following. Repeat for a supported tracked source and a Feed member to ensure their cached preview behavior is retained.
4. Verify owning-profile authentication/content rules, including mixed-profile overviews, and confirm only one page is requested. Inspect the existing client handling of `PostFetchOptions.raw` for the tested engines; no hidden pagination/detail fetch should be added for a preview. Check narrow width and enlarged text; acquire the exclusive emulator lease before device use.
5. Review the complete diff and fix small defects on this branch. Record checked commit and actual commands/results/skips. The complete local suite must pass on the eventual combined develop integration candidate.

## Coordination

Independent branch. #51 edits the same card's title region: preserve both changes on later integration. No merge, PR, issue closure, or branch deletion is authorized. Include `#65` in a later approved final integration commit subject; retain `Refs #65` while acceptance is outstanding.

## Local acceptance evidence (2026-10-22)

This section supersedes the earlier unrun-verification status. Runtime/provider/widget checks cover `22bd65914c2738cc82b7d097b300b9fa48b60144`; the additional transport regression commit is `3396e0b9c43019407102fea8499186c97170b0ea` (same application runtime).

- Initialized fresh-worktree FVM dependencies and missing generated output via `./gen.sh`. Ran `./gen.sh i18n` after adding a preview-specific error string. Generated files remain ignored. Formatted changed Dart files and passed `git diff --check`.
- The first broader run exposed a confirmed regression: feed-member snapshot previews were replaced by the independent preview path, triggering media loads. Fixed it by preserving the supplied feed preview before any new provider access. Added an explicit no-fetch regression. The widget now also reuses the existing origin-specific repository/capability providers. Cached supported-query fixtures use genuinely supported queries rather than `order:score`.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/search/following_topics`: **623 passed** after fixes, including all feed-preview regressions.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/posts/post test/boorus/gelbooru_v2`: **83 passed**.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/search/following_topics/untracked_topic_preview_transport_test.dart`: **3 passed** on the added transport-only commit. Mocked Dio transport with the real quota coordinator verifies one-page bounds, occupied-slot rejection without queueing, and HTTP 429 without replay.
- `fvm dart analyze lib/core/search/following_topics test/core/search/following_topics/untracked_topic_preview_provider_test.dart test/core/search/following_topics/untracked_topic_preview_widget_test.dart`: passed with informational lints, no errors or warnings.
- Controlled fake clocks/completion signals cover positive/negative cache retention, observed-card stability, query/profile/credential/structured-query/manual-refresh identity, media-loading disabled, in-flight/queued cancellation, and request-slot recovery. Widget fixtures verify separate preview/tracking failure messages and unchanged persisted Topic state.
- Source review of the Gelbooru V2 repository/client path confirms a single listing page with no detail-hydration loop; existing origin-aware repository tests verify raw-option/query forwarding. These are mocked/source checks, not live credential or server acceptance.

Flutter 3.47.2 / Dart 3.13.2 and six detected physical-core workers were used with an isolated copy of the pinned SDK to avoid an unrelated startup lock.

**Acceptance remains pending live Realbooru/mixed-profile UI checks**, including real authentication/content-policy behavior, Open/Edit/Remove, and supported-source/feed comparison. The leased emulator did not answer its health check and was released; later it was leased to another task. No live thumbnail/playback, phone operation, APK install, merge, push, PR, closure, deletion, or combined-develop qualification is claimed.

### Android follow-up (2026-10-23)

Initialized native plugin metadata with `fvm flutter pub get --offline`; `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Installed on exclusively leased `emulator-5554` with `adb install -r`, preserving data. APK SHA-256: `a73d298ac6fe1f00e1e59471eae849ee78bb2c3b985541fe02a756a1c6b66ee1`.

Maestro created a temporary manually followed `rating:safe` Topic belonging to the temporary Realbooru profile. The card retained its unsupported-tracking notice, `Last post: Not checked`, and no NEW badge while the empty preview completed. At 360 dp width and 2x system text, checked Open and return, Edit with the keyboard open, cancel without changing the query, and Unfollow; verified the empty Topic overview afterward. Removed the temporary Realbooru profile afterward as well. Screenshots: `/tmp/boorusama-acceptance/65-{realbooru-topic,unsupported-topic-2x,open-search-2x,edit-keyboard-2x}.png`.

The earlier XML API probe (`/tmp/boorusama-acceptance/realbooru-api-check.json`) did not exercise the configured HTML listing transport and did not establish an external preview blocker. The V1 follow-up below supersedes that explanation with production-path and live-device evidence. It does not establish authenticated/content-policy behavior or a populated mixed-profile/feed comparison. No merge, push, closure, branch deletion, or combined-develop qualification occurred.

## Eight-branch review: V1 remediation (2026-10-23)

Starting/runtime commit: `5ed61aa6588de88c7e42fed2e0abb930f48dc71b`, identical to the review's pinned head. Final candidate is the test/handoff-only commit containing this section; application and client runtime files are unchanged.

Added `realbooru_preview_production_path_test.dart`. Its generated-registry assertion compares the Realbooru override directly with tracked `packages/booru_clients/boorus.yaml`, including the HTML parser, endpoint, thumbnail-only capability, offset pagination and fixed page size 42. The registry is current; no regeneration or registry repair was necessary.

The regression uses the real Gelbooru V2 engine repository, origin-aware wrapper, configured client, `parseRbPostsHtml`, DTO/post mapping and quota-coordinated Dio adapter. Only the HTTP response is controlled. Six valid HTML posts have no upload timestamps; normal search parses all six and the preview selects four identical origin-resolved thumbnail URLs. Raw and typed query variants each issue one listing request for normal search and one for preview, on `/index.php?page=post&s=list&tags=cat+rating%3Asafe&pid=0`; no detail hydration, later page, or XML request occurs. The server fixture may return more than four records, matching the fixed-size listing contract. The rendered card contains four image widgets and retains the unsupported notice. Persisted Topic objects and mutation counts remain unchanged, and the tracking refresh harness receives no requests. Existing preview-error and supplied-feed-fallback regressions remain in the affected suite.

Initial new-fixture attempts stalled because a serialized fake-clock store was awaited from the real async transport zone. Kept all UI and persistence assertions, limiting `tester.runAsync` to transport work and reading the serialized store in its originating zone. The corrected production-path file passes **3 tests**. The mocked image-byte adapter reports empty-response placeholders; that is separate from the verified listing parser/URL mapping and from the successfully loaded live images below.

Executed verification:

- `fvm flutter pub get --offline`; formatted the new Dart file; `git diff --check` passed. No tracked dependency/generated changes.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/search/following_topics test/boorus/gelbooru_v2`: **682 passed**, including the new production-path cases (`/tmp/boorusama-review-65-focused.log`). Direct final fixture log: `/tmp/boorusama-review-65-production-zone.log`.
- From `packages/booru_clients`, `fvm flutter test --no-pub --reporter=expanded --concurrency=6`: **104 passed**, the complete client/parser suite (`/tmp/boorusama-review-65-clients.log`).
- `fvm dart analyze test/core/search/following_topics/realbooru_preview_production_path_test.dart`: no errors/warnings; one informational adjacent-HTML-string lint (`/tmp/boorusama-review-65-final-analysis.log`).
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed, exit 0** (`/tmp/boorusama-review-65-build.log`). Installed preserving data with `adb -s emulator-5554 install -r` under the exact exclusive lease. APK SHA-256: `1d8d9ad20cdf014da407308020ece1cf0c2d5132292f922f29f71d30ff4dc511`.

Live Maestro comparison used a newly created, credential-free **Review Realbooru** profile and the same `rating:safe` query. Normal search displayed **42 posts**. Following the query produced **four actually loaded previews**, with `New-post tracking is unsupported for this search.`, `Last post: Not checked`, and no NEW badge. No post was opened, so no live detail hydration was needed. App Debug logs (Network filter) recorded the actual URL and HTTP status, rather than inferring them from a different transport:

| Scenario | Local time (Europe/Vienna) | Listing URL | Result |
| --- | --- | --- | --- |
| Ordinary search | 2026-10-23 16:15:23 | `https://realbooru.com/index.php?page=post&s=list&tags=rating:safe&pid=0` | HTTP 200; 42 parsed posts; 388 ms request |
| Independent Topic preview | 2026-10-23 16:17:16–18 | Same URL | HTTP 200; four loaded previews; 1.684 s request |

Credential-redacted evidence: `/tmp/boorusama-review-65-live-trace.json`; screenshot: `/tmp/boorusama-review-65-topic.png`. The trace contains only this temporary credential-free site's matching requests. **The configured path is working in this check; there is no established Realbooru external blocker.** This is not a claim about the deprecated XML API or every future live response.

Cleanup: unfollowed the temporary Topic and verified `No topics yet`; restored the original **Default profile**. No original profile/history entry was deleted, no app data was reset and no system font/viewport settings were changed. An existing `rating:safe` history entry was reused by the live search. Automatic approval review initially rejected removal of the session-created **Review Realbooru** profile pending explicit permission. After the user's explicit authorization, Maestro verified the confirmation named only `Review Realbooru`, deleted that profile, and asserted its absence plus the continued presence of **Gelbooru**, **Safebooru**, and **Default profile**. Returned to Browse and released the exact emulator lease. Cleanup is complete. This documentation-only follow-up does not change the checked runtime/test candidate or require another application test run.

Preservation audit: current develop is `afc04f4933aa0e442b9f80b2662f0fc5ad277379`, including newer feed-preview activity/cache work. No runtime file was replaced, so those changes and #42's covered-route/selection changes remain untouched on develop. The #51 title renderer and #65 supplied-feed-preview short circuit must both survive future integration; no combined #51/#65 tree was assembled or claimed tested here. A parsed English-resource comparison against `565a504c...` found exactly this branch's `following_topics.preview_error` addition and #59's two `pixiv.experimental` additions; both branches/resources remain unchanged. Likewise #48's `autocompleteCategories` and #59's `additionalBoorus` backend additions remain on their respective branches. No historical cleanup script was rerun.

V1's transport, registry, production parser and live comparison findings are resolved. A full regression on this test-only #65 candidate was not rerun; combined-develop qualification remains separate. Authenticated/content-policy behavior, the populated mixed-profile/supported-feed live comparison and the broader text/theme device matrix remain open. No merge, push, PR, issue closure, branch deletion or worktree deletion occurred.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `4d2a77a66a7de23273894ff062f4d98a0b63e20d`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

V1's production-path regressions and recorded live Realbooru HTML evidence remain valid: the configured client uses the HTML listing, not the deprecated XML API. The real registry/client/repository/parser fixtures pass in the combined suite and enforce one page, four previews and unchanged unsupported tracking/persistence. No new Realbooru runtime change was necessary.

Preserved current develop's feed-preview activity/cache work and the supplied-feed-preview short circuit. Added combined #51/#65 named/unnamed success/failure card cases that assert no tracking requests or persistence mutations. The combined Android run showed four actually loaded supported-source previews, compact title/query formatting, edit/name/open/unfollow and cleanup at 2x text. This run does not repeat the earlier credential-free live Realbooru trace or claim live authenticated mixed-profile/feed coverage; origin/auth/query/policy identity, independent errors and no-fetch supplied-feed behavior have controlled production/provider/widget coverage.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
