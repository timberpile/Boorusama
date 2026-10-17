# Consolidated review remediation

Review baseline: `49f2b9ade`, branch `maintenance/upstream-v4.6.1-migration`.
The three supplied reports consolidate into 21 actionable items, plus one
explicitly conditional concern. Repeated mentions are one item, not additional
independent defects. The original implementation report's 68/68 completeness
claim is superseded by this reconciliation.

Follow-up: targeted authenticated live API and Android checks passed on
2026-10-17. B10 is now activated. Those checks found and fixed one additional
empty-listing parser defect, documented below.

## Findings, evidence and changes

R1/R2/R3 refer to the user's three supplied reports. "Confirmed" distinguishes
an implementation/acceptance gap from a claim that a live endpoint is broken.
The approved decision log remains authoritative.

| # | Decision / reports | Validation and resolution |
| --- | --- | --- |
| 1 | A14 / R1, R2 | Confirmed Android DSL compilation failure in the baseline Dev build. Disambiguate SDK variable names, replace deprecated Kotlin options, and remove the obsolete global BuildConfig flag. AGP 9 then exposed an incompatible existing cookie-manager plugin. Restore the established AGP 8.12.1 / Kotlin 2.2.20 / Gradle 8.14 combination under A14's selective adoption rule; retain SDK 36, Java 17, flavors, package identity and signing. Enable app BuildConfig explicitly. |
| 2 | A01/X03 / R1 | Confirmed by a failing runtime-scope replacement widget test with real Hive storage. Hive factories no longer close application-owned boxes when a provider scope is disposed. Covers favorites, bookmarks/groups and the identical blacklist ownership pattern. Factory seams and fake-factory disposal remain intact. |
| 3 | D02 / all | Confirmed injected cleanup failure made a completed session unreachable. Commit terminal status, completion time, final statistics and record deletion in one SQLite transaction. A failed transaction retains retryable state and records. Startup repairs interrupted finalizations without replaying notifications; repeated cleanup preserves saved totals. Regression includes a SQLite abort trigger, rollback, startup recovery and repeated finalization. |
| 4 | N02 / R1, R2 | Confirmed original URLs/client bypassed media resolution. Resolve every progressive target/lower/fallback candidate and preload request through profile network settings, selecting an independent replacement-host client and filtered headers. Grid fallback transport receives the same treatment. A controlled adapter test checks viewer plus preload URLs, cache destination and credential stripping. |
| 5 | D01 / R1, R2 | Confirmed with controlled concurrent writes to one destination. Replace check-then-rename with native atomic publication that cannot replace an existing file. Identical content is idempotent; different content remains a recoverable conflict. Native implementations use Linux/Android no-replace rename, Darwin exclusive rename and Windows non-replacing move. |
| 6 | P08 / R1, R3 | Confirmed a deferred deletion's hidden cache key could enqueue onto its leased path. Refuse replacements while readers or deferred deletion own that path, including a recheck after asynchronous admission work. Package regression holds two readers, attempts replacement, releases both, then confirms an allowed replacement survives repeated old-lease release. |
| 7 | X04 / R1 | Confirmed the old test explicitly expected a cache path and no share directory. Sharing now copies validated images into `boorusama-share`; cache protection lasts only through copying. Cache clearing cannot delete the share copy. Existing release and startup cleanup remove share files. |
| 8 | B06 / all | Confirmed held favorite lookup blocked listing. Capability discovery and favorite enrichment now run asynchronously after obtaining posts. Existing favorite-cache merging preserves intervening user actions; optional failures remain soft. A completion-gated regression proves listing returns before the lookup is released. |
| 9 | D01 / all | Confirmed failure/retry APIs had no application UI consumer. Both download screens now display a metadata failure notice opening one shared recovery page. Retry operates on the sidecar journal only, retains conflicts and explains failed retries. Updates invalidate the failure list; resume refreshes failures written by background isolates. Narrow/large-text widget coverage proves retries leave media unchanged. |
| 10 | N05 / R2, R3 | Confirmed exported cookies defaulted unknown flags to false and native path to `/`. Android exports a conservative host-only, request-path and transport scope, with unknown HttpOnly treated as restricted. Dart defaults unknown security flags to restricted values. Explicit native attributes remain authoritative. This narrows unknown attributes; Android's header API cannot recover the original attributes. Conversion checks cover Secure, HttpOnly, path and host-only behavior; installed native behavior remains manual acceptance. |
| 11 | N01/D05 / R2, R3 | Confirmed Anime-Pictures returned an uncoordinated transport despite its quota definition. Attach its Dio to the shared `ApiRequestCoordinator`; the transport regression verifies that provider boundary. |
| 12 | P03 / R2 | Confirmed there were no app reload callers and error placeholders were static. Add focusable localized Retry controls that call `ExtendedImageController.reload()` for grid/fallback images. Progressive retry targets failed requests while retaining decoded lower pixels. Only explicitly retried failed cache keys are cleared. Tests cover pointer/keyboard retry, independent tile taps, corrupt target bytes, retained pixels and successful replacement. |
| 13 | D07 / R2, R3 | Confirmed missing `{id}` could yield `.jpg`. When an ID token is used but no genuine ID exists, generate an explicitly named `media_` URL-hash filename with the actual extension. Different URLs with the same basename remain distinct; no synthetic post ID is exported. |
| 14 | P02 / R2, R3 | Confirmed unchecked optional enable-value cast threw, and discarded options produced no warnings. Parse the switch tolerantly and retain transient per-profile warning codes for invalid/unknown actions and host rules. Package-import preflight and legacy profile-import confirmation show localized warnings. Keep UUID/unrelated fields; unsafe/uninterpretable options normalize to supported values rather than retaining invalid host rules. |
| 15 | P04 / R2 | Confirmed obsolete typed errors published before the latest-result guard. Guard error publication and resolve queued refresh callers using the final pass, also suppressing obsolete thrown failures. Tests cover typed and thrown old failures followed by a successful refresh. |
| 16 | B01 / R2 | Confirmed shared action children were empty/unused and Sankaku had no controls. Add a shared site capability for rating/date/order/user/pool/favorite options, supplied by Sankaku and Danbooru. The existing common mobile/desktop action section renders one shared options UI; site definitions own raw prefixes/values. Preserve Danbooru's existing saved-metatag controls. Test constrained dialog submission and safe mappings; raw syntax/composer/autocomplete remain available. |
| 17 | N01 / all | Confirmed reference audit found only the obsolete sliding-window implementation, its export and its own tests. Remove those files/export; retain the coordinator and its regression coverage. |
| 18 | D07 / R3 | Confirmed dry run checked disk existence but never reserved destinations within a batch. Reserve normalized destinations across all pages: skip a duplicate when skipping is enabled, otherwise fail preparation visibly before any transfer. Pixiv's page-specific default remains unchanged. Tests exercise both conflict policies; ordinary bulk fixtures now use distinct names. |
| 19 | N01 / R3 | Confirmed retry backoff could not be interrupted. Make retry waiting cancelable and cancel its timer. A controlled-clock regression proves cancellation settles without waiting for Retry-After or issuing another attempt. |
| 20 | B10 / R3 | Confirmed acceptance violation, not a demonstrated endpoint failure: the new listing host was enabled without the required live checks. Initially restore the established relative XML listing endpoint and default parser. The subsequent authenticated live/Android checks below passed after fixing the empty-response defect; the JSON listing endpoint is now activated with the dedicated parser. Profile identity and existing details/autocomplete endpoints are retained. |
| 21 | Documentation / all | Confirmed `git diff --check e8bf883 -- docs/migrations/upstream-v4.6.1` reported handoff trailing whitespace and the catalog's extra EOF line. Remove those whitespace defects. |

