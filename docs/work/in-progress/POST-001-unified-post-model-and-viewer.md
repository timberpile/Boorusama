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
