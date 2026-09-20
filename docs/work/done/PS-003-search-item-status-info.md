# Remove routine Last checked text from pinned-search items

Priority: Normal
Affected feature: Pinned-search list
Reported on branch: `fix/rule34-pinned-search-tracking`

## Problem

Pinned-search items display Last checked directly, adding routine status text
to the list.

## Expected behavior

Do not show Last checked directly on items. Warnings and errors should remain
visible. The user suggested an Info action as a possible place for additional
details; this is optional, not a requirement to expand the MVP.

## Acceptance criteria

- [x] Normal items do not display Last checked directly.
- [x] Relevant warnings and errors remain visible on the item.
- [x] If an Info action is added, routine check details are available on demand
  and all new user-facing text uses i18n resources.

## Relevant context

- `lib/core/search/subscriptions/src/widgets/pinned_search_card.dart`
- `lib/core/search/subscriptions/src/pages/pinned_searches_page.dart`
- [Subsystem documentation](../../pinned_searches.md)
- Validate Android UI behavior with Maestro as required by `AGENTS.md`.

## Completion evidence

Record verification here when resolved.

## User decisions — 2026-09-17

Add an Info action for routine check details; remove Last checked from normal cards.

## Completion — 2026-09-17

Agent: Codex (/root)
Branch: `feature/chronological-pinned-search-support`

Focused suite passed 124 tests. Maestro confirmed normal cards hide Last checked and the Info dialog displays it without refreshing.
