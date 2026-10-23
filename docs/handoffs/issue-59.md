# Issue #59 — Local acceptance handoff

Branch: `feature/59-pixiv-experimental`  
Implementation commit: `2374361d1c9bb3ba7a614a6cb727fdf7362c83b5`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/59

## Status and required first action

This is an implementation candidate, **not an accepted or integration-ready branch**. Flutter formatting, analysis, localization generation, automated Flutter tests, and device checks have not run. This environment has no FVM/Flutter/Dart SDK and cannot clone GitHub; changes were prepared through the GitHub connector.

**Three unrelated English resource changes remain and must be restored before acceptance.** They came from the full-file resource update and are not intended product changes:

- `settings.backup_and_restore.export_import.name_template`: restore `Save as template`.
- `settings.backup_and_restore.export_import.saved_template`: restore `Template saved`.
- `bookmark.server_favorites.accountChanged`: restore `The account changed. Saved posts are kept; fetch again for the current account.`

The following guarded cleanup performs exactly those restorations. It then checks the entire parsed resource against the base, allowing only the new `pixiv.experimental` object, before writing anything. Its replacement and rejection logic was exercised with an isolated Python fixture, **not against a local checkout of this repository**. Inspect the current diff first; if another agent has already cleaned the file, skip the script instead of bypassing its assertions.

```bash
python3 - <<'PY'
import json
import subprocess
from pathlib import Path

path = Path('packages/i18n/translations/en-US.json')
base_ref = '565a504cf714fa9de19053b22f5f761561a35f54'
base = json.loads(subprocess.check_output(
    ['git', 'show', f'{base_ref}:{path.as_posix()}'], text=True,
    encoding='utf-8',
))
base['pixiv']['experimental'] = {
    'label': 'Experimental',
    'description': (
        'Pixiv support is limited and may change. '
        'Not all website features are available.'
    ),
}
text = path.read_text(encoding='utf-8')
fixes = {
    '"name_template": "Template name"':
        '"name_template": "Save as template"',
    '"saved_template": "Saved template"':
        '"saved_template": "Template saved"',
    '"accountChanged": "The account changed. Saved posts are kept; retry later."':
        '"accountChanged": "The account changed. Saved posts are kept; fetch again for the current account."',
}
for old, new in fixes.items():
    assert text.count(old) == 1, f'Unexpected current resource: {old}'
    text = text.replace(old, new, 1)
assert json.loads(text) == base, 'Unexpected additional resource differences; review manually'
with path.open('w', encoding='utf-8', newline='') as output:
    output.write(text)
PY

git diff 565a504cf714fa9de19053b22f5f761561a35f54 -- packages/i18n/translations/en-US.json
```

After cleanup, that resource diff should contain only the four-line `pixiv.experimental` addition. Commit the correction on this branch with `#59` in the subject. Do not merge into develop merely to apply it.

## Implementation

`lib/boorus/pixiv/configs/experimental_notice.dart` adds a compact, non-interactive Experimental label and a concise limitation note. Both use `context.t` and existing Kurumi theme typography. Text wraps rather than using a fixed height.

`PixivAuthConfigView` in `lib/boorus/pixiv/configs/widgets.dart` includes the notice above the existing account controls. This is the shared authentication surface for creating a Pixiv profile and editing an existing one. There is no new acknowledgement, feature gate, profile renaming, or separate settings page. The existing refresh-token field, platform-dependent login option, signed-in status, and credential-export warning are preserved.

The intended resource change adds `pixiv.experimental.label` and `pixiv.experimental.description` to the base English locale. Other locales use the existing fallback behavior; no localization configuration change or generated files are committed. Regenerate through the existing `./gen.sh i18n` entry point before compiling.

`lib/boorus/pixiv/README.md` documents experimental status and the integration boundaries. Authentication isolation, URL validation, credential redaction, persistence compatibility, and data integrity remain mandatory. No storage, backup format, engine capability, network request, or authentication behavior is intentionally changed.

## Tests added and source review

`test/boorus/pixiv_experimental_notice_test.dart` contains focused widget tests for the label, explanation, absence of acknowledgement controls, semantics, and wrapping at 240/320 logical pixels with enlarged text, keyboard insets, and light/dark themes. These tests have **not been executed** and do not replace testing the complete profile route.

The implementation diff was inspected against the base. The production `widgets.dart` diff is confined to the new import and two inserted widgets; an intermediate bracket transcription error was corrected before publishing the branch. The remaining resource cleanup is explicitly listed above. No runtime or device acceptance is claimed.

## Required local acceptance

1. Read current `AGENTS.md`, the relevant repository-local skills, and `docs/development_workflow.md`. Fetch this branch into its own worktree and preserve other agents' changes. Inspect HEAD and apply the guarded resource cleanup above if it is still needed.
2. Bootstrap using the repository's FVM workflow and run `./gen.sh i18n`. Do not commit ignored generated localization output. Confirm the new accessors compile and non-English locales fall back correctly.
3. Format the changed Dart files with `fvm dart format`. Analyze the affected application/package scope. Run the new widget test and existing profile configuration tests, using physical-core concurrency from `python3 scripts/physical_core_count.py`. Record the actual commands, checked commit, results, and skips.
4. Add complete-route widget coverage using existing configuration fixtures for both new and existing Pixiv profiles, signed out and signed in. Confirm one notice, an unchanged token/login/passHash draft after merely opening the page, working Cancel/Save, and the existing credential warning still present. Never put a real token in fixtures, logs, or screenshots.
5. On an exclusively leased Android emulator, open Pixiv setup and edit an existing profile. Check narrow width, enlarged text, light/dark themes, keyboard open/closed, scrolling to all controls, and a non-English locale. Confirm other engines do not show this notice. No live login is required merely to render the status label; any credential-dependent test must use the user's approved test account and protect its token.
6. Review the final full diff, correct small defects on this branch, rerun the affected tests, and update this handoff with evidence. A later approved combined develop candidate must pass the complete regression suite via `./scripts/run_regression_tests.sh` before integration.

