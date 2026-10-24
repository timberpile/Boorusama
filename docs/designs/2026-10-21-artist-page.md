# Danbooru Artist Page

**Status:** Agreed UX direction for [Issue #64 — Refine Artist Page](https://github.com/timberpile/Boorusama/issues/64). This document and mockup are design references, not Flutter implementation.

**[Open the interactive, standalone HTML mockup](mockups/2026-10-21-artist-page.html)** (single file, in-browser mobile/desktop and light/dark switches). It uses fictitious artist and post data.

## User-approved interaction

- Make the artist identity, known alternative names, external/social links and available Wiki information easier to scan above the post grid. Keep related tags accessible.
- The main follow action is labeled **Follow**, not **Follow Topic**; retain its existing function and account scope.
- **Do not add Browse Posts** at the top. Posts are already directly below the artist details.
- Above the post grid, retain the existing **Newest / Popular** ordering and add a visible **Search** action in the Posts header.
- Search opens a **separate regular Search screen**, under the artist's original profile, with the artist tag prefilled. It does not mutate the artist's Follow query.
- In Search, all ordinary tag suggestions, filters, and operators remain available. Back returns to the Artist Page at its previous scroll position and Newest/Popular choice.
- Do not embed a full Search bar, inline tag-filter row, quick-filter chip collection, or a new bottom-sheet filter into the Artist Page. The Search shortcut supplies that functionality in a familiar place.
- Reuse existing Kurumi visual language and artist tag/detail components; maintain appropriate narrow-width and enlarged-text behavior.

## Expected design checks

1. The header remains compact on a narrow Android display and displays the same sections on desktop.
2. The Search action always targets the correct artist and originating booru profile even if the global selected profile differs.
3. Navigating into and out of Search preserves the artist page's Follow status, tab/order and scroll position.
4. Empty or unavailable Wiki/social data does not create misleading placeholders, dead links or large blank sections.
5. External URLs open through the existing safe link-launch pathway.

Existing screens: `lib/boorus/danbooru/artists/artist/src/pages/artist_page.dart` and `lib/boorus/danbooru/tags/details/src/danbooru_tag_details_page.dart`.
