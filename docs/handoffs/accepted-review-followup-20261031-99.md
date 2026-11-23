# Accepted review follow-up handoff — #99

Prepared 2026-10-31. Branch `feature/99-selected-tag-suggestions`.

Verified implementation/test candidate: `135cf72f3368449a6e1deb9de7fe3eaeda2f464a`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

The actual inline recommended-tag plus/minus row reads the selected-tag controller and canonical tag identity. Already selected positive/negative tags and confirmed aliases are excluded without changing autocomplete, editing or composing-text contracts.

Reviewed the actual RelatedTagSection wiring, canonical positive/negative extraction, confirmed alias knowledge, controller notifications, recommendation editing and IME behavior. The fix targets the inline recommendations rather than only autocomplete.

No new sibling-branch prerequisite was added by this correction.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 926.8 s, exact candidate `135cf72f3368449a6e1deb9de7fe3eaeda2f464a`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 70.0 s, build commit `135cf72f3368449a6e1deb9de7fe3eaeda2f464a`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/danbooru/posts/search/src/danbooru_search_page.dart lib/boorus/danbooru/posts/search/src/widgets/related_tag_section.dart lib/core/search/suggestions/selected_tag_suggestions.dart test/boorus/danbooru/posts/search/inline_related_tags_test.dart` — PASS: 0 errors, 0 warnings, 1 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 135cf72f3368449a6e1deb9de7fe3eaeda2f464a` passed.
- Focused evidence `focused-final-v2`: `fvm flutter test --no-pub --concurrency=6 test/boorus/danbooru/posts/search/inline_related_tags_test.dart test/core/search/selected_tag_suggestions_test.dart test/core/search/selected_tag_suggestions_widget_test.dart test/core/search/options/search_suggestion_async_test.dart test/core/search/search_profile_switch_test.dart` — PASS (76.0 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/99-selected-tag-suggestions/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `917d3b41cba5ca85db628c493eceaa51382970e802c06f794ef31b5c4b84c085`.

Live cat exclusion, inline minus highres and plus commentary_request passed. The negative chip uses the existing em-dash presentation. Known aliases and composing/edit cases have controlled production-widget coverage.

Detailed actual observations and provenance are retained in `99-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Search cat: the selected cat must not remain in the inline plus/minus recommendations.
2. Use minus on highres, then plus on another recommended tag: each selected recommendation disappears immediately.
3. Exercise confirmed aliases, editing/removing selected tags, autocomplete and IME composition.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
135cf72f3368449a6e1deb9de7fe3eaeda2f464a fix: filter selected tags from inline recommendations (#99)
```
