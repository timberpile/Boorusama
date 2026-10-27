# #54 — Find shared Pixiv artworks across profiles

Branch: `feature/54-pixiv-share-lookup`
Independent base: `2e5ca00d7bca6881cfddd19125c72d5f80d9593d`
Status: locally committed and verified, including authenticated official Pixiv
shares, original-file matching, Android task reuse, and the complete local suite.
The user authorized final Astra High review followed by develop integration,
publication and normal task cleanup. The review/grid continuation below is
current; earlier dated sections retain their historical verification limits.

## Thumbnail grids and final Astra High review — 2026-10-27

The user requested three-column thumbnail results for both Find Pixiv Artwork
and Find on Other Profiles before the authorized integration. Their shared
`CrossProfileResults` renderer now uses a fixed three-column, square-thumbnail
grid within each existing profile section. It reuses `BooruImage` with the target
profile's image configuration. Each thumbnail opens its exact target Post through
the existing scoped viewer. Post IDs remain accessible as semantic button labels
and tooltips. Profile grouping, status/count/provenance, pagination and request
orchestration are preserved; no second screen was introduced.

Grid implementation: `5b4a580e7bd731a444ec8dd9ebf9996641b82b57`.
Final tested candidate: `a7e8cb1bcc29bfed08225e7d5432cc77a3d218d2`, incorporating
`origin/develop` at `429d505c7d33d563ff9a57438623f3c1fee36ca3`. Develop's UI label
changes were retained, including Load More, and i18n output was regenerated.
The user's task-related `.gitignore` additions in `8cd4f26fc` are preserved during
integration so private `.test_profiles.base64` and `.test_profiles.bsexport`
exports remain ignored. These entries do not change the tested runtime.

The explicitly requested **Astra High** subagent reviewed the complete feature,
grid changes and develop reconciliation. **No confirmed defects or blocking
findings; review approved.** It checked native startup/task routing, original
hashing bounds and cancellation, credentials/profile isolation, source/exact
matching, pagination/deduplication, incomplete-coverage semantics, and grid
interaction/testing. The review itself was read-only; the parent performed the
following final-candidate checks.

- `./scripts/run_regression_tests.sh`: **passed**, exit 0. **5,333 application
  tests**; all 13 package/CLI suites passed (201, 254, 59, 191, 59, 47, 31, 45,
  65, 436 with two existing skips, 32, 167, 16). PR policy and Android-release
  script checks passed, plus **72 Python tests**. Physical-core concurrency 6.
- Focused grid/page/Pixiv/application-flow run: **21 passed** before develop
  reconciliation; final complete suite covers the reconciled version. Two new
  tests verify actual 3+1 cell positioning, square thumbnails, per-profile image
  configuration, exact fourth-post routing and Back for both entry modes at
  width 320 and 2x text scale. Existing assertions now scroll to offscreen
  sections and wait for layout before tapping. First exploratory test failures
  were corrected scroll/layout assumptions, not passing runs.
- Final scoped `fvm flutter analyze --no-pub` over lookup code/tests and changed
  Gelbooru parsers/consumer test: **no issues**. An initial unused test import was
  removed before restarting the full suite. The interrupted preliminary suite
  is not counted as a pass. Dart formatting and task-diff whitespace checks pass.
- Final x86_64 dev debug APK built successfully after an unchanged repeat.
  Changed runtime source files were found byte-for-byte in the kernel blob.
  Pulling the installed APK confirmed exact local-build SHA-256 correspondence:
  `0e6e571c631a27bacff9458690ac1e6619fd45459b0f6a4349f0f3de639fd0c4`.

Actual Android/Maestro checks on exclusively leased **emulator-5556**, using the
existing signed-in official Pixiv app and imported profiles:

- Official Pixiv share of `83452178` opened Find Pixiv Artwork. The Danbooru
  group displayed **eight matches in rows 3+3+2**; live hierarchy showed the three
  columns at x=56, 264 and 472, with square 192-pixel cells. Tapping the middle
  thumbnail **12457819** opened that exact post. View in Browser confirmed
  `danbooru.donmai.us/posts/12457819`; Back returned viewer → lookup → Browse.
- Official share of safe `150636168`, then opening Default-profile post
  `12457716` and selecting **Find on Other Profiles**, displayed the same grid
  layout with exact-file matches on Safebooru, Danbooru and Gelbooru. Tapping
  **7268205** opened its Safebooru viewer; View in Browser confirmed
  `safebooru.org/?page=post&s=view&id=7268205`. Back correctly traversed browser,
  target viewer, other-profile lookup, source viewer, shared-artwork lookup,
  and original Browse. Active browsing profile remained unchanged.
- Final screenshots: `/tmp/issue54-originals/grid-pixiv-eight-matches.png` and
  `grid-other-profiles.png`. Full runner log: `grid-final-complete.log`; analysis:
  `grid-final-analysis.log`; APK proof: `grid-final-apk-proof.txt`, in that same
  temporary directory. Evidence conclusions are recorded here for portability.
- Lease released; ordinary AVD left running with test logins/profiles retained.
  No website uploads, public posts, purchases, or credential exports occurred.

Review and final verification gates are satisfied for the authorized squash
integration. Handoff-only updates do not change the checked runtime/test state.
Historical limitations below remain historical unless explicitly superseded;
the earlier one-off original network failure is not claimed conclusively fixed.

## R-18 account-setting re-verification — 2026-10-27

