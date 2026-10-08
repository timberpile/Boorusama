# Support negative tags in bookmark search

Priority: Normal  
Affected feature: Bookmark search within All, Ungrouped, and named bookmark groups  
Status: Unclaimed

## Problem

Bookmark search currently treats every whitespace-separated token as a required tag. The `-tag` syntax used in normal booru search therefore fails to exclude bookmarks.

## Expected behavior and acceptance criteria

- [ ] A search token `-tag` excludes a bookmark whose stored tag set contains `tag`; a positive `tag` continues to require it. Example: `blue_hair -glasses` requires the former and excludes the latter.
- [ ] Multiple positive and negative tokens combine with AND semantics. Negative-only queries (for example `-glasses -hat`) work for all bookmark views and site/profile selections.
- [ ] Match against locally stored bookmark tags only; absent tags are treated as absent. A bookmark with an empty/unavailable tag set is not excluded by a negative token. No hydration or remote fetch is performed for filtering.
- [ ] Normalize tag comparison consistently with existing search semantics (including case handling), without changing stored tags or bookmark membership. A lone `-` is an incomplete filter token, not an exclusion of every bookmark.
- [ ] Local bookmark autocomplete searches for the tag name after removing the leading `-` from the current token, and selecting a suggestion preserves that token's negative operator.
- [ ] Focused tests cover positive/negative mixtures, multiple exclusions, negative-only filters, empty tags, group scope, case handling, and negative autocomplete insertion. Existing sort and profile filters remain unchanged.

## Context and constraints

`BookmarkScrollView._parseTagsFromText()` produces a list of raw tokens, passed to `selectBookmarks()` / `filterBookmarks()`. The latter currently calls `selectedTags.every(bookmark.tags.contains)`. The bookmark suggestion provider also matches against the raw final input token. Consider the existing `TagExpression` parser for shared leading-negative semantics, but do not introduce unsupported remote metatags, OR, or wildcard search as part of this item.

- [Bookmark scroll view](../../../lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart)
- [Bookmark selectors/filter](../../../lib/core/bookmarks/src/providers/bookmark_group_selectors.dart)
- [Bookmark autocomplete](../../../lib/core/bookmarks/src/providers/suggestion_provider.dart)
- [Bookmark search bar](../../../lib/core/bookmarks/src/widgets/bookmark_search_bar.dart)
- [Shared tag expression](../../../lib/core/posts/filter/src/tag_expression.dart)

Dependencies: None.

## Decision

2026-10-08: Assume bookmark tags are the standard stored post data; missing data needs no special recovery and cannot be used to exclude a bookmark.
