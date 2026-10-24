# Local handoff: expanded search options follow-up

Issue: https://github.com/timberpile/Boorusama/issues/71
Branch: `feature/71-search-options`
Continuation base: `164836decb393845ccbfb53c736d95b667fccc6b`
Latest runtime commit reviewed remotely: `8a1744b53f30fb9a058f6063a6de1a6c807a89d2`

## Status and scope

This is a published implementation draft, **not integration-ready**. The user
requested topmost-modal Android Back behavior, graphical Danbooru options,
username suggestions and comprehensive per-site search coverage. Substantial
parts are implemented; the all-sites/all-filters requirement is still partial.
The remaining work includes functional integration and coverage, not merely
syntax fixes. The issue must stay open.

Continue the existing branch/worktree. Read current `AGENTS.md`, the relevant
repository skills, development/issue workflow and engineering guidelines.
Preserve unrelated changes. Do not merge, open a PR or close the issue. The user
explicitly authorized checkpoint publication on this branch; publish each
completed feature/fix batch and verify its remote SHA before proceeding. Do
not force-push over another agent's changes.

The starting branch already contained six draft commits after the local agent's
previously verified `981e7358e0673eba38395ba158c29da649a2c52c`. Those drafts were
inspected rather than assumed lost or silently overwritten. Review the entire
`981e7358..HEAD` follow-up in addition to this continuation's `164836d..HEAD`.
The earlier `verification.md` passes do NOT verify this follow-up.

## Published feature checkpoints

All checkpoints below were published with an expected-tip guard and read back
from the GitHub branch reference. The final handoff commit adds documentation
on top of this runtime state; inspect the actual branch HEAD before starting.

| Commit | Scope |
| --- | --- |
| `fac63f4d3e5d5af1c703b6b1966da8b28b327084` | Catalog Back handling and stacked modal test |
| `7e983585c4d886736ff6db1df6d47f5b40ddc6b0` | e621/Moebooru user and Szurubooru user/pool suggestions |
| `8bc2835c27edba53b97bb91d38d36c328468469c` | Szurubooru typed catalog and serializer |
| `976dce1d7108ef97e67fa78e09930625855ebb5b` | Paheal catalog and native comparison editing |
| `463236e5370a4400075cd3ab9d8b5766bcb6a7be` | Philomena fields and API sorting |
| `c014e7a2549cae410fb9e1ce99322289883ac25e` | Rule34-specific ratios, domain search and random ordering |
| `a14ff4ee8f6b6e21a7599109fdc9265ed5ebefa4` | Hybooru and preservation of typed serializer behavior |
| `3ca93d92c50293e76e9e6fa55cb26077dd35c1c7` | Nozomi Date/Popular in shared options |
| `50ead882d28ea3219f7b5a06f9c91a9df57b43c5` | Danbooru range exclusion and exclusive ordering |
| `8e5a82e3b4ad68e7da235bb9d753ee461dc8299a` | Hydrus numeric/date/media predicates |
| `e0670fb7073cd913ae482cf2c16cf5011f183689` | Existing e-shuushuu/Anime-Pictures account API filters |
| `b71b0684c34639c08ed823acb3384c3fc8b665ad` | Relationship validation, valid defaults, sheet bounds and test corrections |
| `8a12ebf035d2496efeb3d88667d2aa6e5ef0cc14` | Translation lookup and pending English/German manifests |
| `8a1744b53f30fb9a058f6063a6de1a6c807a89d2` | e621 exact IDs/ranges and Szurubooru semantic labels |

## Setup and verification actually performed

No checkout was available in the remote execution environment. A read-only
clone attempt failed due to DNS; the connected GitHub API was used for scoped
branch edits. No claim of a clean local worktree is made. `fvm` is absent;
`fvm flutter test --no-pub test/core/search/options` exits 127 with command not
found. Flutter tests, Dart formatting/analysis, generation, builds, emulator,
CI and live authenticated post searches were NOT executed here.

Actual checks: primary-source/client inspection, repeated manual source review,
CAS publication/read-back, commit comparison, and Python parsing/key parity of
the two localization manifests. Each locale contains 287 nonempty values.
The compact validated manifest bytes match these published Git blobs:

- English: `bfbbb7ef757c8274f2700cde1d8b738bb51edf5f`
- German: `7360f40a0507f39b93db8a7bfbee9bb49ffd82cc`

Fourteen application test files and one booru_clients HTTP-parameter test were
added during this continuation. They are uncompiled source, not passing test
evidence. Existing earlier follow-up tests also require execution. Correct
actual defects rather than weakening assertions to match incorrect behavior.

## First local steps

Fetch the branch and inspect worktree status. Continue its existing isolated
worktree or attach a new one if none exists. Never reset/stash unrelated edits.
Record the starting SHA. Install the pinned SDK/dependencies with FVM and apply
only the NEW coverage manifests:

