# IDEA-017: Danbooru single-artist follow

- Priority: Normal
- Affected feature/branch: Danbooru post artist information / `feature/danbooru-artist-follow`
- Problem: Danbooru post artist information does not expose the existing Following Feed membership control.
- Expected behavior: Show an icon-free, rounded filled Follow/Following pill beside artist information only when a post has exactly one artist tag. Keep the existing artist link, commentary, and source presentation.
- Acceptance criteria:
  - No Follow control appears for zero artist tags.
  - The existing Follow control appears for exactly one artist tag and follows that exact tag.
  - No Follow control appears for multiple artist tags.
  - Existing artist information, commentary, and source presentation remain available.
- Relevant context: `docs/pinned_searches.md`; Following Feeds reuses exact single-tag query identity.
- Dependencies: None.
- Agent/session: `/root/implement_17`
- Work branch: `feature/danbooru-artist-follow`

## Progress

- Added an optional inline action slot to shared artist information. Danbooru supplies the existing `FeedFollowButton` only for one artist tag; other engines retain their previous presentation.
- TDD red: the focused widget test failed to compile because the inline action API was absent.
- TDD green: focused 0/1/2 artist-tag widget cases pass and assert Follow visibility/query, artist labels, source URL, and commentary.

## Completion evidence

- `fvm flutter test --no-pub test/boorus/danbooru_artist_follow_test.dart`: passed, 3 tests.
- `fvm flutter test`: passed, 1,487 tests before the final component-boundary refactor.
- Final refactor full suite (`fvm flutter test --no-pub`): 1,485 passed and one unrelated failure: `test/bulk_downloads/providers/downloads/session_test.dart`, “Session Resume should mark dry run session as pending when interrupted”. Rerunning that test file passed all 33 tests.
- `fvm flutter analyze --no-pub`: 227 info findings, equal to the 227 base findings.
- `git diff --check`: passed.
- Acceptance: exact one artist tag displays the existing Follow control for that tag; zero and multiple tags omit it; artist labels, source URL, and commentary remain visible.
- Final gate emulator validation was performed on `emulator-5556`; see the final gate evidence below.

## Review round 1 correction

- Moved the Follow action into the artist `SourceLink` tile's trailing action area. When translated commentary is available, the translation popup and Follow button share a wrapping trailing layout; source, artist label, and commentary remain on the same section.
- Added bounds-based cases at 320dp width and 2x text scale. Both failed before the layout fix because Follow bounds did not overlap the artist tile; both pass after the fix. The cases also verify the translation popup remains visible and no layout exception occurs.
- Final focused tests: `fvm flutter test --no-pub test/boorus/danbooru_artist_follow_test.dart` passed (5 tests).
- Final analyzer: 227 info findings, equal to the base.
- Final emulator check: dev APK built from this worktree and installed on `emulator-5556`; relaunched without clearing app state. Maestro hierarchy reports artist tile bounds `[0,1130][1080,1298]` and Follow button bounds `[798,1151][1049,1277]`. Screenshot is embedded in the Maestro MCP transcript; the screenshot tool did not return a filesystem path. No shared account state was changed.
- Final `git diff --check`: passed. Full suite was not rerun during this review round; the previous final full-suite run had one unrelated download-session failure, whose isolated file rerun passed all 33 tests.

## Final gate

- Focused widget suite: `fvm flutter test --no-pub test/boorus/danbooru_artist_follow_test.dart` passed all 5 tests.
- Isolated full suite: `fvm flutter test --no-pub` passed all 1,489 tests.
- Analyzer: `fvm flutter analyze --no-pub` reported 227 info findings, matching the 227 base findings.
- Build: `fvm flutter build apk --debug --flavor dev --target-platform android-x64` passed and installed on `emulator-5556`. Initial build attempt could not update the read-only FVM engine cache; approved cache access allowed the same build to pass.
- Normal live layout on `emulator-5556`: the exact-one artist `fuyuichi` appeared with Follow inside its `SourceLink` row. Hierarchy bounds were artist row `[0,1130][1080,1298]`, Follow `[798,1151][1049,1277]`; screenshot is embedded in the Maestro transcript.
- Narrow/large-text live layout: temporarily set display override to 840x2400 at density 420 (320dp logical width) and system font scale 2.0. Hierarchy showed row `[0,1298][840,1534]`, Follow `[519,1353][809,1479]`, confirming the button stayed inside the row. The same post had original-only Japanese commentary, so no translated popup was available live; widget geometry tests verify the translation popup remains available alongside Follow and that neither layout throws.
- Restored emulator-5556 font scale to 1.0 and display to 1080x2400; density stayed at 420. No Follow action or account membership changes were made. Zero/multiple artists remain verified by widget tests.
- `git diff --check`: passed after final code verification.

## Follow-up: compact artist pill

- User-approved appearance: the inline Follow/Following control uses a compact filled pill without the feeds icon or membership-count badge. Colors come from the active theme; the membership picker and localized state labels remain available.
- Scoped the presentation to the Danbooru inline row through the existing shared control. Other placements retain their current presentation.
- TDD red: the focused suite passed its three artist-cardinality cases and failed four appearance/layout cases because the feeds icon was present.
- Focused verification: all seven widget tests passed, including both follow states, custom theme colors, accessible tap semantics, membership picker contents, zero/one/multiple artists, narrow width, and enlarged text.
- Full-suite and emulator follow-up verification are coordinated by the root agent separately.
