# Issue 44 implementation and verification

Issue: #44 — Fetch server favorites into ordinary bookmark groups.
Specification: [Server favorites groups](../designs/server-favorites-bookmark-groups.md).
Task branch: `feature/44-server-favorites`, continued from backend checkpoint
`1fca998349` on source baseline `fd7ae8e63b`.

The feature is available under **Profile Favorites → overflow → Favorites Sync**.
Issue #44 records delivery status. Device and live-account verification limits
are recorded below.

## Behavior and implementation

- The dedicated settings page, its navigation entry, and its search catalog item
  have been removed. Both the shared Favorites header and Danbooru's custom
  header expose the same Kurumi overflow action. Signed-out Favorites retain it.
- The same compact, scrollable Favorites Sync dialog opens from every Favorites
  profile. Its introduction explains saving server favorites as local bookmarks.
  The global picker is labeled Default bookmark group; each available profile has
  a Bookmark group field with Use default / None / Use different group. Inherited
  values show the resolved group path. Available profiles stay expanded in saved
  profile order. Unavailable profiles, including missing credentials, appear in
  saved order at the bottom with only name, icon, and their concrete reason.
  None, deleted targets, and transient fetch failures remain configurable.
  About Favorites Sync explains the purpose, additive fetches, direct actions,
  and local/server boundaries beside the fitted single-line title. Visible
  Save & Fetch all, Save & Fetch, and Save & Retry buttons sit below their target
  fields. Close and Save share the footer; Close is outlined.
- A dedicated single-choice destination picker reuses ordinary bookmark folders,
  None, and creation in the current folder. Selecting a group returns to the form
  immediately. Draft selection neither saves settings nor edits posts. Save and
  Save & Fetch commit the whole editor in one preferences write. Save closes the
  dialog; both fetch actions keep it open to display progress and recovery actions.
  Global and per-profile fetch buttons save first. Unavailable profile
  assignments remain intact; stale settings or changed accounts require reload.
- As requested in the UX follow-up, first binding to a populated, unassigned
  group now requires an explicit warning that its existing bookmarks will be
  cleared. Cancel preserves all content and assignments. Confirmation carries
  the reviewed group snapshot; changed contents/accounts reject the save.
  Clearing uses the ordinary bookmark service, preserves other memberships, and
  restores removed content on caught save failures. Already assigned groups can
  be shared without clearing. Empty/new groups require no destructive warning.
- Fetching remains explicit and additive, with progress, Cancel, errors, and
  Retry. The global action fetches every configured, available profile,
  including overrides. Per-profile actions fetch only their selected account.
  None, unsupported engines, signed-out accounts, and missing targets are
  excluded. Progress, cancellation, errors, and retry stay visible in the editor.
  Jobs also continue if the user closes it manually; reopening restores their
  progress. One failure does not stop other profiles.
  Save & Fetch verifies captured accounts and targets before making requests.
  Changing settings never starts a fetch. Committed pages survive
  cancellation and retries. No scheduler, background reconciliation, or deletion
  based on server results is introduced.
- Supported queries use the existing coordinated post clients with raw options
  and no profile browsing filters. Danbooru uses `ordfav:`, Gelbooru uses `fav:`, e621 uses its
  ordered `/favorites.json` account endpoint, Moebooru uses `vote:3:... order:vote`, and Szurubooru uses `special:fav`
  for the authenticated account. Gelbooru requires a numeric account ID;
  Moebooru also requires the site's existing favorite-support capability.
  Gelbooru V2, including Realbooru, uses its existing dedicated favorites-list
  client with site-configured pagination instead of a tag query. Cookie-only
  accounts work without an API key. Thumbnail-only sites resolve full posts
  before bookmarking, with cancellation between detail requests.
  Manual imports and their nested lookups use the existing bulk-transfer
  request context and shared per-origin pacing. Cancellation revokes queued
  request admission; direct projections remain interactive.
  Search-depth caps and stalled pagination report failure rather than claiming
  exhaustion. Short pages alone are never an end marker. Fetching collects the
  complete list before saving pages and posts in reverse source order; download
  and save progress are separate. Download interruption adds no buffered posts;
  save interruption preserves committed pages. Existing bookmarks retain dates
  and memberships. See the specification for site-order limitations.
- Single-post buttons, context menus, gestures, and unified selection actions
  carry the originating profile ID into the confirmed-action wrapper. Profiles
  sharing identical auth remain distinguishable. Auth-only callers continue to
  fail closed on ambiguity. The wrapper reuses the supplied engine repository
  and applies exactly one profile-specific projection.
