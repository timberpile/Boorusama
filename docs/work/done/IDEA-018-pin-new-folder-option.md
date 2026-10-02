# New-folder option in the pin dialog

- Priority: Normal
- Feature: Pinned searches
- Branch: `feature/pin-new-folder-option`
- Agent: `/root/implement_18`, session 2026-10-02
- Dependencies: None; base `46558a4d0`; correction base `465375370`.

## Problem and expected behavior

Creating a folder separately can persist an empty destination before pinning.
The selector must list Home, New, then existing folders. New only selects the
destination; Pin opens Create folder above the still-mounted pin form. Accept
saves the folder and its member together; cancel/error leaves a recoverable form.

## Acceptance criteria

- Destinations always appear as `[Home]`, `[New]`, then existing folders.
- Selecting New opens no dialog. Pin/Save opens Create folder above the pin form.
- Cancel closes only Create folder, preserving search name and New selection,
  without writes. Canceling the pin form also writes nothing.
- Valid acceptance saves folder/pin atomically and closes the form. Empty names,
  duplicate names, storage failures and deletion races create no orphan folder.
- Failure preserves the pin form for retry or a different destination.
- Existing-folder/Home pinning, renaming and preview feedback remain intact.
- Search-name/destination spacing and reachable actions work normally and at
  narrow width with 2x text.

## Implementation and evidence

Read AGENTS/workflow/queue and pinned-search documentation; sampled picker,
dialogs, serialized notifier and Hive repository. Used TDD and writing-good-tests.
Initial setup and generation completed in the original implementation.
Earlier UI-sequence evidence was superseded by the user's corrected acceptance.

- Correction RED: menu ordering was wrong, selection opened Create folder, gap
  was zero; narrow/2x exposed an overflowing action row. Log:
  `/tmp/boorusama-ready-18-correction-red.log`.
- Added 16px form spacing and wrapping actions. New is selection-only; asynchronous
  form submission collects the name and waits for the existing compensated
  repository operation before closing the pin form. Validation/storage errors
  display existing localized feedback inside the preserved form.
- Self-review found Kurumi's direct outside-tap/Escape dismissal bypassed the
  back guard during saves. Storage-gated RED tests reproduced both; per-form
  dismissal/shortcut guards fix them, retaining idle cancellation.
  Log: `/tmp/boorusama-ready-18-correction-inflight-red.log`.
- Final five-file focused GREEN: 86 passed, including 32 real pin-action cases.
  Covers menu geometry, stacked mounted state, typed-name preservation, empty
  validation, duplicate/storage failures and recovery to Home, concurrent
  duplicate creation, deleted existing pin, rollback, preview failure, and
  outside/back/Escape behavior during active writes. Log:
  `/tmp/boorusama-ready-18-correction-focused.log`.
- Isolated full suite: 1,505 passed in 4m44s, no failures/widget warnings.
  Log: `/tmp/boorusama-ready-18-correction-full.log`. Subsequently changed only
  analyzer-required braces and reran all focused tests.
- Analyzer: exactly the existing 227 info findings, matching the prior baseline
  lines byte-for-byte; no touched-file warning/error/info. Log:
  `/tmp/boorusama-ready-18-correction-analyze.log`.
- Final format check on five Dart files: zero changes. `git diff --check` clean.
- Fresh dev debug x64 APK built in 40.2s and installed without clearing app data.
  Build log: `/tmp/boorusama-ready-18-correction-build.log`.

## Exact-device Android acceptance

Maestro MCP and ADB targeted only `emulator-5564`. Selected its existing
Danbooru profile because the initial Gelbooru profile does not support pins.

- Passing 18-command flow proved selection-only New, disabled empty Save,
  stacked Create folder and cancel preserving typed `QA Cats` and New.
- Passing 25-command flow proved canceled named folder absent, whole-form cancel
  unpinned, then successful folder/pin creation and both dialogs closed.
- Popup hierarchy proved Home/New/existing order at y1016/1142/1268.
- Passing 25-command flow proved duplicate-name recovery without extra folder,
  preserving search name/New, then Home and existing-folder saves.
- Passing 12-command flow opened the temporary folder and its pin through
  Pinned Searches navigation.
- At 360dp width and 2x text, screenshots and two passing 9-command flows proved
  spacing, reachable actions, New selection, stacked empty folder form and
  cancellation state. No overflow was observed.
- Screenshots in `/tmp`: `boorusama-ready-18-correction-stacked.png`,
  `boorusama-ready-18-correction-order.png`,
  `boorusama-ready-18-correction-spacing.png`,
  `boorusama-ready-18-correction-narrow-2x.png`,
  `boorusama-ready-18-correction-stacked-narrow-2x.png`.
- Confirmed UI cleanup removed only `QA Cats`/`qaidea018v2` and
  `QA IDEA018 V2`; verified those and the canceled draft absent.
- Restored original profile (Gelbooru), 1080x2400, density 420, font scale 1.0,
  stylus handwriting unset and hardware-keyboard IME display 0. Read back settings.
  No credentials read or shared-account writes.

An initial pin-form assertion hit the unsupported profile, resolved by selecting
Danbooru. Cleanup initially expected an exact folder label; hierarchy showed its
`0 items` suffix and the corrected regex flow passed. These were driver/setup
failures, not product failures.

## 2026-10-02 dialog review follow-up

- Agent: `/root/implement_18_dialog`; branch: `feature/pin-new-folder-option`.
- Localized the single-line `Query: <query>` display, changed the name field
  label to `Name` and its hint to the exact query, and gave the destination a
  `Folder` form label matching the name field.
- RED: the inline-query and form-dropdown widget assertions failed before the
  change. GREEN: 38 focused tests passed; changed-file analysis found no issues.
- Full suite: 1,504 passed and one failed; compact output truncation hid the
  failing test name. The known timing-sensitive bulk-download session file
  passed all 33 tests in isolation. No second full run was made.
- Fresh dev debug x64 APK built and installed on emulator-5564 without clearing
  data. Maestro screen and hierarchy showed Query, Name/hint, Folder, and the
  Home then New menu. Selecting New opened no folder dialog; Cancel closed the
  pin form. No pin or folder was saved in this check.

## Handover

Acceptance is verified. Fresh independent review is coordinated by the parent
after the scoped commit. No push/merge/delete. Cross-box compensation retains
the documented lack of crash atomicity and cannot guarantee recovery from an
unrecoverable second failure during rollback.
