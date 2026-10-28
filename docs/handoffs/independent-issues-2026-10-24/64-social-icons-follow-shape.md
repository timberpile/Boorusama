# Issue #64 — Social icons and Follow button corners

Branch: `feature/64-artist-page`.
Baseline: `cb4ff5596b8c9f9f0c3843612581ee6a81d37c40`.
This report covers the user's social-icon and app-wide Follow shape follow-up.
Earlier Artist Page handoffs remain unchanged.

## Changes

Labelled Artist Page Socials chips previously selected from five bundled brand
icons using the profile URL parser. Other platforms always received a generic
icon; they did not attempt a favicon request. Even Pixiv fell back when the
link was an artwork, stacc page or site root instead of a recognized profile.

Branding now uses the validated URL's hostname independently of profile parsing.
Reddit, Pixiv, Patreon, Facebook, Instagram, Bluesky, Tumblr, DeviantArt and
ArtStation join the existing X, YouTube, TikTok and Threads icons. Subdomains and
listed aliases use the same bundled icon. Exact domain boundaries prevent a
lookalike hostname from receiving another site's branding. Bundled brands omit
the site name, retaining the readable account/path or an icon-only site-root
chip, as requested previously.

Other domains use the existing configuration-aware cached favicon loader at
16 dp. Its request uses the actual origin rather than attempting to infer a
different source from the URL. The hostname label remains available for these
sites, including when loading is disabled or fails. Tooltips, accessible link
labels and launch targets retain the original validated URL. No URL identity
resolution, dependencies, generated assets or grid/navigation changes were added.

The shared Follow/Following control now uses a 12 dp radius instead of the
former 24 dp stadium radius at its 48 dp height. Standalone Follow actions in
dialogs and the Following Topics empty state use 10 dp instead of the default
20 dp radius at 40 dp height. Shared constants keep the shapes consistent.
Artist pages, post details and Search reuse the shared control, including
non-Danbooru artist consumers. Button heights, hit targets, colors, follow
destinations, and state handling are unchanged. Save/Next actions and menu rows
keep their existing styles.

## Verification

Checked candidate: runtime and tests committed alongside this report, based on
the baseline above. Ordinary test concurrency: six physical cores.

- Formatted all seven changed/new Dart files; `git diff --check` passed.
- Scoped `fvm dart analyze` exited 0 with no errors or warnings. It reports six
  existing informational diagnostics in unchanged Following Topics page code
  (three brace recommendations, a redundant argument, two unawaited futures).
  Newly introduced diagnostics were fixed before the final run.
- **839 tests passed, no skips, exit 0** on the final candidate:

  ```bash
  fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
    test/core/search/following_topics \
    test/boorus/danbooru_artist_banner_test.dart \
    test/boorus/danbooru_artist_follow_test.dart \
    test/boorus/danbooru_artist_identity_test.dart \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_artist_socials_test.dart \
    test/boorus/danbooru_artist_tag_counts_test.dart \
    test/boorus/danbooru_artist_url_presentation_test.dart \
    test/core/config_widgets/website_logo_test.dart \
    test/core/posts/details/source_detail_facts_ui_test.dart
  ```

  This includes the complete following-topics directory and Artist Page
  consumers. New coverage checks bundled brands on profile/other/root URLs,
  host boundaries, a completed favicon fetch through the cache manager, failed
  fetch fallback, and original URL launch behavior. Existing checks verify
  Follow/Following theme colors, the new radius, state/actions, responsive
  Socials, scrollbar fading, narrow/enlarged layouts and keyboard-open dialogs.
  The final candidate passed after formatting and analyzer fixes; an earlier
  candidate also passed all 839 tests. Native hooks emit a nonfatal
  `File modified during build` message even on the repeated run; no tracked
  generated/runtime output changed.
- `fvm flutter build apk --debug --flavor dev --no-pub`: passed, exit 0.
  The unchanged build was repeated and passed again. Existing native-hook
  invalidation messages and Gradle/Kotlin support warnings remain nonfatal.
- Installed the final APK with `adb install -r` on exclusively leased
  `emulator-5554`, without clearing app data. Installed and built SHA-256 match:
  `7f327730ff4339716f0ac35b2924a89c5404512ba0b62538951159e1639ed5fc`.
- Maestro MCP: opened `diives` through Search, a post and Artist navigation.
  Expanded Socials and visually confirmed Reddit, Pixiv (including a non-profile
  link), Patreon and Facebook glyphs. Cached remote favicons also visibly
  loaded for Weasyl, Minds, Fur Affinity, Dropbox and SubscribeStar. Observed
  the reduced Follow corners in Search and the Artist header; opened and
  dismissed the existing folder picker without changing subscriptions, then
  collapsed Socials again.
- One exploratory Maestro assertion expected `Follow in...`; inspection showed
  the actual picker title is `Follow`. Corrected assertions for `Follow`,
  `Home`, and `Done`, dismissal and Socials collapse all passed. This was a
  test-selector mismatch, not a failed application action.
- Temporary final-source screenshot evidence:
  `/tmp/issue64-social-icons-loaded.png`,
  `/tmp/issue64-social-icons-collapsed.png`,
  `/tmp/issue64-social-follow-search.png`,
  `/tmp/issue64-social-follow-picker.png`.
  Display settings stayed 720x1600, density 320, font scale 1.0. Narrow width,
  enlarged text, desktop layout and keyboard cases are covered by widget tests.
  The emulator lease was released after the final operation.

## Limits and delivery

Bundled brand icons work without a network favicon request. Other sites still
depend on automatic image loading being enabled and the existing favicon service
being available; failure keeps a generic icon and a usable labelled link.

The full application/package/CLI/tooling suite was not rerun for this scoped
follow-up. Run `./scripts/run_regression_tests.sh` on the final combined candidate
before develop integration. No native desktop run was performed.

Local commit only, with `Refs #64`. No push, PR, merge or issue closure is
authorized by this follow-up. The primary checkout remains untouched.
