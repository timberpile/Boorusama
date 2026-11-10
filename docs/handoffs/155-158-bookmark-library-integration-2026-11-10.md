# P4 Bookmark library integration — 2026-11-10

The owner accepted the final search-focus correction and approved P4 integration
after the recursive group-duplication change. This completes #155 and #158;
P5 and later rollout packages remain separate.

## Verified integration candidate

Approved task tip: `8f43f95ef2daaf5f1fd3c09f72c31ad04b7ff861`.
Develop base: `d2325820b07b51af036f2d6b80fc20f013f9d243`.
Combined candidate: `f4c47d6a7235ed5807eaa3910991f970b29e5193`.
Its pre-report tree is `8f70d2ee002c30e5b254a3c35ac540bc4c8b8a0b`.

Reconciling published P2/P3 retained P4's admitted storage lifecycle, unified
membership fixtures and partial Details merge. Develop's formatted actor test
and qualification reports are retained. The accepted picker/search/thumbnail/
navigation corrections and recursive group copies are included.

`./scripts/run_regression_tests.sh` passed on the combined candidate using six
detected physical cores: **6,601 application tests**, **1,677 package/CLI tests
across 13 suites**, **both repository shell suites**, and **76 Python tests**.
The complete runner exited zero. Analysis of the eight reconciled Dart files
reported zero errors/warnings and nine existing informational findings (exit 1).
The new report and corrected duplication documentation are documentation-only;
the published runtime/test tree must match the checked candidate exactly.

The earlier Android migration/restoration evidence remains historical for its
named candidate; this integration performs no new APK build or device run.
Latest UI acceptance is supplied by the owner's manual feedback in this session.

## Delivery and cleanup

Integrate as one Conventional Commit containing both issue IDs, with #155/#158
closing references, and publish it to `origin/develop`. Verify remote commit/tree
correspondence before closing issues and removing stale workflow labels. Remove
only the completed `feature/155-158-bookmark-library-package` branch/worktree;
retain other rollout branches and the unchanged primary checkout.

Durable local evidence: `.worktrees/_artifacts/p4-approved-integration-20261110/`.
This includes the checked commit/tree, complete runner log/exit, analysis, scope,
publication state and final results. Preserve ignored worktree files under that
artifact root before cleanup, including existing local build outputs.