- Moebooru's custom vote-based toolbar now uses that same confirmation wrapper.
  Other supported engines' ordinary actions already pass through the central
  repository. Sankaku's separate ID-based notifier and Shimmie2's legacy bulk
  client remain outside the collection feature; fetching for those engines is
  explicitly unsupported. No unsupported engine has an inferred adapter.
- Successful additions to an existing bookmark group publish an immutable
  incremental state using the committed rows and membership. Existing decoded
  posts and their identity index entries are reused. Repeated memberships are a no-op;
  failed publication or an unexpected group change uses full-reload recovery.
- Direct projections use raw post lookup independently of the fetch adapter or
  fetch credentials. Unsupported engines return no projection before loading
  settings; capability errors are also excluded from action feedback. This
  removes Realbooru's repeated unsupported-fetch warning after successful
  favorite/unfavorite actions. Realbooru now projects those actions normally.
- Genuine optional local-projection failures never change a successful remote result.
  A separate, dismissible localized notice remains visible independently of
  remote-action success toasts. Its scrollable content and the reused group-name
  dialog fit constrained screens and enlarged text.
- Settings remain under the independent `server_favorite_targets_v1`
  `MiscDataStore` key. Bookmark/profile export models are unchanged. Group
  export contains ordinary posts, groups, and folders without credentials,
  assignments, fetch state, or active behavior.

## Integration verification (2026-10-21)

The user accepted Favorites Sync and authorized integration. The combined
candidate `1b8c698234fe259b2a3dfecbf30d8de541ecf89a` includes the approved feature
through `2c90227e2` and develop `61588fd5d`. The separate
`fix/bookmark-mutation-latency` worktree is outside this integration.

- `./gen.sh i18n`: validation and generation passed for the combined resources.
- `./scripts/run_regression_tests.sh`: exit 0; 4,459 application tests and all
  13 package/CLI suites passed. GoRouter retained two existing skipped tests.
  Pull-request policy and Android release-script checks passed, as did all
  72 Python tooling tests. The host engine emitted the previously observed
  Dart VM finalizer/callback diagnostic without failing tests.
- `git diff --check`: passed. Origin was refreshed after verification and
  remained at the tested develop base.

Only this documentation was updated after the complete pass. The integration
uses one Conventional Commit with the same tested runtime/test contents.
No new phone/emulator, native-build, process-restart, or authenticated live-account
checks were performed during integration; earlier evidence retains its stated
limits. Ordinary bookmarking performance follow-up remains a separate task.

## Historical Favorites Sync UX verification

The UX follow-up on `cce0285bc` changes only the dialog, English localization,
related tests, and this specification/handoff. Storage, request sources, fetch
ordering, mutation handling, and performance code are unchanged. Existing
Kurumi menus, ListTile field typography, app bar title fitting, and button styles
are reused. Group values occupy at most two lines to keep controls compact;
the mode popup is bounded by available space above or below its field and scrolls.

Verification on the final UX implementation:

- `fvm flutter test --no-pub --concurrency 6` with
  `test/core/bookmarks/server_favorites`, `test/core/posts/favorites`,
  `test/core/navigation/favorites_profile_picker_regression_test.dart`,
  `test/application/settings_flow_test.dart`,
  `test/boorus/moebooru_favorites_provider_test.dart`,
  `test/boorus/e621/server_favorites_source_test.dart`, and
  `test/boorus/gelbooru_v2/server_favorites_source_test.dart`: exit 0, 130 passed.
  The host engine emitted a Dart VM finalizer/callback diagnostic; no test failed.
- `./gen.sh i18n`: localization validation and code generation passed.
- `fvm dart format --output=none --set-exit-if-changed` on all four changed Dart
  files: passed, no formatting changes.
- `fvm dart analyze` on the dialog and three changed test files: no errors or
  warnings; one existing informational deprecation for the test harness's
  `MaterialUiCompatibilityBridge`.
- Changed documentation relative links and `git diff --check`: passed.

Widget coverage includes visible field/action labels, inherited folder paths,
saved ordering in both lists, missing credentials, retained unavailable profile
assignments, None and deleted targets staying configurable, whole-draft saves,
global fetches including overrides, independent retry, populated-group
confirmation, stale-account protection, and dialog closing behavior. Layout tests
cover 320-pixel width, doubled text, 640-by-320 landscape, long profile/group names,
both nested pickers with semantics enabled, and group creation with the keyboard
open.