```bash
fvm flutter pub get
(cd packages/boorusama_cli && fvm dart pub get)
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-en-US.json --dry-run --diff
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-en-US.json
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-de-DE.json --dry-run --diff
fvm dart run i18n_cli:booru_i18n apply docs/handoffs/71-search-options/coverage-de-DE.json
./gen.sh i18n
```

If `search_options.ext` already exists locally, reconcile children instead of
blindly overwriting it. Do not reapply the old `i18n-en-US.json`/`i18n-de-DE.json`
from the first implementation; the previous local agent already applied those.
Commit the real locale changes. Review additional e621-specific/role-restricted
labels (for example `restricted_user`) that still fall back to native syntax.
The manifests are not a permanent installation step and the UI is not fully
localized before they are applied/generated.

Format all affected Dart files and run analysis. Suggested commands in Bash:

```bash
base=981e7358e0673eba38395ba158c29da649a2c52c
git diff --name-only -z "$base" HEAD -- '*.dart' | xargs -0 fvm dart format
fvm flutter analyze
test_workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$test_workers" test/core/search/options
fvm flutter test --no-pub "--concurrency=$test_workers" \
  test/core/search/search_profile_switch_test.dart \
  test/core/search/navigation_search_profile_test.dart \
  test/core/search/search_history_profile_test.dart test/metatag_regex_test.dart
./scripts/run_regression_tests.sh
git diff --check
```

The full runner is required because shared query/controller behavior and a
local package changed. Ensure it includes the complete booru_clients suite and
all application/package/CLI/tooling suites. Add directly affected consumer
checks where existing discovery is insufficient. A pass before a relevant
runtime/test change is not a final-candidate pass.

## Review priorities and concrete acceptance

### Modal ownership and draft state

Exercise the actual search-option sheet, options/pin catalog and nested calendar
with Android system Back. Each press must dismiss only the top layer; Cancel
must not mutate query or close Advanced Search. Test keyboard open/closed,
focus restoration and Back during route transitions. The existing
`SearchModalBackHandler` handles root-modal priority over nested search; the new
catalog wrapper and stacked test cover the missing catalog case. A source/test
review is not a device reproduction.

At 320 dp and at least 2x text, test vertical scrolling, horizontal quick choices,
Apply/Cancel reachability, top/bottom search-bar placement, large keyboards and
calendar dates outside the picker bounds. Check IME composition, invalid units,
empty drafts, quick-choice changes and selected-item cancellation.

### Entity suggestions

Danbooru uses its native entity autocomplete. e621 and Moebooru have explicit
username endpoints; Szurubooru supports users and pool names resolving to IDs.
Check that the selected profile's auth/transport is used; test two profiles with
identical query text, rapid edits, dismissal during fetch, old-response ordering,
forbidden/private results, no matches and endpoint failures. No ordinary tag
result may become a username. Selecting a result only changes the sheet draft;
only Apply commits. Manual entry must remain usable when lookup is unavailable.

Existing parser tests do not replace async-provider and actual HTTP-interceptor
coverage for every new endpoint. Add those deterministic tests using completion
signals/fake time rather than host-speed sleeps.

### Serialization and API boundaries

Check each catalog's generated request, not just the chip text. Rule34's
fractional ratio has 3% tolerance; its decimal ratio filter is distinct. Parent
and user IDs are exact where required. Danbooru age/score range exclusion and
ordering-family replacement must preserve unrelated raw items. Verify e621
KB/MB units, private favorites/votes and staff-only filters with real account
permissions. Role-aware visibility is not yet implemented.

Szurubooru uses inclusive ranges and comma sort directions; Paheal uses equals
and direct comparisons; Philomena uses comparator suffixes and API sf/sd.
Hydrus never accepts `-system:` and only some predicates accept <=/>=.
Hybooru ratings are numeric service ratings, not safety classifications.
Verify native date timezone/day semantics rather than equating them across
engines. Native `limit` may interact with client/API page limits and needs
explicit pagination acceptance; do not claim equivalent behavior unchecked.

Philomena's native q must preserve underscores in field names/URLs while plain
tag names still use spaces. Nozomi ordering must select the post index without
becoming a tag. e-shuushuu/Anime-Pictures account filters must become API
parameters, never tag lookup terms. Verify first-page reset, old-request
cancellation, results/count agreement and no duplicate refresh on confirmed
mutation. The previous e-shuushuu resolver's partial/fuzzy behavior was not
redesigned in this work.

### Known functional compatibility work

Only recognized standalone adapter directives are consumed. Opaque raw queries
are preserved, but a flattened raw query containing an app-only sort/account
directive is not generally reconstructed into API parameters. Audit **History,
share links, Follow/Topics, favorites, profile snapshots and restoration** end
to end. Preserve typed structure where available; implement a deliberately
scoped parser or explicit representation for adapter metadata where necessary.
Do not silently drop directives, split arbitrary quoted/Boolean raw syntax or
claim native-only wire strings support these extra parameters. This remains
an acceptance blocker, not a syntax-error task.

## Coverage still missing

