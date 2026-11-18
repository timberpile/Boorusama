# Pixiv Work listing verification (#174)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/174-pixiv-work-grouping`.

`SearchPage` sets `SearchProfileSession.local` for every destination-bound or
Following-origin search. That flag describes profile ownership, while
`PixivWorkSearchPage` incorrectly used it to select `DefaultSearchPage`, whose
Post repository expands Pixiv Pages. SearchParams carries queries, not cached
Post collections. Normal locally owned searches now retain native Work results.
An explicit `postResultsOnly` session contract preserves the compatibility page
for Post-only callers, independent of account ownership. No current production
caller supplies a Post collection through SearchProfileSession. Browse's native
path and the existing Work/Page mapping, Ugoira path and viewer are unchanged.

Checks on the final runtime/test tree:

- `fvm dart format lib/core/search/search/src/widgets/search_profile_session.dart lib/boorus/pixiv/works/search_page.dart test/boorus/pixiv/works/work_listing_entry_points_test.dart`: passed.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works/work_listing_entry_points_test.dart`: 9 passed, covering Browse, empty/artist/text searches in global and locally owned sessions, and the explicit Post-only fallback.
- `timeout 20s fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv/works/work_mapper_test.dart`: 6 passed, including multi-page Work count/order and Ugoira.
- `timeout 30s fvm dart analyze lib/boorus/pixiv/works/search_page.dart lib/core/search/search/src/widgets/search_profile_session.dart test/boorus/pixiv/works/work_listing_entry_points_test.dart`: no issues.
- `git diff --check`: passed.

The initial combined two-file run exceeded a 75-second compilation guard and
was interrupted; it is not counted as a pass. The two smaller final runs above
completed against unchanged code and tests.

Not run: emulator/Maestro, live Pixiv/account calls, APK build/install, Android
visual checks, complete regression suite. Owner QA: open normal and Following-
origin Pixiv searches, change query/profile, paginate and navigate Work Pages;
confirm one illustration per card and correct account, then compare Browse,
single-page Works and Ugoira. This is a source-confirmed route fix, not a claim
that the owner's exact device entry path has been reproduced or accepted.
