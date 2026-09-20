# Clarify pinned-search Info and the last refresh outcome

Priority: Normal
Affected feature: Pinned-search Info dialog

## Problem and reproduction

Open a pin's overflow menu and select Info. The dialog shows the display name
and query as unlabeled consecutive lines. If no custom name was entered, both
lines are the same query. It also shows Last checked and Last attempted without
saying whether the last attempt succeeded. A failed attempt's message is absent
from Info, even though the card can show a localized error.

## Expected behavior

Info identifies the query and, only when the pin has a custom name, identifies
that name. It describes the outcome of the most recent refresh attempt. For a
failed attempt, the Last attempt value includes the corresponding user-facing
error message while retaining the date of the last successful check as
separate history.

## Acceptance criteria

- [ ] Show a localized Name label and value only when an explicit name exists.
- [ ] Always show a localized Query label and the stored query. An unnamed pin
  does not repeat the query as its name.
- [ ] Show whether the last attempt succeeded or failed when an attempt exists.
  Before any attempt, do not imply success or failure.
- [ ] On failure, show the localized message for the stored error kind directly
  in the Last attempt value, including the unsupported case. Do not add a
  separate Message field. Keep the last successful check timestamp distinct
  from the failed attempt timestamp.
- [ ] After a later successful refresh, Info shows success and no stale failure
  message.
- [ ] Widget coverage includes unnamed and named pins, never attempted,
  successful attempt, failed attempt after an earlier success, and recovery.
  Validate the dialog on Android with Maestro.

## Context and dependencies

`SearchSubscription.name` is nullable and `displayName` falls back to `query`.
Refresh persistence records `lastAttemptAt`, `lastSuccessfulCheckAt`, and
`lastErrorKind`; it does not persist a raw exception message. Use the existing
localized error-kind messages unless the product deliberately changes that
storage model. No dependency on the folder redesign.

- [Info dialog](../../../lib/core/search/subscriptions/src/pages/pinned_searches_page.dart)
- [Pin card error messages](../../../lib/core/search/subscriptions/src/widgets/pinned_search_card.dart)
- [Refresh state](../../../lib/core/search/subscriptions/src/types/search_subscription.dart)
- [Earlier Info task](../done/PS-003-search-item-status-info.md)
- [Subsystem documentation](../../pinned_searches.md)

Follow the [development workflow](../../development_workflow.md) when
implementing. This ticket records the requested change; no fix has been applied.