## Conditional concern

R3 explicitly excluded mixed-origin quick actions from its confirmed findings.
The current bookmark builder (`bookmark_scroll_view.dart`) and Following feed
builder (`topic_feeds_page.dart`) resolve each post's origin and pass that
profile's auth to `DefaultImageGridItem`. The generic grid uses the selected
profile, but no currently affected mixed-origin use of that default builder was
established. No speculative behavior change was made for this concern.

## Original repair verification (before live follow-up)

Checked candidate: `0c1ade6eec43a1104b24391c702c4bf1972b3541`.
Runtime fixes are in `d5af43e58`; `0c1ade6ee` aligns consumer tests with the
approved behavior. The report/README changes after this candidate are
documentation-only. Local `develop` and `origin/develop` remain at
`e8bf883912ecd5a8c4154472a962aa0aabf0c09a`, an ancestor of the candidate;
the pinned upstream v4.6.1 commit also remains an ancestor.

- `./scripts/run_regression_tests.sh` — **exit 0** on the final candidate.
  All 3,802 application tests, all 12 package/CLI suites, pull-request policy
  tests, Android release-script tests and all 61 Python tests passed. No declared
  test skips appeared in this run. Ordinary test concurrency was six physical
  cores, detected by `python3 scripts/physical_core_count.py`.
