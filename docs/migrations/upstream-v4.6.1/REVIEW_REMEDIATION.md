# Consolidated review remediation

Review baseline: `49f2b9ade`, branch `maintenance/upstream-v4.6.1-migration`.
The three supplied reports consolidate into 21 actionable items, plus one
explicitly conditional concern. Repeated mentions are one item, not additional
independent defects. The original implementation report's 68/68 completeness
claim is superseded by this reconciliation.

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
| 20 | B10 / R3 | Confirmed acceptance violation, not a demonstrated endpoint failure: the new listing host was enabled without the required live matrix. Restore the established relative XML listing endpoint and default parser; keep the existing details/autocomplete endpoints. The generated configuration reflects this. Activation remains gated on targeted authenticated/unauthenticated live checks. |
| 21 | Documentation / all | Confirmed `git diff --check e8bf883 -- docs/migrations/upstream-v4.6.1` reported handoff trailing whitespace and the catalog's extra EOF line. Remove those whitespace defects. |

## Conditional concern

R3 explicitly excluded mixed-origin quick actions from its confirmed findings.
The current bookmark builder (`bookmark_scroll_view.dart`) and Following feed
builder (`topic_feeds_page.dart`) resolve each post's origin and pass that
profile's auth to `DefaultImageGridItem`. The generic grid uses the selected
profile, but no currently affected mixed-origin use of that default builder was
established. No speculative behavior change was made for this concern.

## Verification

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
Installed upgrade/signing acceptance, live authenticated service checks, and
Windows/macOS/iOS native execution remain unverified. Linux atomic sidecar
publication is exercised locally; other platform implementations require native
acceptance.
The gated Rule34 listing switch remains deferred. Local fixes do not authorize
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

### Outstanding live acceptance

Authenticated list/details, pagination, filter/limit semantics, successful
challenge completion, cookie origin/path/transport isolation, and cache
isolation remain open. Automatic approval review rejected transmitting the
stored Rule34 test user ID/API key to the external API without explicit approval
for that payload/destination. Approval was requested; the authenticated probe
was not run. The emulator contained no pre-signed-in Boorusama account.

No runtime files changed for this verification. The complete local suite result
above remains applicable to the same runtime candidate. These observations do
not activate B10 or establish production-signed upgrades, other ABIs, enlarged
text/narrow-width acceptance, native sidecar publication, or the remaining media
and download checklist.
