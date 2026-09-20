# Refresh overdue searches while the app is open

Priority: Normal
Affected feature: Pinned-search background refresh

## Expected behavior

Refresh only while the application is open. Use the shared scheduler on launch,
resume, and foreground intervals. Pause scheduling when inactive or backgrounded.
Operating-system background jobs and notification permissions are deferred.

## Dependencies

Depends on PS-007. Reuse the existing application lifecycle integration.

## Acceptance criteria

- [x] Launch/resume runs overdue work through the shared scheduler.
- [x] Foreground intervals respect the five-minute eligibility rule.
- [x] No new work starts while the app is inactive/backgrounded.
- [x] Resume rechecks eligibility without duplicate timers or overlapping runs.
- [x] Disabling refresh cancels foreground scheduling.
- [x] Deterministic lifecycle tests and Maestro verification cover pause/resume.

## Completion evidence

Implemented persisted global enable/interval settings and a foreground lifecycle coordinator.
Verified strict five-minute eligibility, ten-check sequential budgets, twenty-second
start deadline, retry backoff, Wi-Fi/Ethernet gating, and pause/resume behavior.
Full suite: 1,073 tests passed; static analysis clean; dev APK built. Android
Maestro verified the five-minute settings default and restart persistence.
No operating-system background jobs are registered.

## User decisions — 2026-09-17

Only refresh while the app is open for now. Operating-system background execution is deferred; implement foreground lifecycle coordination instead.