- `fvm flutter analyze --no-pub --no-fatal-infos` — **exit 0**, with no errors
  or warnings and 198 informational diagnostics. Fatal-info analysis is not
  claimed.
- `fvm flutter build apk --debug --flavor dev --no-pub` — **exit 0** on the
  final runtime, producing `build/app/outputs/flutter-apk/app-dev-debug.apk`.
  Flutter emits compatibility warnings about the retained AGP/Kotlin/Gradle
  versions; dependency Java/deprecation warnings also remain.
- `./gen.sh`, followed by focused `./gen.sh i18n` / `./gen.sh booru` runs as
  inputs were finalized — **passed**. The final tests/build used outputs
  generated from the committed localization and booru inputs.
- Changed Dart files were formatted with `fvm dart format`. Diff whitespace,
  unresolved-index and merge ancestry checks passed.
- Focused reproduction, recovery/UI, bulk, sharing, cookie, filename, cache and
  retry checks passed. UI automation covered narrow width, enlarged text,
  keyboard-constrained entry, pointer/keyboard Retry and metadata-only recovery.

The initial nine application reproductions failed against `49f2b9ade` and pass
with the repairs. The original Dev build reproduced SDK-name/DSL compilation
errors. A separate minimal **offline** AGP 9.0.1 project reproduced removal of
`android.defaults.buildfeatures.buildconfig`.

The first complete attempt failed five assertions that encoded superseded
endpoint/share/refresh contracts and one intermittent pending-image-request
timer in the keyboard focus test. Consumer expectations were corrected while
retaining media lifetime, latest-result, final-error and API-details checks.
The keyboard case passed its isolated rerun, and the subsequent complete run
passed on the final candidate. Recurring nonfatal Flutter native callback
messages also occur in the supplied baseline-run logs; the final run still
completed successfully.

Evidence logs are retained locally under `/tmp/migration-fixes-*`, including
`regression-final.log`, `regression-first-attempt.log`, `analyze-final.log`,
`build-final.log`, `repro-baseline.log` and `agp-property-repro.log`.

## Limits

The user subsequently requested emulator verification. The bounded checks below
supplement A02's manual checklist; they do not complete that checklist.
Installed upgrade/signing acceptance and Windows/macOS/iOS native execution
remain unverified. Authenticated Android API and native cookie checks are
recorded in the follow-up below. Linux atomic sidecar
publication is exercised locally; other platform implementations require native
acceptance.
The Rule34 listing switch is now activated after targeted live verification.
Local fixes do not authorize
integration, pushing, PR creation, tagging or release publication.

## Live verification — 2026-10-17

Candidate: `2fedcb0df` (runtime/test candidate `0c1ade6ee`, followed by a
documentation-only commit). Installed the previously built development APK
with `adb -s emulator-5554 install -r`, without clearing data. This emulator had
no Boorusama installation, so this was a fresh install, not an upgrade test.

- Device: exclusively leased `emulator-5554`, Android 16 / API 36, x86_64.
- Package: `com.timberpile.boorusama.dev`,
  `4.6.1-timberpile.1-dev`, version code 190, target SDK 36.
- APK SHA-256:
  `ce78683d78ba2b351069b54c1c77f3785db297e0b467a138668c652aa99b7624`.
- UI control: Maestro MCP, explicitly targeted to the leased emulator. The
  physical device discovered by ADB was not used. Lease released after checks.

### Confirmed on the emulator

- Fresh startup completed and the default Safebooru profile loaded 60 posts.
  Dismissed What's New; it did not reappear on the subsequent app launch.
- Created an anonymous Rule34 profile and switched to it. The live listing
  request opened the native challenge recovery screen, showing Rule34's CAPTCHA.
  Cancel returned to the usable `403 / Access denied` page with a Retry button.
  No challenge was solved and no successful cookie transfer is claimed.
- Tapping Retry completed with `0 posts / No data available`. A flow expecting
  the CAPTCHA to reopen failed its assertion. This is a separate observation,
  not a passing challenge retry/solve test; the response behind the empty result
  was not captured, so its cause is unestablished.