## Coordination and authorization

This branch is independent of the other quick-win branches. There is no integration dependency on the search redesign. The other branch handoffs are `docs/handoffs/issue-<number>.md` on their corresponding branches, not on develop.

The develop instruction change is already in base commit `565a504cf714fa9de19053b22f5f761561a35f54`. A later approved final integration commit subject must retain `#59`, including after squash or cherry-pick. Keep `Refs #59` while acceptance is outstanding.

No merge, pull request, issue closure, or branch deletion is authorized by this handoff. Report local acceptance and remaining blockers separately from implementation status.

## Local acceptance evidence (2026-10-22)

This section supersedes the earlier unrun-verification status. Checked runtime/test commit: `6feebb64d550fa25ee69a34c8352235b750492b1`.

- Applied the guarded three-value English resource restoration. A parsed-JSON comparison against the base confirms the resource now differs only by `pixiv.experimental`.
- Fixed the missing widget import that prevented the notice from compiling. Fixed the original semantics-test handle lifetime; added complete profile-route fixtures using the actual Pixiv engine and synthetic credentials only.
- Initialized the fresh worktree through FVM dependencies and `./gen.sh`, including required i18n generation. Generated files remain ignored. Formatted changed Dart files and passed `git diff --check`.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/application/config_lifecycle_flow_test.dart test/boorus/pixiv_experimental_notice_test.dart test/core/configs`: **79 passed**.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/pixiv/configs test/boorus/pixiv_experimental_notice_test.dart test/application/config_lifecycle_flow_test.dart test/application/support/fake_booru_backend.dart`: **no issues found**.
- Coverage includes new-profile picker/setup/cancellation; existing signed-out and signed-in profiles; one notice and the original credential-export warning; unchanged token/login/passHash draft on opening; Cancel and Save; absence on another engine; German-locale English fallback; and the original 240/320-pixel, 2x-text, light/dark, keyboard-inset widget matrix. Saving an empty credential retains the pre-existing empty-to-null normalization; signed-in values remain identical.
- Real asset I/O for changing locales runs outside the widget fake-clock zone. Application route checks await route completion or concrete state instead of waiting for unrelated loading animations.

Flutter 3.47.2 / Dart 3.13.2 and six detected physical-core workers were used with an isolated copy of the pinned SDK to avoid an unrelated startup lock.

**Acceptance remains pending Android profile-route checks**, including scrolling with the real keyboard and a non-English locale. The leased emulator did not answer its health check and was released; later it was leased to another task. No APK, live login, phone operation, merge, push, PR, closure, deletion, or combined-develop verification occurred.

### Android follow-up (2026-10-23)

Initialized native plugin metadata with `fvm flutter pub get --offline` and built this branch using `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Installed the APK with `adb -s emulator-5554 install -r` under an exclusive lease, preserving existing data. SHA-256: `d60801d7e92387446eb6d543f09140cb3e819d0121c6dd2720235804189bcf43`.

Maestro opened the real Pixiv preset setup route via its combined `Pixiv / Account required` selector. Verified exactly one Experimental notice and the separate credential warning, then checked the name field with keyboard open and the scrollable credential warning at 360 dp width and 2x system text. Canceled setup without creating an account or entering credentials. Screenshots: `/tmp/boorusama-acceptance/59-{pixiv-setup-notice,pixiv-name-keyboard-2x,pixiv-warning-2x}.png`.

The emulator has no existing Pixiv profile. Real-account edit/save and live authentication therefore remain unverified on-device; the actual production editor's preservation/cancel/save paths were covered by the 79 automated checks above. Non-English fallback was checked by a real German-locale asset fixture, not an Android language change. No merge, push, closure, deletion, or combined-develop qualification occurred.

## Popular Sites acceptance feedback (2026-10-23)

The Popular Sites picker now respects the bottom system safe area. Pixiv displays an Experimental badge directly beside Account required in its preset row; the labels wrap on constrained widths. Reused the existing badge styling and Experimental localization. The existing editor notice remains available.

Checked the runtime/test tree committed with this handoff. `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/configs test/boorus/pixiv_experimental_notice_test.dart`: **72 passed**. Four new rendered cases cover 320/360 pixels at 1x/2x text, bottom system padding, both preset badges, side-by-side placement at normal width, and selecting Pixiv. Focused analysis of the changed page and test: **No issues found**. Formatting and `git diff --check` passed. Logs: `/tmp/boorusama-59-followup/{tests,analyze}.log`. Flutter 3.47.2 / Dart 3.13.2, six workers.

No new device run or complete regression was performed for this scoped follow-up. Live authenticated Pixiv and earlier device/integration limits remain unverified. Local only; no merge, push, PR, closure or deletion.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `e158dd41f19fbe48ff4f0abb90c6cc568b065d10`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

Preserved both `additionalBoorus` (#59) and `autocompleteCategories` (#48) in the shared application backend. Parsed English-resource comparison against current develop contains exactly the preview error and two Pixiv experimental additions; historical resource cleanup was not rerun.

Maestro verified the Pixiv Popular Sites row at 360 dp/2x text: Account required and Experimental both fit (the latter wraps below at this width), with the list above the Android gesture bar. Setup displays Experimental, the limitation description, login/token controls and the unchanged credential warning. Cancelled without creating a profile. Complete-route signed-in/signed-out existing/new editor, credential preservation, Cancel/Save and locale fallback tests all pass in the complete suite. No live Pixiv authentication was needed or claimed; auth behavior is unchanged.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