No emulator/phone interaction, native build, authenticated live fetch, or complete
integration suite was performed for this UI follow-up. Earlier full-suite and
device evidence below applies to its recorded candidates. Further bookmark
performance investigation belongs to the separate agent task.

## Historical favorite-projection performance verification

A successful favorite was followed by a complete library load: decode every
saved snapshot, repair memberships, and rebuild all identity indexes. A serial
host Flutter debug benchmark reproduced this work after every addition. The
successful `addPostsToGroup` path now publishes only the committed additions and
updated group membership, retaining existing decoded bookmark instances and
index entries. Writes still complete in the same serialized mutation queue before
state is published. Error recovery retains the full reload.

`fvm flutter test --no-pub --concurrency 1 benchmark/server_favorite_projection_performance_test.dart`
uses real temporary Hive storage, synthetic profiles/posts, a fake remote post
lookup, a warmed library with existing posts in Default and an initially empty
Favorites target, one warm-up and three reported additions per size.
Measured before and after on the same host:

| Existing bookmarks | Before median (range), ms | After median (range), ms |
| --- | --- | --- |
| 1,000 | 32.204 (30.472–34.546) | 3.403 (2.785–4.349) |
| 5,000 | 131.913 (126.896–173.236) | 9.395 (8.076–9.587) |

Each baseline addition recorded one whole-library decode/load. No such operation
was recorded after the fix. These are host debug wall times for local projection,
including storage waits, not CPU-only measurements or Android frame timings.
The benchmark does not include network latency, a cold initial library load,
unfavorite removal, or rendering of dependent widgets.

The controller regression failed before the fix on repeated full-library
decoding. It now checks an existing bookmark joining a group, a new bookmark,
an idempotent repeat, retained old snapshots/dates and derived indexes matching
a cold reload. A provider regression forces publication to fail after membership
has committed and checks that recovery publishes the saved result.

Checks on the final runtime diff against `7ac1be675`:

- The projection regression reproduced the unwanted full-library decoding before
  the implementation change. The focused controller/provider run passed 63
  tests; the provider file passed all 45 tests after adding the recovery case.
- `./scripts/run_regression_tests.sh`: exit 0 at detected physical-core
  concurrency 6. Application: 4,396 passed. All 13 complete package suites
  passed, including the CLI. GoRouter retains its two existing unconditional
  skips. Pull-request policy and Android release-script checks passed; Python
  repository tooling: 72 passed. Existing native-finalizer diagnostics appeared
  without failing tests.
- The serial benchmark above passed both library-size cases before and after.
  It stays opt-in and has no strict wall-time assertions.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/types/bookmark_library_state.dart lib/core/bookmarks/src/providers/bookmark_provider.dart test/core/bookmarks/server_favorites/controller_integration_test.dart test/core/bookmarks/bookmark_provider_test.dart benchmark/server_favorite_projection_performance_test.dart`:
  exit 0; no errors or warnings, four existing informational lints.
- `fvm dart format --output=none --set-exit-if-changed` on the five changed Dart
  files, `git diff --check`, and relative documentation-link validation passed.

No native build, device run, authenticated mutation or phone frame recording was
performed; the user's reported pause still needs confirmation on their phone.

## Historical Realbooru pacing verification

The Android log shows six Realbooru imports failing with HTTP 503 after 29–36
successful post-detail requests, mostly about 150 ms apart. The favorites listing
itself succeeds. Realbooru resolves a page's thumbnail posts before reporting the
page as fetched, explaining the zero-page counter. An anonymous request for the
last failed post subsequently returned HTTP 200. This supports a transient burst
failure, without establishing a documented server quota or an HTTP 429 limit.

The importer was using the default interactive request class and bypassing the
coordinator's bulk pacing. It now runs each page and all nested detail requests
in the existing bulk-transfer context, with automatic cooldown replay disabled
and a job-cancellation admission guard. The current fallback bulk policy spaces
starts by 1,250 ms across clients for the same origin; this is application policy,
not a claimed Realbooru quota. Direct favorite actions keep interactive handling.

Checks on the final runtime diff against `49fb8d7bf`:

- Before the fix, the two new controller regressions failed on interactive
  classification and a missing cancellation guard. Afterward they pass; the
  Realbooru client/source regression also verifies that listing and nested detail
  requests inherit bulk classification, cooldown policy, and cancellation.
- `fvm flutter test --no-pub --concurrency 6 test/core/bookmarks/server_favorites test/boorus/gelbooru_v2 test/boorus/e621/server_favorites_source_test.dart test/boorus/moebooru_favorites_provider_test.dart test/core/http/client test/core/posts/favorites test/core/navigation/favorites_profile_picker_regression_test.dart`:
  exit 0; 278 passed at detected physical-core concurrency 6. Includes existing
  controlled-clock HTTP pacing tests, cancellation, account/session protection,
  additive ordering, shared targets, retries, and dialog/header consumers. A
  nonfatal native-finalizer diagnostic remains.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites/controller.dart test/core/bookmarks/server_favorites/controller_integration_test.dart test/boorus/gelbooru_v2/server_favorites_source_test.dart`:
  exit 0; no issues found.
