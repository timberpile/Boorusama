# Issue #64 — Artist identity and avatar navigation supplement

Branch: `feature/64-artist-page`.
Baseline: `d6a3e37fea1d8667ca99b28648c547a2f6072c8c` (the completed Artist Page redesign).
Status: supplemental implementation completed and verified with focused tests locally on 2026-10-28. The main redesign handoff is unchanged.

## Changes

- The post-details Artist section renders its existing placeholder avatar, artist tags and applicable actions whenever at least one valid artist tag exists, including `NoSource` and `NonWebSource`. Blank tags are ignored without normalizing valid tags. Empty artist sets retain commentary without inventing a profile.
- Only a usable HTTP(S) WebSource supplies the optional external subtitle. Pixiv sources retain their existing artwork URL; no profile URL, avatar lookup, scraping or network dependency was introduced.
- Danbooru supplies the existing `goToArtistPage` callback through a scoped ConsumerWidget. A single artist avatar opens that exact tag, preserving underscores, case, non-ASCII characters and the originating configuration independently of the global profile.
- Multiple artists open a bounded, scrollable Kurumi popup containing explicit artist choices. No arbitrary first artist is opened. The avatar keeps its existing circular placeholder, with a 48 dp tap region and localized View Artist tooltip/semantics.
- SourceLink exposes an optional avatar wrapper; generic source rendering contains no artist routing. External subtitle taps/long presses, Follow/Following and translated commentary controls remain separate. No Artist Page banner, posts grid, following persistence or unrelated engine code was changed.

## Verification

Checked state: the supplemental runtime/test content committed with this report, following baseline `d6a3e37fe`. Only this report was added after the final test/analysis pass.

- `fvm dart format` on the three changed runtime files and the new identity test: passed.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos` on those four files: no issues, exit 0.
- Focused Flutter run at detected physical-core concurrency 6: **42 passed, no skips, exit 0**:

  ```bash
  fvm flutter test --no-pub --concurrency="$(python3 scripts/physical_core_count.py)" \
    test/boorus/danbooru_artist_identity_test.dart \
    test/boorus/danbooru_artist_follow_test.dart \
    test/boorus/danbooru_artist_page_test.dart \
    test/boorus/danbooru_secondary_route_scope_test.dart \
    test/core/posts/details/source_detail_facts_ui_test.dart
  ```

The 14 new cases cover missing/non-web/web/Pixiv/invalid web sources; absent/blank artists; exact-tag routing from a non-global profile; external subtitle launches independent of internal navigation; the existing Follow picker; explicit multi-artist selection; commentary switching; 320 dp at 200% text and 1200 dp layouts, including keyboard insets and non-overlapping controls. HTTP/external dependencies and routing are controlled in the tests; no live service request is required.

`git diff --check` passed. Existing Follow and source-detail consumer tests also passed independently during implementation. No localization inputs changed, so generation was unnecessary.

## Remaining acceptance and delivery boundary

No new Android/device or native desktop run was performed for this supplement; actual post-details avatar taps and the chooser can still be checked manually on a device. The earlier redesign's complete regression/device results describe its baseline only. Before any integration, the final combined candidate must pass `./scripts/run_regression_tests.sh` against the intended develop base; that full combined gate was not rerun for this scoped follow-up.

Changes are committed locally on the existing task branch with `Refs #64`. No push, PR, merge, issue closure or branch/worktree cleanup was performed.
