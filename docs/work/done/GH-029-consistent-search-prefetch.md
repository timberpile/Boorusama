# GH-029: Consistent search prefetch distance

- Priority: Normal
- Affected feature: Infinite-scroll post listings
- Work branch: `fix/29-consistent-search-prefetch`
- Agent/session: Codex, current session

## Problem

The next page of a new search starts loading too close to the end, while later
pages start progressively earlier because the trigger uses a percentage of the
entire accumulated scroll extent.

## Expected behavior

Infinite-scroll listings start fetching at a consistent remaining distance,
before the user reaches the end of the loaded posts.

## Acceptance criteria

- [x] The next page starts loading with one viewport of content remaining.
- [x] The trigger distance is consistent for the first and later pages.
- [x] Focused and full automated tests pass.

## Context

- GitHub issue: https://github.com/timberpile/Boorusama/issues/29
- Dependencies: None

## Progress

- Added a regression test covering first-page and accumulated-page scroll
  extents; both cases failed against the percentage-based trigger.
- Replaced the percentage trigger with a one-viewport `extentAfter` trigger;
  the focused regression test passes.
- Verified the fresh-search flow on Android with Maestro: a 60-post search
  fetched more results while loaded content remained below the viewport.
- `fvm flutter analyze` completed with no issues.
- The full Flutter test suite passed with 1,268 tests.
- The dev Android debug APK built successfully for x64.