Read [the complete site matrix](../../designs/search-option-coverage.md).
Thirteen engine families have at least partial guided controls. The full user
request remains unfinished in these specific areas:

- Rule34: ratio and exact source-domain predicates remain unavailable through
  the observed authenticated API; known matching posts return empty. Guided
  controls are omitted, with verified native source URL patterns offered instead.
- Pixiv: wire existing target/sort/duration/date parameters with explicit user
  scope versus text-search validation and account entitlement handling. The
  current user endpoint ignores text, so exposing freely composable filters
  without this work is incorrect.
- Zerochan/Asiachan: recency/popularity exist in the client only for nonempty tag
  searches. Add query-aware applicability and an adapter; do not show a control
  that the client ignores on the global feed.
- Sankaku variants: establish current official/authenticated syntax and account
  restrictions. Do not assume Danbooru equivalence from similar tag names.
- Gelbooru 0.1: establish the current legacy host grammar before assigning a
  modern catalog. Unknown custom hosts are not automatically certified.
- Hydrus: instance-specific services/ratings/domains, unary predicates,
  duplicate/similarity/regex/URL conditions and sorting need further work.
- Anime-Pictures/e-shuushuu: only existing account API parameters are connected;
  other web/API filters still require verified mappings and typed controls.
- Every engine: finish role/version-aware visibility where restrictions matter,
  advanced compound/quoted text value editors where useful, raw adapter
  round-trips and any untranslated site-specific labels.

Source links and per-batch findings are in the matrix and adjacent notes:
`entity-endpoints.md`, `szurubooru.md`, `native-dialects.md`, `philomena.md`,
`rule34.md`, `hybooru.md`, `nozomi.md`, `hydrus.md`, `api-user-filters.md`,
`danbooru-semantics.md`, `e621-review.md`, `review-corrections.md` and
`localization.md`. They are evidence/implementation notes, not a parallel task
tracker. GitHub #71 remains the task authority.

## Completion reporting

Commit and publish coherent corrections on the same branch, with `Refs #71`,
and read back the remote SHA after every substantive batch. Review the whole
follow-up diff and repeat corrections/checks. Before any eventual integration,
run the complete suite on the combined final candidate and obtain merge
approval. Device checks use the repository's emulator lease and Maestro rules;
never expose test credentials. Record actual commands, source SHA, results,
skips and remaining limits. Do not reuse historical passing numbers as evidence
for this code or describe remaining feature work as mere local syntax cleanup.

## Priority Gelbooru and Realbooru follow-up (2026-10-23)

Current branch contains further issue #71 checkpoints beyond the historical
runtime SHA above. See docs/handoffs/71-search-options/realbooru.md for the
independently researched Realbooru semantics and live acceptance queries.
The current branch head, not the older SHA table, is the handoff source.

- b710365: shared site-aware sort choices (no duplicate Quick Choices)
- 56e7a6e: corresponding native metatag recognition/highlighting
- b97876e: four-profile compatibility tests and official site evidence
- 251235c: corrected a malformed source transformation before verification

Realbooru's current cheatsheet confirms the nine common legacy options;
it does not authorize Rule34-only ratio/domain/random controls. Gelbooru.com
has a separate seeded-random variant; its graphical editor still offers only
unseeded random, while manual seeded syntax is recognized. Username autocomplete
for these four priority sites is intentionally deferred at the user's request.

No live API results could be retrieved through the remote browser, and FVM
remains unavailable. This follow-up has not passed Flutter tests, format,
analysis, emulator or regression. Run the added provider/serializer tests,
the full suite and actual four-site Maestro/API acceptance before integration.

## Local continuation checkpoint (2026-10-23)

Fetched origin and fast-forwarded the existing isolated worktree from
`981e7358` to the requested `3bc5067696178150cf1056bbf0b1a652e70d116e`.
Applied both new coverage manifests (287 values each), generated i18n and
formatted all 60 original follow-up Dart files. Corrected the two parameter
assignment analysis errors and new-scope lint diagnostics. Updated obsolete
random-sort/score-exclusion expectations and made narrow-layout scrolling
scale with the expanded catalog rather than the old small list.

Fixed flattened raw-query adapter directives for Philomena sorting, Nozomi
index ordering and Anime-Pictures/e-shuushuu account IDs. The bounded scanner
extracts only supported top-level tokens; quoted, escaped, grouped, malformed
and unknown syntax is retained. Remaining native text is not split into tags.
Added regression cases for these flattened query paths.

Checks at this checkpoint: `fvm flutter test --no-pub --concurrency=6
test/core/search/options` passed 114 tests; the separately repeated original
serializer/layout files passed 14 tests. Full-project analysis reported only
informational diagnostics (3007 before the last scoped lint correction), no
warnings/errors. Final scoped analysis, complete suite, final-source APK/device
acceptance, the rest of the full diff review and authenticated live-site
checks are still pending. Initial API probes show Rule34 requires credentials,
Gelbooru rejects anonymous DAPI requests, and Realbooru returns XML
`success=false` explicitly stating its API is shut down indefinitely. These
responses are availability limits, not search-filter passes.


