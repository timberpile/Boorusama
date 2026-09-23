# POST-001: Unify post models and mixed-booru presentation

Priority: High

Affected feature or branch: `feature/bookmark-post-behavior-parity`

## Problem

Search and server favorites use native engine post types, while bookmarks and
Following Feeds persist reduced representations. The same upstream post loses
engine-specific fields, grid decorations, viewer sections, and interactions
outside its native listing. Exact generic post contexts also prevent one
viewer from safely displaying posts from different engines.

## Expected behavior

- Search, favorites, bookmarks, and feeds use one runtime `Post` model.
- Engine-specific data is retained in typed payloads and persisted through
  versioned snapshots where required.
- Shared grids render the same post presentation in every container.
- One viewer swipes continuously through mixed booru posts and changes profile,
  media behavior, details, and interactions per page.
- Invalid or unavailable native data falls back to cached common data, a
  localized warning, and safe generic UI.
- Existing local bookmarks migrate, and version-1 bookmark backups remain
  importable through a localized compatibility adapter.

## Acceptance criteria

- Every registered image-post engine passes common/payload snapshot contract
  tests without losing meaningful fields.
- `BookmarkPost` and `CachedFeedPost` are no longer shipped runtime models.
- Search, server favorites, bookmarks, and feeds share grid and viewer
  presentation contracts.
- Mixed Danbooru, e621, Pixiv, and fallback posts use the correct origin
  profile and UI while swiping in one viewer.
- Bookmark group and feed refresh semantics remain unchanged.
- Focused tests, full tests, analysis, diff validation, and Android Maestro
  verification pass.

## Context and constraints

- Design: [Unified Post Model and Mixed-Booru Viewer](../../superpowers/specs/2026-09-22-unified-post-model-and-viewer-design.md)
- The abandoned `feature/feed-post-rendering-parity-investigation` branch is
  reference material only and is not an implementation base.
- Credentials and provider state must never be stored in posts or backups.
- No new engine actions or feed-engine support are included.

## Claim

- Agent/session: `/root`, current Codex session
- Work branch: `feature/bookmark-post-behavior-parity`

## Progress

- Design requirements reviewed and approved with the user.
- Fresh worktree created from `origin/develop`.
- Baseline `fvm flutter test` passed with 1,252 tests.
- Implemented one final runtime `Post` with engine-neutral core data, origin,
  and typed engine payloads. Parser-only records no longer cross repository
  boundaries; `BookmarkPost`, `CachedFeedPost`, `UnifiedPost`, and `SimplePost`
  are removed.
- Registered snapshot codecs and native presentations for every image-post
  engine. Search, favorites, bookmarks, and feeds now share post-card and
  mixed-viewer presentation boundaries.
- Bookmarks and Following Feeds persist versioned post snapshots. Existing
  local rows migrate without inventing engine fields, and bookmark backup
  version 1 remains readable through the localized import adapter.
- Added reason-specific localized fallback UI. Missing engines use the generic
  image client, so cached/legacy posts remain navigable instead of rendering a
  repository exception.
- Profile-specific home and Danbooru listing repositories now attach the exact
  host and profile ID before rendering. Scoped theme providers declare their
  dynamic-profile dependencies, so native detail chips can switch profiles
  after the same provider was already read by another page.

## Verification

- `fvm flutter test --no-pub test/core/posts test/core/bookmarks test/core/search/subscriptions test/core/backups test/core/http/client/dio_for_widget_provider_test.dart test/boorus/posts`: 631 tests passed.
- `fvm flutter test --no-pub`: 1,353 tests passed.
- Focused analysis of every final touched Dart file reports no issues. Full
  `fvm flutter analyze --no-pub` reports 234 info-level lints and no errors or
  warnings.
- `git diff --check`: clean.
- Android dev APK built and installed successfully on `emulator-5554`.
- Maestro opened an existing 60-post legacy list whose profiles no longer
  exist. The grid loaded through the generic client, posts opened and swiped,
  the missing-profile warning stayed visible, and generic tags and file
  details remained usable.
- Widget coverage verifies one viewer switching among Danbooru, e621, Pixiv,
  and fallback pages without changing the globally selected profile, plus
  native bookmark and feed presentation behavior.
- Maestro loaded real Danbooru and anonymous e621 home results, bookmarked one
  post from each profile, and opened the resulting two-engine bookmark list.
  The first page exposed e621's Comments action; after one swipe, the same
  viewer exposed the Danbooru artist and removed Comments without an exception
  or fallback warning.

All acceptance criteria are verified.

## Reopened verification

- Manual review found a duplicated bookmark-viewer toolbar, live removal
  invalidating the open page, source logos falling back to a globe, and
  versioned bookmarks with a missing origin host opening in the fallback UI.
- Native presentations now own their toolbar without bookmark decoration. The
  bookmark toolbar is retained only for the generic fallback presentation.
- Bookmark details snapshot their mixed post list. Target-aware bookmark
  changes are queued without publishing viewer state, cancel on a second tap,
  and commit idempotently only after the details route closes. Commit failures
  do not block later changes and surface as a soft warning. The bookmark grid
  coalesces its refresh until the viewer closes, including when navigation
  replaces the source page.
- Bookmark cards resolve the exact origin profile and its custom icon. Bare
  source hosts are normalized as web URLs, including hosts with ports and IPv6
  literals.
- New and stored versioned snapshots recover a missing origin host from their
  generated or persisted post URL and rewrite the repaired snapshot. Decode
  failures keep their original versioned payload intact while using the safe
  generic fallback.
- Focused bookmark and mixed-viewer suites passed 124 tests. The final full
  `fvm flutter test --no-pub` run passed 1,370 tests.
- Focused analysis of the final regression files reports no issues. Full
  `fvm flutter analyze --no-pub` still reports the known 234 info-level lints
  and no errors or warnings. `git diff --check` is clean.
- Maestro verified Gelbooru and Danbooru profile icons in the mixed bookmark
  grid, one native Danbooru toolbar, no Riverpod dependency error, a stable
  image during deferred removal, second-tap cancellation, and the bookmark
  count changing only after leaving the viewer.

The reopened acceptance criteria are verified.
