# Danbooru Artist Page

**Status:** Approved UX direction for [Issue #64 — Refine Artist Page](https://github.com/timberpile/Boorusama/issues/64). Implementation and verification are recorded in the [task handoff](../handoffs/independent-issues-2026-10-24/64-artist-page.md); the [integration report](../handoffs/independent-issues-2026-10-28/64-artist-page-integration.md) records the final combined regression gate.

**[Open the approved standalone HTML mockup](mockups/2026-10-28-artist-page.html)** (mobile and desktop). The 2026-10-28 reference supersedes the [earlier mockup](mockups/2026-10-21-artist-page.html). Its artwork, accounts and counts are illustrative; the app uses real source data.

## Approved visual layout

- A short blurred banner reuses the newest eligible still image's grid thumbnail and cache. It remains the newest artwork when Popular is selected. If loaded posts contain no usable still, a separate image-only lookup searches until an eligible image is found or results are exhausted, respecting active hiding rules without advancing the grid. Missing or failed artwork uses a themed fallback; decorative images use the configured grid-thumbnail quality.
- Back, the existing Follow control and bulk-download/copy overflow actions overlay the banner. A neutral circular avatar overlaps its lower edge; real artist-avatar lookup remains outside this issue.
- Center the artist name above compact Aliases, Wiki and Related Tags pills. Aliases start collapsed and copy on tap. Wiki requires usable content. Related tags open a scrollable category-colored chip sheet with count/name sorting; no inline word cloud.
- Related-tag counts are tag-wide API totals, not artist intersections. Unknown/synthetic zero counts are omitted. The action counts the available, deduplicated set, capped by the existing provider.
- Compact Socials chips identify handles and account IDs without identity-resolution APIs. They use bundled site icons where available and cached favicons otherwise. A single horizontal row expands into wrapped rows; its scrollbar appears briefly while scrolling. The toggle uses right/down arrows. Full URLs remain available through tooltips and accessibility.
- One Posts heading/count, visible independent Search, grid settings and Newest/Popular sit directly above the shared PostGrid. Existing blacklist, selection, pagination and post actions remain available.
- Mobile uses one continuous profile/posts scroll view. Large screens place the independently scrollable profile beside the grid. Wrapping and normal touch targets take priority over exact mockup pixel heights at enlarged text.

## User-approved interaction

- Make the artist identity, known alternative names, external/social links and available Wiki information easier to scan above the post grid. Keep related tags accessible, offering By count and A–Z sorting with the global totals from the existing Related Tags response and no additional count requests.
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