The user confirmed that R-18 was disabled on the test account and enabled it.
This supersedes the earlier restricted-artwork verification limit below. **R-18
artworks are supported** when Pixiv returns their originals and the source
profile's local filters allow them; there is no blanket R-18 exclusion.

Read-only probes of the same exported Pixiv credential established the change:
OAuth user `x_restrict` changed from **0 to 1**; artwork `141607376` changed from
`visible=false` with the `s.pximg.net` R-18 placeholder to **`visible=true` with a
real `i.pximg.net` original**. Local rating filter was **none** throughout. Requests
without a `filter` parameter (the production detail request), with `for_ios`, and
with `for_android` agreed before and after. Thus the discrepancy was the account
setting, not a platform-filter parameter. Probes kept tokens in memory and did
not save credentials or alter account settings.

Reclaimed emulator-5556 and used Maestro with the unchanged final runtime APK
from `c5e86823a`. The official Pixiv app's Share action sent the user's exact
`ban装甲 | abmayo #pixiv https://www.pixiv.net/en/artworks/141607376` caption through
the Android chooser. Boorusama opened Find Pixiv Artwork and completed lookup
for Default, Safebooru, Danbooru, Rule34 and Gelbooru with **No visible matches**,
without access-restriction or incomplete-original warnings. The MD5 fallback
therefore completed; this artwork has no visible match in those tested profiles.
This is real-app Android evidence for the previously restricted artwork. The
Pixiv and Realbooru profiles remain unsupported lookup targets as before.

Back returned to Browse. The device lease was released and existing logins and
profiles retained. Evidence: `/tmp/issue54-originals/r18-account-enabled-lookup.png`.
No runtime/test changes were needed; the previous complete suite remains valid
for this same candidate. Only this English verification record changed, checked
with `git diff --check`. No upload, publication, integration or issue closure.

## Original downloads and duplicate Android tasks — 2026-10-27

Implementation and tested runtime commit:
`c5e86823aaa68cec591664e64bef15b235111a76` (`Refs #54`).
Continued the existing worktree from `c11e24fd7165366059baeca4f8da1731a285ca12`.
The startup-delivery queue, existing #49 results/viewer, profile isolation,
source methods, pagination and lookup concurrency remain intact.

### Confirmed causes and fixes

**Duplicate tasks:** MainActivity's `singleTop` did not override the document/task
flags added by Android's actual share chooser. The official Pixiv app constructs
an ordinary `ACTION_SEND`, `text/plain`, String `Intent.EXTRA_TEXT` containing the
caption and artwork URL. Its chooser delivery carried `0x0b080000`, including
`NEW_DOCUMENT` and `MULTIPLE_TASK`. A sender using the same chooser construction
created separate Boorusama tasks 35 and 37. Explicit-component adb SEND commands
used in earlier QA had missed this mechanism.

