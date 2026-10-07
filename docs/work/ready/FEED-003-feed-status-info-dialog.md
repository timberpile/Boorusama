# Move Following Feed status into an Info dialog

Priority: Normal
Affected feature: Open Following Feed

## Problem

An open Following Feed currently displays checked-source counts, failures,
rate-limit status and the last-check time above its posts. These maintenance
details distract from browsing; the user wants them available on demand, as
with pinned searches.

## Expected behavior

Move these details into an Info dialog opened through the feed's context menu.

## Acceptance criteria

- [ ] The open feed's normal content no longer shows checked-source counts,
  failure summaries, rate-limit details or last-check timestamps.
- [ ] An Info action in the feed's context menu opens a dismissible dialog,
  following the pinned-search Info pattern. Keep the existing edit/manage action.
- [ ] The dialog shows checked sources out of total, failures, any existing
  rate-limit status, and the existing last-check information, including a clear
  never-checked state. Read current cached state; opening it starts no refresh
  or network request and changes no feed/source state.
- [ ] Missing/deleted feeds and empty source collections are handled safely.
  A refresh completing while the dialog is open updates its information.
- [ ] Preserve feed browsing, NEW/read semantics and existing refresh behavior.
  Active refresh progress remains available; this moves maintenance details.
- [ ] Reuse localized Info/status labels where possible. Verify dialog opening,
  content, dismissal and absence of status text from the normal feed view with
  focused widget tests; check narrow-screen usability.

## Context and authorization

User requested a work item on 2026-10-06. This records the request; it does not
expand the currently active implementation assignment.

- [Pinned-search and feed subsystem](../../pinned_searches.md)
- [Following Feed page](../../../lib/core/search/subscriptions/src/pages/following_feeds_page.dart)

Dependencies: None. Coordinate with FEED-001/FEED-002 if replaying prepared
changes to the same page.
