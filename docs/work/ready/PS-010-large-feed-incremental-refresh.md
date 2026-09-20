# Keep large following feeds responsive with incremental refresh

Priority: Normal
Affected feature: Following-feed scaling

## Expected behavior

Feeds with hundreds or thousands of sources open from cache immediately and
refresh incrementally within global budgets. Avoid rebuilding every source or
waiting for a complete refresh before publishing useful results.

## Dependencies and design

- Depends on [PS-009](PS-009-combined-following-feeds.md).
- Define measurable opening/refresh targets, result-retention limits, and a
  representative large-source fixture before optimizing.
- Safe server-side OR sharding is conditional: implement only where an engine's
  query limits, source attribution, newness semantics, and error handling are
  verified. Retain independent source refresh as the fallback.

## Acceptance criteria

- [ ] Opening a cached large feed does not issue a request per source or await network completion.
- [ ] New source snapshots update materialized results incrementally with bounded retention.
- [ ] Global concurrency and per-run budgets continue to apply and work remains fair across feeds/profiles.
- [ ] Freshness/progress and partial errors remain visible during incomplete runs.
- [ ] Each source retains independent checkpoint/error state, including when safely batched.
- [ ] Unsupported batching falls back to independent bounded checks without local query emulation.
- [ ] Benchmarks cover hundreds/thousands of sources and document measured limits.

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

Investigate and test appropriate source, retention, and performance limits autonomously.
