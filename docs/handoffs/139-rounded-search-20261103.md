# Issue #139: Rounded Search Bar correction

Continue `feature/139-related-families`. The user's commit `6a7d4a533` is preserved
unchanged: Bookmark Search again uses the default rounded Kurumi field surface,
matching Browse. The shared opaque semantic surface behind Search Bar and
Timeline Toolbar remains intact. Ordering, canonical membership and card behavior
are unchanged. This supersedes the transparent-input description in the earlier
[UI correction handoff](139-bookmark-ui-corrections-20261103.md).

Commits: `9192181a8` updates the narrow/large-text application test to assert the
default filled, rounded component over its opaque parent; `7a8912d61` removes
the obsolete transparent-input pixel expectations. No unrelated runtime edit or
rewrite of the user's commit was made. Later handoff edits are documentation only.

## Verification

- Scoped FVM formatting and `git diff --check` passed.
- `fvm flutter analyze --no-pub --no-fatal-infos` on Bookmark Search and the two
  affected test files: no issues.
- Bookmark scroll/keyboard/surface application tests: 2 passed (1x and 2x text).
- Final complete Kurumi package: 184 passed, including both default-surface
  pixel checks. The two transparent-override expectations were removed.
- Complete local gate qualified across unchanged-source phases: **6,073 app,
  1,657 package/CLI tests across 13 suites, both shell suites, 72 Python tests**.
  The original complete runner passed the app and first package, then its
  unchanged CLI timezone test exceeded the default 30-second host timeout during
  concurrent builds. The complete CLI package passed serially; all remaining
  packages/tooling passed (`REMAINING_EXIT=0`). The final Kurumi pass above
  supersedes its earlier 186-test pass. The initial `REGRESSION_EXIT=1` is retained
  as failure evidence, not described as an atomic successful run.

The current rounded field is verified by controlled narrow/keyboard tests. Earlier
device evidence of a transparent field is historical, not acceptance of this
correction. Updated #145 device checks are recorded separately. The user's manual
correction was not overwritten to match old screenshots. Physical device, device
RTL and the broader Header/system-bar matrix remain outside this finalization.

Logs: `.worktrees/_artifacts/approved-ui-139/`. #145 must include this final state
before its own handoff. Prepared for the user's final integration review; no push,
PR, develop merge or issue closure is authorized or performed. A changed combined
develop candidate requires a fresh complete gate before integration.
