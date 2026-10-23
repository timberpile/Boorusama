# Issue #51 — Local acceptance handoff

Branch: `feature/51-topic-query-formatting`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/51

## Implementation

The shared `FollowingTopicCard` now renders an unnamed Topic's query with compact, read-only filled tag chips using the normal Kurumi chip styling and application category palette. Named Topics retain their exact custom name and use the same query presentation in their existing subtitle. Feed member cards reuse this card automatically. Text is bounded to two lines with ellipsis rather than introducing a horizontally scrolling chip editor or another tap target.

Ordinary tag underscores become spaces only in presentation. Operators remain explicit within their chips. Metatag values, URL underscores, quotes, escaped content, wildcards, unknown syntax, and whitespace are retained. The small lossless display lexer is deliberately not used to parse, normalize, save, execute, or validate a search. Existing `FollowingTopic.query`, `queryStructure`, identity, sorting, tracking, and edit state are untouched.

Tag colors reuse `booruTagTypeProvider` and `tagColorProvider` with the card's own profile. Missing ordinary-tag metadata is resolved in a batch through that profile's existing `tagRepoProvider`, then stored in the category cache. Missing profiles, unavailable metadata and offline errors retain neutral backgrounds. Raw/metatag values are not sent to the category lookup. This branch uses the same pre-existing providers as #48, so it is independently based on develop rather than stacked on #48.

## Tests and verification status

Added `test/core/search/following_topics/topic_query_display_test.dart`: exact reconstruction of raw input, ordinary-tag presentation, operators, quoted/escaped/unknown syntax, compact narrow/large-text rendering, custom-name preservation, and card opening.

**Formatting, analysis, Flutter tests, and device checks have not run.** The remote environment has no FVM/Flutter SDK and cannot clone GitHub. Do not treat this branch as accepted or ready to integrate.

## Local acceptance

1. Fetch into an isolated worktree and follow `AGENTS.md`; bootstrap dependencies/generated files as needed. Format changed Dart files and analyze affected Topic/tag UI code.
2. Run the new test and the existing `test/core/search/following_topics` suite with physical-core concurrency. Include shared Topic-card/feed-member layout tests. Add a provider-backed rendering regression that overrides the local category cache to verify actual category colors, missing/error fallback, and profile switching with no network access.
3. Verify unnamed and custom-named cards in the Topic overview and Feed member view, light/dark/custom themes, narrow width, and enlarged text. Test operator/metatag queries, quotes, URLs, non-Latin tags, long names, and raw custom syntax. Confirm Info/Edit/Search still show or execute the original query, not display text.
4. Follow the exclusive emulator lease procedure before device work. Review the full diff, fix small defects on this branch, and record checked commit plus actual commands/results/skips. Run the complete local suite on any final combined develop integration candidate.

## Coordination

No branch dependency on #48. #65 can touch the same shared card to supply previews: retain both the title formatting and independent preview behavior when integrating later. No merge, PR, issue closure, or deletion is authorized. A later approved integration subject must include `#51`; keep `Refs #51` until acceptance passes.

## Local acceptance evidence (2026-10-22)

This section supersedes the earlier unrun-verification status. Checked runtime/test commit: `a1513fcfac0aed0feb09e7ac7f6f3b78740aca11`.

- Bootstrapped the fresh worktree with FVM dependencies and missing generated output via `./gen.sh`; generated files remain ignored. Formatted changed Dart files and passed `git diff --check`.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/search/following_topics`: **618 passed**.
- `fvm dart analyze lib/core/search/following_topics test/core/search/following_topics/topic_query_display_test.dart`: passed with informational lints, no errors or warnings.
- Added provider-backed rendered text checks for exact originating-profile cache keys, profile switching, cache failure/unknown fallback, category colors, non-Latin tags, and no cache lookup for metatags/quoted URLs. Existing raw reconstruction, operator, custom-name, compact/narrow/enlarged-text, card action, Topic, and feed-member suites pass.
- Source review confirms the display lexer is not used to save or execute queries; existing Info/Edit/Search paths retain original data.

Flutter 3.47.2 / Dart 3.13.2 and six detected physical-core workers were used with an isolated copy of the pinned SDK to avoid an unrelated startup lock.

**Acceptance remains pending the Android overview/feed-member and visual theme matrix**, including live Info/Edit/Search. The leased emulator did not answer its health check and was released; the later check found it leased to another task. No device result or combined-develop qualification is claimed. No merge, push, PR, issue closure, or deletion occurred.

### Android follow-up (2026-10-23)

After the emulator recovered and became available, initialized native plugin metadata with `fvm flutter pub get --offline` and built this branch with `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Installed with `adb -s emulator-5554 install -r`, preserving app data. APK SHA-256: `df4378cb3d9030b3b8aaff6241a668e3070dacdd54f8125fa19a30a2f4e2d610`.

Maestro created a temporary Safebooru Topic with exact query `hatsune_miku rating:general` and selected its Home membership. Verified readable `hatsune miku rating:general` on the card, and the original underscore-form query in Details and Edit. The live detail value is combined with the `Query:` label; the initial standalone selector was corrected to that actual semantics. Checked the card/action menu and detail/edit dialogs at 360 dp width with 2x system text, opened the Topic's search, returned, and unfollowed only the temporary Topic. Screenshots: `/tmp/boorusama-acceptance/51-{topic-created-dark,topic-actions-2x,exact-query-details-2x,exact-query-edit-2x,open-search-2x}.png`.