- Switched back to the default profile. Shared Search Options exposed Rating,
  Date, Sort order, Uploader, Pool and Favorites by user. Rating offered General,
  Sensitive, Questionable and Explicit. Selecting General and Add produced
  `RAW   rating:g `; submitting loaded 60 live posts. The final Maestro assertion
  used the complete chip label after an initial exact-text selector mismatch.
  Android's first-use stylus tutorial interrupted an earlier interaction and
  was dismissed before repeating it.

### Anonymous live API probes from the host

These were bounded, read-only HTTPS requests with `limit=2`, `pid=0`, and
`tags=rating:safe landscape`. They are host-network evidence, distinct from the
emulator UI checks above. No account credentials were transmitted.

| Endpoint | Observed response |
| --- | --- |
| Proposed `https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&json=1` | HTTP 200, JSON string: `Missing authentication. Go to api.rule34.xxx for more information`; no redirect; `Access-Control-Allow-Origin: *`. |
| Existing `https://rule34.xxx/index.php?page=dapi&s=post&q=index` | HTTP 403, HTML CAPTCHA page; no redirect; no CORS header. |

The CORS header observation is not browser CORS acceptance. Neither probe
returned `Retry-After`; no live 429 was induced.

### Initial outstanding live acceptance (superseded by the follow-up)

Authenticated list/details, pagination, filter/limit semantics, successful
challenge completion, cookie origin/path/transport isolation, and cache
isolation remain open. Automatic approval review rejected transmitting the
stored Rule34 test user ID/API key to the external API without explicit approval
for that payload/destination. Approval was requested; the authenticated probe
was not run. The emulator contained no pre-signed-in Boorusama account.

No runtime files changed in this initial verification session. The complete
local suite result above applied to that runtime candidate. These initial
observations did not activate B10 or establish production-signed upgrades, other ABIs, enlarged
text/narrow-width acceptance, native sidecar publication, or the remaining media
and download checklist.

## Authenticated live follow-up — 2026-10-17

Runtime candidate: `81691486c`. The user explicitly approved sending the stored
Rule34 test user ID/API key to `https://api.rule34.xxx` for read-only listing,
pagination and detail checks. The earlier approval block is resolved. Credentials
were not embedded in source/APKs, printed, or committed. Android received them
through stdin into a mode-restricted app-private file; the temporary target
deleted that file immediately after reading it, and deletion was verified.

### Results and the additional defect

Authenticated host probes returned valid JSON for unfiltered/`landscape`
listings, two disjoint pages, `limit=1`, an exact `id:` filter and matching
details. No-result queries returned HTTP 200 with a **zero-byte, chunked
`application/json` body**, rather than `[]`. The initial `rating:safe landscape`
query also returned an empty body; it was not evidence of failed authentication.
A successful authenticated response had no redirect and
`Access-Control-Allow-Origin: *`. No live 429 or Retry-After was observed.

The real Android Dio/client path exposed one additional B10 defect: Dio decodes
that empty JSON body as `null`, which `parseR34PostsApi` rejected. The scoped fix
uses the listing caller's empty value for null input. Detail parsing stays
strict. The new deterministic `rule34_empty_response_test.dart` reproduces the
actual bodyless/chunked transport through Dio: the listing test failed before
the fix and passed afterward; a null detail response still throws.

The approved JSON listing endpoint is now activated with `parseR34PostsApi`.
The generated configuration and consumer regression assert HTTPS API host,
`json=1`, page-to-`pid` translation, limit, tags and existing profile credentials.
Profile/site identity, details and autocomplete endpoints remain unchanged.

### Real Android client and native checks

Reused exclusively leased `emulator-5554` (Android 16 / API 36, x86_64).
A temporary credential-free Flutter entrypoint used the real
`GelbooruV2Client`, the proposed endpoint/parser and the application's
`AuthErrorResponseInterceptor`. It displayed only pass/fail text and requested
no media. Maestro MCP launched it and successfully asserted completion.
The final current-process log and UI showed all **11 checks passing**:

1. Authenticated listing includes IDs, hashes, media URLs and the requested tag.
2. Pagination returns disjoint post IDs.
3. Limit one returns one post.
4. Exact ID filtering returns the requested post.
5. Detail ID/hash/file URL match the listing.
6. The bodyless no-result response parses as zero posts.
7. Anonymous missing-authentication JSON becomes HTTP 401 through the app's
   actual interceptor.
8. A synthetic Secure/HttpOnly cookie exported by the native channel retains
   conservative host, exact requested path, Secure and HttpOnly attributes.
9. The native cookie is excluded from HTTP.
10. It is excluded from an unrelated path.
11. It is excluded from an unrelated host.

