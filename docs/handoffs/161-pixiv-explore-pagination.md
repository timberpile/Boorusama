# Issue #161: Pixiv Explore pagination handoff

- Issue: https://github.com/timberpile/Boorusama/issues/161
- Branch: `bug/161-pixiv-explore-pagination`
- Base: `266a14c0f87f29213d48696bda7c806dc1d05b6e` (`develop` at preparation)
- Published implementation: `6c26e5cabc8723049bda8f6cf1121694fb8adb5a`
- Related: #162 provides bounded automatic continuation when filtered pages do not fill the viewport. #161 is independently based on `develop`.

## Implementation

Pixiv Explore now uses the existing `pixivIllustListResultToPostResult` converter, forwarding the API's `hasMore` signal even when no visible post survives filtering. The redundant repository-level exhausted-page cache is removed; the scoped `PostGridController` owns continuation and refresh state. Ranking, Following, and Recommended feed queries retain their existing parameters and origin bindings.

The new `test/boorus/pixiv_explore_pagination_test.dart` covers empty and hidden continuing pages, terminal responses, refresh after exhaustion, retrying a failed page's original offset, late terminal responses, and separate feed sessions. The code change is scoped to `lib/boorus/pixiv/explore/providers.dart`.

## Verification performed and limitations

Source and test blobs match the originally prepared Git patch objects. The earlier patch workspace passed `git diff --check` and clean patch-import checks.

**Not run:** FVM formatting, analysis, Flutter tests, Android/Maestro acceptance, complete regression, or an independent reviewer. This branch is **not** ready for integration. Keep the issue open.

## Required verification

Read the current repository `AGENTS.md` in an isolated worktree and run:

```sh
fvm dart format lib/boorus/pixiv/explore/providers.dart test/boorus/pixiv_explore_pagination_test.dart
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$workers" test/boorus/pixiv_explore_pagination_test.dart test/pixiv_explore_test.dart test/core/search/following_topics/pixiv_search_pagination_test.dart test/core/posts/listing/post_grid_controller_exhaustion_test.dart
```

Check account/profile, feed mode/date, privacy, retry and refresh isolation, and analyze affected sources. For combined acceptance, test #161 with #162, since the latter adds the shared bounded automatic fill of empty pages. Obtain an independent review, fix all valid findings, and rerun checks. Full regression on the final combined develop candidate is mandatory before merge. Do not create a PR or integrate without explicit authorization.
