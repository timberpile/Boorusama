# Disable scheduled pinned-search refresh

Priority: High
Affected feature: Pinned Searches and Following Feeds
Work branch: `fix/disable-scheduled-search-refresh`
Agent: Codex (`/root/implement_08`)

## Problem

The foreground scheduler checks pinned searches on launch, resume, network
recovery, and a one-minute timer. Its default five-minute interval can create
far more site traffic than users expect.

## Expected behavior

Pinned searches and feed sources refresh only through explicit user actions.
Stored automatic-refresh settings remain readable and writable so a future,
more conservative scheduler can migrate them safely. Controls for the disabled
scheduler are not shown.

## Acceptance criteria

- [x] Launching, resuming, connectivity changes, and elapsed foreground time do
      not schedule pinned-search or feed-source requests.
- [x] Per-search, per-feed, folder, and Refresh All actions remain available.
- [x] Opening a pinned search remains cache-only apart from its existing
      mark-read mutation.
- [x] Automatic-refresh settings continue to round trip through `Settings`.
- [x] The pinned-search UI does not expose settings for disabled scheduling.
- [x] A separate ready task records the conservative scheduler follow-up.
- [x] Focused tests, full tests, and static analysis pass without regressions.

## Relevant context

The existing scheduler, request gate, and settings schema are retained as
dormant migration context. The app-level lifecycle integration is the trigger
being disabled. Manual refresh behavior remains owned by
`SearchSubscriptionsNotifier`.

## Dependencies

None.

## Progress

- Traced automatic work to the app-wide lifecycle wrapper and coordinator.
- Confirmed manual refresh and no-fetch-on-open behavior already have widget
  coverage.
- Captured failing lifecycle and UI tests before changing production code.
- Made the app lifecycle boundary inert and removed the inactive settings
  action from the pinned-search toolbar.
- Focused verification passed 50 tests covering lifecycle, page actions,
  settings persistence, and request gating.
- Independent review approved the implementation with no Critical or Important
  findings. Its minor connectivity-transition coverage suggestion was added and
  mutation-proven against the former lifecycle implementation.
- The isolated full suite passed all 1,485 tests.
- Static analysis reported the unchanged baseline of 227 informational
  findings and no new diagnostics.
- `git diff --check` passed. The implementation range does not modify
  `Settings`, `SearchRefreshSettings`, or backup schema code, and
  `PS-031-conservative-automatic-refresh.md` remains in `docs/work/ready/`.