### Localization and accessibility correction

The catalog audit found 34 missing field labels and nine missing descriptions
in each applied locale, including restricted-user guidance. Added them in
English/German and a catalog-wide declared-label/description regression test.
Added a localized calendar-button tooltip so the date picker is accessible
without relying on an unlabeled icon. Regenerated i18n. The options suite now
passes 115 tests; affected analysis has no issues. The prior complete-run
candidate is still running and is not final-source evidence after this change.

Device checks so far: keyboard appears from Browse; opening Advanced Search
hides it; Back dismisses the catalog and value sheet individually. The actual
nested calendar Back sequence preserves its parent sheet and Advanced Search.
Maestro selector failures were corrected using the live combined accessibility
labels; they were not treated as app defects. Final-source installation and
narrow/large-text acceptance remain pending.


### Calendar readability correction

Actual 320 dp Android screenshots at 2x system font exposed truncated two-digit
calendar days. Limit text scaling only inside the framework's fixed seven-column
calendar to 1.3x; the option editor retains the user's full scaling. This is an
intentional local exception to normal text scaling because otherwise days such
as 10/11/12 become visually indistinguishable. Added a widget regression with
the SDK Roboto font that measures the full width of day 31 against its cell,
plus Back/cancellation assertions. The test passes; affected analysis has no
issues and the Android APK builds. Repeat full regression/device checks on this
candidate rather than reusing the earlier complete pass.


## Local validation report (2026-10-23)

Runtime candidate: `cfd53476bb90343eb6b282277d66d41cac0be4dc`.
Runtime/test tree before report-only edits:
`e55cf2f67860942c33bd95afef30f5c5951934aa`.
Checkpoints `3f9dbfce2`, `dc2a611eb`, and `cfd53476b` were pushed normally to
`origin/feature/71-search-options`; each remote reference was read back and
matched. No PR, develop integration or issue closure was performed.

### Review and corrections

Reviewed the complete `981e7358..HEAD` follow-up across catalogs, validation,
serializers, FREE wrappers, host-specific extraction/highlighting, request
adapters, modal ownership, controller replacement/refresh and their tests.
Checked history, Topic, sharing and profile-switch consumers. Repeated review
after the raw-adapter and calendar corrections found no additional confirmed
code defects within this implemented scope. Deployment/account acceptance and
the coverage gaps below remain distinct from static/runtime test results.

- Applied new en-US/de-DE manifests before generation. Added the missing 34
  labels/nine descriptions per locale and calendar action text; all declared
  labels/descriptions now have English/German catalog coverage.
- Fixed two parameter-assignment errors, changed-scope lint diagnostics,
  obsolete sort/exclusion expectations and catalog-sized layout-test scrolling.
- Restored supported API directives in flattened raw queries without splitting
  the remaining native expression or consuming quoted/grouped/invalid tokens.
- Made the calendar action accessible and fixed clipped two-digit days at
  320 dp/2x text. The calendar alone caps scaling at 1.3x; other controls retain
  system text scaling. The real-font width regression also checks cancellation.

### Automation

Setup: `fvm flutter pub get`; CLI dependency setup; documented i18n apply/dry-run
commands for both coverage manifests; `./gen.sh i18n` (repeated only after the
additional locale inputs changed). Generation validation succeeded.

- All 64 changed Dart files: `fvm dart format --output=none
  --set-exit-if-changed` reports zero changes; scoped `fvm flutter analyze
  --no-pub` reports no issues.
- Repository-wide `fvm flutter analyze --no-pub`: exit 1 solely due to
  3006 informational diagnostics, zero errors/warnings. All diagnostic paths
  are outside the changed Dart scope. This is not a clean default repository
  analysis pass. A separate `fvm flutter analyze --no-pub --no-fatal-infos` run exits 0,
  retaining all informational output while checking errors/warnings.
