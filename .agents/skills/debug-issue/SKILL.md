---
name: debug-issue
description: Diagnose and fix a Boorusama failure with a known symptom but unestablished cause.
---

# Debug an issue

1. Reduce the report to a concrete failing behavior. Inspect its execution path,
   state transitions, tests, and useful logs; prefer focused reproduction over
   launching the app/emulator.
2. Compare plausible causes using distinguishing evidence; suspicious code is
   not proof. Check relevant async/lifecycle, stale state/cache, nullable data,
   profile/site, persistence/migration, generated client/model, retry/HTTP,
   and viewer/navigation boundaries.
3. Fix the established cause with the smallest change, rather than masking the
   symptom. Switch to `design-change` only if substantial design decisions arise.
4. Add a focused regression test when practical. Observe failure before the fix
   when inexpensive; avoid scaffolding solely to enforce RED/GREEN sequencing.
   For parallel-only failures, check fixture clocks, fixed sleeps and wall-time
   assumptions. Prefer controlled clocks and completion gates over larger sleeps,
   retries or exclusions. Preserve actual timeout/backoff/cancellation contracts;
   rerun affected tests at the parallel setting that exposed the failure.
5. Check the original behavior or failure mechanism and apply scope-appropriate
   verification from `AGENTS.md`. Expand to consumer tests across meaningful
   boundaries; broad/unclear scope needs the full suite. Before develop
   integration, require a complete pass on the final candidate, reusing a pass
   on that same candidate across handoffs and report-only edits. Resolve failures
   and re-verify relevant changes. Report root cause, fix, checks and remaining
   uncertainty, without a debugging transcript.
