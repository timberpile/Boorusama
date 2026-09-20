# Schedule bounded automatic refresh across profiles

Priority: Normal
Affected feature: Pinned-search automatic refresh

## Expected behavior

Provide one global refresh interval and a shared coordinator for overdue
searches across every configured profile. Manual and automatic requests reuse
SearchRefreshService and coalesce overlapping work. The navigation indicator
continues to reflect only the active profile.

## Dependencies and design

- Depends on [PS-005](../done/PS-005-engine-refresh-adapters.md) for explicit engine capabilities.
- PS-006 folders are independent and are not a scheduler prerequisite.
- Specify interval defaults, disabling behavior, run budgets, retry policy,
  and scheduler-state persistence before implementation.
- See [automatic roadmap](../../superpowers/specs/2026-09-14-pinned-searches-design.md#automatic-refresh).
- Platform background execution is a separate step in PS-008.

## Acceptance criteria

- [ ] A persisted global setting controls the interval and allows disabling automatic refresh.
- [ ] Launch/resume checks only eligible overdue searches across all profiles.
- [ ] Never-checked searches precede oldest successful checkpoints, with stable ID ties.
- [ ] A global concurrency limit and per-run request/time budgets bound each run;
      unfinished work remains eligible for later runs.
- [ ] Failed searches receive retry backoff without advancing their successful checkpoint
      or starving other eligible searches.
- [ ] Concurrent manual/automatic refreshes avoid duplicate in-flight work.
- [ ] Deleted profiles/searches and unsupported engines are skipped safely.
- [ ] Background updates publish cached previews and NEW state without fetching on list opening.
- [ ] Fake-clock tests protect eligibility, budget limits, fairness, backoff, and cancellation.

## Constraints and verification

Use the existing profile repositories and engine query composition. NEW means
observed matching uploads after the checkpoint; metadata edits to old posts do
not trigger it. Preserve PS-001's bounded snapshots and failure behavior; do
not restore exact counts or exhaustive pagination. Keep the side-menu section
and desktop tab positions stable. Add localized text through i18n.

Test observable behavior and persistence where relevant. Validate Android UI
with Maestro. Update [subsystem documentation](../../pinned_searches.md) and
record completion evidence here before moving the task to `done/`.

## Completion evidence

Not started.

## User decisions — 2026-09-17

Default automatic interval: five minutes. Only check searches last successfully refreshed more than five minutes ago. Respect an existing mobile-data restriction if applicable; investigate a conservative request budget.
