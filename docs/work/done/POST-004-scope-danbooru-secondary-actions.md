# POST-004: Keep Danbooru secondary actions on the post profile

Priority: High

Affected feature or branch: `feature/bookmark-post-behavior-parity`

Agent/session: Codex `/root`, 2026-09-23

Work branch: `feature/bookmark-post-behavior-parity`

Dependencies: POST-001 unified post model and mixed-booru presentation

## Problem

Tag-history routes and favorite-group sheets opened from a mixed viewer can
leave its page-local profile scope and then query or mutate the globally
selected Danbooru profile.

## Expected behavior

Danbooru routes and sheets launched for a post carry and install that post's
resolved `BooruConfig`, including nested sheets.

## Acceptance criteria

- Tag history uses the viewed post's profile for images and network requests.
- Favorite-group selection and creation use the viewed post's profile.
- Tests cover a viewed Danbooru profile different from the global profile.

## Completion evidence

- Tag-history route data carries and installs the page-scoped profile.
- Favorite-group selection, creation, and editing sheets install the supplied
  profile, including the nested creation sheet.
- Comments, searches, artists, characters, tag sheets, editors, user pages,
  voter/favoriter lists, and wiki pages carry and install the launching profile.
- Providers reached from those scoped pages declare their current-profile
  dependencies, so Riverpod rebuilds them in the page-local container instead
  of raising an override assertion.
- The route handoff regression test passes with a page-local profile, and tag
  history and the reported Danbooru search/details/back flow loaded successfully
  on `emulator-5556`.
- The complete 1,392-test suite passes.
