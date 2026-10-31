# Accepted review follow-up handoff — #92

Prepared 2026-10-31. Branch `bug/92-selection-share-image`.

Verified implementation/test candidate: `87b4f0325d5621b5d5221dabedafac0289bfdf05`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

The actual Selection Share service captures the source-scoped Post Quality. Original quality omits only the duplicate Image payload; other qualities keep working Image and Original actions. Completed preparation updates dimensions/type/size in the same open sheet from existing cache facts, without another media request or delayed geometry change.

Reviewed source/auth headers and fallback preparation, cache ownership, mounted/revision guards, failure recovery, same-sheet metadata and video/poster separation. Baseline metadata staleness was reproduced. The reported High-only failure did not reproduce on the sampled old public JPEG, so no unsupported causal claim is made.

No new sibling-branch prerequisite was added by this correction.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1028.2 s, exact candidate `87b4f0325d5621b5d5221dabedafac0289bfdf05`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 227.2 s, build commit `87b4f0325d5621b5d5221dabedafac0289bfdf05`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/shares/src/providers.dart lib/core/posts/shares/src/share_payloads.dart lib/core/posts/shares/src/unified_post_share_sheet.dart test/application/selection_share_quality_flow_test.dart test/core/posts/shares/share_sheet_media_description_test.dart` — PASS: 0 errors, 0 warnings, 9 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 87b4f0325d5621b5d5221dabedafac0289bfdf05` passed.
- Focused evidence `focused-final-v2`: `fvm flutter test --concurrency=6 test/core/posts/shares test/application/selection_share_quality_flow_test.dart` — PASS (148.0 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/92-selection-share-image/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `463e96865d7d565d7bf74dce07a10d05eb04de7b528c64321a638eb918d136fd`.

Actual Danbooru High Share-first/Copy-first and Original unvisited-post flows passed with native chooser cancelled. Same-sheet High metadata updated from blank. Authenticated-source headers/fallback, video/poster and metadata-failure cases are controlled tests, not a claim of live Pixiv sharing. Clipboard changed; original High restored.

Detailed actual observations and provenance are retained in `92-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Set Post Quality High. Select a fresh unvisited image without opening its viewer, open Share and use Image Copy and native Share in both orders.
2. Check dimensions/type/size update in that same open sheet after preparation.
3. Set Post Quality Original: Image absent, Original usable, Links/.bslink still present. Check cache/error/cancel and authenticated sources; restore quality.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
87b4f0325d5621b5d5221dabedafac0289bfdf05 fix: honor post quality and refresh prepared share metadata (#92)
```
