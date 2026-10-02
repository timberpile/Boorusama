# Reintroduce conservative automatic search refresh

Priority: Low
Affected feature: Pinned Searches and Following Feeds

## Problem

Automatic search refresh is disabled because the previous five-minute
foreground scheduler could make requests too aggressively across configured
sites. Users may still benefit from infrequent background maintenance once its
site-level traffic is bounded.

## Expected behavior

Design and implement an opt-in or safely defaulted scheduler with a daily-scale
interval. Coordinate it with site-level request throttling so pinned searches,
feeds, and other requests cannot collectively exceed a site's limits.

## Acceptance criteria

- [ ] Product decisions define the default state, interval, and user-facing
      controls before implementation.
- [ ] Scheduling is daily-scale rather than minute-scale and limits work per
      site and per run.
- [ ] Automatic and manual work share site-level throttling and coalesce
      duplicate refreshes.
- [ ] Offline, lifecycle, retry, and rate-limit behavior is deterministic and
      covered with fake-clock tests.
- [ ] Existing stored `searchRefresh` settings are migrated or interpreted
      explicitly.
- [ ] Manual refresh remains available when scheduling is disabled.

## Relevant context

`SearchRefreshScheduler`, `SearchRefreshCoordinator`, and
`SearchRefreshSettings` preserve the previous implementation and schema as
reference. Reusing them requires a fresh design review; their old five-minute
defaults are not acceptance criteria for this task.

## Dependencies

Depends on a central per-site request scheduling or throttling decision.