The cookie fixture used an isolated `.invalid` hostname and was expired after
the checks. A preliminary harness assertion incorrectly expected the standalone
parser to retain the decoded authentication message; the final harness uses the
production interceptor instead. This was a diagnostic correction, not another
production defect. Both failed/partial runs and the final passing markers are
retained separately; only the final run supports the 11-check pass claim.

The normal app was rebuilt and installed with `install -r` afterward; existing
profiles were preserved. Its default Safebooru feed loaded 60 posts. Switching
to the anonymous Rule34 profile showed `401 / Authentication failed`, an
`Edit API key` action and the server's missing-authentication explanation.
Maestro asserted those labels, switched back to the default profile and
asserted 60 posts. The emulator lease was then released. Final normal APK SHA-256:
`c0a5a410a247cddb90e6be41c744a906c28e6f6e9e9afd6d351f42171da37a4c`.
The temporary entrypoint is ignored under `.tmp/` and is not production code.

### Automated verification and limits

- Complete `booru_clients` package: 102 tests passed after the parser fix.
- Related application/client/coordinator/cookie consumers: 41 tests passed.
- Scoped Dart analysis: no issues.
- `./gen.sh booru`: passed; generated output reflects the committed endpoint.
- Normal Dev debug APK build: passed.
- Full application analysis with `--no-fatal-infos`: exit 0, no errors/warnings,
  198 informational diagnostics.

`./scripts/run_regression_tests.sh` completed with **exit 0** on runtime candidate
`81691486c70af58e600913197263adefc1e6646c`: all 3,802 application tests, all 12
package/CLI suites, pull-request policy checks, Android release-script checks and
61 Python tooling tests passed. The runner used the detected six physical cores.
Documentation-only edits after that commit do not change the tested runtime.
Diff whitespace and local documentation-target checks also passed.

Sanitized evidence is in `/tmp/migration-auth-live-*.json`,
`/tmp/migration-live-emulator-before.log`,
`/tmp/migration-live-emulator-passed.log`, and `/tmp/migration-rule34-*`.

This establishes targeted native Android API compatibility and native cookie
export restrictions. It does not establish successful CAPTCHA solving, browser
CORS execution, an induced real 429, live cross-profile cache isolation,
production-signed upgrades, other ABIs/platforms, or the rest of the manual
checklist. The temporary client target does not exercise the complete production
bootstrap, UI, coordinated transport or persistent cache; those boundaries have
separate local regression coverage. Live JSON records omitted upload timestamps;
they remain unknown rather than being synthesized from metadata-change times.


## Develop synchronization - 2026-10-17

The checked candidate combines migration tip `5a1267461e80b7afbc5c226a4a9194a016739d94`
with local develop `d52b6694eb370a8099c820c397250b5199b0baa5` (Following Topics UX
consistency). Develop was merged into the existing migration branch rather than
rebasing upstream history. The original upstream merge and all later migration
repairs remain intact, including pinned upstream commit
`5b04bf6a164f028d41701299367d0dde74dde330`.

Conflict resolutions retain the migration's Kurumi menus and Material UI test
compatibility while adopting develop's shared Follow/Following destination flow,
manual-only following, duplicate counts, route-scoped profile ownership, backup
presentation, and translations. The obsolete context-menu overlay stays deleted;
its icon/badge coverage now exercises the current Kurumi tile's trailing slot.
Search regression coverage retains typed/raw query preservation, local save and
preview failure separation, and feedback isolation after navigation/query changes.

Integration checks also found and corrected two compatibility gaps:

- Feed pages subscribed to the removed global route observer. Both pages now
  retain the app-scoped navigation observer for subscription and disposal. Real
  navigation tests cover pausing first-check initialization while another route
  covers either feed page, then resuming when it is uncovered.
- The headless full-backup test expected an empty legacy Topic Feeds source.
  Its expectation now follows develop's deliberate presentation change. Legacy
  source registration and import/export compatibility retain their existing
  dedicated regression coverage.

### Verification

The final combined runtime and tests passed:

- `./gen.sh i18n` - translation validation and generation succeeded.
- `fvm dart format --output=none --set-exit-if-changed` on all 61 changed Dart
  files - no changes required.
- Affected Following, navigation, backup, viewer and artist tests were exercised
  during integration. After correcting stale widget selectors, the repaired
  cases passed; the final search-action file passed all 21 tests. The complete
  Kurumi package passed all 122 tests.
