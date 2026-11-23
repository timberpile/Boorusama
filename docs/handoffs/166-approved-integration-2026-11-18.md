# Approved bookmark cover integration (#166)

The owner accepted #166 and authorized its integration into develop. #134 remains
under review; its timeline grouping, geometry and single-source site-badge
correction stay on `feature/134-related-timeline-groups`.

## Candidate and scope

- Accepted issue tip: `e2ba5704946ffc0f3dd15d394e31c271e420f9b4`.
- Current develop base: `96e026cc9b7db88bd8544166deacaa5a15a0867e`.
- Qualified combined candidate: `632e706dacaee817e4a9e14962a6053da9996a79`.
- Qualified tracked tree: `3229b7e8d8b1a5bb9633c7206e929296b42ecc19`.

Current develop was composed into the issue worktree without conflicts. The
compositions in Related Gallery insets and English translations were reviewed:
develop's viewport behavior and Following Topics labels remain, together with
#166's selected-cover and source-independent bookmark reading changes.

The squash prepared in an isolated develop worktree matches the qualified
runtime, tests, dependencies, tooling and generation inputs exactly. Only this
report and Markdown hard-break whitespace in the original #166 handoff differ
after qualification. No full application rerun is needed for those document-only
changes. The primary detached checkout and unrelated worktrees remain untouched.

This integration includes profile-independent saved-group reads, sticky and
policy-checked cover recovery, Related cover fitting, authoritative presentation
counts and the shared Related item badge. Counts learned through reading do not
mutate publisher-owned received records. General release/migration policy is
unchanged. Shared #166 dependencies also referenced by #134 are included; the
#134 timeline feature itself is excluded.

## Complete local verification

`./scripts/run_regression_tests.sh` completed with exit **0**, using the default
physical-core detector's six workers:

- Application: **7,769 passed**.
- All 13 package/CLI suites: **1,722 passed**, with two existing go_router skips.
- Both repository shell suites passed (PR policy and Android release scripts).
- Python repository tooling: **76 passed**.

Total Flutter/Dart tests passed: **9,491**. No test failures.

`./gen.sh i18n` regenerated localization output because develop's merged
translation inputs changed. The analyzed bookmark/group/cover scope reported
**0 errors, 0 warnings, 244 informational findings** (exit 1). The final squash
passes `git diff --check`. Existing non-fatal fixture hit-test/VM diagnostics
remain in the durable test log.

No Android/emulator/Maestro, APK/native build, live API or authenticated-account
checks were performed for this integration. Owner acceptance is the manual
acceptance; host tests do not establish device performance or live-service behavior.

Durable evidence: `.worktrees/_artifacts/166-approved-integration-20261118/`.
The complete runner log and exit file establish completion on the recorded
candidate. #134's separate correction and 51 targeted checks are documented in
`134-single-source-group-badges-2026-11-18-results.md` on its feature branch.