Text shares now enter a transient, exported `IncomingTextShareActivity` with no
UI and a separate affinity excluded from Recents. It clones the original Intent,
retains its extras, MIME type, ClipData and URI grants, removes task/document
flags and selector, and explicitly forwards to MainActivity with `NEW_TASK`,
`SINGLE_TOP` and `REORDER_TO_FRONT`. It then finishes. The existing `share_handler`
receiver and startup queue still handle initial and warm delivery. No second
lookup screen or Flutter sharing listener was added. MainActivity retains
`singleTop`: changing it to `singleTask` would conflict with
[RevenueCat's background purchase verification requirement](https://production-docs.revenuecat.com/docs/getting-started/installation/flutter).
Forwarding does not clear native activities above the Flutter host. Purchases
were not exercised.

**Healthy original download cancelled:** For safe artwork `150636168`,
authenticated metadata returned a real original, and the CDN returned HTTP 200
with Content-Length **15,296,742**. The previous 20-second total transfer timer
cancelled it after **20,010 ms**, with **7,863,958 bytes** received and data still
arriving. Host requests and the production hasher completed the same original;
this was not a missing login or incorrect URL/header. The per-file allowance is
now **60 seconds**, within the unchanged **90-second artwork budget**. All size,
page, queue, TLS, redirect, host-validation and cancellation limits remain.
A later Android cold-start trace completed all bytes in **35,972 ms**.

**Restricted artwork looked like a download failure:** With the user's imported,
working Pixiv profile, metadata for the supplied `141607376` returned
`visible=false`, `x_restrict=1` and the R-18 placeholder
`https://s.pximg.net/common/images/limit_r18_360.png`. The same authentication
successfully accessed safe artwork `150636168`. A valid login alone does not
make restricted originals available. The resolver now distinguishes server
visibility/mute restrictions and source-profile filtering through a typed access
decision and localized restriction message. It never downloads or hashes the
placeholder and does not claim a definitive no-match. No account restrictions
or server settings were changed. This proves the supplied test profile's server
response; it does not establish the settings of the user's phone profile.

### Automated verification

Final runtime, tests and generated i18n are those in `c5e86823a`. Temporary
credential-free timing instrumentation was removed, with the exact candidate
source restored before the final build. Commands ran in the isolated worktree
with pinned FVM Flutter 3.47.2 and physical-core concurrency **6**.

- `./scripts/run_regression_tests.sh`: **passed**, exit 0. Application **5,093**;
  all **13** package/CLI suites passed (145, 254, 59, 191, 59, 47, 31, 45, 65,
  436 with two existing skips, 32, 161, 16). PR policy and Android release-script
  checks passed; **72** Python tooling tests passed.
- `fvm flutter analyze --no-pub lib/core/posts/cross_profile_lookup test/cross_profile_lookup`:
  **passed**, no issues.
- `fvm dart format --output=none --set-exit-if-changed lib/core/posts/cross_profile_lookup test/cross_profile_lookup`:
  **passed**, 26 files unchanged; `git diff --check` passed.
- Focused provider, original-hasher and share-UI files: **39 passed**. Regression
  tests first demonstrated the wrong restricted classification and cancellation
  of a progressing stream beyond 20 seconds. Controlled clocks exercise progress
  and the retained transfer bound. Provider tests cover server restrictions,
  muted artwork, source-profile filtering and pending blacklist lifetime. The
  restriction widget is checked at width 320 with 2x text scaling.
- Earlier affected lookup, application-flow and sharing run: **465 passed**;
  superseded by the final complete pass above.
- Native `PendingSharedTextIntentsTest`: **3 passed**, no skips/failures, after
  forced `:app:testDevDebugUnitTest --tests com.timberpile.boorusama.PendingSharedTextIntentsTest --rerun`.
- Final APK instrumentation `SharedTextTaskReuseTest`: **2 passed** in 11.592 s.
  Three document/multiple-task shares reuse the same background Activity object
  and task; payload/grants are preserved without mutating the sender Intent.
  Initial ActivityScenario helper failures were test-harness failures, not passes;
  the final tests use lifecycle completion signals and platform launches.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`:
  passed; repeated unchanged after Flutter requested a rebuild. The final repeat
  had no modified-during-build notice. Existing toolchain/deprecation warnings
  remain. Changed runtime Dart sources were found byte-for-byte in the APK's
  kernel blob, and temporary diagnostic markers were absent.

Final local/installed APK SHA-256 (pulled installed APK compared with build):
`2daf1aab7f79c2b9d8ecef99ac14b574e3fe7bf43e02015be8c32be99ec9d3da`.

### Actual Android verification and remaining limits

Used leased **emulator-5556**, ordinary Phone2 AVD, with renewal before every
operation and Maestro MCP for UI control. The main checkout's ignored
`.test_profiles.bsexport` was imported through the UI using Copy: six authenticated
test profiles were added while retaining the original Default profile. The
original export was preserved. The official **Pixiv 6.201.0** app was also signed
in using the authorized test credentials. Direct Android input was used only to
finish login, as explicitly authorized after Maestro's U+0000 login-form failure.
Credentials and tokens are absent from committed evidence and fixtures.

- Official Pixiv Share for `150636168` delivered the caption plus localized URL
  through the Android chooser and opened the existing lookup screen. Verified
  both stopped/cold and background/warm starts, plus repeated real shares.
- Final APK: safe artwork found Danbooru source post **12457716** and Safebooru.org
  **7268205**, explicitly labelled **Exact File Match**. Original MD5:
  `1fc648abbd44939bbba165ba625d17ab`. This exercises the authenticated original
  download and exact-file target lookup end to end on Android.
- Opened the Safebooru result in the existing viewer. View in browser opened
  `safebooru.org/?page=post&s=view&id=7268205`. Back returned browser → viewer →
  lookup → Browse. The original browsing profile was retained.
- Repeated real shares reused task **59** before a deliberate force-stop and
  task **66** after a cold start, with one MainActivity per task inspection.
  A same-artwork foreground equivalent Intent on the final APK also opened no
  extra route: one Back returned to Browse. Foreground delivery used an equivalent
  Intent because opening Pixiv's own Share necessarily backgrounds Boorusama.
- The user's exact `141607376` caption was tested through an equivalent Intent
  on the final APK: lookup opened, showed the explicit restriction message, and
  Back worked. Official Pixiv showed Open settings and offered no artwork Share
  for this restricted item under the QA account, so its real-app share remains
  unverified. No Pixiv restriction settings were changed.
- One intermediate cold run opened the lookup and source results but showed
  incomplete original coverage. Its precise exception was not retained; browse
  image requests also logged empty network responses during that run. Subsequent
  timing-instrumented and final-APK cold runs completed the original and match.
  This intermittent failure is recorded, not counted as a successful download or
  claimed conclusively diagnosed. Network errors and transfers exceeding the
  retained bounds can still produce incomplete coverage.
- Existing plain-URL Danbooru sharing displayed its local confirmation on the
  final APK. **Cancel** was pressed; no upload page was opened and no artwork,
  file or public post was uploaded. No purchase was made. No end-to-end upload
  submission was attempted, in accordance with the user's prohibition.
- Sankaku remains optional and disabled because its matching methods are not
  live-verified. Re-encoded images still cannot match original-byte MD5. Old
  duplicate tasks created by an earlier APK are not forcibly destroyed.

Local evidence is under `/tmp/issue54-originals`, including complete-regression,
final-analysis, task-reuse-final-candidate logs and Maestro screenshots
`real-pixiv-exact-match.png`, `final-cold-real-pixiv-match.png`, and
`restricted-original-message.png`. These temporary files are not portable
handoff dependencies; the findings and verification limits are recorded here.

Cleanup completed: temporary login/share helper apps (including their private
credential/export copies and login URI handler) and the instrumentation APK were
uninstalled; the test clipboard and temporary host OAuth/token artifacts were
cleared. The six imported profiles and signed-in official Pixiv app remain
available. Boorusama was returned to Browse with Default profile selected. The
exclusive emulator-5556 lease was released, and the ordinary AVD was left running.
The main checkout's user-owned `.gitignore` edits and profile exports were
preserved. Only this task worktree was committed; no push, PR, merge or issue
closure was performed.

Automatic approval review rejected an earlier proposed localhost credential
bridge because it could expose the password to other local processes. The bridge
was never started; private device storage and the user's authorized profile import
were used instead. This rejection did not block the final verification.

## Multi-Booru expansion — 2026-10-27

Implementation and tested runtime commit:
`41870d62b980455e2b470322cb022b74a4a279bd` (`Refs #54`).
Continued `feature/54-pixiv-share-lookup` in its existing isolated worktree from
`c03f607cfd84b4cb13b66d7d6d4259fa044f7b27`, after fetching `origin` and reading
the updated issue. Preserved the native startup fix
`6fb3f815854593a77ae78c00b7e809cf77815879` and all earlier work.

### Cause, capability decisions and implementation

The earlier Android regression was the proven native EventChannel startup race
described below; that fix remains unchanged and was retested. The absence of
Rule34, Gelbooru and Safebooru from shared-Pixiv lookup had a separate cause:
`supportsSharedPixivLookup` and its session only enabled Danbooru's `pixiv_id`
search. General post-context MD5/source capability was not connected to shared
artwork lookup. Sharing provides an artwork reference, not a Booru Post or hash.

The existing session now has explicit, live-verified host/API capabilities:

| Target | Shared-artwork source method | Exact-file fallback |
| --- | --- | --- |
| Danbooru API | `pixiv_id:<id>` | `md5:<hash>` |
| Gelbooru.com API | Modern/localized, legacy and image source patterns | `md5:<hash>` |
| Rule34.xxx API (`api.rule34.xxx`) | Modern/localized, legacy and image source patterns | `md5:<hash>` |
| Safebooru.org API (registered XML parser) | Disabled: positive stored-source queries failed | `md5:<hash>` |
| Sankaku / other hosts | Unverified, disabled | Unverified, disabled |

The three patterns are `source:*pixiv.net/*artworks/<id>*`,
`source:*pixiv.net/*illust_id=<id>*` and
`source:*pximg.net/*/<id>_p*`. Every production query contains the numeric artwork
ID; there is no broad source-domain scan. Search hits are only candidates:
`SourcePostLookup` independently parses returned references, decodes HTML query
separators, accepts multiple URLs only when their Pixiv IDs agree, and rejects
missing/ambiguous identity. Prefix IDs do not match. Returned origin, profile and
positive post ID are checked before visibility filtering. Source and exact-file
matches retain distinct provenance.

Each variant and original hash retains its own remote page cursor. The existing
Load more action preserves raw continuation, deduplicates post IDs across
queries/pages, and retains loaded matches after subsequent failures. Errors or
invalid metadata do not silently trigger downloads. Completed source searches
with any visible or filtered match stop MD5 fallback for that target.

Optional originals reuse `PixivClient.getIllustDetail` under a configured Pixiv
profile and enforce that source profile's visibility rules before download.
`ExactPostLookup.findHash` takes a digest directly, without synthetic Posts.
Originals are streamed to MD5 through a separate strict-TLS CDN client with the
Pixiv Referer, no API credentials/cookies and no redirects. Only owned HTTPS
`pximg.net` original-image paths for the exact artwork/page are allowed. Limits:
20 pages, 32 MiB/file, 128 MiB/artwork, metadata 10 seconds, transfer 20 seconds,
session 90 seconds, serial pages and two application-wide CDN downloads. Metadata
over 20 pages is rejected before source Post parsing. Hashes are cached only for
the results session and shared across targets. Route dismissal cancels active
and queued media transfers; source account edits/removal revoke the session.

Each target still uses its own existing repository, credentials, restrictions
and blacklist; the three-target queue and #49 results/viewer are reused. No
second screen, sharing listener, authentication system or active-profile switch
was introduced. Missing Pixiv authentication, partial/unavailable originals and
Ugoira produce localized incomplete coverage, not a definite no-match or a
misleading Load more button. Re-encoded files cannot match original-byte MD5.

Parser review found two ways incomplete evidence could look like no-match:
Gelbooru V2 parsers filtered missing hashes before lookup validation, and an XML
API error could be read as empty posts. Lookup responses now retain incomplete
records for identity validation, and non-post/error XML is rejected. Ordinary
feed hash filtering remains unchanged.

### Live API verification (October 27)

Read-only requests used credentials from ignored `.test_credentials` for each
matching Booru host. No credentials were logged or committed. Safebooru.org had
no account entry and was tested anonymously against its public API; authenticated
Safebooru behavior is consequently not established.

| Host | Known MD5 positive | Artwork/source controls |
| --- | --- | --- |
| `safebooru.donmai.us` (configured Danbooru account) | Post `12457849`, `761033954ac7b0b5eadb7a5c9aafebfe` | `pixiv_id:150842777` and its stored image source returned that post |
| `gelbooru.com` | Post `15166406`, `47c018573fdf86a7f178400c7f5f5010` | Localized `151298449`; modern pattern `83452178` returned `6500970`, `5456672`; legacy `95939279` returned `15164263`; image pattern `150537068` returned `15166373` |
| `api.rule34.xxx` | Post `19169464`, `a039ebfaaca9fc9059e505dfee01471c` | Localized `116628203`; modern `122424425` returned `19169485`; legacy `55231416` returned `19169230`, `19169199`; image/multiple-reference `150504616` returned `19169226` |
| `safebooru.org` | Post `7268205`, `1fc648abbd44939bbba165ba625d17ab` | Stored image source identifies `150636168`, but even its literal source query returned no results |

For every host, the known MD5 was positive, all-zero MD5 was empty, an unknown
metatag was empty rather than an ordinary feed, and `limit=1` pages zero/one
(Danbooru pages one/two) yielded the positive then empty page. Source-pattern
controls included nonexistent artwork `999999999999999999`, which returned no
matches. Gelbooru modern and Rule34 legacy source queries also produced distinct
positive posts on consecutive `limit=1` pages. Modern/localized, HTML-escaped
legacy and direct-image references were exercised individually. Safebooru's
source variants failed their positive controls and remain disabled. Its real
registered no-JSON API returned valid empty `<posts count="0" ...>` XML; this
was checked separately from its bodyless empty JSON behavior. Rule34's bodyless
HTTP 200 empty JSON response remains supported.

Gelbooru's literal modern source query did not find the known control reliably;
the verified pattern strategy is intentional. Its image-pattern response can
return a canonical Pixiv source rather than the indexed image reference, so
independent artwork-ID validation is required. Rule34 can return several source
URLs in one field, which the previous single-URL helper could not interpret.

Local research scripts/results are under `/tmp/issue54-expansion`; these are
temporary evidence, not required runtime files. No artwork or file was uploaded
to any website, and no public comment, PR or issue update was posted.

### Automated verification of the implementation commit

Runtime code, tests, dependencies and generated runtime output were frozen for
the successful complete run; later changes only document that same candidate.
FVM SDK: pinned Flutter 3.47.2. Detected physical-core concurrency: **6**.

```bash
./scripts/run_regression_tests.sh
fvm flutter analyze --no-pub \
  lib/core/posts/cross_profile_lookup test/cross_profile_lookup \
  packages/booru_clients/lib/src/gelbooru_v2/parsers \
  packages/booru_clients/test/gelbooru_v2/lookup_response_validation_test.dart
fvm dart format --output=none --set-exit-if-changed \
  lib/core/posts/cross_profile_lookup test/cross_profile_lookup \
  packages/booru_clients/lib/src/gelbooru_v2/parsers/common.dart \
  packages/booru_clients/lib/src/gelbooru_v2/parsers/gel_parsers.dart \
  packages/booru_clients/lib/src/gelbooru_v2/parsers/r34_parsers.dart \
  packages/booru_clients/test/gelbooru_v2/lookup_response_validation_test.dart
fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub
(cd android && ./gradlew :app:testDevDebugUnitTest \
  --tests com.timberpile.boorusama.PendingSharedTextIntentsTest --rerun)
git diff --check
```

- Complete local runner: **exit 0**, application **5,087 passed**. All 13 package
  suites passed: booru_clients 145, boorusama_cli 254, cache_manager 59,
  coreutils 191, dtext 59, extended_image 47, filename_generator 31,
  flutter_sqlite3_migration 45, foundation 65, go_router 436,
  i18n_cli 32, kurumi 161, retriable 16. The two existing go_router skips are
  `routing config works with shell route` and obsolete StatefulShellRoute branch
  cleanup after configuration changes. PR policy, Android release tooling and
  **72 Python tooling tests** passed. Log: `complete-regression.log` in the
  temporary evidence directory.
- The complete run includes the final regression tests for all enabled methods,
  missing/ambiguous metadata, prefix false positives, target-origin isolation,
  independent variant/hash pagination, deduplication, failures, cancellation,
  multi-page originals, source removal, unavailable auth/Ugoira/partial coverage,
  bounded streaming, redirects, wrong MIME/host and controlled-clock transfer and
  metadata timeouts. Existing #49 visibility/profile/navigation tests also passed.
- Affected lookup tests (**158 passed**) and the full booru_clients suite
  (**145 passed**, FVM Flutter runner because of `graphql_flutter`) passed during
  work. An early repository-boundary fixture lacked the new profile provider
  dependency and failed with `UnimplementedError`; its override was corrected
  before the passing affected and complete runs.
  Two intermediate new cancellation tests initially hung due to the fake-clock
  harness not advancing Dio's zero-delay timer; those attempts were stopped and
  do not count as passes. The corrected 25-test original-hash file and then the
  complete unchanged candidate passed.
- Final analysis: **no issues found**. Final formatting: **29 files, 0 changes**.
  Translation JSON and the README handoff link were checked; whitespace passed.
  Changed localization inputs were regenerated with `./gen.sh i18n`.
- Native queue tests forced to rerun: **3 passed, 0 skipped/failures/errors**,
  fresh XML timestamp `2026-10-27T09:15:37.769Z`.
- APK built successfully. Earlier builds/native tasks emitted Flutter's
  `File modified during build` notice; the final serial unchanged APK build
  completed without that notice. Toolchain KGP/Gradle deprecation warnings remain.
  All 16 changed/new runtime Dart files, including package parsers, were verified
  byte-for-byte in the APK's embedded kernel sources. The installed APK was pulled
  back and matched the local APK SHA-256:
  `8c29ed3a9b373c247ed9c5a3ea92c331a9112b19f6aa31f6b86cbaec4dbc5f92`.

### Actual Android verification and limits

Used exclusively leased `emulator-5556` (Phone2). An attempted separate read-only
launch did not remain the active process; the running Phone2 instance was an
ordinary AVD. Cleanup therefore explicitly removed the QA data rather than
assuming disposable storage. The busy `emulator-5554` was not used. Maestro controlled
the UI at `http://127.0.0.1:10000/`; ADB provided install, process-stop,
foreground and startup-race Intents. Added disposable QA profiles using a private
Android content-provider export; the existing Default profile was preserved by
choosing Copy. Credentials were never placed in public storage or fixtures.

On the verified installed APK:

- **Stopped app:** local native sender used the Android chooser with
  `ACTION_SEND`, `text/plain`, String `EXTRA_TEXT` containing
  `QA artwork | QA artist #pixiv https://www.pixiv.net/en/artworks/151301916`.
  Lookup opened and returned Danbooru `12452714` under both Default and QA54
  Danbooru, and Gelbooru `15161533` under QA54 Gelbooru.
- **Background:** another real chooser share for artwork `55231416` opened the
  existing lookup and returned Rule34 `19169230` and `19169199`. Load more
  completed remaining variants with **Results: 2**, without duplicates.
- **Foreground:** explicit equivalent Intent opened artwork `151301916` from
  the live browsing activity. Android confirmed delivery to the existing instance.
- **Repeated shares:** two more copies while that artwork's results were open
  created no extra route; one Back returned to browsing. The same artwork could
  be opened again after dismissal.
- **Startup race:** force-stopped Boorusama, launched unrelated `MAIN`, then
  immediately sent the captioned Pixiv Intent. Lookup and the known Danbooru
  result appeared; Back returned to browsing. The prior native fix is preserved.
- **Target-bound open and Back:** opened actual Danbooru, Gelbooru and Rule34
  results. Viewer actions matched the target engine, and View in browser emitted
  the corresponding `safebooru.donmai.us`, `gelbooru.com` or `rule34.xxx` host.
  Back returned through viewer, lookup and browsing. The profile chooser still
  selected **Default profile** after target-result viewing. Independent-account
  credentials/restrictions are additionally covered by controlled boundary tests.
- **Incomplete coverage:** Safebooru and empty-source targets displayed
  `Sign in to a Pixiv profile to check exact-file matches.` rather than unsupported
  or definitive no-match. Source matches worked without Pixiv authentication.
- **Existing upload sharing:** sharing `https://example.com/qa.jpg` locally to
  Boorusama showed its existing Danbooru upload confirmation. Tapped **Cancel**
  and verified return to browsing. **Never tapped OK, submitted an upload, or
  uploaded any artwork/file to a website.** This verifies the confirmation/cancel
  path; actual upload submission was neither needed nor authorized.

Official Pixiv 6.201.0 was installed and launched with Maestro: onboarding Skip
led to its login screen. `.test_credentials` contains no usable Pixiv token or
login, even after rechecking following the user's permission to use that file.
Its authenticated Share action could not be exercised. The equivalent-Intent
evidence above is **not** real Pixiv Share evidence. End-to-end original retrieval
and resulting MD5 fallback on device likewise remain unverified; those paths have
controlled stream/resolver/session tests and independent live Booru MD5 controls.
Safebooru live verification is anonymous, not authenticated. Sankaku stays optional
and disabled. No claim is made that original MD5 can find re-encoded artwork.

The four QA profiles and temporary sender/Pixiv apps were explicitly removed,
preserving the original Default profile. Private QA export copies were cleaned
up, and the exact emulator lease released. The ordinary emulator was left running.
No PR, push, merge, issue closure or branch
cleanup is authorized. A future combined develop candidate still needs its own
complete regression if its runtime/dependencies differ from this tested commit.

## Android regression continuation — 2026-10-26

Fix commit: `6fb3f815854593a77ae78c00b7e809cf77815879`.
Preserved baseline: `947a0460f1280f33b7ded842791f0102c0e7dbec`.
Fetched `origin` and continued the existing isolated branch without resetting,
rebasing, merging or publishing it.

### Confirmed root cause and fix

The unchanged baseline reproduced a silent loss when a text share arrived during
Flutter initialization: stop Boorusama, launch its main activity, then immediately
send an `ACTION_SEND`, `text/plain`, String `EXTRA_TEXT` artwork URL to that
activity. Android reported delivery to the existing top activity. The native
`share_handler_android` plugin logged `EventSink is not available`; once startup
finished, Maestro showed browsing rather than lookup results.

The plugin caches the initial activity Intent but does not retain a warm
`onNewIntent` delivery while its EventChannel listener is absent. In this
reproduction the cached launch Intent was `MAIN`, so `media.content` never
contained the later artwork URL. URL parsing or navigation could not recover it.
Canonical single cold shares and settled warm shares already worked on the
baseline; this evidence establishes the startup race, rather than proving the
timing of every occurrence reported from the user's device.

`MainActivity` now holds early text-share Intents until `UploadToDanbooru` has
subscribed to the existing plugin and processed its initial payload. A small
lifecycle channel resumes delivery through the original `super.onNewIntent`
path; it carries no shared text. Disposal pauses delivery before unsubscribing,
and activity destruction clears pending Intents. Other Intent types continue
immediately through the existing paths. The source also resets the plugin's
consumed initial payload, preventing replay after receiver remounts.

No new receiver, Intent filter, URL resolver, dependency or lookup screen was
introduced. Pixiv parsing, the existing router/frame wait, duplicate artwork
tracking, #49 result presentation, target-profile boundaries and the three-request
lookup queue remain in place. `NavigationActivity` is below this receiver in the
production shell, so its guard was not the cause in the reproduced flow.

### Verification on the fix candidate

Detected physical-core concurrency: 6. Commands ran with the pinned FVM SDK.

```bash
fvm dart format --output=none --set-exit-if-changed \
  lib/core/posts/shares/src/incoming_shared_text_source.dart \
  lib/boorus/danbooru/posts/uploads/src/widgets/upload_to_danbooru.dart \
  test/cross_profile_lookup/pixiv_share_receiver_test.dart \
  test/core/posts/shares/incoming_shared_text_source_test.dart
fvm flutter test --no-pub --concurrency=6 \
  test/cross_profile_lookup test/application/cross_profile_lookup_flow_test.dart \
  test/core/posts/shares
fvm flutter test --no-pub --concurrency=6 \
  test/cross_profile_lookup/pixiv_share_receiver_test.dart \
  test/core/posts/shares/incoming_shared_text_source_test.dart
fvm flutter analyze --no-pub --no-fatal-infos \
  lib/core/posts/cross_profile_lookup \
  lib/core/posts/shares/src/incoming_shared_text_source.dart \
  lib/boorus/danbooru/posts/uploads/src/widgets/upload_to_danbooru.dart \
  test/cross_profile_lookup \
  test/core/posts/shares/incoming_shared_text_source_test.dart
fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub
(cd android && ./gradlew :app:testDevDebugUnitTest \
  --tests com.timberpile.boorusama.PendingSharedTextIntentsTest)
git diff --check
```

- Affected Dart suite: **404 passed**. Final fixture cleanup was followed by
  the focused **10-test pass** on the committed test state.
- Android queue unit tests: **3 passed**, no skips or failures. They cover ordered
  startup replay exactly once, receiver detach/resubscribe and activity cleanup.
- New Dart coverage exercises buffered startup shares, initial-read failure,
  duplicate launch/warm delivery, late disposal, plugin content mapping, lifecycle
  signaling and consumption of the cached initial payload.
- Analysis: exit 0, no errors or warnings; one pre-existing
  `curly_braces_in_flow_control_structures` info in the upload confirmation action.
- APK build, formatting and whitespace checks passed. Flutter emitted a
  `File modified during build. Build must be rerun.` notice even on a serial
  unchanged repeat; no tracked runtime source changes were produced.
  The installed APK was pulled back and matched the final local APK SHA-256:
  `06eb56c6051bffe7b2c29dee11adbf228d19082eb057564fe8d50bc0d72a7f22`.
- The unchanged baseline's first affected-suite attempt timed out in one
  Danbooru repository-boundary test; that file then passed all 3 tests serially.
  The fixed candidate's affected suite completed without that failure.
- No complete repository-wide regression was run; integration still requires
  that gate on the eventual combined develop candidate.

### Actual Android checks and limits

Used exclusively leased `emulator-5554`, with Maestro for UI control and explicit
ADB Intents for timing-sensitive/foreground scenarios. Existing app data and
accounts were preserved; process stops separated startup scenarios.

Pixiv was initially absent. A downloaded Pixiv **6.201.0 (69129)** APK was
signature-verified and installed for investigation. Its signer SHA-1 was
`2e11400cda20f4f6bb285c9f500cc11cf288db8b`. The app required a fresh login, and
there was no authenticated session available. **The real Pixiv Share action was
not exercised.** Inspection of that APK's share construction and localized
resource established `ACTION_SEND`, `text/plain`, String `EXTRA_TEXT` containing
`<title> | <artist> #pixiv https://www.pixiv.net/en/artworks/<id>` (the Japanese
resource omits `/en`). This is artifact evidence, not a successful real-app test.

A temporary separate sender reproduced that exact Intent structure and opened
Android's real chooser. Selecting **Boorusama Timber Dev** exercised cross-app
delivery rather than only explicit activity starts.

| Scenario | Observed result on fixed APK |
| --- | --- |
| MAIN launch followed immediately by artwork SEND | Previously lost share now opens artwork `151301916` and live match `#12452714`. |
| Fully stopped, chooser share | Opens the same lookup/results without an upload prompt. |
| Backgrounded, chooser share | Opens lookup; tested from Safebooru.org browsing as well as the default Danbooru profile. |
| Foreground, new artwork SEND | Opens artwork `118809844` with 13 live results. |
| Same artwork shared while its results are open | One results route; one Back returns to browsing. |
| Same artwork shared again after dismissal | Reopens normally. Sharing after selecting Bookmarks also opens results. |
| Open result and Back | Live `#12452714` opens in the viewer; Back returns to results, then browsing. The viewer's browser action targets `safebooru.donmai.us`, confirmed in Android's launch log while browsing originated from Safebooru.org. |
| New foreground share over a result viewer | Back restores the prior viewer, then its lookup, then browsing. |
| Existing non-Pixiv URL share | Danbooru upload confirmation appears and Cancel dismisses it; repeated for a share buffered during startup. No upload was submitted. |

No shared-text delivery errors appeared in the fixed scenario logs. Screenshots
were captured for startup, cold, foreground and upload-confirmation states.
The temporary sender and Pixiv installation are removed after QA; the browsing
profile is restored to Default profile and the emulator lease released.

Remaining acceptance: reproduce the user's actual share with a signed-in official
Pixiv app. Equivalent-Intent success does not prove the user's exact payload or
every timing condition. Same-site accounts with distinct real credentials,
live profile edits/removal during requests and actual browser upload submission
were not device-tested in this continuation; existing automated profile/isolation
and pagination coverage passed. No PR, push, develop merge or issue closure was
performed. The historical handoff below is retained as implementation context;
its absent-FVM/local-Android notes are superseded by this continuation.

## Scope and account boundaries

The existing single Android text-share receiver now recognizes a safe Pixiv
artwork reference before attempting the existing Danbooru upload flow. It accepts
captioned modern/locale artwork URLs, legacy illustration links and known Pixiv
image URLs without resolving redirects or fetching an untrusted shared URL.
Ambiguous multiple artwork IDs, spoofed hosts, credentials, nonstandard ports,
malformed encoded IDs and oversized input are rejected. The stored reference is
only an artwork ID and a canonical public URL, not a fabricated Booru post.

Initial and warm deliveries share one listener. Duplicate deliveries of an
already-open artwork do not push duplicate result pages. Closing the page permits
a later explicit share of the same artwork. Disposed listeners ignore late
initial results; an initial platform failure does not disable warm deliveries.
A small injectable port wraps the existing share_handler dependency; no new
plugin, Android manifest change, platform receiver or second picker was added.

The #49 CrossProfileLookupPage/Results UI, queue (three active profile lookups),
pagination, target-bound viewer opening, live profile edit/removal checks and
visibility policies are reused. All compatible configured accounts are searched,
including the currently browsed account. No active-profile switch, source-post
refresh or image download is needed. Returned metadata must establish the same
artwork ID and target origin. Source matches are not labeled identical-file
matches. Counts are visible, deduplicated loaded results; incomplete pages never
claim exact totals and require explicit Load more.

**Verified capability:** Danbooru artwork-ID search. Gelbooru's generic source-URL
search, Rule34's MD5 support and the experimental Pixiv engine are not treated as
proof of equivalent artwork-ID lookup. Those profiles remain explicitly listed
as unsupported. Adding another engine requires verified query semantics and
origin/source validation, not a broad wildcard guess.

## Tests and source review

Local container checks: JSON parsing and `git diff --check`. FVM is absent in the
container, so the attempted focused command could not execute. Hosted CI results
must be recorded from their actual logs and checked commit; do not infer a pass
from this implementation handoff.

New tests cover safe/ambiguous reference parsing, initial/warm duplicate delivery,
late disposal, platform errors, unsupported engines, cancellation while resolving
an account, all-compatible-account fan-out, privacy filtering, distinct failure
and empty states, source provenance, incomplete counts, pagination deduplication,
narrow enlarged-text layout and queued cancellation after disposal. The existing
HTTP repository boundary test additionally verifies Pixiv-ID requests use the
target Danbooru credentials, endpoint, rating and deleted-item restrictions.

The original #49 tests remain required because the page and SourcePostLookup API
are shared. The original find(Post, ...) method delegates to the reference-based
method without changing its matching/fallback semantics. Queue callbacks capture
their session before awaiting a slot and cannot read a disposed WidgetRef.

Run locally after fetching and reading current AGENTS.md:

```bash
./init.sh
workers="$(python3 scripts/physical_core_count.py)"
fvm dart format --output=none --set-exit-if-changed \
  lib/core/posts/cross_profile_lookup \
  lib/core/posts/shares/src/incoming_shared_text_source.dart \
  lib/boorus/danbooru/posts/uploads/src/widgets/upload_to_danbooru.dart \
  test/cross_profile_lookup
fvm flutter analyze --no-pub --no-fatal-infos \
  lib/core/posts/cross_profile_lookup \
  lib/core/posts/shares/src/incoming_shared_text_source.dart \
  lib/boorus/danbooru/posts/uploads/src/widgets/upload_to_danbooru.dart \
  test/cross_profile_lookup
fvm flutter test --no-pub --concurrency="$workers" \
  test/cross_profile_lookup test/application/cross_profile_lookup_flow_test.dart \
  test/core/posts/shares
(cd packages/i18n && fvm dart test --concurrency="$workers")
```

Run the i18n command only if that package contains tests; use its actual Flutter
or Dart test runner according to AGENTS.md. Generated translations belong to the
normal init/gen flow, not manual edits. Preserve #50's existing-label changes
when combining the independent branches.

## Required Android acceptance

Read `docs/android_emulator.md`, acquire an exclusive lease and use Maestro.
Exercise Android Share with the app stopped, backgrounded and already open;
include a non-Danbooru browsing destination, same-site accounts with different
credentials, a source with multiple pages, empty/failed/unsupported profiles,
captioned/localized links and a second share after returning. Verify no upload
prompt appears for a recognized artwork. Check target-scoped viewer/download/
bookmark actions and Back navigation without changing the browsing profile.
Check real target content restrictions, narrow width, large text, edited/removed
profiles during requests, and cancellation on dismiss. The fake transport tests
do not establish live API availability or actual Android delivery behavior.

No PR, merge or issue closure is authorized. After explicit integration approval,
run the complete LOCAL regression command on the final combined candidate before
publishing develop or closing #54. Hosted scoped verification is not that gate.
