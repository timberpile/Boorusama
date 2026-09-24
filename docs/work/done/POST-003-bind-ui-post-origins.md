# POST-003: Bind origins for every UI-facing post fetch

Priority: High

Affected feature or branch: `feature/bookmark-post-behavior-parity`

Agent/session: Codex `/root`, 2026-09-23

Work branch: `feature/bookmark-post-behavior-parity`

Dependencies: POST-001 unified post model and mixed-booru presentation

## Problem

Parsers intentionally emit an engine-only origin. Several direct post,
artist, favorite, popular, related, and pool fetch paths still expose those raw
posts to grids or viewers, so profile resolution falls back to generic UI.

## Expected behavior

Every post crossing a UI-facing repository boundary carries the exact profile
host and profile hint that produced it.

## Acceptance criteria

- Direct single-post routes preserve the full source profile.
- Specialized artist, favorite, popular, related, and pool fetches bind the
  producing profile before their posts reach a grid or viewer.
- Regression coverage proves native origin resolution for representative raw
  and specialized fetch paths.
- Focused and full tests pass.

## Completion evidence

- Direct routes now carry the full `BooruConfig` and bind the returned post to
  its exact host and profile ID.
- Artist, favorite, popular, related-post, and pool fetches bind their posts at
  the UI repository boundary.
- Custom AnimePictures, Pixiv, Eshuushuu, Nozomi, and Moebooru feeds bind
  direct-client results with the same reusable origin boundary.
- Origin repository and direct-fetch regression tests pass, along with the
  complete 1,397-test suite.
