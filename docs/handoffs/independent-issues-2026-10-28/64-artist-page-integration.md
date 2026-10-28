# Issue #64 — Artist Page integration

Approved task tip: `34352cd50e9e0029973a269e640b75d581de07bc`.
Develop base: `8676e5ee2bacc4107623b2b0b920eec907089a6a`.
Combined runtime/test candidate: `3d8bf0cf2533cb367b5c09e7fe4f4b30d98ae775`.

The user approved integration of `feature/64-artist-page`. Current origin refs
were fetched, the two develop commits were merged into the task worktree without
conflicts, and localization output was regenerated. The primary checkout and
unrelated task worktrees were preserved. Develop receives one squash commit
whose sole parent is the develop base above; the intermediate task merge is not
published as develop history.

The final implementation includes the responsive Artist Page, shared PostGrid,
profile-scoped Search/Wiki/tag navigation, source-independent post-details artist
identity and avatar navigation, compact Socials with site icons/favicons, reduced
shared Follow corners, Safebooru count URL handling and still-image banner lookup.
Related Tags offers By count and A–Z using the existing API's tag-wide totals,
remembers the selected order and makes no additional per-tag count requests.
The central design description now reflects these final approved decisions.

## Integration verification

Verification uses the combined candidate above. Only design/report documentation
changes followed preparation of that runtime/test candidate.

- `./gen.sh i18n`: validation and generation passed.
- Full changed Dart scope (29 files), `fvm dart analyze`: exit 0, no errors or
  warnings. Six pre-existing informational diagnostics remain in unchanged
  Following Topics page code: three brace recommendations, one redundant
  argument and two unawaited-future notes.
- `git diff --check`: passed. The complete task delta against develop was
  reviewed; the develop reconciliation changed only existing localization inputs
  shared with this task and required no conflict resolution.
- Complete gate: `./scripts/run_regression_tests.sh`, default six physical cores:
  **passed, exit 0**, on the combined candidate above. Shell policy and Android
  release-script checks passed; Python tooling reported 72 tests, OK.

| Suite | Passed | Skipped |
| --- | ---: | ---: |
| Application | 5,478 | 0 |
| booru_clients | 206 | 0 |
| boorusama_cli | 254 | 0 |
| cache_manager | 59 | 0 |
| coreutils | 191 | 0 |
| dtext | 59 | 0 |
| extended_image | 47 | 0 |
| filename_generator | 31 | 0 |
| flutter_sqlite3_migration | 45 | 0 |
| foundation | 65 | 0 |
| go_router | 436 | 2 existing |
| i18n_cli | 32 | 0 |
| kurumi | 167 | 0 |
| retriable | 16 | 0 |

No new skip or exclusion was introduced. The two existing go_router skips,
verified from their `skip: true` declarations rather than concurrent reporter
labels, are "routing config works with shell route" and "Obsolete branches in
StatefulShellRoute are cleaned up after route configuration change." Existing
native-hook invalidation messages were nonfatal; no tracked generated or runtime
output changed during the completed run.

The existing task reports contain Android, live-service and responsive evidence;
these checks were not repeated during integration. Native desktop and a release
performance benchmark remain unrun. Earlier handoff statements that a full gate
is pending are superseded by the completed combined-candidate check above.

## Publication and cleanup

Publication verifies the exact squash tree and parent, checks for unexpected
outgoing merge commits, refreshes origin and uses a normal fast-forward push.
Issue #64 is completed only after the result is verified in origin/develop.
Remote task deletion uses the observed branch tip as an expected-tip lease;
local cleanup preserves any uncertain ignored configuration before removing
generated files, the task worktree and the squash-equivalent task branch.
No PR or release is created.
