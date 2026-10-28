# Issue #64 — Compact Socials and artist-specific tag counts

Branch: `feature/64-artist-page`.
Baseline: `eb3437ed5ae177bdc70acf1b3cca3d9e8b77cf10`.
This separate follow-up implements the user's subsequent UI and count feedback.
The earlier redesign, identity supplement and initial polish reports are unchanged.

## Implementation

- Socials uses the standard transient scrollbar: hidden while idle, visible
  during scrolling, then faded out. The inline safe-area correction remains.
- Divider spacing above Socials is halved from 16 to 8 dp. The disclosure row is
  compact, the 4 dp title-to-links spacer and 6 dp scroll gutter are removed,
  and the 16 dp profile-to-posts spacer is removed. Link targets remain at least
  44 dp; text, icons and borders use the available space more closely.
- Socials disclosure is a right arrow when closed and a down arrow when open.
  Localized Show All/Show Less tooltips and expanded semantics remain available;
  fitting lists still omit the toggle.
- X, YouTube, TikTok, Threads and Pixiv use their existing specific brand icons
  with account/ID text only. Niconico, Lit.Link and unknown sites retain their
  site names because their current icons are generic TV/link/globe symbols.
  The URL formatter, original launch targets and full-URL accessibility remain.
- Related Tags has one fixed descending-count order, with alphabetical ties and
  unknown counts last. The sort selector and its state/callbacks are removed.
- Counts now come from the existing count repository using the exact artist and
  related tag together, in the originating profile. Global `tag.postCount` is
  never substituted. Known zero counts display zero; failed or absent counts
  remain blank. Tooltips explicitly describe this artist's posts.
- A manually declared AsyncNotifier loads counts only when the sheet opens,
  limits concurrency to three requests, deduplicates tags, and reuses results in
  the existing route/profile scope. The modal shares that scope, preserving
  navigation and avoiding a fresh count batch on every reopen. A thin progress
  indicator is visible during loading. Disposal stops new queued requests.
- Counts occupy a separate part of each chip, so a long tag ellipsizes without
  hiding its count at narrow widths or enlarged text.

Danbooru's [related-tag calculator](https://github.com/danbooru/danbooru/blob/master/app/logical/related_tag_calculator.rb)
uses a sample for frequency, so multiplying frequency by an artist total would
produce estimates for larger artists. This implementation uses intersection
count queries instead. The shared post grid, source parsing and identity/avatar
navigation implementation are unchanged.

## Verification

Checked state: the runtime/tests committed with this report, following the
baseline above. Ordinary test concurrency: six physical cores.

- Changed Dart files formatted; `git diff --check` passed.
- `./gen.sh i18n`: validation and generation passed for the updated count tooltip.
- Scoped analysis: no issues, exit 0.

  ```bash
  fvm flutter analyze --no-pub --no-fatal-infos \
    lib/boorus/danbooru/artists \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_artist_socials_test.dart \
    test/boorus/danbooru_artist_tag_counts_test.dart
  ```

- **52 tests passed, no skips, exit 0**:

  ```bash
  fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
    test/boorus/danbooru_artist_tag_counts_test.dart \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_artist_socials_test.dart \
    test/boorus/danbooru_artist_identity_test.dart \
    test/boorus/danbooru_artist_follow_test.dart \
    test/boorus/danbooru_secondary_route_scope_test.dart \
    test/core/posts/details/source_detail_facts_ui_test.dart
  ```

  Coverage includes scrollbar opacity before/during/after scrolling using the
  test clock, disclosure arrows, brand/generic labels, original URL launches,
  320 dp enlarged text, visible long-tag counts, profile-scoped exact queries,
  failed/zero counts, request concurrency and real sheet reopen without repeated
  requests. Existing Follow, Wiki, search/Back, grid and identity tests pass.

- `fvm flutter build apk --debug --flavor dev --no-pub`: passed. Flutter's
  intermediate-file invalidation required a repeat build; toolchain warnings
  remain nonfatal. No dependencies or generator infrastructure changed.

## Device evidence

Used the exclusively leased `emulator-5554` and Maestro MCP, installing with
`adb install -r` without clearing app data. The final-source APK's installed and
built SHA-256 matched:
`961c133a2a23be7c25c152ef94a90881ec971949576fdf49642843dec96ba0d2`.

- Normal phone: 720x1600, density 320, font scale 1.0. Idle Socials has no
  scrollbar, the compact arrows expand/collapse, specific brand labels are
  omitted, and generic icons retain site names. Horizontal scrolling reached
  the final Lit.Link entry during verification.
- 320 dp at 200% system text: Socials stays in one scrollable row, disclosure
  works, the Related Tags sheet scrolls, and long tags ellipsize while their
  counts remain visible. Header and close controls remain usable.
- Desktop split: 1440x1000, density 160, font scale 1.0. Both Socials modes fit
  the profile pane beside the existing navigation sidebar and shared grid.
- Live artist `ktnazm0702` has 28 posts. Related Tags now shows the artist tag at
  28, drill hair at 21, red hair at 19 and buttons at 8, in descending count
  order, with no sort selector. A close/reopen in the same scope immediately
  retained these counts. A layout/scope change can require another count load;
  the device flow waits for data rather than assuming it has already arrived.

Final-source local screenshots (temporary evidence, not app assets):
`/tmp/issue64-compact-final-phone.png`,
`/tmp/issue64-compact-final-phone-expanded.png`,
`/tmp/issue64-compact-final-320-text200.png`,
`/tmp/issue64-compact-final-320-expanded.png`,
`/tmp/issue64-compact-final-counts-text200.png`,
`/tmp/issue64-compact-final-artist-counts.png`,
`/tmp/issue64-compact-final-desktop.png`,
`/tmp/issue64-compact-final-desktop-expanded.png`.

The original size, density and text scale were restored and verified
(720x1600, density 320, font scale 1.0). The lease was released.

## Limits and delivery

The first sheet opening can make up to 30 count requests, with at most three
active, and therefore depends on network latency. Loaded results are reused in
the route/profile scope; they are not persisted across app restarts. Failed
counts remain blank. No estimated or global fallback is shown.

The full application/package/CLI/tooling regression was not rerun for this
scoped follow-up. Before merge approval, run `./scripts/run_regression_tests.sh`
against the final combined develop candidate. Native desktop and individual
external-site launches remain outside this Android/UI verification.

Changes are committed locally with `Refs #64`. No push, PR, merge or issue closure
was performed. The primary checkout and earlier handoffs remain unchanged.
