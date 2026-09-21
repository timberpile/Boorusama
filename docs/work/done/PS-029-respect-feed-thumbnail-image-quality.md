# Respect image-quality settings in feed thumbnails

Priority: Normal

Affected feature: Following-feed overview and cached feed grid

Agent/session: Codex `/root`

Work branch: `fix/feed-thumbnail-image-quality`

## Problem

Feed previews and cached feed grids always render `thumbnailImageUrl` directly.
Changing the image-grid quality setting therefore has no effect on feeds, even
though regular post grids select thumbnail, sample, or original media through
the configured grid-thumbnail resolver.

## Expected behavior

Feed thumbnails use the same image-quality, grid-size, animated-media, and
engine-specific URL-selection rules as regular post grids.

## Acceptance criteria

- [x] Feed overview previews use the configured grid-thumbnail media resolver.
- [x] The opened feed grid uses the configured grid-thumbnail media resolver.
- [x] Higher-quality settings no longer force `thumbnailImageUrl`.
- [x] Low quality continues to select thumbnail variants.
- [x] Focused widget tests, the full test suite, analysis, and diff checks pass.
- [x] The Android feed UI is checked with Maestro when available.

## Relevant context

- `lib/core/search/subscriptions/src/pages/following_feeds_page.dart`
- `lib/core/posts/listing/src/providers/providers.dart`
- `lib/core/posts/listing/src/types/grid_thumbnail_url_generator_default.dart`

## Progress

- Confirmed both feed surfaces bypass the shared resolver by passing
  `thumbnailImageUrl` directly to `BooruImage`.
- Fresh-worktree generation and the 1,241-test baseline pass.
- Added a shared feed-thumbnail widget that resolves media through the regular
  grid-thumbnail providers and used it on both feed surfaces.
- Verified low and high URL selection with widget tests, including the feed
  overview path.
- Preserved engine-specific media variants in cached posts so Automatic
  quality continues to select Danbooru's 180/360/720 URLs by grid size.
- `fvm flutter test` passes all 1,248 tests; `fvm flutter analyze` and
  `git diff --check` also pass.
- Built and installed the Dev Android APK. With Image quality set to High,
  Maestro confirmed both the following-feed overview previews and an opened
  cached-feed grid render successfully.
