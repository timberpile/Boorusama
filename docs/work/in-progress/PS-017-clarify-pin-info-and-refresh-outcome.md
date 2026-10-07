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

Info shows `Name: <name>` only when the pin has a custom name, and always shows
`Query: <query>`, with localized labels before their values. It describes the
outcome of the most recent refresh attempt. For a
failed attempt, the Last attempt value includes the corresponding user-facing
error message while retaining the date of the last successful check as
separate history.

## Acceptance criteria

- [x] Show a localized `Name: <name>` line only when an explicit name exists.
- [x] Always show a localized `Query: <query>` line with the stored query. An
  unnamed pin shows only the Query line, without repeating it as a name.
- [x] Show whether the last attempt succeeded or failed when an attempt exists.
  Before any attempt, do not imply success or failure.
- [x] On failure, show the localized message for the stored error kind directly
  in the Last attempt value, including the unsupported case. Do not add a
  separate Message field. Keep the last successful check timestamp distinct
  from the failed attempt timestamp.
- [x] After a later successful refresh, Info shows success and no stale failure
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
implementing. Implementation is complete locally; Android validation remains pending.

## Implementation

- Agent: Codex /root, 2026-10-07
- Branch: `agent/ps-017`
- Worktree: `/home/timber/code/Boorusama/.worktrees/ps-017`

### Changes and verification

- Info labels the explicit name and stored query, including explicit names that
  happen to equal the query. Unnamed pins show no Name line.
- Last attempt includes its timestamp and success/failure outcome. Failures use
  the same localized error-kind messages as cards, including unsupported.
  Last checked remains separate. Successful refreshes clear the old failure.
- Added English and German labels/outcome strings; other languages follow the
  existing English fallback policy. Storage and scheduling remain unchanged.
- Ran `./gen.sh` for missing generated output and changed localization inputs.
- Ran `fvm dart format` on both changed Dart files.
- `fvm flutter test test/core/search/subscriptions/pinned_search_info_dialog_test.dart
  --reporter expanded`: all 27 tests passed. Coverage includes named/unnamed,
  never attempted, success, every error kind after an earlier success, and a
  real failed refresh followed by successful recovery in an open dialog.
  English/German layout checks pass at 280dp and 2x text with an unsupported
  failure; OK remains reachable. Keyboard checks are not applicable to this
  read-only dialog.
- Focused `fvm flutter analyze` on the dialog and test: no issues found.
- `git diff --check`: passed.

### Pending Android validation

`adb devices -l` succeeded but listed no devices. Maestro MCP `list_devices`
failed with a 180-second timeout. No device could be leased, so Android UI
validation was not performed. Keep this ticket in progress until the required
Maestro check is completed on an available Android emulator. Merged `agent/execute-plan-commit-policy` into `agent/ps-017` and committed
the implementation on that branch. No integration into `develop` or remote
publication was performed.

### Relative dates follow-up

- Last checked and Last attempt use localized relative dates and update on the
  existing minute pulse. Success and failure messages remain visible.
- Next refresh uses localized “in …” wording with days/hours/minutes, rounding
  remaining time up to the next minute rather than implying an early check.
- Regenerated i18n and formatted changed Dart files. All 28 Info widget tests
  passed, including relative-history minute updates and English/German countdown
  and narrow-width/enlarged-text checks. Focused analysis found no issues.
- Android/Maestro validation remains pending as documented above.
