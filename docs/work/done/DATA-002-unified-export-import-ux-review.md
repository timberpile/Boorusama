# Review unified export and import UX

Priority: High

Affected feature: `feature/backup-sharing-mockup`

Agent/session: Codex `/root` with independent `/root/ux_review`

Work branch: `feature/backup-sharing-mockup`

## Problem

The completed unified export/import implementation needs an independent,
hands-on Android design review before delivery. Clear evidence-backed findings
should be corrected; ambiguous product suggestions need user discussion rather
than speculative implementation.

## Expected behavior

The installed Dev build is reviewed on dedicated Android emulators through
Maestro. Every reported issue is checked against the branch and approved
product model. Clear recommendations are implemented with focused regression
coverage, while unresolved choices are documented for discussion.

## Acceptance criteria

- [x] Record the reviewed branch, commit, devices, flows, and limitations.
- [x] Classify every recommendation as accepted, rejected with evidence, or
  requiring product clarification.
- [x] Implement every clear accepted recommendation with regression coverage.
- [x] Revalidate affected Android flows with Maestro.
- [x] Run focused analysis and tests plus the complete Flutter test suite.
- [x] Preserve a clean, linear feature branch without remote publication.

## Dependencies

- [Unified export/import implementation](DATA-001-unified-export-import.md)
- Two dedicated Android emulators for the independent review.

## Progress

- Independent Sol High reviewer assigned `emulator-5556` as sender and
  `emulator-5564` as receiver. The physical Android device is excluded.
- Reviewed commit `efcbbcd06` on `feature/backup-sharing-mockup`, covering full
  and custom export, templates, credentials, clipboard/file import, preflight,
  import actions, nearby transfer, Android file opening, and error states.
- Accepted and corrected the unresolved profile-mapping crash, inconsistent
  action selectors, dense/noisy review summaries, private nearby-send flow,
  collection selection hierarchy, duplicate settings navigation, missing
  export-ready summary, raw error text, stale instructions, and weak no-op and
  completion states.
- Preserved the approved template actions (`Save only` and `Save & export`)
  instead of adopting the reviewer's alternative dialog layout. A separate
  user-visible undo/checkpoint browser remains a product question because the
  import transaction already performs automatic rollback and recovery.
- Did not classify one failed loose-JSON import attempt as a defect: the
  reviewer's fixture was not verified as a supported legacy export, while the
  repository's supported legacy import tests pass.

## Completion evidence

- Export/import tests: 131 passed.
- Focused Flutter analysis: no issues.
- Complete Flutter suite: 1,639 passed; two bulk-download timing tests failed
  only in the concurrent suite and both passed when their 34-test file was
  rerun in isolation.
- Android Dev build completed and was installed on `emulator-5564`. Maestro
  confirmed the consolidated Export & import settings page and the revised
  full/custom export entry flow use the app's standard visual structure.
- Physical-device Android file association, third-party file-manager behavior,
  and real credential-bearing nearby transfer were not exercised.
