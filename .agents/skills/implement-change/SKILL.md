---
name: implement-change
description: Implement a clear, scoped Boorusama change without unresolved architecture or product decisions.
---

# Implement a change

1. Inspect relevant code/tests and nearby patterns; load subsystem docs when
   useful. Switch to `debug-issue` if a bug's cause is uncertain, or
   `design-change` for substantial unresolved architecture, persistence,
   migration, or UX decisions.
2. Make the smallest cohesive change following existing architecture. Preserve
   compatibility unless the request changes it; localize user-visible text.
   Any text added to the UI must provide important context. Use UI text
   sparingly, only when needed to understand the current state, make a
   decision, or complete an action. Prefer icons where their meaning is clear.
3. Add/update tests for meaningful behavior, edge cases, or regressions, not
   trivial getters, language behavior, or internal implementation details.
4. Apply the proportional verification in `AGENTS.md`. Prefer targeted tests:
   `fvm flutter test <test-path>` or `fvm dart test` in a Dart package.
5. Report changes, significant decisions, verification, and limitations.

No automatic design, implementation plan, work item, subagent, separate reviewer,
or second verification workflow.
