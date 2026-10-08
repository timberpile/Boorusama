# Simplify feed deletion and pinned-search removal copy

Priority: Low  
Affected feature: Following Feeds and Pinned Searches destructive-action menus and dialogs  
Status: Unclaimed

## Problem

Current confirmations expose internal details about hidden searches and cached previews. Individual Pinned Searches also mix `Delete` and `Unpin` terminology despite removal being permanent. The UI should communicate the action and its consequence plainly, without describing implementation details.

## Expected behavior and acceptance criteria

- [ ] Following-feed removal uses the short menu/action label **`Delete`** and the confirmation text **`Delete this feed?`**. Remove the copy about hidden searches and preserved pinned searches.
- [ ] Removing an *individual* Pinned Search uses **`Remove`** consistently in its menu entry, confirmation action, and dialog. The confirmation reads **`Remove this pinned search?`** and does not mention cached previews.
- [ ] An individual pinned search is still permanently removed from the app (not merely unpinned from a screen). Retain the existing deletion and cleanup behavior, including the distinction between independent pinned searches and feed-internal sources.
- [ ] Keep **`Pinned Searches`** as the feature name; do not rename it to `Saved Searches`, which means something different in Danbooru.
- [ ] Keep folder deletion conceptually distinct: a pinned-search *folder* may still use `Delete` and its existing warning when deleting the folder also removes contained pins. Do not accidentally change folder copy by reusing a shared `delete_title` translation key.
- [ ] Use localization keys and update relevant translations/fallbacks, rather than hard-coding English. Focused widget checks verify the visible strings and that Cancel leaves data unchanged while confirmation still performs the original operation.

## Context and constraints

The feed overflow already uses the generic Delete action, but `pinned_searches.delete_feed` and `delete_feed_confirmation` still include redundant/extraneous copy. An individual pin currently uses `PinnedSearchAction.delete`, a generic Delete menu label and `pinned_searches.delete_title` / `delete_message`. Folder deletion also uses `delete_title`; split translation semantics as necessary.

- [Following Feeds page](../../../lib/core/search/subscriptions/src/pages/following_feeds_page.dart)
- [Individual pin menu](../../../lib/core/search/subscriptions/src/widgets/pinned_search_card.dart)
- [Pin confirmation and folder deletion](../../../lib/core/search/subscriptions/src/pages/pinned_searches_page.dart)
- [English translation baseline](../../../packages/i18n/translations/en-US.json)
- [Pinned-search behavior](../../pinned_searches.md)

Dependencies: None. Presentation/copy only; no persistence migration.

## Decision

2026-10-08: Keep `Pinned Searches`; use `Delete` for feeds and `Remove` for individual pinned searches, with simple confirmations and no hidden-source or preview details.
