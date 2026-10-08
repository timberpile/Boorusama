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
5. Check the original behavior or failure mechanism. After the last edit, run
   the complete local suite required by `AGENTS.md` before final review or
   handoff; focused reproduction and CI do not replace it. Resolve failures and
   repeat the complete suite after further edits. Report root cause, fix, checks,
   and remaining uncertainty, without a debugging transcript.
