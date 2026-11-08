# Issue #160: viewport thumbnail prefetch handoff

- Issue: https://github.com/timberpile/Boorusama/issues/160
- Branch: `feature/160-viewport-thumbnail-prefetch`
- Base: `266a14c0f87f29213d48696bda7c806dc1d05b6e` (`develop` at preparation)
- Published implementation: `2ad0873a0ed195c3db3d6f633818795afc3d58df`
- Related: #162 builds on this implementation.

## Implementation

The shared post grid defaults to `ScrollCacheExtent.viewport(1)`, measured against its actual scrollable viewport. The old fixed-pixel provider is no longer consulted for the default, while explicit pixel overrides remain supported. Pixiv Favorites removes its screen-height / 1200 dp override. The engine-specific media URL, media-quality, and image-cache paths are unchanged; page pagination is separately tracked in #162.

Changes: `lib/core/posts/listing/src/_internal/raw_post_grid.dart`, `lib/core/posts/listing/src/widgets/post_grid.dart`, `lib/boorus/pixiv/favorites/page.dart`, and two widget-test files.

## Verification performed and limitations

The patch was imported onto an actual GitHub `develop` parent through the GitHub Git API. The changed file contents and relevant test blobs were checked against the prepared Git object IDs. The earlier isolated patch workspace passed `git diff --check` and a combined mail-patch import check.

**Not run:** FVM formatting, Dart analyzer, Flutter/widget tests, Android/Maestro scenarios, the complete local regression suite, and independent review. There is no verified integration candidate. Do not merge or close the issue yet.

## Required verification

Use an isolated worktree for this branch, read current `AGENTS.md`, and run:

```sh
fvm dart format lib/core/posts/listing/src/_internal/raw_post_grid.dart lib/core/posts/listing/src/widgets/post_grid.dart lib/boorus/pixiv/favorites/page.dart test/application/timeline_thumbnail_cache_test.dart test/boorus/pixiv_favorites_page_lifetime_test.dart
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$workers" test/application/timeline_thumbnail_cache_test.dart test/boorus/pixiv_favorites_page_lifetime_test.dart test/core/posts/listing test/core/images
```

Review the cold/warm thumbnail requests and scrolling in both directions on Gelbooru, Realbooru, and Pixiv Favorites, including grid size/layout changes, constrained panes and high-quality Realbooru format probes. Capture actual performance and limits rather than inferring network success from the cache-extent assertions. Arrange an independent reviewer and address findings. Before integration, reconcile the combined candidate with current `develop` and pass `./scripts/run_regression_tests.sh`. A PR/merge requires explicit authorization.
