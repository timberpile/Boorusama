# Filter Following Feeds by name and profile

Priority: Normal
Affected feature: Following Feeds overview

## Problem

The Following Feeds overview lists feeds from all configured profiles but has
no text search or profile filter. A growing collection becomes difficult to
scan.

## Expected behavior

Provide a visible text filter for feed names and a selector for the owning
profile. Both filters operate on the loaded overview without changing feeds or
requesting posts.

## Acceptance criteria

- [ ] A trimmed, case-insensitive substring matches feed names. An empty
  query matches all feeds. The text field remains visible when no feed matches.
- [ ] Offer All profiles and configured feed-owning profiles, using the
  existing name/site caption to distinguish duplicate profile names. Select
  by profile ID, not display name or site URL. Text and profile conditions
  combine with AND; the existing feed order is retained among results.
- [ ] Selection affects only cards in the overview. Opening a feed, its NEW
  state, background/foreground refresh behavior, card actions, and the global
  navigation indicator keep their existing meaning. Changing a filter makes
  no post or image requests beyond the overview's existing cached previews.
- [ ] If a selected profile is removed, return to All profiles. Leaving and
  reopening the overview starts with unfiltered choices. Distinguish no feeds
  from no matching feeds, and provide a clear-filter action.
- [ ] Localize new labels and states. Focused widget tests cover feed-name
  matching, duplicate profile names, combined text/profile filters, no-match
  recovery, and unchanged card opening. Validate the overview on Android
  with Maestro.

## Context and dependencies

Each feed already stores one owning `profileId`; this ticket adds no feed
storage or network search behavior.

- [Pinned-search and feed subsystem](../../pinned_searches.md)
- [Following Feeds overview](../../../lib/core/search/subscriptions/src/pages/following_feeds_page.dart)

Dependencies: None.