- Changed-file formatting, `git diff --check`, and relative documentation-link
  validation passed.

No complete local suite, native build, device run or authenticated live import
was performed for this scoped fix. The user's phone still needs to confirm that
the paced import avoids the observed 503. The anonymous single-post check does
not establish end-to-end account import success. No remote favorites changed.

## Historical review-fix verification

The two review findings against `3418afca4` also reproduced on `31144af0a`.
Before implementation changes, deterministic regressions failed for favorite and
unfavorite account replacement during session capture, and for retrying a failed
profile while another job remained running. The fix compares the captured auth
against the original action auth and separates assignment-edit availability from
per-profile fetch availability. A fourth regression ensures an unsaved draft
cannot be committed through a fetch while another job is running.

Checks on the final runtime diff against `31144af0a`:

- Reproduction: the two named account-race regressions and the independent-retry
  widget regression all failed before the implementation changes. After the
  fixes, the same checks and the running-job/draft guard passed (4 tests).
- `fvm flutter test --no-pub --concurrency 6 test/core/bookmarks/server_favorites test/core/posts/favorites test/core/navigation/favorites_profile_picker_regression_test.dart test/boorus/moebooru_favorites_provider_test.dart test/boorus/e621/server_favorites_source_test.dart test/boorus/gelbooru_v2/server_favorites_source_test.dart`:
  exit 0; 124 passed at detected physical-core concurrency 6. This includes
  account/session checks, remote-success projection behavior, shared groups,
  independent jobs, retry, stale configuration protection, and the real
  Favorites headers. Dialog checks exercise 320-pixel width, doubled text,
  landscape picker measurement and keyboard-open creation. A nonfatal native
  finalizer diagnostic was emitted.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites/controller.dart lib/core/bookmarks/src/server_favorites/dialog.dart test/core/bookmarks/server_favorites/controller_integration_test.dart test/core/bookmarks/server_favorites/dialog_test.dart`:
  exit 0; no errors or warnings, one existing informational compatibility-bridge
  deprecation in the test harness.
- `fvm dart format --output=none --set-exit-if-changed` on the four changed Dart
  files: exit 0, no formatting changes needed.
- `git diff --check` and relative documentation-link validation: passed.

No complete local suite, native build, device run or live-account checks were
performed for these scoped fixes. The reviewer's complete-suite result predates
this candidate and is not reused as certification of the current runtime changes.

## Historical ordering verification

This follow-up to `4d86eb99c` preserves server listing order under newest-bookmark
sorting for newly created bookmarks, across page boundaries. e621 now uses the
ordered account-favorites endpoint. Equal bookmark dates use insertion IDs to
break ties. Fetch terminology and download icons remain unchanged as requested.
Fetching is still additive; a regression checks a shared global target retains
another profile's favorites and manual bookmarks when fetching one profile.

The two-phase download/save behavior and source-order limitations are recorded in
the [specification](../designs/server-favorites-bookmark-groups.md#favorite-ordering).
Checks on the final runtime diff against `4d86eb99c`:

- `./gen.sh i18n` and changed-file `fvm dart format`: passed. Localization
  validation and generation also passed after the final concise help edit.
- `fvm flutter test --no-pub --concurrency 6 test/core/bookmarks test/core/posts/favorites test/core/navigation test/boorus/e621 test/boorus/gelbooru_v2/server_favorites_source_test.dart test/application/selection_feedback_flow_test.dart`:
  exit 0; 541 passed. Covers reversed multi-page creation order, overlaps,
  equal-time sorting, retries, shared targets and unchanged existing dates,
  download/save cancellation, and surrounding bookmark/navigation consumers.
  Nonfatal native-finalizer and selection hit-test diagnostics were emitted.
- After the final help wording, `fvm flutter test --no-pub --concurrency 6 test/core/bookmarks/server_favorites/dialog_test.dart`:
  exit 0; 22 passed, including fetched-versus-saved progress, narrow width,
  doubled text, landscape picker measurement, and keyboard-open creation.
- From `packages/booru_clients`, `fvm dart test --concurrency 6`:
  exit 0; the complete package suite passed all 104 tests. The new e621 tests
  exercise both response shapes, order preservation, pagination and the existing
  authenticated Dio client. The application adapter test verifies raw requests,
  origin identity and unavailable posts not producing false exhaustion.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites lib/core/bookmarks/src/providers/bookmark_group_selectors.dart lib/boorus/e621/favorites/providers.dart test/core/bookmarks/server_favorites test/core/bookmarks/bookmark_upload_sort_test.dart test/boorus/e621/server_favorites_source_test.dart packages/booru_clients/lib/src/e621/e621_client.dart packages/booru_clients/test/e621/favorites_test.dart`:
  exit 0; no errors or warnings, 31 informational lints in the checked scope.
