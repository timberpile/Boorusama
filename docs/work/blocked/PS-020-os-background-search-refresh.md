# Refresh pinned searches and feeds outside the foreground

Priority: Low
Affected feature: Pinned searches and following feeds

## Problem

Automatic search refresh currently runs only while the app is in the
foreground. Searches belonging to pins and feeds remain stale when the app is
closed or backgrounded until foreground scheduling resumes. This is accepted
for the current feed redesign.

## Expected behavior

Add a separately designed operating-system background refresh path that uses
the shared TrackedSearch refresh service and bounded scheduler. Visible pins
and feed-internal searches retain independent state. A feed remains an
eventually consistent view of its sources; background work must not require
opening the feed or refreshing every source at once.

## Acceptance criteria

- Specify platform-supported scheduling, network and power constraints,
  permissions, and user controls before implementation.
- Coalesce concurrent work for the same TrackedSearch. A visible pin with the
  same query as a feed's internal search remains an independent search.
- Bound each background run and resume overdue sources fairly across runs.
- Verify foreground and background work do not duplicate an in-flight source
  refresh, and that cached feed results and `NEW` state survive process restart.
- Explain the limits of background scheduling to users without promising
  real-time feed updates.

## Relevant context and dependencies

- Depends on the TrackedSearch-based feed redesign and the foreground scheduler in
  [PS-007](../done/PS-007-automatic-refresh-scheduler.md) and
  [PS-008](../done/PS-008-platform-background-refresh.md).
- The current decision is to keep refresh in the foreground; this issue is
  separate from the feed redesign.

## Blocker

The platform background design and its user-facing guarantees have been
deferred to a later issue.