The device pass covers this dark-theme Topic path. Light/custom/dynamic theme comparisons, Feed-member rows, and the complete operator/non-Latin/raw live matrix remain unverified on-device; automated fixtures cover their rendering/query-preservation behavior. No merge, push, closure, deletion, or combined-develop qualification occurred.

## Artist metadata and filled-chip follow-up (2026-10-23)

Artist tags previously remained neutral whenever the local category cache had no entry. The new profile/query-scoped provider first reuses cached metadata, batches only missing ordinary tags through the existing source repository, persists known returned categories, and invalidates stale local lookups. Repositories retain their existing request chunking. Unrequested/unknown results are ignored; network/cache failure preserves cached colors. Disposal cancels outstanding requests and prevents stale result persistence. Completed results remain cached for five minutes after their last listener to avoid refetching while navigating. This explicitly replaces the earlier local-only lookup decision in response to acceptance feedback. Raw/metatag values are not sent to the category endpoint.

The shared Topic/Feed card renderer now uses Kurumi compact chips with the same category background/foreground/border palette as normal tags. Unknown syntax and unknown categories use neutral chip backgrounds. Operators remain visible, custom names stay verbatim, and the raw stored/executed query is unchanged. The display remains bounded to two lines with ellipsis; long individual chips are constrained to available width. Chips ignore pointer events so their enclosing card retains its actions; the full displayed query remains available to accessibility semantics.

Checked the runtime/test tree committed with this handoff:

- `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/search/following_topics test/core/tags`: **634 passed**. Covers batched cold-cache lookup, cache reuse, normalization/deduplication, ignored unknown/unrequested results, persistence under the owning site, offline fallback, cross-profile isolation and canceled requests.
- Rendered tests cover actual filled backgrounds and foregrounds in light/dark themes, profile switching, neutral metadata failures, non-Latin/raw/metatag syntax, 160-pixel/2x layout, query preservation and card opening by tapping a chip's location. Existing Topic/Feed/action suites pass. Their shared fixture explicitly stubs metadata presentation; dedicated provider tests exercise the actual cache/repository path without network access. Updated two card-label expectations to assert the full accessible query across individual chips.
- Focused analysis of all six changed/new Dart files: **passed with 13 informational lints, no errors/warnings**. Formatting and `git diff --check` passed. Logs: `/tmp/boorusama-51-accepted-{tests,analyze}.log`. Flutter 3.47.2 / Dart 3.13.2, six test workers. Dependencies were refreshed with `fvm flutter pub get --offline` after obsolete temporary SDK paths caused the initial compile attempt to fail.

No new device run, live tag-API check or complete regression was performed for this scoped follow-up. The earlier device results describe the older text-only renderer; a new visual acceptance pass is still needed for these filled chips. A combined integration candidate needs complete verification. Local only; no merge, push, PR, issue closure or deletion.

## Inline chip sizing follow-up (2026-10-23)

Acceptance requested the height of ordinary text while retaining the category backgrounds. Removed the chip's vertical padding and outer vertical gap, reduced horizontal padding to 4 pixels, and inherited the surrounding title/body text style instead of forcing a heavier label. The outer paragraph uses the same scaled line metrics and top-aligned chip spans. Each chip scales its own text once; disabling additional WidgetSpan scaling prevents doubled enlargement at 2x text. Query/category lookup behavior is unchanged.

Pinning stores the query and optional typed tag names, not category metadata; creating a Topic does not ensure category-cache entries. Typed/pasted queries or clearing the independent category cache can therefore require the existing metadata fallback.

Checked runtime/test tree: the local commit containing this section. `fvm flutter test --no-pub --concurrency=6 --reporter=expanded test/core/search/following_topics`: **629 passed**. Six new rendered comparisons verify that both chip and complete query-line heights match ordinary inherited/body/title text at 1x and 2x. Existing narrow-width, color, offline, Topic/Feed/action and query-preservation tests pass. Focused analysis of the changed renderer/test with `--no-fatal-infos`: **passed with 9 informational test lints, no warnings/errors**. Formatting and `git diff --check` passed. Logs: `/tmp/boorusama-51-inline-{height-v5,consumers,analyze}.log`. Flutter 3.47.2 / Dart 3.13.2, six workers.

No new device run or complete regression was performed for this scoped presentation adjustment. Local only; no merge or publication. Earlier device/live/integration limits remain.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `6b700637239789ed732b5c2a32b1acb056b17275`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

Combined both title/subtitle formatting and #65's preview widget. Found and removed a later cold-cache fallback that fetched remote tag metadata solely for colors, contrary to issue #51. A zero-remote-access regression failed with one access before correction. Category resolution now reads the owning profile's local cache only, retains engine-specific empty categories, and leaves uncached tags neutral. Query serialization/execution is unchanged. Kept compact text-height chips and added w600 label weight.

The combined card fixture tests custom/unnamed titles with independent preview success/failure, separate unsupported/error status, four images, card opening and unchanged persistence/tracking requests. Maestro rendered a temporary `hatsune_miku rating:general` Topic with four loaded supported-source previews at 2x text, edited its optional name to `QA Integration Topic`, and opened the card. The executed search retained the original raw query. Unfollowed it and verified No topics yet.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
