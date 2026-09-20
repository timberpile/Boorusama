# Run overdue search refresh through platform background execution

Priority: Normal
Affected feature: Pinned-search background refresh

## Expected behavior

Refresh only while the application is open. Use the shared scheduler on launch,
resume, and foreground intervals. Pause scheduling when inactive or backgrounded.
Operating-system background jobs and notification permissions are deferred.

## Dependencies

Depends on PS-007. Reuse the existing application lifecycle integration.

## Acceptance criteria

- [ ] Launch/resume runs overdue work through the shared scheduler.
- [ ] Foreground intervals respect the five-minute eligibility rule.
- [ ] No new work starts while the app is inactive/backgrounded.
- [ ] Resume rechecks eligibility without duplicate timers or overlapping runs.
- [ ] Disabling refresh cancels foreground scheduling.
- [ ] Deterministic lifecycle tests and Maestro verification cover pause/resume.

## Completion evidence

Not started.

## User decisions — 2026-09-17

Only refresh while the app is open for now. Operating-system background execution is deferred; implement foreground lifecycle coordination instead.