- Direct options suite: 115 passes after localization; the subsequently added
  real-font calendar regression passes separately. The full final suite below
  covers all of them together, plus history/profile/Topics/sharing consumers.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64
  --no-pub`: successful, repeated unchanged. The final confirmation build
  completed without the recurring native-hook rebuild warning. Existing Kotlin
  version deprecation advice remains unrelated to this task.
- `./scripts/run_regression_tests.sh` on the final runtime candidate: exit 0.
  Application 4581; packages: booru_clients 105, boorusama_cli 254,
  cache_manager 59, coreutils 191, dtext 59, extended_image 47,
  filename_generator 31, flutter_sqlite3_migration 45, foundation 65,
  go_router 436, i18n_cli 32, kurumi 133, retriable 16. Total 6054 passes.
  Two pre-existing explicit `skip: true` GoRouter cases remain skipped.
  Pull-request policy and Android release shell checks pass; Python tooling
  passes 72 tests. Default detected concurrency is six physical cores.
  Full log: `/tmp/71-followup-regression-calendar-final.log`. Earlier complete
  passes were repeated after each subsequent runtime correction.
- `git diff --check 981e7358 HEAD`: clean.

### Android acceptance

Exclusively leased `emulator-5554`, Android x86_64. Installed the current-source
dev APK without clearing app data. The installed and local APK SHA-256 both are
`929d723a1d69a96a80cdb819ac13b1f52410ebb4267dc4630a9efc90fb5972d2`.

Maestro exercised normal width and 320 dp (`640x1280`, density 320), system font
1.0/2.0, keyboard entry, Advanced Search hiding the keyboard, ordinary tag
suggestions, manual `one piece` plus Enter returning results, applying a quick
age filter closing Advanced Search/updating results, Include/Exclude preview,
catalog/value-sheet navigation and the actual nested calendar. Back cancels the
topmost layer and preserves its parent/draft. Browse remains interactive after
hiding the keyboard (Menu can be opened). Large-text calendar screenshots were
reviewed before and after the fix; all days are now readable. Catalog and Apply
controls remain above the Android navigation area, with scrolling available.
Initial failed Maestro selectors were corrected against live accessibility
labels; successful flows, not those failed attempts, support the claims above.

Local screenshot evidence (not fixtures):
`/tmp/71-followup-final-keyboard.png`,
`/tmp/71-followup-narrow-options.png`,
`/tmp/71-followup-narrow-catalog.png`,
`/tmp/71-followup-narrow-calendar.png` (before fix),
`/tmp/71-followup-narrow-calendar-fixed.png`,
`/tmp/71-followup-narrow-autocomplete.png`,
`/tmp/71-followup-narrow-typed-results.png`,
`/tmp/71-followup-narrow-filter-results.png`,
`/tmp/71-followup-narrow-exclude-score.png`.
Restored physical `720x1600` without override and font scale `1.0`; relaunched
Browse and released the lease. No stored profiles or credentials were reset. A second exclusive lease was
claimed for the Gelbooru combined-query smoke check described below; it used
the existing profile and did not change device display settings. Returned to
Browse, rechecked 720x1600/font 1.0 and released this second lease too. Additional
screenshot: `/tmp/71-followup-gelbooru-combined-results.png`.

### Live service results and remaining gates

Live requests used actual server responses, not HTTP status alone. Only metadata
was checked; no credentials appear in test fixtures, committed reports or logs.

| Site/channel | Actual evidence | Limit |
| --- | --- | --- |
| Danbooru anonymous post API | 30 nonempty matching rows each for `rating:g`, `-rating:q`, `age:<7d`, `age:>5y`, `score:>=10`, `score:10..20`, `-score:10..20`, `width:1000..2000`, and `one_piece rating:g score:>=10`. Checked each returned rating/score/date/dimension/tag. `one_piece order:score` returned ten scores in descending order. Tag autocomplete `one_pie` returned five suggestions including `one_piece`. | Global `order:score` and `rating:g order:score` repeatedly return HTTP 500; global sorting acceptance remains open despite valid syntax and successful tag-scoped sorting. |
| Gelbooru.com anonymous web search | Parsed 42 post metadata rows per query: all four current ratings, rating exclusion, `score:>=10`, combined `one_piece rating:general score:>=10`, and descending score order pass. Rating ascending begins with explicit, descending with sensitive as its native alphabetical values dictate. Two unseeded random requests return different IDs; combined `one_piece rating:general sort:random` retains both filters in all 42 rows. Normal tag autocomplete returns ten JSON suggestions including `one_piece`. | Anonymous DAPI returns HTTP 401. A separately leased final-source Maestro run in the existing Gelbooru profile executes `one_piece rating:general score:>=10 sort:score:desc` through the raw-suggestion row, returns 2757 Results and opens a result whose actual tag list contains `one piece`. Per-row rating/score predicates were independently checked on the web response; this is not a dump/certification of every authenticated API row. Seeded-random requests return posts, but repeated IDs changed while the dataset was changing; deterministic replay is not certified. |
| Rule34.xxx | The user subsequently approved the API credential use. Authenticated listings validate questionable/explicit ratings, rating exclusion, score thresholds, ascending/descending score and ascending ID order, changing random results, combined `one_piece` queries and normal tag autocomplete. Known-post controls verify native `source:` URL patterns and show the documented ratio/domain predicates return empty for a matching post. | Removed those incompatible predicates from the guided API catalog/extractor and exposed native source URL filtering. `rating:safe` has no positive match and returns a valid empty response. See `rule34.md` for actual predicates and controls; the earlier authorization blocker is resolved. |
| Realbooru | Official syntax and serializer/provider tests cover its legacy rating/score/dimensions/user/parent and rating/parent sorts. Web listing responds; ordinary autocomplete returns ten JSON suggestions including `one_piece`. | Post API returns HTTP 200 XML `success=false`, explicitly saying it is shut down indefinitely. None of its post-result filters is certified through the app/API. Its existing post-ID metatag is still undocumented/unverified. |

Sanitized local evidence: `/tmp/71-danbooru-live.jsonl`,
`/tmp/71-gelbooru-html-live.jsonl`; additional sorting/autocomplete checks were
recorded in command output. Username autocomplete for Gelbooru/Rule34/Realbooru
remains explicitly out of scope. No Gelbooru credentials were sent by host probes.

The existing all-sites coverage gaps (Pixiv, Zerochan/Asiachan, Sankaku, Gelbooru
0.1, instance-specific Hydrus and role/version constraints) are not silently
closed by this validation pass. Issue #71 remains open; the priority-site live
limits above prevent claiming complete acceptance or readiness to integrate.


## Rule34 authorized live follow-up (2026-10-23)

Starting checkpoint: `e97c0dd92969b4304bc937ba2cbbf3a61a5de12a` (clean existing
worktree, fetched origin, no divergence). The user explicitly authorized the
local Rule34 test API credentials for `api.rule34.xxx`; no other credential
scope changed. The prior automatic-review rejection is resolved by this new
authorization. See `rule34.md` for sanitized live evidence and the deterministic
known-post controls behind the catalog correction.

Found and corrected an actual API capability mismatch: website-documented
`aspectratio`, `aspectratiof` and `sourcedomains` all return empty for known
matching posts. They are no longer offered or recognized as supported API
metatags. The verified `source:` URL/pattern control is offered instead, without
pretending it implements exact domain semantics. Existing raw input/history and
pins are preserved. Other hosts keep their existing capabilities. No locale
inputs changed, so generation is unnecessary.

Targeted tests/analysis and final regression/build/device results are recorded
below after completion. The earlier 6054-test pass remains historical evidence
for `cfd53476b`, not qualification of this correction. No PR, develop merge or
issue closure is authorized/performed.


### Rule34 correction verification

Runtime checkpoint: `8743a087a26c7ea6224d957946939b4d60795148`, normally pushed
to the existing branch and verified against the remote SHA. Subsequent changes
in this report are documentation only.

- `fvm flutter test --no-pub --concurrency=6 test/core/search/options
  test/metatag_regex_test.dart`: 132 passes.
- All 64 follow-up Dart files: formatting check reports zero changes; scoped
  `fvm flutter analyze --no-pub` reports no issues. No i18n generation was
  required because all labels/descriptions already exist.
- The dev x86_64 APK builds; a repeated unchanged build completes without the
  native-hook rebuild warning. Installed it on exclusively leased
  `emulator-5554` without clearing data. Installed/local SHA-256 both equal
  `91300482c720167b333b05bcc47b6c3db0010d38618af91d0d8a28986de5aecc`.
- A successful current-APK Maestro flow confirms keyboard entry, Advanced
  Search hiding the keyboard and catalog Back ownership. The common UI is
  unchanged by this capability-only correction; the previous narrow/2x checks
  remain evidence for those widgets. No Rule34 profile was created or its
  credentials stored in Android: its site-specific verification uses the
  authorized host API and real-profile catalog/provider tests.
- An initial startup attempt overlapped installation and was discarded.
  Cold-launch cleanup assertions timed out before Browse became visible;
  subsequent live hierarchy inspection showed Browse. An optional repeated
  final Browse assertion was rejected by automatic review on the stated grounds
  that the lease had already been released. The immediately preceding renewal
  succeeded; the rejected UI call was not executed or retried. Prior successful
  flow/hierarchy evidence is retained, and the separate APK hash/settings
  verification renewed the lease before each read and completed normally.
  Physical size 720x1600/font 1.0 were unchanged. The lease was released;
  `emulator_lease.py status emulator-5554` reports available.
- Additional API source checks: `source:*subscribestar.art*` returns 30 rows
  whose source contains that hostname; the combined `one_piece
  rating:questionable score:>=10 source:*subscribestar.art*` returns three rows
  satisfying every predicate. Source pattern semantics deliberately do not
  pretend to implement the unavailable exact-domain operator.
- `./scripts/run_regression_tests.sh` on runtime checkpoint `8743a087a`:
  completed with exit 0. Application 4581 plus 1473 package/CLI passes equals
  6054 Dart/Flutter passes; the same two existing GoRouter skips remain.
  All PR-policy/Android-release shell checks and 72 Python tooling tests pass.
  Default concurrency is six detected physical cores. This complete pass
  supersedes the earlier runtime candidate's qualification; subsequent edits
  touch only documentation. Re-review found no further confirmed code defects.
- `git diff --check` and local Markdown link-target checks pass. The existing
  repository-wide 3006 informational analyzer diagnostics remain outside the
  changed scope; the 64 changed Dart files have no diagnostics.

Logs: `/tmp/71-rule34-capabilities-tests.log`,
`/tmp/71-rule34-analysis-final.log`, `/tmp/71-rule34-format-final.log`,
`/tmp/71-rule34-build-confirmed.log`, `/tmp/71-rule34-regression-final.log`,
`/tmp/71-rule34-source-listing.jsonl`.
Screenshot: `/tmp/71-rule34-current-apk-options.png` (common search UI).
The original Danbooru/Realbooru live limits remain; Rule34 ratio/domain support
is an explicit API capability gap, and a positive Safe rating remains unproved.

### Dialog spacing follow-up

The Uploaded screenshot exposed touching chip rows after compact chip styling
removed Material's implicit vertical padding. Restore explicit 6 px gaps after
Include/Exclude, between quick choices and comparisons, and between value fields
and their unit choices (including the second range bound). This matches the
existing horizontal choice gap. Keep the existing 12 px comparison-to-field
spacing and the compact timeline cards unchanged. No localization or generated
inputs change.

Verification on the two-file runtime change above `8207cb399`:

- `fvm dart format` on both changed Dart files: zero further changes.
- Scoped `fvm flutter analyze --no-pub`: no issues.
- `fvm flutter test --no-pub --concurrency=6 test/core/search/options`: 116
  passes, including 320 px width, 2x text, keyboard-open cancellation,
  Uploaded months/years, safe-area actions, and horizontal scrolling.
- Both the initial run and an unchanged repeat completed with 116 passes and
  exit 0. Both emitted the known `File modified during build. Build must be
  rerun.` native-hook warning documented in `docs/build_troubleshooting.md`;
  no tracked generated output changed.
- Diff review and `git diff --check` pass. This scoped spacing follow-up uses
  widget coverage; the complete repository suite, APK build, device checks and
  live-site checks were not repeated. Earlier full/device/live results remain
  historical evidence for their recorded runtime checkpoints.

### Search-option discovery follow-up

Replace prefix-only option discovery with case-insensitive partial-word matching
against localized titles and native syntax keys. All entered words must match;
their order may differ, and spaces, underscores and hyphens are equivalent
separators. Rank exact matches first, then prefixes, then other matches, preferring
shorter titles within each group and preserving catalog order for ties. This
keeps `Tag count` visible among the three option suggestions for `count` rather
than burying it beneath specialized counters. This is substring/token matching,
not typo correction. Exclude unsupported negations before limiting suggestions.
Tag autocomplete, raw fallback and completed `key:value` handling retain their
existing behavior. No localization or generated inputs change.

Verification above `7cf0e0c11`:

- Five new unit/widget checks cover ranking, partial words, reordered words,
  separators, case, title/key matching, empty/unmatched input, and actual
  Danbooru `count`/`COUNT ta`/`-count` suggestion selection to canonical syntax.
- The complete search-option group passes 121 tests with
  `fvm flutter test --no-pub --concurrency=6 test/core/search/options`.
  Its known native-hook warning is described in `docs/build_troubleshooting.md`.
- All three changed Dart files pass formatting and scoped analysis; diff review
  and `git diff --check` pass.
- Full repository, APK, device and live-service checks were not repeated for
  this local matching change; earlier results remain tied to their recorded
  runtime checkpoints.

### Preferred filter names follow-up

Danbooru implements `pixiv` and `pixiv_id` in the same predicate branch. Keep
the explicit `pixiv_id` spelling in discovery surfaces. An explicit engine-scoped
alias map also consolidates 19 plural count synonyms into the parser's `_count`
fields, `comm` into `commenter`, and `artcomm` into `commentaryupdater`: 22 hidden
Danbooru aliases in total. e621 consolidates 14 aliases for file type, commenters,
favorites, flaggers, votes and parent/child booleans into its primary parser
names. Prefer explicit/native parser names; this is an application convention,
not a claim that upstream deprecates the other spellings.

Primary evidence checked during this follow-up:

- [Danbooru predicate dispatch](https://github.com/danbooru/danbooru/blob/master/app/models/post.rb)
  (`pixiv`/`pixiv_id`, commenters and commentary updaters).
- [Danbooru count vocabulary](https://github.com/danbooru/danbooru/blob/master/app/logical/post_query_builder.rb)
  (`COUNT_METATAGS` and their plural synonyms).
- [e621 parser](https://github.com/e621ng/e621ng/blob/master/app/logical/tag_query.rb)
  (shared dispatch branches and `BOOLEAN_METATAG_ALIASES`).

The complete typed grammar remains available for saved history, Topics, sharing,
raw input and explicitly typed aliases. Only discovery/catalog surfaces collapse
complete synonyms; fields with different domains, payloads or semantics remain
separate (for example uploader name/ID, note creator/updater, or up/down/any
votes). Other engine catalogs contain no additional complete field synonyms
identified in this audit. Existing alias pins resolve to one preferred row;
unpin removes all saved spellings through existing persistence callbacks. FREE
metadata transfers to the preferred spelling. Searching an old shorthand still
finds its preferred field. Applying a guided field replaces ordinary synonymous
conditions together, while preserving opaque raw items.

Verification: all eight new alias regression checks pass, covering both
engine catalogs, old-query recognition, FREE metadata, alias pins and unpin,
single preferred suggestions, canonical selection, and ordinary-vs-raw
replacement. Scoped analysis of the nine changed Dart files reports no issues.
The initial catalog widget fixture used the wrong authentication profile; it
was corrected and the focused group rerun successfully. No locale inputs changed;
generation is unnecessary. No APK/device/live API checks were repeated for this
catalog change.

Runtime checkpoint: `36c770166e2a558010dd28bcac47b09f8a04d29c`, normally pushed
to the existing task branch and verified by remote SHA. Subsequent edits affect
only this report and the coverage design document.

- `./scripts/run_regression_tests.sh` completed with exit 0 on the unchanged
  retry: 4594 application and 1473 package/CLI passes across 13 packages equals
  6067 Dart/Flutter passes. The application run includes all 129 search-option
  tests. Both existing GoRouter skips remain. All 72 Python tooling tests and
  both PR-policy/Android-release shell groups pass. Default concurrency is six
  physical cores.
- The initial full run stopped after 4593 application passes and one unchanged
  sharing-test cleanup failure: `share_sheet_unsupported_media_test.dart`
  attempted to delete an already removed staged image after test completion.
  The test and its production path are identical to the preceding checkpoint.
  Its isolated serial rerun passed, followed by the successful unchanged full
  retry above. No sharing code or tests were altered to obtain the pass.
- `fvm dart format` reports zero further changes for all nine changed Dart
  files; scoped `fvm flutter analyze --no-pub` reports no issues. The known
  native-hook build warning remains as documented in
  `docs/build_troubleshooting.md`.
- Re-review of the complete follow-up diff found no further confirmed defects.
  `git diff --check` and local Markdown link-target checks pass.

Logs: `/tmp/71-alias-focused.log`, `/tmp/71-alias-analysis-final.log`,
`/tmp/71-alias-regression.log`, `/tmp/71-alias-sharing-isolation.log`, and
`/tmp/71-alias-regression-retry.log`. Existing live-site limitations recorded
above remain tied to their prior checkpoints. No PR, develop merge or issue
closure was performed.

## Accepted develop integration (2026-10-24)

The user accepted the final UI and requested integration. This supersedes the
earlier publication/merge restrictions and pending-authorization status in the
historical handoffs. Integrate task tip `c4fde626142ef2508cf054a002f480aa93d47dfd`
onto develop `f54665a35f1f9e642c0c3027972377d3cb1b2163` as one issue-linked
squash commit. The primary checkout and unrelated worktrees remain unchanged.

The combined candidate preserves develop's newer category metadata and bold
chip rendering while retaining the search lifecycle, raw fallback and guided
options. Autocomplete passes category metadata into the combined controller;
the existing suggestion-selection regression now asserts its preservation.
Favorites keep the bold style inside the new collapsible section. The legacy
parser retains develop's URI-path/lowercase extension handling and uses the
feature's empty fallback when the original URL is absent. Both sets of test
harness overrides are preserved. Six content conflicts were resolved and the
complete integration diff reviewed.

Fresh-checkout FVM dependencies and missing ignored runtime output were
prepared with cached dependency resolution and `./gen.sh`. Locale changes are
already in the real English/German JSON files; old manifests were not reapplied.

- Formatting: all 117 changed Dart files, zero further changes.
- Analysis: zero errors/warnings; six informational diagnostics on unchanged
  lines inherited from develop's test fixtures. Default analysis exits 1 for
  those infos; the same 117-file analysis with `--no-fatal-infos` exits 0.
- Focused combined verification: 205 passes across search options, tag category
  consistency and legacy Gelbooru/Realbooru parsing/request tests.
- `./scripts/run_regression_tests.sh`: exit 0 on the first combined-candidate
  run, with 4904 application and 1528 package/CLI passes across 13 packages:
  6432 Dart/Flutter passes total. The two existing GoRouter skips remain. All
  72 Python tooling tests and both PR-policy/Android-release shell groups pass.
- Integration equivalence audit: 133 feature-only files are preserved exactly;
  all 11 develop/task overlaps were reviewed. Remaining differences from the
  accepted task tip are develop's already integrated work and the documented
  category-plumbing assertion/handoff. No unrelated outgoing merge commits.

Final runtime checks used staged candidate tree
`760c0cb59c768150955d336f09d3575fae916056`; this result update is documentation
only. Logs: `/tmp/71-integration-generation.log`,
`/tmp/71-integration-format.log`, `/tmp/71-integration-analysis.log`,
`/tmp/71-integration-analysis-confirmed.log`, `/tmp/71-integration-focused.log`,
`/tmp/71-integration-regression.log` and
`/tmp/71-integration-equivalence-audit.txt`. Local Markdown links and
`git diff --check` pass.

Known live-service and broader site-coverage limits above remain documented;
this integration does not claim exhaustive engine coverage or restore the
Rule34 operators rejected by real API checks. The prior device evidence remains
tied to its recorded APKs. Constrained UI is exercised by the integration's
widget suite; no new device/live API run is claimed.
