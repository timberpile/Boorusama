# Issue #64 — Artist Page UI polish

Branch: `feature/64-artist-page`.
Baseline: `c237a26478dc442b027ef1b65fc8b07f9dfa5e19`.
Status: scoped implementation and verification completed locally on 2026-10-28.
This report supplements the original redesign and Artist identity handoffs;
neither earlier handoff was changed.

## Changes

- Back stays at the banner's safe leading edge; Follow and overflow now align
  together at the safe trailing edge. Existing Follow behavior is reused.
- The localized overflow action reads **Copy Artist Tag** and copies the exact
  original search tag, including underscores and Unicode, with existing feedback.
- Profile disclosures now read **Aliases** and **Socials**. Counts, aliases,
  Wiki and Related Tags retain their existing data and interactions.
- Socials defaults to one horizontal scrolling row containing every usable URL.
  Show All expands into a wrapping list; Show Less restores the row. Lists that
  fit omit the toggle. Compact 16 dp icons, bounded single-line labels, padded
  48 dp button regions, full-URL tooltips and link semantics keep links usable.
- A pure Artist-local formatter recognizes X handles and user IDs, YouTube
  handles/channel IDs/legacy custom and user paths, TikTok, both Threads domains,
  Niconico, Lit.Link and Pixiv. Domain matching respects label boundaries.
  Unknown HTTP(S) sites and non-profile pages remain available as generic links.
  Distinct X and YouTube account links remain separate. Validated original URLs
  use the existing external launcher unchanged; active-URL and normalized
  duplicate filtering remain in place.
- Unsupported schemes, embedded credentials and malformed URLs are skipped.
  Final review reproduced a malformed legacy Pixiv query throwing on invalid
  UTF-8; decoding is now guarded and the regression is tested.
- Android inspection found a scrollbar painting over chip text because it
  inherited the page's system bottom inset. The inline control now removes that
  redundant inset, with the scrollbar below its chips.

