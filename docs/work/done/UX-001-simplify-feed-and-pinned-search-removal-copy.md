# Simplify feed deletion and pinned-search removal copy

Priority: Low
Affected feature: Following Feeds and Pinned Searches destructive-action menus and dialogs
Status: Completed
Agent/session: Codex (2026-10-09)
Branch: `agent/ux-001-removal-copy`
Worktree: `.worktrees/ux-001-removal-copy`

## Problem

Current confirmations expose internal details about hidden searches and cached previews. Individual Pinned Searches also mix `Delete` and `Unpin` terminology despite removal being permanent. The UI should communicate the action and its consequence plainly, without describing implementation details.

## Expected behavior and acceptance criteria

- [x] Following-feed removal uses the short menu/action label **`Delete`** and the confirmation text **`Delete this feed?`**. Remove the copy about hidden searches and preserved pinned searches.
- [x] Removing an *individual* Pinned Search uses **`Remove`** consistently in its menu entry, confirmation action, and dialog. The confirmation reads **`Remove this pinned search?`** and does not mention cached previews.
- [x] An individual pinned search is still permanently removed from the app (not merely unpinned from a screen). Retain the existing deletion and cleanup behavior, including the distinction between independent pinned searches and feed-internal sources.
- [x] Keep **`Pinned Searches`** as the feature name; do not rename it to `Saved Searches`, which means something different in Danbooru.
- [x] Keep folder deletion conceptually distinct: a pinned-search *folder* may still use `Delete` and its existing warning when deleting the folder also removes contained pins. Do not accidentally change folder copy by reusing a shared `delete_title` translation key.
- [x] Use localization keys and update relevant translations/fallbacks, rather than hard-coding English. Focused widget checks verify the visible strings and that Cancel leaves data unchanged while confirmation still performs the original operation.

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


## Implementation and verification

- Added dedicated individual-pin `remove` and `remove_confirmation` localization
  keys and simplified feed strings. Other locales use the regenerated English
  fallback. Folder deletion already uses the separate `folders` namespace, so
  its title, warning, and action are preserved. Persistence calls are unchanged.
- All 62 focused removal-copy/widget tests passed, including cancellation,
  permanent removal, feed-source cleanup, and distinct folder copy at 320-pixel
  width and 200% text. These confirmations have no keyboard inputs.
- 2026-10-10 follow-up: fixed the blocking image-cache tests at the user's request.
  Their fixed 400 ms waits did not guarantee completion of real disk I/O/native
  decoding. A deliberate 600 ms target decode reproduced the exact blue-expected,
  red-actual failure before the fix.
- Replaced those waits with bounded waits for actual requests, displayed image
  stages, cancellation, and listener cleanup. Reselection waits for the decoded
  display handoff before the next supersession; recovery also waits for its own
  representation-change notification so an earlier blue image cannot satisfy it.
  Pixel colors, exact decode/request counts, completer identity, cache budgets,
  listener cleanup, and keepAlive-release assertions remain enforced.
- The repaired cache file passed eight consecutive fresh runs (32 test cases),
  retaining the deliberately slow native target decoder as a regression check.
  The related progressive-image suites also passed together (26 tests).
  Analysis of the repaired file found no issues. Analysis of the earlier copy
  change reported only the pre-existing informational lint at
  `pinned_searches_page.dart:63`.
- Final verification gate: run the complete application, all package/CLI suites,
  and repository-tooling suites after this document's final edit. Record the
  exact outcome in the local completion commit and handoff; the focused results
  above do not replace this gate.
- No device, upgrade, CI, integration, or publication result is claimed.
