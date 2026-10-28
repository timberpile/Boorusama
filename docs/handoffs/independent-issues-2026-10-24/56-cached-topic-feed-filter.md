# Issue 56: Cached Topic Feed filter

## Accepted result

- Issue: #56, Filter Cached Topic Posts.
- Task branch: `feature/56-cached-topic-feed-filter`.
- Integration base: `482ae4b1e5fd1e34b344a5c61959a210b8527281`.
- Tested runtime candidate: `fca3259693655f9ca970c930885c8f7a25f20933`.
- The user accepted the final UI and authorized integration on 2026-10-27.
  This report update changes documentation only.

The feed's top-app-bar Search action reveals a compact Bookmark-style filter,
which starts hidden. The open action displays a magnifier with a small corner X
and a localized Close Search tooltip without changing its bounds. The input has
no leading magnifier; its English placeholder is `Search Cached Posts...`. Source
choices and the selected source display the standard site favicon; All uses the
globe icon. Hiding the controls dismisses the keyboard, clears draft/tag/source
filters, and restores normal feed pagination.

Exact positive tags are ANDed; negative tags exclude matches. Filtering uses
persisted feed snapshots only and preserves saved Topic queries/checkpoints.
The filtered controller returns all local results on page one, terminates later
pages, and displays an appropriate empty state. This page's initialization,
history prefetch, Load Older Posts, and Refresh are gated while filtering.
Already dispatched requests may finish; independent background refresh is not
globally disabled. Posts discovered only in temporary history buffers are not
included, and scroll position is not retained across filter changes.

Suggestions and counts use posts matching the selected source and committed
positive/negative tags. Draft typing does not alter the active filter. Editing a
tag excludes that tag from the suggestion scope so replacements remain available
within the other filters. Removing tags broadens suggestions; refreshed snapshots
update an open list. Source-wide vocabulary preserves readable multiword tag
commits even when the filtered result is empty. The bounded, lazy suggestion list
scrolls independently of the feed and has no five-tag truncation.

Suggestions and chips share Bookmark offline category coloring, including saved
per-origin categories, configured palettes, dynamic colors, and locally cached
category metadata resolved under each origin profile's URL/installation path.
Unknown or conflicting categories remain neutral. No remote tag lookup,
credentials, schema, migration, or backup state is added.

## Verification

- `./gen.sh i18n`: validation and generation passed. The i18n package has no test
  suite; ignored generated output was current for the tested candidate.
- Changed-file `fvm dart format` and `git diff --check`: passed.
- Affected-file analysis: 0 errors, 0 warnings, 2 existing informational guard-style
  diagnostics in `topic_feeds_page.dart`.
- Focused filter/feed/widget checks: 52 passed. These cover source icons, action
  icon/bounds, category colors, contextual counts, positive/negative/source
  combinations, tag editing/removal, snapshot refresh, default-hidden controls,
  clearing/history restoration, unchanged saved Topic data, and scrolling through
  20 tags at 320px width with 1x/2x text and an open keyboard.
- Affected Following Topics/Bookmarks/tag-color regression: 1,311 passed.
- Complete integration gate: `./scripts/run_regression_tests.sh`, using the
  detected six physical cores, completed successfully on 2026-10-28:
  application 5,352 passed; all 13 package/CLI suites 1,603 passed; the two existing
  go_router skips were retained; both repository shell suites and all 72 Python
  tooling tests passed. No runtime or test changes followed this complete pass.

The user provided final UI acceptance. No additional emulator/Maestro run was
performed for the final UI follow-ups or this integration. Preserved local
artifacts and the complete gate log are outside the task worktree under ignored
`artifacts/issue56-integration-2026-10-27/`; the pre-existing APK is preserved
without claiming it was built from this final runtime candidate.
