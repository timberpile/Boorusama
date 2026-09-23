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
- The route handoff regression test passes with a page-local profile, and tag
  history loaded successfully from the mixed viewer on `emulator-5556`.
