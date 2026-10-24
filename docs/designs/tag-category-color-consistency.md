# Consistent tag-category colors throughout the application

## Problem

Tag category presentation is inconsistent across autocomplete, selected search chips, bookmark search, and other tag-bearing views. Users should recognize Artist, Character, Copyright, General, Meta, and supported site-specific categories consistently.

## Requirements

- Audit tag presentation in ordinary search autocomplete, bookmark autocomplete, selected search tag chips, and applicable bookmark post/tag views. Apply consistent category-color semantics rather than a generic chip foreground.
- Reuse or centralize the existing **TagColorGenerator**, category-resolution providers, and theme-aware colors. Respect booru-specific category definitions in both light and dark themes.
- Preserve visible and distinct operator/metatag styling (for example, a negation prefix) while giving the actual tag the correct category color. Do not change chip editing, removal, counts, context menus, or filtering behavior.
- Resolve colors from known metadata/caches. **Never add network requests solely for tag coloring.** Missing/unknown categories use a neutral readable fallback instead of a guessed category.
- For bookmark collections spanning profiles or boorus, use the tag's actual known origin/category context, not whichever browsing profile happens to be selected.
- Cover category mapping, unknown categories, theme differences, autocomplete, selected chips, narrow widths, and enlarged text.

## Existing implementation points

- [Tag color generator](../../lib/core/tags/tag/src/tag_color_generator.dart)
- [Tag category provider](../../lib/core/tags/categories/src/tag_category_providers.dart)
- [Shared tag chip](../../lib/core/posts/details_parts/src/tags/tag_chip.dart)
- [Selected search tag chip](../../lib/core/search/search/src/widgets/selected_tag_chip.dart)
- [Bookmark suggestion provider](../../lib/core/bookmarks/src/providers/suggestion_provider.dart)
- [Bookmark suggestion UI](../../lib/core/bookmarks/src/widgets/bookmark_search_bar.dart)

The current search chip styles operators/metatags individually, but the tag's own text may use a generic fallback color. Extend existing mechanisms rather than building a separate color system.