- `./scripts/run_regression_tests.sh` - exit 0: all 3,782 application tests, all
  12 package/CLI suites, pull-request policy and Android release-script checks,
  and all 61 Python tooling tests passed. No suites or individual tests were
  skipped. The runner used the detected six physical cores.
- `fvm flutter analyze --no-pub --no-fatal-infos` - exit 0, no errors or warnings,
  177 informational diagnostics. Strict fatal-info analysis is not a clean gate.
- `fvm flutter build apk --debug --flavor dev --no-pub` - exit 0 on the final
  runtime, producing `build/app/outputs/flutter-apk/app-dev-debug.apk`.
- Diff whitespace, unresolved-index and conflict-marker checks passed.

The first complete application run finished with only the stale backup-source
expectation failing. Its complete test file passed after correction, followed by
an entirely successful complete runner on the final candidate. The report update
is documentation-only and does not change the verified runtime or tests.

Logs are retained locally under `/tmp/migration-develop-*.log`, including
`regression.log`, `regression-first-attempt.log`, `analyze.log`, and `build.log`
with that filename prefix.

This synchronization qualifies the combined candidate locally. It does not close
remaining user-run manual UI, production upgrade, live-site, or release acceptance
in the existing checklist. No emulator/device actions were performed for this
synchronization. Local develop remains unchanged, and the migration worktree is
retained. No push, pull request, develop/master integration, tag or release action
is included.


## Reported regression repairs — 2026-10-17

This follow-up starts at the verified develop merge `92dd044f82d7f0add4ca5749b74252b5a677d8ee`
on `maintenance/upstream-v4.6.1-migration`. It preserves the upstream history and
updates this migration branch only.

The Android picker supplied both `.bsexport` and `.zip` to the upgraded plugin's
MIME filter. Android recognizes ZIP but cannot map the custom export extension,
so document providers excluded `.bsexport`. Export import now requests any Android
document and validates the selected extension using the existing localized
error. Other platforms retain their custom-extension filter. This changes file
selection, not container format or import persistence. The user independently
confirmed that a 4.6.1 export imports in 4.5.0.

Backup settings now uses the adaptive settings header as its only header,
labelled **Export & import**. Standalone uses retain their app bar; the settings
navigation category remains **Backup and Restore**.

The Danbooru vote repair protects newer local vote/favorite changes from stale
preload responses and fetches only entries still needing lookup. A controlled
preload/favorite/removal test reproduced a lost automatic upvote before the fix
and verifies lookup of the actual server vote ID before removal afterward. This
is a confirmed local race consistent with the intermittent toast, not proof that
every live Danbooru failure has the same cause.

GIF grid eligibility now follows the original format and API byte length. A
transcoded sample previously masked the original GIF format and bypassed the
5 MiB guard. Automatic now animates eligible GIFs at every grid size, as the user
explicitly requested on 2026-10-17; `decisions.md` P06 records that policy update.
Known original sizes must be positive and at most 5 MiB at every quality. Missing
or non-animated samples fall back to the eligible original. Still-image quality,
explicit viewers and downloads retain their own policies; no network size probes
or data migrations were added.

The user reported that reinstalling resolved the original whole-video freeze.
The newly reported details-panel reset had a separate reproducible lifecycle
cause: toggling viewer gestures inserted/removed a Semantics wrapper and disposed
the video child. Kurumi now keeps that wrapper stable while updating its semantic
actions. A stateful media regression fails before the repair and passes afterward,
retaining position and playback state through both panel transitions.

### Acceptance limits

Android document-provider selection, live Danbooru voting, and native MP4 playback
across the details panel still require user-run checks in
`MANUAL_ACCEPTANCE_CHECKLIST.md`. WebM and alternative playback engines remain
unverified on a device. These fixes and automated checks do not close the other
migration acceptance gates.

The backup destination was checked at 320 px and 200% text after opening it.
Starting the entire main-screen journey at those constraints also exposed an
existing overflow in the unchanged `post_list_configuration_header.dart` Row;
that listing-header issue is outside these reported regression repairs and is
not covered by a claim of complete responsive UI acceptance.

A bounded synthetic-media emulator probe did not complete: Maestro launch timed
out, and APK installs did not complete within their bounds. Package metadata
retained its prior update time, so no new installation was confirmed. The local
probe server and reverse port mapping were removed and the emulator lease was
released. The normal application Dev APK was rebuilt after the temporary probe
build. No physical phone was operated and no app data was cleared.


