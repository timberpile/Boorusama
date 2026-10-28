# Issue #64 — Safebooru counts and video-leading artist banners

Branch: `feature/64-artist-page`.
Baseline: `8eb13612dc8bea9c47beedaec989300deda0fed3`.
Follow-up to the user's Safebooru count clarification and still-image banner
request. Earlier handoffs are unchanged.

## Diagnosis and implementation

The original pagination report was clarified by the user: `diives` has nine
Safebooru results, while the unrestricted Danbooru count is 388. Public count
requests on 2026-10-28 confirmed that Safebooru's `/counts/posts.json` also returns
388 unless `rating:g` is supplied, which yields nine. The existing count
repository added that restriction only for the exact URL
`https://safebooru.donmai.us/`. Missing trailing slashes, uppercase hosts, HTTP or
explicit ports bypassed it. The regression tests reproduced these failures.

Counts now recognize the exact Safebooru hostname through URI parsing, so these
equivalent URL forms receive `rating:g`. Danbooru and lookalike hosts retain
their previous query behavior. The existing search-result and artist/tag count
consumers share this repository; no global tag metadata is rewritten.

The banner previously selected only the first visible post, and then the widget
rejected video/GIF media. A test reproduced a newest video hiding a perfectly
usable later still image. The banner now scans the filtered loaded posts for
a usable still, excluding animated media, ZIP/SWF, banned posts when hidden,
and empty thumbnail resolutions.

If the loaded page contains no usable image, a separate newest-image query uses
`filetype:jpg,png,webp,avif -animated` through the originating post repository.
It checks batches of 20 until an allowed image is found or results are exhausted.
It uses the configured grid-thumbnail resolver and quality, respects active tag
and bookmark URL filtering, and skips favorites/vote preload cascades. It does
not replace the grid's video results, change its page or move its scroll position.
Refreshes/filter changes invalidate old lookups; disposal prevents late results
from publishing or starting further pages. Failure keeps the themed fallback.

No pagination runtime change was made. During diagnosis, controlled phone and
desktop grids loaded successive full pages, and Android `kantoku` scrolling
loaded 60, 120 and 180 posts. These checks helped distinguish the clarified
count mismatch from a general pagination failure.

## Automated verification

Checked state: the runtime and tests committed with this report, following the
baseline above. Ordinary test concurrency: six physical cores.

- Changed Dart files formatted; `git diff --check` passed.
- Scoped analysis: no issues, exit 0:

  ```bash
  fvm flutter analyze --no-pub --no-fatal-infos \
    lib/boorus/danbooru/artists lib/boorus/danbooru/posts/count \
    test/boorus/danbooru_post_count_test.dart \
    test/boorus/danbooru_artist_banner_test.dart \
    test/boorus/danbooru_artist_page_test.dart
  ```

- **89 tests passed, no skips, exit 0**:

  ```bash
  fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
    test/boorus/danbooru_artist_banner_test.dart \
    test/boorus/danbooru_post_count_test.dart \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_artist_tag_counts_test.dart \
    test/boorus/danbooru_artist_socials_test.dart \
    test/boorus/danbooru_artist_identity_test.dart \
    test/boorus/danbooru_artist_follow_test.dart \
    test/boorus/danbooru_secondary_route_scope_test.dart \
    test/core/posts/details/source_detail_facts_ui_test.dart \
    test/core/search/following_topics/search_page_follow_action_test.dart
  ```

  New coverage includes URL variants and lookalikes, the rendered nine-result
  Safebooru header, skipping newest animated posts, an integrated video-only grid
  with a separate profile-scoped still lookup, multi-page candidate filtering,
  stale completions, disposal and exhausted/failed lookups. Existing responsive,
  filtering, sort, grid state, Search/Back, Follow and identity consumers pass.

- `fvm flutter build apk --debug --flavor dev --no-pub`: passed. The unchanged
  build was repeated after Flutter invalidated intermediate files; the final
  build passed. Toolchain deprecation warnings remain nonfatal.
- Localization and generated inputs did not change, so generation was not needed.

## Runtime verification

- Public, count-only requests against Safebooru confirmed `diives` gives 388
  unrestricted and nine with `rating:g`. Its rendered nine-result search header
  is covered by the widget/HTTP regression. Native UI checks used Danbooru;
  this specific URL-variant count change was not repeated in a native Safebooru
  profile UI run.
- Used exclusively leased `emulator-5554` with Maestro MCP. Installed the final
  APK with `adb install -r` without clearing data. The installed and built
  SHA-256 matched:
  `81b48493deabc0b6960da91c83e9cd92b215f03e08fac64ea03a7c9680bbfb45`.
- Opened `diives` through real Search, a newest video result, and Artist
  navigation. Its banner rendered a blurred still image above the unchanged
  video-leading grid. Newest/Popular toggles remained usable and retained the
  newest banner. Recent image-error logs showed no matching load failures.
- Final-source screenshots: `/tmp/issue64-diives-banner-final.png` and
  `/tmp/issue64-diives-banner-popular.png` (temporary local evidence).
- Display settings remained 720x1600, density 320, font scale 1.0. The emulator
  lease was released. Native desktop was not repeated; responsive layouts and
  enlarged text remain covered by the passing widget suite.

## Limits and delivery

Still-image lookup can add requests when a loaded page has no eligible image,
and may inspect further image-only pages when candidates are hidden or unusable.
Image download failures keep the decorative fallback; they do not interrupt the
grid. No release/profile performance benchmark was performed.

The full application/package/CLI/tooling regression was not rerun for this scoped
follow-up. Before integration, run `./scripts/run_regression_tests.sh` against the
final combined develop candidate. Earlier complete passes do not cover this fix.

Changes are committed locally with `Refs #64`. No push, PR, merge or issue closure
was performed. The primary checkout and earlier handoffs remain unchanged.
