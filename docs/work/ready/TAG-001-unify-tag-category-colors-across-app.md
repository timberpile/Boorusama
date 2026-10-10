# Unify category-colored tag presentation across the app

Priority: Normal  
Affected feature: Tag autocomplete, selected-tag chips, bookmark search, and other tag-bearing UI  
Status: Unclaimed

## Problem

Tag category styling is inconsistent between search suggestions, selected tags, bookmark search, and other places where users interact with tags. Users should be able to recognize Artist, Character, Copyright, General, Meta, and supported site-specific categories consistently.

## Expected behavior and acceptance criteria

- [ ] Audit tag-presenting surfaces and use the same category-color semantics for visible tag names/chips, including **normal search autocomplete**, **bookmark search autocomplete**, **selected search-tag chips**, and applicable bookmark tag views.
- [ ] Reuse or centralize the existing `TagColorGenerator`, tag category resolution, and theme-aware tag colors instead of duplicating independent hard-coded mappings. Respect booru-specific category semantics and light/dark themes.
- [ ] For tag chips already showing an operator such as `-`, retain a visually distinct operator while applying the proper category styling to the tag itself; do not lose existing editing, removal, count, or context-menu interactions.
- [ ] Tag color resolution must use available category metadata and caches. **Do not introduce network requests solely to color tags.** If category metadata is missing or unknown, show a neutral, readable fallback rather than a misleading category color.
- [ ] For bookmark groups or mixed-profile content, do not infer category meaning from an unrelated currently selected profile; respect the tag's known owning site/profile context where possible.
- [ ] Focused tests cover category mapping, unknown categories, theme changes, autocomplete and selected chips in both normal and bookmark search, and usability at narrow width / enlarged text. Existing query/filter behavior remains unchanged.

## Context and constraints

Bookmark autocomplete already attempts color resolution with `booruTagTypeStoreProvider` and `tagColorGenerator()`, but styling is not consistently applied across all tag UI. Normal search `SelectedTagChip` presently colors operators/metatags yet uses a generic foreground color for the tag text. Extend existing mechanisms rather than assuming the app has no color support.

- [Tag color generator](../../../lib/core/tags/tag/src/tag_color_generator.dart)
- [Tag category provider](../../../lib/core/tags/categories/src/tag_category_providers.dart)
- [Shared TagChip](../../../lib/core/posts/details_parts/src/tags/tag_chip.dart)
- [SelectedTagChip](../../../lib/core/search/search/src/widgets/selected_tag_chip.dart)
- [Bookmark suggestions](../../../lib/core/bookmarks/src/providers/suggestion_provider.dart)
- [Bookmark suggestion UI](../../../lib/core/bookmarks/src/widgets/bookmark_search_bar.dart)

Dependencies: None. Coordinate presentation changes with [BM-007](../done/BM-007-support-negative-tags-in-bookmark-search.md) if both alter bookmark autocomplete.

## Decision

2026-10-08: Make category-color styling consistent wherever tags are presented, not only inside bookmark search. No metadata-fetching changes solely for colors.
