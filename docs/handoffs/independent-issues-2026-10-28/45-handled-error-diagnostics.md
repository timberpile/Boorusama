# Issue 45: Handled-error diagnostics

## Accepted scope

- Issue: #45, Record actionable diagnostics for handled app errors.
- Branch: `maintenance/45-handled-error-diagnostics`.
- Integration base: `09cbda57a40b5b6aba2de4b56192d941d6e53ab8`.
- Runtime candidate: `b251f46df3cbfe4ae75fb24134a31c6b9930f68d`.
- Original published task tip: `0b49ced5b88f852b43888707dba69a3f583f8a0c`.
  All seven commits rebased without conflicts and retained identical patches.
- The user accepted automated verification without another manual review and
  authorized integration on 2026-10-28.

## Changes and limits

A small helper extends the existing Logger pipeline with code-owned operation
and recovery identifiers, exception types, bounded package/Dart source frames,
HTTP status/request categories, format offsets, numeric OS codes, and SQLite
result/extended codes. A bounded underlying Dio cause is retained without
serializing arbitrary exception messages or payloads. Routine Dio cancellation
produces no diagnostic. Stack output is limited to eight safe source frames.

Representative startup/storage/history, profile write/removal/recovery,
bookmark snapshot decoding, media preparation/sharing, download, Following
preview, and import/export failures now retain their responsible operation and
safe technical context. Snapshot failures and share wrappers preserve original
exceptions/stacks; supported fallback data and recovery outcomes are retained.
Import rollback failures are reported separately and bounded. Profile/history
fallbacks avoid redundant duplicate warning entries; preview disposal,
cancellation, and deferred requests are not misclassified as failures.

Credentials, request headers, sensitive URLs/queries, private payloads, local
paths, and raw SQL/exception messages are excluded from these new diagnostic
events, including when sensitive logging is enabled. Existing concise feedback
and recovery behavior are retained. This is representative instrumentation,
not a claim that every handled failure in the app has been audited.

## Verification

- Before the final rebase, the focused diagnostic, privacy, cancellation,
  snapshot, profile, share, and preview checks were rerun: 26 passed.
- Earlier post-rebase diagnostics/backup/share checks: 182 passed; these are
  historical supporting evidence rather than the final integration gate.
- Final changed-file analysis: 0 errors, 0 warnings, 19 informational diagnostics.
- `./gen.sh i18n` validated and regenerated output required by the current base.
- Complete final gate: `./scripts/run_regression_tests.sh`, using six detected
  physical cores, completed successfully on 2026-10-28: application 5,368 passed;
  all 13 package/CLI suites 1,603 passed; both repository shell suites and all 72
  Python tooling tests passed. The two existing go_router skips were retained.
  No runtime/test changes followed the complete pass; this handoff is a
  documentation-only addition.

Historical device evidence is preserved in ignored
`artifacts/local-implementation-review-2026-10-26/45-device-checks.md`.
That leased Android/Maestro run used source `5fd9c79e4` before later rebases:
an invalid synthetic export was rejected, its safe preflight diagnostic and
package source frame were displayed, and the private sentinel was absent.
No import was committed; only the staged fixture was removed. This is not a
fresh device check of the final runtime candidate. No live service outage was
induced or additional device run performed for this integration.

Pre-existing APK/editor settings and final logs are preserved outside the task
worktree in ignored `artifacts/issue45-integration-2026-10-28/`. The saved APK is
not claimed to have been built from the final runtime candidate.
