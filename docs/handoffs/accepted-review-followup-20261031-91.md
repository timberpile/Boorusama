# Accepted review follow-up handoff — #91

Prepared 2026-10-31. Branch `feature/91-branded-search-link-share`.

Verified implementation/test candidate: `66d9bfe2aead7ee084d6c1f0b4834cb8c1c11c34`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Ordinary Search/timeline Share keeps the standard Share icon. The .bslink payload action inside the unified share sheet uses the existing application asset at a normal visual size. A 24-dp clipped slot compensates for transparent padding in that same asset; payload and native chooser behavior stay unchanged.

Reviewed outer versus inner action ownership, actual asset padding, 24-dp slot/alignment, semantics and both theme/narrow/enlarged fixtures. Device review caught the initially tiny visible artwork; the correction and updated geometry regression were retested.

No new sibling-branch prerequisite was added by this correction.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1188.1 s, exact candidate `66d9bfe2aead7ee084d6c1f0b4834cb8c1c11c34`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 147.6 s, build commit `66d9bfe2aead7ee084d6c1f0b4834cb8c1c11c34`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/links/share_search_link_button.dart lib/core/posts/shares/src/unified_post_share_sheet.dart test/core/posts/links/search_share_icon_test.dart test/core/posts/links/share_search_link_button_test.dart test/core/posts/shares/share_boorusama_link_test.dart` — PASS: 0 errors, 0 warnings, 1 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 66d9bfe2aead7ee084d6c1f0b4834cb8c1c11c34` passed.
- Focused evidence `branding-crop-final`: `fvm flutter test --no-pub --concurrency=6 test/core/posts/shares/share_boorusama_link_test.dart` — PASS (14.8 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/91-branded-search-link-share/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `4fed41bc4a439e7b3de59983b6b515ed8e034b5d8cf5adea29b6554d9b3df68e`.

Actual Search .bslink chooser and final selected-post Links sheet were exercised; final post filename boorusama-post-12482689.bslink was asserted. No recipient selected.

Detailed actual observations and provenance are retained in `91-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Open Search Share: outer icon must be the standard Share symbol.
2. Select a post > Share > Links: only Boorusama Link File uses the app artwork, at normal icon size.
3. Open the native chooser for a .bslink file and cancel; other media/link action icons remain standard.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
66d9bfe2aead7ee084d6c1f0b4834cb8c1c11c34 test: preserve the branded payload icon viewport (#91)
0f06ff1aa6cde3a8e25a623bc1f5ac34bb803760 fix: show link branding at the normal visible icon size (#91)
be5c8381182b0f7d9b8940f20e5703b510fe9db7 fix: brand link-file payload instead of Share entry (#91)
```