Brand icons reuse the existing Font Awesome dependency; no dependency, generic
post-source parser, shared PostGrid or identity-navigation implementation changed.
The formatter uses URL contents only, with no scraping, redirect resolution or
account API requests. URL forms were checked against the official
[YouTube channel URL documentation](https://support.google.com/youtube/answer/6180214)
and [Meta's Threads web announcement](https://about.fb.com/news/2025/04/new-features-threads-web-experience/).
New English strings use the existing localization fallback for untranslated locales.

## Automated verification

Checked state: the runtime and tests committed with this report, following
`c237a2647`. Report-only edits do not change the checked runtime candidate.
Detected ordinary test concurrency: **6 physical cores**.

- `./gen.sh i18n`: localization validation and generation passed. No other
  generator inputs changed. The i18n package has no test suite.
- `fvm dart format` on all changed Dart files: passed.
- Pure formatter tests: **55 passed, no skips, exit 0**.

  ```bash
  fvm dart test --concurrency="$(python3 scripts/physical_core_count.py)" \
    test/boorus/danbooru_artist_url_presentation_test.dart
  ```

- Artist UI and nearby consumer tests: **49 passed, no skips, exit 0**.

  ```bash
  fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_artist_socials_test.dart \
    test/boorus/danbooru_artist_identity_test.dart \
    test/boorus/danbooru_artist_follow_test.dart \
    test/boorus/danbooru_secondary_route_scope_test.dart \
    test/core/posts/details/source_detail_facts_ui_test.dart
  ```

  These cover known/unknown URL launches preserving each original target, unsafe
  URL exclusion, 320 dp at 1x/2x text, one-row reachability, redundant-toggle
  suppression and resize behavior, trailing header geometry with safe insets,
  exact Unicode tag copying and feedback, metadata disclosure, Wiki/Related Tags
  route scope, post-grid state across layout changes, Follow and post-details
  source-independent Artist identity/avatar navigation.

- Scoped analysis: **no issues, exit 0**.

  ```bash
  fvm flutter analyze --no-pub --no-fatal-infos \
    lib/boorus/danbooru/artists \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_artist_socials_test.dart \
    test/boorus/danbooru_artist_url_presentation_test.dart
  ```

- `fvm flutter build apk --debug --flavor dev --no-pub`: passed. Flutter's
  intermediate-file invalidation required a repeat build; the final build
  completed independently after tests. Toolchain deprecation warnings remain.
- `git diff --check`: passed.

## Android rendering and interactions

Used exclusively leased `emulator-5554` with Maestro MCP, installing the debug
dev APK with `adb install -r` without clearing app data. Live artist:
`ktnazm0702`, with 28 posts, two aliases, 30 related tags and eight Socials links.

- Default phone: 720x1600 physical, density 320 (360 dp), system font scale 1.0.
  Header actions aligned correctly; Socials occupied exactly one row. Horizontal
  swipes reached the final Lit.Link entry. Expansion showed all eight links,
  including separate X handle/ID and YouTube channel/handle entries. Show Less
  returned to one row. The corrected scrollbar stayed below the text.
- 320 dp: density 360 at the same physical size; checked at font scales 1.0 and
  2.0. Header controls, Socials expansion/collapse and the copy menu remained
  usable with no visible overlapping controls. Follow opened its existing picker,
  which was dismissed without changing subscriptions.
- Desktop split: 1440x1000 at density 160, font scale 1.0. The existing navigation
  sidebar, Artist profile sidebar and shared post grid rendered together. Both
  collapsed and expanded Socials fit their pane. Popular and scoped Search
  navigation worked; Search retained the artist query and showed 28 results.
  Search remained usable with the software keyboard open; Back returned to the
  Artist Page.
- Copy Artist Tag and existing Copied feedback were exercised on Android;
  exact underscores/Unicode clipboard content is verified by the widget test.
  Alias disclosure and the Related Tags sheet were exercised on Android.

Local screenshot evidence (temporary files, not published artifacts):
`/tmp/issue64-polish-phone-collapsed.png`,
`/tmp/issue64-polish-phone-last-social.png`,
`/tmp/issue64-polish-phone-expanded.png`,
`/tmp/issue64-polish-copy-menu.png`,
`/tmp/issue64-polish-aliases.png`,
`/tmp/issue64-polish-phone-320.png`,
`/tmp/issue64-polish-phone-320-large-text.png`,
`/tmp/issue64-polish-phone-320-large-expanded.png`,
`/tmp/issue64-polish-phone-320-large-menu.png`,
`/tmp/issue64-polish-desktop-collapsed.png`,
`/tmp/issue64-polish-desktop-expanded.png`,
`/tmp/issue64-polish-search-desktop-keyboard.png`.

The rendering matrix preceded the final malformed-query guard; that guard does
not change valid-link presentation. Automated suites and the APK build were
rerun afterward.

The final APK was then reinstalled and smoke-tested through the real post to
Artist navigation, Aliases/Socials rendering, Show All/Show Less and Copy Artist
Tag with Copied feedback. Final-source screenshot:
`/tmp/issue64-polish-final-phone.png`. Built and installed APK SHA-256 matched:
`0e65dced90d83ffd586143ab9bc9791bf0b66ae6627b01a6a7639e71bf844c8d`.
Original display settings were restored and verified (720x1600, density 320,
font scale 1.0); the emulator lease was released after the final smoke check.

## Remaining limits and delivery boundary

- Desktop verification used Android at desktop logical dimensions, not a native
  desktop build or physical mouse/keyboard.
- Every required URL pattern was tested against the injected external launcher;
  external websites and installed third-party apps were not individually opened.
- This artist has no Wiki action; Wiki routing is covered by scoped widget tests.
  The earlier identity supplement is covered by its regression tests; its full
  multi-artist chooser matrix was not repeated on Android during this polish.
- The complete application/package/CLI/tooling regression was not rerun for this
  scoped follow-up. Before merge approval, run `./scripts/run_regression_tests.sh`
  on the final combined candidate against the intended develop base. Earlier
  redesign results do not qualify these newer changes for integration.

Changes are committed locally with `Refs #64`. No push, PR, merge, issue closure
or branch/worktree cleanup was performed. The primary checkout is unchanged.