### Follow-up verification

The checked state is the runtime and tests in this follow-up commit, based on
`92dd044f82d7f0add4ca5749b74252b5a677d8ee`, with local develop still at
`d52b6694eb370a8099c820c397250b5199b0baa5`. Only this report was extended after
the complete pass; runtime, tests, dependencies and generated output did not
change afterward.

- `fvm dart format --output=none --set-exit-if-changed` on all 13 changed Dart
  files: exit 0, no changes.
- Final focused import, backup, GIF and vote checks: all 80 tests passed.
  The viewer lifecycle regression also passed with all 34 interactive-viewer
  tests. Broader viewer/video consumers ran during implementation and are
  included in the successful complete gate below.
- `./scripts/run_regression_tests.sh`: exit 0, all **3,794 application tests**,
  **1,024 tests across all 12 package/CLI suites** (including all 123 Kurumi
  tests), pull-request policy and Android release-script checks, and all
  **61 Python tooling tests** passed. Six detected physical cores were used;
  no suites or individual tests were skipped. An earlier complete run was
  interrupted to add the static-JPEG sample regression; the final complete
  run passed after that fix. Initial narrow-layout fixture failures were
  corrected before this final run.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings;
  177 informational diagnostics. Comparison with the previous merge analysis
  found no new diagnostics.
- `fvm flutter build apk --debug --flavor dev --no-pub`: exit 0 after the final
  runtime change, producing the normal application at
  `build/app/outputs/flutter-apk/app-dev-debug.apk`. Translation inputs did not
  change, so no new generation was required for this follow-up.
- Whitespace and unresolved-index/conflict-marker checks passed. Both original
  migration/develop tips and pinned upstream `5b04bf6a164f028d41701299367d0dde74dde330`
  remain ancestors.

Final logs are under `/tmp/migration-regressions-`: `full.log`,
`focused-final.log`, `video-green.log`, `analyze-final.log`, and `build-final.log`.
The migration worktree is retained; develop, remotes and release state are not
modified by this follow-up.


## Unfavorite vote synchronization and settings naming — 2026-10-17

This repair follows `c61324c93944f2ee5f6d8505141464cbad25a6bf`. The user supplied
a more precise sequence: favorite → automatic upvote → unfavorite → the upvote
still appears → manual vote removal fails. The earlier preload-race repair did
not cover this separate unfavorite transition.

