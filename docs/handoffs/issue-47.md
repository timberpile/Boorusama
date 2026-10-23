# Issue #47 — Local acceptance handoff

Branch: `feature/47-safebooru-preset`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54` (`develop` after the issue-ID instruction change).  
Issue: https://github.com/timberpile/Boorusama/issues/47

## Implementation

The existing `safebooru.donmai.us` Danbooru site registration now contains quick-profile metadata with the name **Safebooru (Danbooru)** and optional authentication. The existing catalog, picker, profile editor, and website-logo path consume that metadata. No new profile engine, special-case picker row, host alias, authentication policy, or migration was introduced. Danbooru and `safebooru.org` remain separate presets; custom URL setup is unchanged.

`test/core/configs/safebooru_quick_profile_test.dart` exercises the actual generated registry, rather than a copied metadata fixture. It checks the engine, name, URL, optional authentication, edit-ID prefill, and preservation of the other presets.

## Local verification required

The remote implementation environment had no Flutter/FVM SDK or clone-capable network access. Source and existing catalog/picker tests were inspected, but **Dart formatting, generation, analysis, Flutter tests, and device checks have not run**. Do not treat this as a passed acceptance or an integration-ready branch.

1. Fetch the branch and attach it to its own worktree; preserve any existing worktree and unrelated local changes. Read current `AGENTS.md` and the development workflow.
2. Initialize dependencies with the repository's FVM/bootstrap workflow as needed. Run `./gen.sh booru`: `boorus.yaml` changed, and generated files under `packages/booru_clients/lib/src/generated/` are intentionally ignored. Do not commit generated output.
3. Run:

   ```bash
   fvm dart format test/core/configs/safebooru_quick_profile_test.dart
   fvm flutter test --concurrency="$(python3 scripts/physical_core_count.py)" \
     test/core/configs/safebooru_quick_profile_test.dart \
     test/core/configs/quick_profile_site_test.dart \
     test/core/configs/quick_profile_setup_picker_test.dart
   fvm flutter analyze lib/core/configs/create test/core/configs
   (cd packages/booru_clients && fvm dart test)
   ```

4. Verify the actual picker displays **Safebooru (Danbooru)**, selecting it prepopulates `https://safebooru.donmai.us/` and the correct editable name, and saving without credentials succeeds. Check narrow width and enlarged text; confirm the Danbooru, Safebooru (`.org`), and custom URL options still work. Follow the exclusive emulator lease procedure before device work.
5. Review the entire branch diff, fix small defects on this branch, rerun affected checks, and record commands/results and the checked commit in the acceptance report. Use the complete local-suite command from `docs/engineering_guidelines.md` on any final develop integration candidate.

## Integration boundary

This branch is independent of the other quick-win branches. No merge, PR, issue closure, or branch deletion is authorized by this handoff. When integration is separately approved, include `#47` in the final Conventional Commit subject; keep `Refs #47` until acceptance is complete. Preserve this handoff until the receiving agent no longer needs it.

## Local acceptance evidence (2026-10-22)

This section supersedes the earlier unrun-verification status. Checked runtime/test commit: `14146706065dee8de3382096fb62b34b54074c2b`.

- Initialized fresh-worktree dependencies and missing generated output; `./gen.sh` included the required booru generation. Generated output remains ignored.
- Formatted the changed test with `fvm dart format`; `git diff --check` passed.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/configs`: **65 passed**.
- From `packages/booru_clients`, `fvm dart test --reporter=expanded --concurrency=6`: **104 passed**.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/configs/create test/core/configs`: passed with informational lints, no errors or warnings.
- Added a rendered picker test using the actual generated registry at 320 pixels and 2x text, with the repository's Roboto fixture font. Selecting Safebooru (Danbooru) returns the correct editable name/URL and optional-authentication metadata. Existing separate Danbooru/.org entries and custom-URL picker tests pass.

Flutter 3.47.2 / Dart 3.13.2 and six detected physical-core workers were used, with an isolated copy of the pinned SDK to avoid an unrelated startup lock.

**Acceptance remains pending Android/UI checks**, particularly saving a real new profile without credentials and exercising its editable settings. The leased emulator failed its shell health check and was released; a later check found the sole emulator leased to another task. No current-source APK or live profile-save result is claimed. No merge, push, PR, closure, branch deletion, or combined-develop verification occurred.

### Android follow-up

The emulator later recovered and became available. Under an exclusive lease, initialized Flutter native plugin metadata with `fvm flutter pub get --offline`, then built this candidate with `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Installed with `adb -s emulator-5554 install -r`, preserving existing data. APK SHA-256: `b68b77da34e4886ed75e00da8c38c3f74db16475f69ee3dd6a6ad2e387e18486`.

Maestro verified distinct Safebooru (Danbooru)/Safebooru picker entries, selected the Danbooru preset, checked the normalized `safebooru.donmai.us` / Danbooru editor heading, edited its name with the keyboard open at 360 dp width and 2x text, and created the profile without entering Login or API key. Verified the saved profile row and deleted only the temporary acceptance profile afterward. Two preliminary selector assertions were corrected for the actual normalized-host heading and combined saved name/URL semantics; they were not application failures. Screenshots: `/tmp/boorusama-acceptance/47-preset-name-keyboard-2x.png` and `47-saved-no-credentials.png`.

This completes the previously missing credential-free Android save path. No live authenticated credentials or actual remote search results were tested for this preset. No merge, push, closure, or combined-develop qualification occurred.

## Acceptance feedback follow-up (2026-10-23)

Duplicate profile captions now keep the configured name in both the shared Browse/Favorites/Search picker and the legacy Search menu. Removed appended domains and duplicate ordinals, as requested; website icons and ID-based selection remain. Blank-name fallback remains a host/URL. This supersedes the earlier collision-disambiguation requirement. The accepted Safebooru preset is unchanged.

Checked the runtime/test tree committed with this handoff. `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/navigation/profile_context_menu_test.dart test/core/navigation/favorites_profile_picker_regression_test.dart test/core/search/navigation_search_profile_test.dart test/core/configs`: **72 passed**. New duplicate-caption regression covers different domains and identical domains and selects the intended stable ID. Focused analysis of the two changed widgets and test: **No issues found**. Formatting and `git diff --check` passed. Logs: `/tmp/boorusama-47-followup/{tests-final,analyze}.log`. Flutter 3.47.2 / Dart 3.13.2, six test workers.

No new device run or complete regression was performed for this scoped caption follow-up. Earlier device/integration limits remain. Local only; no merge, push, PR, issue closure or deletion.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `df0361ab3b633ac84eb10f5637e1dc33b075d180`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

The generated registry includes the Safebooru (Danbooru) entry. The real picker opens `safebooru.donmai.us` using Danbooru, prefills the editable name, and retains optional Login/API key fields. Cancelled the creation draft; no new profile persisted. Existing Gelbooru, Safebooru.org and Default profile remain.

Reconciled #48's full profile-switch tests with the user's name-only picker labels. Both equal-name entries remain separately selectable; selecting the already active entry retains its controller and request count. The final two-file profile run passed 9 tests. Generated configuration, optional/empty auth, duplicate identity and full configuration lifecycle cases pass in the complete suite.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