- `git diff --check` and relative documentation-link validation: passed.

No device run, native build, authenticated live fetch or complete integration
suite was performed for this follow-up. No remote favorites were changed.

## Historical progress-dialog verification

The follow-up to `3418afca4` keeps both fetch actions open and updates the saved
draft baseline so retry and further edits work without reopening. Save still
closes. Help text now describes this behavior. Favorite-date research and the
existing local-date policy are recorded in the
[specification](../designs/server-favorites-bookmark-groups.md#favorite-dates);
no reliable remote favorite timestamp is exposed by the checked sources, so no
dates or storage schema were changed.

Checks on the final runtime diff against `3418afca4`:

- `./gen.sh i18n`: exit 0, localization validation and generation passed.
- `fvm dart format lib/core/bookmarks/src/server_favorites/dialog.dart test/core/bookmarks/server_favorites/dialog_test.dart`: passed.
- `fvm flutter test --no-pub --concurrency 6 test/core/bookmarks/server_favorites test/core/navigation/favorites_profile_picker_regression_test.dart test/boorus/gelbooru_v2/server_favorites_source_test.dart`:
  exit 0; 89 passed. Tests cover visible committed-page progress, global and
  individual fetches staying open, cancellation, errors and retry, later edits
  using the saved baseline, Save closing, and manual Close/reopen during a job.
  Existing narrow-width, doubled-text, landscape and keyboard regressions pass.
  An existing native-finalizer diagnostic did not fail the suite.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites test/core/bookmarks/server_favorites/dialog_test.dart test/core/navigation/favorites_profile_picker_regression_test.dart`:
  exit 0; no errors or warnings, five informational lints in unchanged lines.
- `git diff --check` and relative documentation-link validation passed.
- Primary engine source/API documentation was reviewed for favorite dates.
  Anonymous Realbooru favorites HTML returned HTTP 200 without favorite-date
  identifiers, time attributes, or time elements. No credentials were used and
  no remote favorite action was performed.

No new device run, native build, or complete integration suite was performed for
this follow-up. The historical APK and full-suite results below predate it.

## Historical all-profile UX verification

The shared-editor/Realbooru revision continues from `e399cd981` on the same
isolated branch. No storage schema, export contract, or remote favorite mutation
was introduced. The concise first-binding warning is now “First use will clear
all bookmarks in {groups}.”

- `./gen.sh i18n` passed validation and generation. Changed Dart files were
  formatted with `fvm dart format`.
- `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/core/bookmarks test/core/settings test/core/posts/favorites test/core/navigation test/core/backups test/application/settings_flow_test.dart test/application/selection_feedback_flow_test.dart test/boorus/moebooru_favorites_provider_test.dart test/boorus/gelbooru_v2`:
  exit 0; 1,177 passed at detected concurrency 6. An intermediate fixture
  compile failure was corrected before this completed rerun. Existing native
  finalizer diagnostics appeared without failing tests.
- After the final capability-notice display guard, reran all directly affected
  feature tests and both production Favorites headers:
  `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/core/bookmarks/server_favorites test/core/navigation/favorites_profile_picker_regression_test.dart test/boorus/gelbooru_v2/server_favorites_source_test.dart`:
  exit 0; 88 passed. This checks saved profile order, unsupported rows, atomic
  multi-profile saves, Save/fetch closing, global versus individual scope,
  skipped unavailable profiles, independent failures, cancellation, retry,
  unchanged first-binding/shared-group safeguards, 320-pixel width, doubled
  text, landscape, keyboard-open creation, and intrinsic measurement.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites lib/core/posts/favorites/src/widgets/favorites_page_menu.dart test/core/bookmarks/server_favorites test/core/navigation/favorites_profile_picker_regression_test.dart test/boorus/gelbooru_v2/server_favorites_source_test.dart`:
  exit 0; no errors or warnings, 26 informational lints in the affected scope.
- Realbooru tests exercise the real client, configured favorites parser, offset
  paging (0 then 50), full-post parser, source/profile identity, and cancellation
  with fixture responses. Separate real-Hive/provider tests verify successful
  cookie-only favorite/unfavorite projections and silent unsupported engines.
- Anonymous read-only Realbooru requests returned HTTP 200 with the expected
  favorites HTML structure. Only structural counts were logged. Authenticated
  application fetching and live multi-page Realbooru collections remain
  unverified; the fixture pagination check is not a live-account claim.
- `fvm flutter build apk --debug --flavor dev --no-pub`: exit 0 on the final
  runtime candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`,
  459,221,246 bytes, SHA-256
  `85ae9a361ae1dc5fd9ba7f632fc5fd5977a43260d4fa02272bfdfb766477e143`.
- The final APK was installed without resetting data on exclusively leased
  `emulator-5556`. Maestro checked all-profile layout, saved profile order,
  unsupported rows, the fitted title, fetch controls, and Save closing. The
  preceding build with identical save/fetch logic also checked picker creation
  with the keyboard open, persisted profile None/inheritance choices, global
  Save & Fetch closing, and the dummy account's expected server error on
  reopening. Only synthetic credentials were used; no remote favorites changed.
  Global None and inheritance were restored, the temporary group and both test
  profiles were removed, and the lease was released. The user's phone was not
  operated.
- `git diff --check` and relative documentation-link validation passed.

A fresh complete local suite is still required before integration. The older
complete pass below does not qualify this revised runtime candidate.

## Historical intrinsic-layout verification

Commit `e399cd981` continued from `f343fd651` on the same isolated branch.
The user's Android log identified `RenderShrinkWrappingViewport does not support
returning intrinsic dimensions`, followed by failed layout and semantics
assertions. The earlier compatibility fix addressed a different failure.

- A regression directly measuring the nested dialog's intrinsic height
  reproduced the exact viewport exception before the fix. The picker content
  had a fixed width but no height. It now bounds both axes with the same
  360-by-320 content dimensions as the existing folder destination picker, so
  intrinsic measurements stop at the SizedBox instead of reaching the lazy list.
- Both global and profile selectors pass intrinsic-height checks with semantics
  enabled at 320-by-740 and 640-by-320 logical pixels and doubled text. The large
  library regression also scrolls to the last of 32 root groups before selecting
  a target in nested folders. Drafts remain unsaved and never fetch.
- Changed Dart files were formatted with `fvm dart format`.
- `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/core/bookmarks/server_favorites/dialog_test.dart test/core/navigation/favorites_profile_picker_regression_test.dart`:
  exit 0; 27 passed at detected concurrency 6, including keyboard-open group
  creation, existing save/fetch safeguards, and both production Favorites headers.
- `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/core/bookmarks test/core/navigation/favorites_profile_picker_regression_test.dart`:
  exit 0; 438 passed at detected concurrency 6. Existing native-finalizer
  diagnostics appeared without failing tests.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites/target_picker.dart test/core/bookmarks/server_favorites/dialog_test.dart`:
  exit 0, no errors or warnings; one existing informational compatibility-bridge
  deprecation remains in the test harness.
- `git diff --check` and relative documentation-link validation passed.

No new device interaction check or complete integration suite was performed for
this sizing fix. The APK and emulator checks below belong to the earlier
candidate. The regression reproduces the reported exception through an explicit
intrinsic measurement; the user's phone-specific trigger for that measurement
was not independently reproduced.

## Historical compact-dialog verification

Commit `3ca09f708` continued from `775971e3d` on the same isolated branch. These
results apply to that earlier runtime/test diff and do not qualify the current
intrinsic-layout fix.

- The baseline picker opened in the production widget harness and on Android
  with a simple bookmark library. The user's full-device failure was not
  reproduced. A controlled regression without an inherited legacy compatibility
  bridge did reproduce `No MaterialLocalizations found` when the nested picker
  used Flutter Material's route. The picker and group-creation routes now use the
  application's dialog route and locally bridge reused legacy content. Both
  global and profile selectors pass this regression, including creation, None,
  immediate return, unchanged bookmark content, and unsaved settings.
- The main form no longer contains the inheritance explanation, effective-target
  text, or Fetch server favorites section. The localized Info dialog contains
  that guidance. The title uses `KurumiFittedText` and app bar typography within
  a single nominal line. The three actions remain on one row at 320 logical
  pixels and doubled text; the group-name form also fits a 280-pixel keyboard
  inset.
- `./gen.sh i18n` passed validation and generation. Changed Dart files were
  formatted with `fvm dart format`.
- `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/core/bookmarks test/core/navigation/favorites_profile_picker_regression_test.dart`:
  exit 0; 435 passed at detected concurrency 6. Existing native-finalizer
  diagnostics appeared without failing tests. The focused dialog/header subset
  passed 24 tests (22 dialog tests and both production Favorites headers).
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/server_favorites lib/core/bookmarks/src/widgets/bookmark_group_name_dialog.dart test/core/bookmarks/server_favorites/dialog_test.dart test/core/navigation/favorites_profile_picker_regression_test.dart`:
  exit 0, no errors or warnings; 6 informational lints remain.
- `fvm flutter build apk --debug --flavor dev --no-pub`: exit 0. Final APK:
  `build/app/outputs/flutter-apk/app-dev-debug.apk`, 459,213,215 bytes, SHA-256
  `942e64da38d586688a3c150909afc04702ae891d0b52a4a23363b39d467be537`.
- The final APK was installed without resetting data on exclusively leased
  `emulator-5556`. Maestro verified both selectors return the selected group or
  None, and visually checked the single-line title, Info, and action row. Group
  creation was exercised with the keyboard open. A temporary profile used dummy
  credentials; no authenticated fetch or remote favorite mutation was performed.
  Main-form drafts were discarded with Close. Temporary test data was removed
  and the lease released after checking.
- `git diff --check` and relative documentation-link validation passed.

No fresh complete local integration suite was run for this follow-up. The
complete pass below belongs to an earlier runtime candidate; a fresh complete
pass is required before integration.

## Historical consolidated-dialog verification

Commit `775971e3d` continued from `0fa7809ba`. The following checks apply to that
earlier runtime/test diff and do not qualify the current picker/layout follow-up.

- Localization: `./gen.sh i18n` passed validation and generation.
- Changed Dart files were formatted with `fvm dart format`.
- `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/core/bookmarks test/core/settings test/core/posts/favorites test/core/navigation test/core/backups test/application/settings_flow_test.dart test/application/selection_feedback_flow_test.dart test/boorus/moebooru_favorites_provider_test.dart`:
  exit 0; 1,116 passed at detected concurrency 6. A new catalog assertion initially
  counted the supplied generic category as a removed control; it was corrected
  to check that the obsolete control is absent, and this complete scoped run
  passed. Existing native-finalizer diagnostics appeared without failing tests.
- After removing one unused test import, the complete dialog file passed again:
  `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/core/bookmarks/server_favorites/dialog_test.dart`: 19 passed.
- `fvm flutter analyze --no-pub --no-fatal-infos` on all 31 changed/new existing
  Dart files: exit 0, no errors or warnings; 13 informational lints remain.
- `git diff --check` and relative documentation-link validation passed.
- Widget coverage includes 320-pixel width, doubled text, a 280-pixel keyboard
  inset, nested folder selection and creation, draft cancellation, Save only,
  confirmed destructive binding, shared groups, missing targets, unavailable
  accounts, account changes during confirmation, progress, cancellation, remote
  error/retry, persistence failure, and stale settings reload.
- Dialog tests use the real bookmark/settings logic with in-memory repository
  boundaries. Real Hive integration separately covers confirmed clears, shared
  memberships, stale confirmation, rollback, and unchanged export contracts.
- Both production Favorites headers are exercised with a Favorites profile
  different from the retained Browse profile.

That consolidated-dialog candidate had no native build or device interaction
check. Neither it nor the current follow-up has process-crash/upgrade coverage.

## Historical picker verification

Commit `0fa7809ba` passed 435 related application tests and affected analysis
without errors or warnings (28 informational lints). It used populated groups
without clearing and had no group-creation action. These historical semantics
and counts do not qualify the current dialog or its confirmed-clear behavior.

## Verification of the previous implementation

The full checkout and pinned FVM SDK are available in this environment. The
original checkpoint tests used relative imports into `lib`, producing duplicate
Dart library identities; they now use package imports. No unrelated import-path
changes were retained.

Bootstrap: root `fvm flutter pub get`, CLI `fvm dart pub get`, and `./gen.sh` for
missing generated output. Localization changes use `./gen.sh i18n`. Generated
booru output was restored through `./gen.sh booru` before final verification.
Changed Dart files were formatted with `fvm dart format`.

Previous coverage included target inheritance and first binding, partial recovery,
cancellation, confirmation failures, projection ordering, raw fetch options and
pagination caps, plus real Hive/provider integration for shared targets, identical
auth with profile opt-out, changed accounts/targets, late responses, direct
unfavorite/fetch overlap, renamed/moved/deleted groups, and export isolation.
Widget tests exercise real taps, group creation and keyboard submission at
320-pixel width with doubled text, profile target choices, Cancel/Retry, and
separate projection feedback.

Previous verified runtime candidate: commit `1d6348ef4` (the task diff against
`1fca998349`). The following results do not qualify the newer picker follow-up.

- `fvm flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors or
  warnings; 3,010 informational lints remain across the repository, including
  existing checkpoint style lints. The default fatal-info analyzer is not clean.
- `fvm flutter test --no-pub --concurrency "$(python3 scripts/physical_core_count.py)" test/application/selection_feedback_flow_test.dart test/core/bookmarks/server_favorites test/boorus/moebooru_favorites_provider_test.dart`:
  62 passed. This includes the regression for preserving injected repositories
  and completed-target retries in bulk favorite actions.
- `fvm flutter build apk --debug --flavor dev --no-pub`: exit 0 on the final
  runtime candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`,
  398,861,011 bytes, SHA-256
  `c9e78398ebc02704a5030c61b2fea2ee748696eb6dbd8c8a65dc60a4b7cd7a8a`.
  Existing Gradle/AGP/Kotlin/SDK compatibility and libavif native-hook warnings
  remain. No toolchain or dependency changes were made.
- `./scripts/run_regression_tests.sh`: exit 0 with detected concurrency 6.
  Application: 4,347 passed. All 13 complete package suites passed:
  `booru_clients`, `boorusama_cli`, `cache_manager`, `coreutils`, `dtext`,
  `extended_image`, `filename_generator`, `flutter_sqlite3_migration`,
  `foundation`, `go_router`, `i18n_cli`, `kurumi`, and `retriable`.
  GoRouter retains two pre-existing unconditional skips: “routing config works
  with shell route” and “Obsolete branches in StatefulShellRoute are cleaned up
  after route configuration change”. All other package suites reported no skips.
  Pull-request policy and Android release-script checks passed; Python repository
  tooling: 72 passed. Flutter native-finalizer diagnostics appeared during the
  application run without failing tests; this is a completed-suite claim, not a
  clean-log claim.
- `git diff --check` and local handoff-link validation passed.

A first complete-run attempt exposed the profile wrapper bypassing an injected
favorite repository; the implementation was fixed and its consumer test now
passes. The recorded complete run is the regression evidence for that historical candidate.

## Live and device acceptance limits

Bounded, authenticated, read-only API requests on 2026-10-21 returned 9 then 0
favorites for the configured Danbooru account and 4 then 0 for Gelbooru. Only
counts and pagination outcomes were recorded. No remote favorites were changed.
These endpoint checks are separate from application-provider/client tests.

Authenticated e621, Moebooru, and Szurubooru fetches remain unverified against
live accounts. Permission/hidden-post behavior, production rate-limit responses,
and capped large collections still need live acceptance; deterministic tests
cover keeping committed pages and additive recovery. Server access restrictions
can always yield an incomplete local collection.

Adapter references:

- [Gelbooru API](https://gelbooru.com/index.php?page=wiki&s=view&id=18780)
- [Moebooru query implementation](https://github.com/moebooru/moebooru/blob/master/app/models/post/sql_methods.rb)
- [Szurubooru API](https://github.com/rr-/szurubooru/blob/master/doc/API.md)

The earlier Android check covered the picker and compact layout, with drafts
discarded. Nested-folder navigation, populated-group confirmation, fetch
Cancel/Retry, shared-account overrides, and persistence are covered by automated
tests but have not all been repeated through the Android UI. Authenticated
application fetches and persistence after process restart remain device
acceptance work. Use Maestro with an exclusive emulator lease under
`docs/android_emulator.md`.

No push, PR, merge, or issue closure is authorized by this handoff.