[Danbooru's Favorite model](https://github.com/danbooru/danbooru/blob/master/app/models/favorite.rb)
invokes `unvote_post_on_destroy` after favorite deletion and soft-deletes the
user's positive vote. The application then redundantly looked up that vote for
another deletion. The server returned no active vote, so the notifier returned
false and retained the cached upvote. A later manual lookup also found no vote,
producing the reported failure despite the vote already being absent remotely.

Successful unfavoriting now mirrors Danbooru's acknowledged positive-vote removal
locally, without a vote lookup or second mutation. It preserves downvotes, as the
server does. The notifier caches the confirmed absence so a preload that started
before favorite/unfavorite cannot resurrect the upvote. Failed/cancelled/429
favorite deletions retain their existing state and interruption behavior.

Four regressions use the actual Danbooru client, favorite repository, vote
repository and notifiers against a controlled HTTP adapter reproducing the
server's callback. Before the fix, three failed: stale upvote after unfavorite,
unintended downvote removal, and stale-preload resurrection. The failed-unfavorite case
already passed. All four pass after the fix, including ordinary manual voting
and removal using the real server vote ID. Existing generic favorite interruption
coverage remains; Danbooru-specific expectations now assert no redundant cleanup
request after an acknowledged deletion.

Both the settings navigation entry and destination heading now use the same
localized title, whose English text is exactly **Export and Import**. The
separate header-title override is no longer needed. The route identifier stays
`backup_and_restore` for navigation compatibility. Translation generation passed.
The real settings-flow test checks both wide labels and the single visible label
at 320 px width and 200% text scale.

Live authenticated Danbooru UI acceptance remains user-run; no account mutations,
emulator actions or physical-device operations were performed for this repair.
The other migration acceptance limits above remain open.


### Unfavorite repair verification

The checked candidate is the runtime, English translation input and tests in
this follow-up commit, based on `c61324c93944f2ee5f6d8505141464cbad25a6bf`, with
develop at `d52b6694eb370a8099c820c397250b5199b0baa5`. Only documentation was
extended after the complete test pass.

- `./gen.sh i18n`: translation validation and generation passed.
- `fvm dart format --output=none --set-exit-if-changed` on all seven changed Dart
  files: exit 0, no changes.
- `fvm flutter test --no-pub --concurrency=6` with
  `test/boorus/danbooru_unfavorite_vote_test.dart`,
  `test/boorus/danbooru_vote_race_test.dart`, `test/core/posts/favorites`,
  `test/application/backup_restore_flow_test.dart`, and
  `test/core/backups/export_import/export_import_page_test.dart`: all 41 tests
  passed, including the constrained settings layout and exact English labels.
- `./scripts/run_regression_tests.sh`: exit 0, all **3,798 application tests**,
  **1,024 tests in all 12 package/CLI suites**, pull-request policy and Android
  release shell checks, and **61 Python tooling tests** passed. No test suites
  or individual tests were skipped; the default six physical cores were used.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings;
  the same 177 informational diagnostics as the preceding verified candidate.
- `fvm flutter build apk --debug --flavor dev --no-pub`: exit 0, updated normal
  Dev APK at `build/app/outputs/flutter-apk/app-dev-debug.apk`.
- Whitespace, unresolved-index and required ancestry checks passed. Develop is
  unchanged; only the migration branch is updated. No push or release action.

Logs: `/tmp/migration-unfavorite-{i18n,focused,full,analyze,build}.log`.
The pre-fix reproduction failures are in `/tmp/migration-unfavorite-red.log`.


## Favorite quick-action alignment — 2026-10-17

This repair follows `6b1012278d39061db2cedd7ce87f6fd93dcd7d28` on the existing
migration branch. The favorite widget calculated its transparent padding from
its preferred 48 px touch target even when `ThumbnailActionGroup` constrained
it to 33 px. That compressed the icon's layout box and moved its center 7.5 px
right and down relative to the circular background.

The widget now derives its top/left padding from the actual layout constraints.
The existing 20 px icon, 24 px circle, bottom/right inset, animation and async
favorite flow are retained. The padding remains interactive; unconstrained
standalone favorites retain their 48 px touch target.

Six widget regressions cover unselected/selected states in single, horizontal
and vertical action groups at 200% text scale. All six reproduced the offset
before the fix. They now verify matching centers before, during and after the
animation, padding taps and separate neighboring actions. Existing coverage
also checks the standalone touch target, narrow thumbnails, interrupted actions
and ordinary post taps. The focused overlay/grid/configuration/bookmark/favorite
consumer run passed all 59 tests.

The widget review sheet includes a compact grouped favorite and was rendered to
`/tmp/migration-favorite-alignment.png` and visually inspected. This is controlled
widget rendering, not a device screenshot. No emulator, phone or live account
was operated. The previously open manual migration acceptance remains open.


### Favorite alignment verification

The checked runtime and tests are in this follow-up commit, based on
`6b1012278d39061db2cedd7ce87f6fd93dcd7d28`, with develop unchanged at
`d52b6694eb370a8099c820c397250b5199b0baa5`. Only this report was extended after
the complete pass.

- `fvm dart format --output=none --set-exit-if-changed` on both changed Dart
  files: exit 0, no changes.
- `fvm flutter test --no-pub --concurrency=6` with the thumbnail overlay,
  shared post-grid, thumbnail action configuration, bookmark button layout and
  favorite consumer tests: all **59 tests passed**. The review-sheet run used
  `--dart-define=POST_010_CAPTURE_PATH=/tmp/migration-favorite-alignment.png`.
- `./scripts/run_regression_tests.sh`: exit 0, all **3,804 application tests**,
  **1,024 tests across all 12 package/CLI suites**, repository shell checks and
  **61 Python tooling tests** passed. No suites or individual tests were skipped;
  the default six physical cores were used.
- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or warnings;
  177 informational diagnostics, with no new diagnostics compared to the
  preceding verified candidate.
- `fvm flutter build apk --debug --flavor dev --no-pub`: exit 0 on the final
  source, producing `build/app/outputs/flutter-apk/app-dev-debug.apk`.
- Whitespace, unresolved-index and required ancestry checks passed. No new
  generation was needed because no generation inputs changed.

Logs are under `/tmp/migration-favorite-alignment-`: `red.log`, `focused.log`,
`full.log`, `analyze-final.log`, and `build-final.log`. The interrupted focused
run was restarted; the completed run and final complete gate both passed.
The migration worktree is retained. Develop, the primary checkout, remotes and
release state are not changed by this repair.
